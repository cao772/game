
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GAME-WEB-PACK-001 / W-PACK / r2

Independent Godot source packaging candidate.
Python 3.12+ / standard library only.

Usage:
    python package_manifest_candidate_r2.py --self-test

    python package_manifest_candidate_r2.py \
        --source ./godot_project \
        --output ./artifacts/game_source.zip

Security properties:
- Strict source whitelist
- Canonical source root throughout the pipeline
- Symlink and Windows reparse-point rejection
- No traversal or out-of-root resolved paths
- UTF-8 text validation
- Deterministic ZIP member order and timestamps
- SHA256 manifest
- Atomic, no-overwrite publication using hard links
- Temporary artifact removal on failure

Does not execute packaged files.
Does not validate licenses or release readiness.
"""

import argparse
import codecs
import hashlib
import json
import os
import stat
import sys
import tempfile
import unittest
import zipfile

from pathlib import Path
from unittest import mock


VERSION = "GAME-WEB-PACK-001-r2"

ALLOWED = {
    ".gd",
    ".tscn",
    ".tres",
    ".md",
    ".json",
}

BLOCKED_DIRS = {
    ".git",
    ".godot",
    ".env",
    ".venv",
    "venv",
    "env",
    "ops",
    "cookie",
    "cookies",
    "secrets",
    "credentials",
    "__pycache__",
    "node_modules",
    "dist",
    "build",
    "evidence",
    "screenshots",
    "raw_chat",
    "raw_chats",
    "chat_logs",
    "chat_exports",
    "transcripts",
    "原始聊天",
    "原始对话",
    "聊天记录",
    "聊天导出",
    "对话记录",
    "证据",
    "证据图片",
}

BLOCKED_NAMES = {
    ".env",
    "env",
    "environment",
    "cookie",
    "cookies",
    "secrets",
    "credentials",
    "manifest.json",
}

SENSITIVE_MARKERS = (
    "cookie",
    "credential",
    "secret",
    "raw_chat",
    "chat_export",
    "chat_log",
    "conversation_export",
    "transcript",
    "原始聊天",
    "原始对话",
    "聊天记录",
    "聊天导出",
    "对话记录",
    "会话导出",
)

CHUNK = 1024 * 1024

FIXED_DATE = (1980, 1, 1, 0, 0, 0)


class PackageError(Exception):
    """Packaging rejected before archive publication."""


def absolute_path(raw):
    """
    Reject traversal before computing an absolute path.
    This is a lexical check, not a containment check.
    """
    path = Path(raw).expanduser()

    if ".." in path.parts:
        raise PackageError(
            "Directory traversal in argument"
        )

    return path.absolute()


def assert_node(path):
    """
    Reject symlinks, Windows reparse points,
    and filesystem nodes other than files/directories.
    """
    meta = os.lstat(path)

    if stat.S_ISLNK(meta.st_mode):
        raise PackageError(
            f"Symbolic link: {path}"
        )

    reparse = getattr(
        stat,
        "FILE_ATTRIBUTE_REPARSE_POINT",
        0x400,
    )

    attributes = getattr(
        meta,
        "st_file_attributes",
        0,
    )

    if attributes & reparse:
        raise PackageError(
            f"Windows reparse point: {path}"
        )

    if not (
        stat.S_ISDIR(meta.st_mode)
        or stat.S_ISREG(meta.st_mode)
    ):
        raise PackageError(
            f"Special filesystem node: {path}"
        )

    return meta


def assert_ancestors(path):
    """
    Reject link/reparse ancestors rather than trusting
    Path.resolve() to follow them silently.
    """
    for node in (*reversed(path.parents), path):
        assert_node(node)


def assert_inside(path, canonical_root):
    """
    Resolve the inspected path, then compare it only
    against the canonical source root.

    Never compare a resolved candidate with an
    unnormalized source argument.
    """
    resolved = path.resolve(strict=True)

    if not resolved.is_relative_to(canonical_root):
        raise PackageError(
            f"Path escapes source: {path}"
        )


def windows_reserved_component(name):
    """
    Python 3.13+ on Windows provides os.path.isreserved.
    This function also supplies a conservative fallback
    for Python 3.12 and non-Windows platforms.

    No PureWindowsPath.is_reserved() dependency.
    """
    native = getattr(
        os.path,
        "isreserved",
        None,
    )

    if native is not None and native(name):
        return True

    if name.endswith((" ", ".")):
        return True

    forbidden = '<>:"/\\|?*'

    if any(char in forbidden for char in name):
        return True

    if any(ord(char) < 32 for char in name):
        return True

    stem = name.split(".", 1)[0]
    stem = stem.rstrip(" ").casefold()

    if stem in {
        "con",
        "prn",
        "aux",
        "nul",
        "conin$",
        "conout$",
    }:
        return True

    if (
        len(stem) == 4
        and stem[:3] in {"com", "lpt"}
        and stem[3] in "123456789¹²³"
    ):
        return True

    return False


def safe_relative(path, canonical_root):
    """
    Create an archive-relative POSIX path.

    Both path and canonical_root must originate from
    the same canonical traversal root.
    """
    try:
        relative = path.relative_to(canonical_root)
    except ValueError as exc:
        raise PackageError(
            f"Path is not under canonical root: {path}"
        ) from exc

    parts = relative.parts

    if not parts:
        raise PackageError(
            "Empty relative path"
        )

    for part in parts:
        if part in ("", ".", ".."):
            raise PackageError(
                f"Unsafe member path: {relative}"
            )

        if windows_reserved_component(part):
            raise PackageError(
                f"Reserved member path: {relative}"
            )

    return relative.as_posix()


def excluded_file(name):
    lower = name.casefold()

    if lower in BLOCKED_NAMES:
        return True

    if lower.startswith(".env"):
        return True

    if lower.endswith(
        (".env", ".env.json", ".local.json")
    ):
        return True

    if any(
        marker in lower
        for marker in SENSITIVE_MARKERS
    ):
        return True

    return False


def scan_source(canonical_root):
    """
    Traverse only from the canonical source root.

    Important r2 invariant:
        walk_root == canonical_root

    All relative paths and containment checks use
    this same root object.
    """
    included = []
    excluded = []
    unknown = []

    def walk(folder):
        # Recheck the directory before traversal.
        assert_node(folder)
        assert_inside(folder, canonical_root)

        with os.scandir(folder) as iterator:
            entries = sorted(
                iterator,
                key=lambda entry: entry.name,
            )

        for entry in entries:
            path = Path(entry.path)

            meta = assert_node(path)

            relative = safe_relative(
                path,
                canonical_root,
            )

            assert_inside(
                path,
                canonical_root,
            )

            if stat.S_ISDIR(meta.st_mode):
                if (
                    entry.name.casefold()
                    in BLOCKED_DIRS
                ):
                    excluded.append(
                        relative + "/"
                    )
                else:
                    walk(path)

                continue

            name = entry.name

            if relative == "manifest.json":
                raise PackageError(
                    "Source manifest.json conflicts "
                    "with generated manifest"
                )

            if excluded_file(name):
                excluded.append(relative)
                continue

            # Only the root project.godot is accepted.
            if relative == "project.godot":
                included.append(
                    (relative, path)
                )

            elif path.suffix in ALLOWED:
                included.append(
                    (relative, path)
                )

            elif path.suffix == ".godot":
                excluded.append(relative)

            else:
                unknown.append(relative)

    # r2: always enter via canonical_root.
    walk(canonical_root)

    included.sort(
        key=lambda item: item[0]
    )

    members = [
        item[0]
        for item in included
    ]

    if "project.godot" not in members:
        raise PackageError(
            "Missing root project.godot"
        )

    if not any(
        Path(name).suffix in (".gd", ".tscn")
        for name in members
    ):
        raise PackageError(
            "At least one .gd or .tscn "
            "file is required"
        )

    # Prevent collisions on case-insensitive systems.
    seen = set()

    for name in members + ["manifest.json"]:
        folded = name.casefold()

        if folded in seen:
            raise PackageError(
                "Case-insensitive member collision: "
                f"{name}"
            )

        seen.add(folded)

    return (
        included,
        sorted(excluded),
        sorted(unknown),
    )


def zip_info(name):
    info = zipfile.ZipInfo(
        name,
        FIXED_DATE,
    )

    info.compress_type = zipfile.ZIP_STORED
    info.create_system = 3
    info.external_attr = 0o100644 << 16
    info.flag_bits |= 0x800

    return info


def same_file(a, b):
    """
    Best-effort modification check during packaging.
    """
    return (
        a.st_dev == b.st_dev
        and a.st_ino == b.st_ino
        and a.st_size == b.st_size
        and a.st_mtime_ns == b.st_mtime_ns
    )


def copy_verified(
    zf,
    relative,
    path,
    canonical_root,
):
    """
    Read a regular UTF-8 text file and write its
    bytes directly to the deterministic archive.
    """
    before = assert_node(path)

    assert_inside(
        path,
        canonical_root,
    )

    if not stat.S_ISREG(before.st_mode):
        raise PackageError(
            f"Not a regular file: {relative}"
        )

    flags = os.O_RDONLY
    flags |= getattr(os, "O_BINARY", 0)
    flags |= getattr(os, "O_NOFOLLOW", 0)

    fd = os.open(path, flags)

    try:
        opened = os.fstat(fd)

        if not same_file(before, opened):
            raise PackageError(
                "File changed before reading: "
                f"{relative}"
            )

        digest = hashlib.sha256()

        decoder = codecs.getincrementaldecoder(
            "utf-8"
        )(errors="strict")

        size = 0

        with os.fdopen(fd, "rb") as reader:
            fd = -1

            with zf.open(
                zip_info(relative),
                "w",
            ) as writer:

                while True:
                    block = reader.read(CHUNK)

                    if not block:
                        break

                    if b"\x00" in block:
                        raise PackageError(
                            "Binary/NUL content: "
                            f"{relative}"
                        )

                    try:
                        decoder.decode(
                            block,
                            final=False,
                        )
                    except UnicodeDecodeError as exc:
                        raise PackageError(
                            "Non-UTF-8 content: "
                            f"{relative}"
                        ) from exc

                    writer.write(block)
                    digest.update(block)
                    size += len(block)

                try:
                    decoder.decode(
                        b"",
                        final=True,
                    )
                except UnicodeDecodeError as exc:
                    raise PackageError(
                        "Invalid UTF-8 ending: "
                        f"{relative}"
                    ) from exc

            after = os.fstat(
                reader.fileno()
            )

            if not same_file(opened, after):
                raise PackageError(
                    "File modified while reading: "
                    f"{relative}"
                )

        current = assert_node(path)

        assert_inside(
            path,
            canonical_root,
        )

        if not same_file(before, current):
            raise PackageError(
                "Source changed during packaging: "
                f"{relative}"
            )

        return {
            "path": relative,
            "size": size,
            "sha256": digest.hexdigest(),
        }

    finally:
        if fd >= 0:
            os.close(fd)


def package(source_arg, output_arg):
    """
    Package the source tree into a new ZIP.

    r2 path normalization:
      source_input -> canonical_root
      output_input.parent -> canonical_parent

    All archive operations use canonical_root.
    """
    source_input = absolute_path(
        source_arg
    )

    output_input = absolute_path(
        output_arg
    )

    # Verify original source path before resolving it.
    assert_ancestors(source_input)

    if not source_input.is_dir():
        raise PackageError(
            "Source must be a directory"
        )

    # This is the only source root used afterward.
    canonical_root = source_input.resolve(
        strict=True
    )

    assert_ancestors(canonical_root)

    parent_input = output_input.parent

    # Reject output parent symlinks/reparse points.
    assert_ancestors(parent_input)

    if not parent_input.is_dir():
        raise PackageError(
            "Output parent must exist"
        )

    canonical_parent = parent_input.resolve(
        strict=True
    )

    assert_ancestors(canonical_parent)

    output = (
        canonical_parent
        / output_input.name
    )

    # Compare canonical paths only.
    if output.resolve(
        strict=False
    ).is_relative_to(canonical_root):
        raise PackageError(
            "Output must be outside source"
        )

    if os.path.lexists(output):
        raise PackageError(
            "Output already exists"
        )

    # r2 critical fix:
    # Pass canonical_root, never source_input.
    included, excluded, unknown = scan_source(
        canonical_root
    )

    temp_path = None

    try:
        with tempfile.NamedTemporaryFile(
            mode="wb",
            prefix=".game-pack-",
            suffix=".tmp",
            dir=canonical_parent,
            delete=False,
        ) as temporary:

            temp_path = Path(
                temporary.name
            )

        records = []

        with zipfile.ZipFile(
            temp_path,
            mode="w",
            compression=zipfile.ZIP_STORED,
            allowZip64=True,
        ) as zf:

            for relative, path in included:
                records.append(
                    copy_verified(
                        zf,
                        relative,
                        path,
                        canonical_root,
                    )
                )

            manifest = {
                "format": VERSION,
                "files": records,
            }

            payload = (
                json.dumps(
                    manifest,
                    ensure_ascii=False,
                    indent=2,
                ) + "\n"
            ).encode("utf-8")

            zf.writestr(
                zip_info("manifest.json"),
                payload,
            )

        # Atomic publication on the same filesystem.
        # os.link() fails if output already exists.
        # Do not fall back to overwriting or copying.
        os.link(
            temp_path,
            output,
        )

    finally:
        if temp_path is not None:
            temp_path.unlink(
                missing_ok=True
            )

    return {
        "status": "candidate_not_release_approved",
        "output": str(output),
        "packed_count": len(records),
        "manifest": "manifest.json",
        "skipped_excluded": excluded,
        "skipped_unknown_extensions": unknown,
    }


class PackageTests(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()

        self.addCleanup(
            self.tmp.cleanup
        )

        self.base = Path(
            self.tmp.name
        )

        self.source = (
            self.base / "source"
        )

        self.source.mkdir()

        self.output = (
            self.base / "package.zip"
        )

    def put(self, name, content=b""):
        path = self.source / name

        path.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        path.write_bytes(content)

        return path

    def valid_source(self):
        self.put(
            "project.godot",
            b"config_version=5\n",
        )

        self.put(
            "scripts/main.gd",
            b"extends Node\n",
        )

        self.put(
            "scenes/卧室.tscn",
            b"[gd_scene format=3]\n",
        )

    # Original test 1
    def test_reproducibility_hash_and_exclusion(self):
        self.valid_source()

        self.put(
            "data/config.json",
            b'{"x":1}\n',
        )

        self.put(
            "README.md",
            b"# Demo\n",
        )

        self.put(
            "assets/image.png",
            b"PNGDATA",
        )

        self.put(
            "assets/model.bin",
            b"BINARY",
        )

        self.put(
            ".git/config",
            b"private",
        )

        self.put(
            ".godot/cache",
            b"cache",
        )

        self.put(
            "ops/run.md",
            b"internal",
        )

        self.put(
            "Cookie/session.json",
            b"secret",
        )

        self.put(
            ".env",
            b"SECRET=123",
        )

        self.put(
            "原始聊天/log.md",
            b"private",
        )

        first = package(
            self.source,
            self.output,
        )

        second_path = (
            self.base / "second.zip"
        )

        package(
            self.source,
            second_path,
        )

        self.assertEqual(
            self.output.read_bytes(),
            second_path.read_bytes(),
        )

        self.assertIn(
            "assets/image.png",
            first["skipped_unknown_extensions"],
        )

        self.assertIn(
            "assets/model.bin",
            first["skipped_unknown_extensions"],
        )

        with zipfile.ZipFile(
            self.output
        ) as zf:

            names = zf.namelist()

            self.assertEqual(
                names,
                sorted(names[:-1])
                + ["manifest.json"],
            )

            self.assertIsNone(
                zf.testzip()
            )

            self.assertTrue(
                all(
                    info.date_time == FIXED_DATE
                    for info in zf.infolist()
                )
            )

            self.assertNotIn(
                "Cookie/session.json",
                names,
            )

            self.assertNotIn(
                "ops/run.md",
                names,
            )

            self.assertNotIn(
                ".git/config",
                names,
            )

            self.assertNotIn(
                ".godot/cache",
                names,
            )

            self.assertNotIn(
                "assets/image.png",
                names,
            )

            manifest = json.loads(
                zf.read("manifest.json")
            )

            self.assertEqual(
                [
                    r["path"]
                    for r in manifest["files"]
                ],
                names[:-1],
            )

            for record in manifest["files"]:
                data = zf.read(
                    record["path"]
                )

                self.assertEqual(
                    record["size"],
                    len(data),
                )

                self.assertEqual(
                    record["sha256"],
                    hashlib.sha256(
                        data
                    ).hexdigest(),
                )

    # Original test 2
    def test_missing_entry(self):
        self.put(
            "scripts/main.gd",
            b"extends Node\n",
        )

        with self.assertRaises(PackageError):
            package(
                self.source,
                self.output,
            )

        self.put(
            "project.godot",
            b"config_version=5\n",
        )

        (
            self.source / "scripts/main.gd"
        ).unlink()

        with self.assertRaises(PackageError):
            package(
                self.source,
                self.output,
            )

        self.assertFalse(
            self.output.exists()
        )

    # Original test 3
    def test_existing_output(self):
        self.valid_source()

        self.output.write_bytes(
            b"DO_NOT_OVERWRITE"
        )

        with self.assertRaises(PackageError):
            package(
                self.source,
                self.output,
            )

        self.assertEqual(
            self.output.read_bytes(),
            b"DO_NOT_OVERWRITE",
        )

    # Original test 4
    def test_output_inside_and_traversal(self):
        self.valid_source()

        with self.assertRaises(PackageError):
            package(
                self.source,
                self.source / "inside.zip",
            )

        with self.assertRaises(PackageError):
            package(
                self.source,
                self.source / ".." / "escape.zip",
            )

    # Original test 5
    def test_disguised_binary(self):
        self.valid_source()

        self.put(
            "data/fake.json",
            b"\x00\xff",
        )

        with self.assertRaises(PackageError):
            package(
                self.source,
                self.output,
            )

        self.assertFalse(
            self.output.exists()
        )

        leftovers = list(
            self.base.glob(
                ".game-pack-*.tmp"
            )
        )

        self.assertEqual(
            leftovers,
            [],
        )

    # Original test 6
    def test_link_rejection(self):
        self.valid_source()

        outside = (
            self.base / "outside.gd"
        )

        outside.write_text(
            "extends Node\n",
            encoding="utf-8",
        )

        link = (
            self.source / "linked.gd"
        )

        try:
            os.symlink(
                outside,
                link,
            )
        except (
            OSError,
            NotImplementedError,
        ) as exc:
            self.skipTest(
                "OS cannot create test symlink: "
                f"{exc}"
            )

        with self.assertRaises(PackageError):
            package(
                self.source,
                self.output,
            )

        self.assertFalse(
            self.output.exists()
        )

        link.unlink()

        outside_dir = (
            self.base / "outside_dir"
        )

        outside_dir.mkdir()

        dir_link = (
            self.source / "linked_dir"
        )

        try:
            os.symlink(
                outside_dir,
                dir_link,
                target_is_directory=True,
            )
        except (
            OSError,
            NotImplementedError,
        ) as exc:
            self.skipTest(
                "OS cannot create directory symlink: "
                f"{exc}"
            )

        with self.assertRaises(PackageError):
            package(
                self.source,
                self.output,
            )

        self.assertFalse(
            self.output.exists()
        )

    # New regression test 7
    def test_canonical_root_consistency_without_8dot3(self):
        """
        Regression for the Windows short/long path bug.

        The test does NOT require Windows 8.3 aliases.

        It observes the actual object returned by
        source.resolve(strict=True), then requires
        scan_source(), safe_relative(), and
        copy_verified() to receive that SAME root
        object, not merely a path that compares equal.

        The original r1 scan_source(source_input)
        call violates this contract.
        """
        self.valid_source()

        observed = {
            "root": None,
            "scan": 0,
            "relative": 0,
            "copy": 0,
        }

        original_resolve = Path.resolve
        original_scan = scan_source
        original_relative = safe_relative
        original_copy = copy_verified

        def tracked_resolve(path, strict=False):
            result = original_resolve(
                path,
                strict=strict,
            )

            # Capture the canonical root returned
            # from the initial source resolution.
            if (
                strict
                and path == self.source
                and observed["root"] is None
            ):
                observed["root"] = result

            return result

        def tracked_scan(root):
            self.assertIsNotNone(
                observed["root"]
            )

            self.assertIs(
                root,
                observed["root"],
                "scan_source must receive canonical root",
            )

            observed["scan"] += 1

            return original_scan(root)

        def tracked_relative(path, root):
            self.assertIs(
                root,
                observed["root"],
                "safe_relative must receive canonical root",
            )

            observed["relative"] += 1

            return original_relative(
                path,
                root,
            )

        def tracked_copy(
            zf,
            relative,
            path,
            root,
        ):
            self.assertIs(
                root,
                observed["root"],
                "copy_verified must receive canonical root",
            )

            observed["copy"] += 1

            return original_copy(
                zf,
                relative,
                path,
                root,
            )

        with (
            mock.patch.object(
                Path,
                "resolve",
                autospec=True,
                side_effect=tracked_resolve,
            ),
            mock.patch(
                f"{__name__}.scan_source",
                side_effect=tracked_scan,
            ),
            mock.patch(
                f"{__name__}.safe_relative",
                side_effect=tracked_relative,
            ),
            mock.patch(
                f"{__name__}.copy_verified",
                side_effect=tracked_copy,
            ),
        ):
            result = package(
                self.source,
                self.output,
            )

        self.assertEqual(
            result["packed_count"],
            3,
        )

        self.assertTrue(
            self.output.is_file()
        )

        self.assertEqual(
            observed["scan"],
            1,
        )

        self.assertGreaterEqual(
            observed["relative"],
            3,
        )

        self.assertEqual(
            observed["copy"],
            3,
        )


def self_test():
    suite = (
        unittest.defaultTestLoader
        .loadTestsFromTestCase(PackageTests)
    )

    result = unittest.TextTestRunner(
        verbosity=2
    ).run(suite)

    return (
        0
        if result.wasSuccessful()
        else 1
    )


def main():
    parser = argparse.ArgumentParser(
        description=VERSION
    )

    parser.add_argument(
        "--source"
    )

    parser.add_argument(
        "--output"
    )

    parser.add_argument(
        "--self-test",
        action="store_true",
    )

    args = parser.parse_args()

    if args.self_test:
        return self_test()

    if (
        not args.source
        or not args.output
    ):
        parser.error(
            "--source and --output are required"
        )

    try:
        result = package(
            args.source,
            args.output,
        )

    except (
        PackageError,
        OSError,
        ValueError,
        zipfile.BadZipFile,
    ) as exc:

        print(
            f"PACKAGING_FAILED: {exc}",
            file=sys.stderr,
        )

        return 1

    print(
        json.dumps(
            result,
            ensure_ascii=False,
            indent=2,
        )
    )

    return 0


if __name__ == "__main__":
    sys.exit(main())
