"""Future acceptance cases for GAME-WEB-MODULE-PACK-001 r1.

Development-only fixtures: no tests were executed when this file was authored.
Run explicitly with:
    python -m unittest discover -s tests -p test_package_manifest_check_candidate.py -v
"""
import hashlib
import json
import os
import stat
import tempfile
import unittest
import warnings
import zipfile
from pathlib import Path

from tools.package_manifest_check_candidate import (
    FIXED_DATE,
    FORMAT,
    check_archive,
)


DEFAULT_FILES = [
    ("project.godot", b"config_version=5\n"),
    ("scenes/\u5367\u5ba4.tscn", b"[gd_scene format=3]\n"),
    ("scripts/main.gd", b"extends Node\n"),
]


def entry(path, data, *, compress=zipfile.ZIP_STORED, mode=0o100644):
    info = zipfile.ZipInfo(path, FIXED_DATE)
    info.compress_type = compress
    info.create_system = 3
    info.external_attr = mode << 16
    return info, data


def record(path, data):
    return {
        "path": path,
        "size": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
    }


def make_zip(target, *, files=None, records=None, manifest=None,
             format_name=FORMAT, manifest_text=None, manifest_last=True):
    files = sorted(DEFAULT_FILES if files is None else files)
    records = (
        [record(path, data) for path, data in files]
        if records is None else records
    )
    manifest = {"format": format_name, "files": records} if manifest is None else manifest
    content = (
        json.dumps(manifest, ensure_ascii=False, indent=2).encode("utf-8") + b"\n"
        if manifest_text is None else manifest_text
    )
    payloads = [entry(path, data) for path, data in files]
    payloads += [entry("manifest.json", content)]
    if not manifest_last:
        payloads.reverse()
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", UserWarning)
        with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_STORED) as zf:
            for info, data in payloads:
                zf.writestr(info, data)


class ManifestCheckerAcceptance(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.archive = self.root / "candidate.zip"

    def codes(self):
        return {issue.code for issue in check_archive(self.archive).issues}

    def test_valid_zip_hash_and_unicode_path(self):
        make_zip(self.archive)
        result = check_archive(self.archive)
        self.assertTrue(result.ok, result.issues)
        self.assertEqual(result.checked_files, 3)
        self.assertEqual(result.manifest_files, 3)
        self.assertFalse(result.as_dict()["release_approved"])

    def test_manifest_hash_mismatch(self):
        rows = [record(p, d) for p, d in DEFAULT_FILES]
        rows[0]["sha256"] = "0" * 64
        make_zip(self.archive, records=rows)
        self.assertIn("HASH_MISMATCH", self.codes())

    def test_manifest_size_mismatch(self):
        rows = [record(p, d) for p, d in DEFAULT_FILES]
        rows[0]["size"] += 1
        make_zip(self.archive, records=rows)
        self.assertIn("SIZE_MISMATCH", self.codes())

    def test_missing_file_listed_in_manifest(self):
        rows = [record(p, d) for p, d in DEFAULT_FILES]
        rows.append(record("z_missing.tres", b"missing\n"))
        make_zip(self.archive, records=rows)
        self.assertIn("MEMBER_MISSING", self.codes())

    def test_file_present_but_unlisted(self):
        files = DEFAULT_FILES + [("z_unlisted.md", b"extra\n")]
        rows = [record(p, d) for p, d in DEFAULT_FILES]
        make_zip(self.archive, files=files, records=rows)
        self.assertIn("MEMBER_UNLISTED", self.codes())

    def test_duplicate_manifest_path(self):
        rows = [record(p, d) for p, d in DEFAULT_FILES]
        rows.insert(1, dict(rows[0]))
        make_zip(self.archive, records=rows)
        self.assertIn("DUPLICATE_MANIFEST_PATH", self.codes())

    def test_duplicate_zip_member(self):
        files = DEFAULT_FILES + [DEFAULT_FILES[-1]]
        make_zip(self.archive, files=files)
        self.assertIn("DUPLICATE_ZIP_MEMBER", self.codes())

    def test_parent_traversal_member_rejected(self):
        files = DEFAULT_FILES + [("../escape.gd", b"unsafe\n")]
        make_zip(self.archive, files=files)
        self.assertIn("UNSAFE_PATH", self.codes())
        self.assertFalse((self.root / "escape.gd").exists())

    def test_windows_style_member_path_rejected(self):
        files = DEFAULT_FILES + [(r"scripts\escape.gd", b"unsafe\n")]
        make_zip(self.archive, files=files)
        self.assertIn("UNSAFE_PATH", self.codes())

    def test_windows_reserved_name_rejected(self):
        files = DEFAULT_FILES + [("assets/CON.md", b"unsafe\n")]
        make_zip(self.archive, files=files)
        self.assertIn("UNSAFE_PATH", self.codes())

    def test_missing_required_project(self):
        files = [(p, d) for p, d in DEFAULT_FILES if p != "project.godot"]
        make_zip(self.archive, files=files)
        self.assertIn("MISSING_ENTRY", self.codes())

    def test_missing_required_script_or_scene(self):
        make_zip(self.archive, files=[DEFAULT_FILES[0]])
        self.assertIn("MISSING_ENTRY", self.codes())

    def test_bad_format(self):
        make_zip(self.archive, format_name="unknown-format")
        self.assertIn("FORMAT_MISMATCH", self.codes())

    def test_bad_manifest_json_and_duplicate_property(self):
        make_zip(
            self.archive,
            manifest_text=b'{"format":"GAME-WEB-PACK-001-r2","files":[],"files":[]}',
        )
        self.assertIn("INVALID_MANIFEST", self.codes())

    def test_boolean_size_and_uppercase_sha_invalid(self):
        rows = [record(p, d) for p, d in DEFAULT_FILES]
        rows[0]["size"] = True
        rows[1]["sha256"] = rows[1]["sha256"].upper()
        make_zip(self.archive, records=rows)
        codes = self.codes()
        self.assertIn("INVALID_SIZE", codes)
        self.assertIn("INVALID_SHA256", codes)

    def test_unsorted_manifest_and_zip(self):
        files = list(reversed(DEFAULT_FILES))
        rows = [record(p, d) for p, d in files]
        # make_zip sorts ZIP files, but leaves manifest records in chosen order.
        make_zip(self.archive, files=files, records=rows)
        self.assertIn("MANIFEST_ORDER", self.codes())
        self.archive.unlink()
        make_zip(self.archive, manifest_last=False)
        self.assertIn("MEMBER_ORDER", self.codes())

    def test_zip_symlink_metadata_rejected(self):
        rows = [record(p, d) for p, d in DEFAULT_FILES]
        with zipfile.ZipFile(self.archive, "w") as zf:
            for path, data in sorted(DEFAULT_FILES):
                mode = 0o120777 if path == "scripts/main.gd" else 0o100644
                zf.writestr(entry(path, data, mode=mode)[0], data)
            content = json.dumps(
                {"format": FORMAT, "files": rows}
            ).encode("utf-8")
            zf.writestr(entry("manifest.json", content)[0], content)
        self.assertIn("MEMBER_METADATA", self.codes())

    def test_zip_compression_outside_pr4_rejected(self):
        with zipfile.ZipFile(self.archive, "w") as zf:
            for path, data in sorted(DEFAULT_FILES):
                method = (
                    zipfile.ZIP_DEFLATED if path == "scripts/main.gd"
                    else zipfile.ZIP_STORED
                )
                zf.writestr(entry(path, data, compress=method)[0], data)
            content = json.dumps(
                {"format": FORMAT,
                 "files": [record(p, d) for p, d in sorted(DEFAULT_FILES)]}
            ).encode("utf-8")
            zf.writestr(entry("manifest.json", content)[0], content)
        self.assertIn("MEMBER_METADATA", self.codes())

    def test_archive_is_never_modified_or_extracted(self):
        make_zip(self.archive)
        before = self.archive.read_bytes()
        result = check_archive(self.archive)
        self.assertTrue(result.ok)
        self.assertEqual(self.archive.read_bytes(), before)
        self.assertFalse((self.root / "scripts").exists())
        self.assertFalse((self.root / "scenes").exists())

    def test_reject_archive_symlink_if_supported(self):
        make_zip(self.archive)
        alias = self.root / "link.zip"
        try:
            os.symlink(self.archive, alias)
        except (OSError, NotImplementedError) as exc:
            self.skipTest(f"symlinks unsupported or permission denied: {exc}")
        issues = check_archive(alias).issues
        self.assertIn("ARCHIVE_ERROR", {issue.code for issue in issues})

    def test_reject_archive_argument_traversal(self):
        make_zip(self.archive)
        path = self.root / "sub" / ".." / "candidate.zip"
        self.assertIn(
            "ARCHIVE_ERROR",
            {issue.code for issue in check_archive(path).issues},
        )

    def test_unsafe_unicode_casefold_collision(self):
        files = DEFAULT_FILES + [("data/\u00e9.md", b"a"), ("data/e\u0301.md", b"b")]
        make_zip(self.archive, files=files)
        self.assertIn("DUPLICATE_ZIP_MEMBER", self.codes())


if __name__ == "__main__":
    unittest.main()
