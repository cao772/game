"""Future acceptance tests: GAME-WEB-CONTINUE-PACK-003 r1.

Development status: NOT_RUN. These tests are defined but MUST NOT be
executed as part of the author-requested development-only task.
"""
from __future__ import annotations

import hashlib
import json
import os
import tempfile
import unittest
import warnings
import zipfile
from pathlib import Path
from unittest import mock

from tools.package_manifest_check_candidate import (
    FIXED_DATE, FORMAT, check_archive,
)
from tools.package_manifest_delivery_candidate import (
    REPORT_FILES, REPORT_SCHEMA, TEMP_PREFIX, DeliveryError,
    _validate_target, build_report, deliver_offline, main,
)


FIXTURES = [
    ("project.godot", b"config_version=5\n"),
    ("scenes/\u5367\u5ba4.tscn", b"[gd_scene format=3]\n"),
    ("scripts/main.gd", b"extends Node\n"),
]


def record(path: str, content: bytes) -> dict:
    return {
        "path": path, "size": len(content),
        "sha256": hashlib.sha256(content).hexdigest(),
    }


def add_member(archive: zipfile.ZipFile, name: str, data: bytes) -> None:
    info = zipfile.ZipInfo(name, FIXED_DATE)
    info.compress_type = zipfile.ZIP_STORED
    info.create_system = 3
    info.external_attr = 0o100644 << 16
    archive.writestr(info, data)


def fixture_zip(path: Path, *, files=None, records=None) -> None:
    inputs = sorted(FIXTURES if files is None else files)
    rows = [record(n, d) for n, d in inputs] if records is None else records
    payload = (
        json.dumps(
            {"format": FORMAT, "files": rows},
            ensure_ascii=False, indent=2,
        ) + "\n"
    ).encode("utf-8")
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", UserWarning)
        with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED) as archive:
            for name, data in inputs:
                add_member(archive, name, data)
            add_member(archive, "manifest.json", payload)


class OfflineReviewCandidateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.input = self.folder / "input.zip"
        self.deliver = self.folder / "report.zip"
        fixture_zip(self.input)

    def report_from_bundle(self, path=None):
        with zipfile.ZipFile(path or self.deliver) as archive:
            return json.loads(archive.read("manifest-review.json"))

    def test_stable_machine_report_schema(self):
        report = build_report(self.input)
        self.assertEqual(report["schema_version"], REPORT_SCHEMA)
        self.assertEqual(report["validation_status"], "PASS")
        self.assertFalse(report["release_approved"])
        self.assertEqual(report["counts"]["checked_files"], 3)
        self.assertEqual(report["counts"]["manifest_files"], 3)
        self.assertEqual(report["counts"]["total_diagnostics"], 0)
        self.assertEqual(report["counts"]["by_category"], {})
        self.assertEqual(
            report["source"]["archive_sha256"],
            hashlib.sha256(self.input.read_bytes()).hexdigest(),
        )
        self.assertEqual(
            report["source"]["archive_size_bytes"], self.input.stat().st_size
        )
        self.assertEqual(report["source"]["archive_filename"], "input.zip")
        self.assertNotIn(str(self.folder), json.dumps(report, ensure_ascii=False))

    def test_bundle_contains_only_three_report_files(self):
        original = self.input.read_bytes()
        report = build_report(self.input)
        deliver_offline(report, self.deliver)
        self.assertEqual(self.input.read_bytes(), original)
        with zipfile.ZipFile(self.deliver) as archive:
            self.assertEqual(archive.namelist(), list(REPORT_FILES))
            self.assertEqual(archive.testzip(), None)
            self.assertTrue(
                all(info.date_time == FIXED_DATE for info in archive.infolist())
            )
            self.assertNotIn("project.godot", archive.namelist())
            self.assertNotIn("scripts/main.gd", archive.namelist())
            self.assertEqual(
                json.loads(archive.read("manifest-review.json"))["validation_status"],
                "PASS",
            )
            text = archive.read("diagnostics.txt").decode("utf-8")
            self.assertIn("Release approved: NO", text)
            self.assertIn("SHA256", text)

    def test_deterministic_bytes_two_destinations(self):
        report = build_report(self.input)
        alt = self.folder / "report-copy.zip"
        deliver_offline(report, self.deliver)
        deliver_offline(report, alt)
        self.assertEqual(self.deliver.read_bytes(), alt.read_bytes())

    def test_existing_output_never_overwritten(self):
        original = b"EXISTING AUDIT MUST BE PRESERVED"
        self.deliver.write_bytes(original)
        with self.assertRaises(DeliveryError):
            deliver_offline(build_report(self.input), self.deliver)
        self.assertEqual(self.deliver.read_bytes(), original)
        self.assertEqual(list(self.folder.glob(TEMP_PREFIX + "*.tmp")), [])

    def test_existing_output_symlink_never_followed(self):
        output_alias = self.folder / "symlink-report.zip"
        self.deliver.write_bytes(b"protected")
        try:
            os.symlink(self.deliver, output_alias)
        except (OSError, NotImplementedError) as exc:
            self.skipTest(f"symlink unavailable: {exc}")
        with self.assertRaises(DeliveryError):
            deliver_offline(build_report(self.input), output_alias)
        self.assertEqual(self.deliver.read_bytes(), b"protected")

    def test_linked_parent_is_rejected(self):
        real_parent = self.folder / "real"
        real_parent.mkdir()
        alias = self.folder / "alias"
        try:
            os.symlink(real_parent, alias, target_is_directory=True)
        except (OSError, NotImplementedError) as exc:
            self.skipTest(f"directory symlink unavailable: {exc}")
        with self.assertRaises(DeliveryError):
            deliver_offline(build_report(self.input), alias / "audit.zip")
        self.assertFalse((real_parent / "audit.zip").exists())

    def test_missing_parent_and_parent_traversal(self):
        report = build_report(self.input)
        with self.assertRaises(DeliveryError):
            deliver_offline(report, self.folder / "missing" / "report.zip")
        with self.assertRaises(DeliveryError):
            deliver_offline(report, self.folder / "tmp" / ".." / "report.zip")
        self.assertFalse(self.deliver.exists())

    def test_bad_output_extension_rejected(self):
        with self.assertRaises(DeliveryError):
            deliver_offline(build_report(self.input), self.folder / "report.json")

    def test_hardlink_failure_removes_temporary_file(self):
        report = build_report(self.input)
        with mock.patch(
            "tools.package_manifest_delivery_candidate.os.link",
            side_effect=OSError("simulated unsupported filesystem"),
        ):
            with self.assertRaises(DeliveryError):
                deliver_offline(report, self.deliver)
        self.assertFalse(self.deliver.exists())
        self.assertEqual(list(self.folder.glob(TEMP_PREFIX + "*.tmp")), [])

    def test_duplicate_diagnostic_has_rule_related_path_and_index(self):
        files = FIXTURES + [("scripts/MAIN.gd", b"collision\n")]
        self.input.unlink()
        fixture_zip(self.input, files=files)
        report = build_report(self.input)
        self.assertEqual(report["validation_status"], "FAIL")
        matches = [
            d for d in report["diagnostics"]
            if d["code"] == "DUPLICATE_ZIP_MEMBER"
        ]
        self.assertEqual(len(matches), 1)
        self.assertEqual(matches[0]["category"], "duplicates")
        self.assertEqual(matches[0]["rule"], "UNICODE_CASEFOLD_NFC_COLLISION")
        self.assertIn("scripts/", matches[0]["related_path"])
        self.assertIsInstance(matches[0]["index"], int)
        self.assertIn("remediation", matches[0])
        self.assertFalse(report["release_approved"])

    def test_manifest_duplicate_diagnostic_enriched(self):
        rows = [record(n, d) for n, d in FIXTURES]
        rows.append(dict(rows[1]))
        self.input.unlink()
        fixture_zip(self.input, records=rows)
        result = check_archive(self.input)
        match = next(i for i in result.issues if i.code == "DUPLICATE_MANIFEST_PATH")
        self.assertEqual(match.rule, "EXACT_DUPLICATE")
        self.assertEqual(match.related_path, rows[1]["path"])
        self.assertEqual(match.index, len(rows) - 1)

    def test_parent_traversal_rule_and_escaped_diagnostics(self):
        files = FIXTURES + [("../private.gd", b"NEVER EXTRACT\n")]
        self.input.unlink()
        fixture_zip(self.input, files=files)
        report = build_report(self.input)
        unsafe = [d for d in report["diagnostics"] if d["code"] == "UNSAFE_PATH"]
        self.assertTrue(unsafe)
        self.assertEqual(unsafe[0]["category"], "path_safety")
        self.assertEqual(unsafe[0]["rule"], "PATH_TRAVERSAL_OR_EMPTY_SEGMENT")
        deliver_offline(report, self.deliver)
        self.assertEqual(self.report_from_bundle()["validation_status"], "FAIL")
        self.assertFalse((self.folder / "private.gd").exists())

    def test_missing_and_hash_discrepancies_in_report(self):
        rows = [record(n, d) for n, d in FIXTURES]
        rows[0]["sha256"] = "0" * 64
        rows.append(record("missing/data.md", b"not present"))
        self.input.unlink()
        fixture_zip(self.input, records=rows)
        report = build_report(self.input)
        codes = {d["code"] for d in report["diagnostics"]}
        self.assertIn("HASH_MISMATCH", codes)
        self.assertIn("MEMBER_MISSING", codes)
        self.assertEqual(
            report["counts"]["total_diagnostics"], len(report["diagnostics"])
        )
        self.assertEqual(
            [d["id"] for d in report["diagnostics"]],
            [f"D{i:04d}" for i in range(1, len(codes) + 1)],
        )

    def test_invalid_input_still_delivers_failure_report(self):
        self.input.unlink()
        report = build_report(self.input)
        self.assertEqual(report["validation_status"], "FAIL")
        self.assertIsNone(report["source"]["archive_sha256"])
        codes = {d["code"] for d in report["diagnostics"]}
        self.assertIn("ARCHIVE_ERROR", codes)
        self.assertIn("ARCHIVE_FINGERPRINT_ERROR", codes)
        deliver_offline(report, self.deliver)
        self.assertTrue(self.deliver.is_file())

    def test_source_byte_mutation_between_passes_is_reported(self):
        first = {"name": "input.zip", "size_bytes": 100, "sha256": "a" * 64}
        second = {"name": "input.zip", "size_bytes": 100, "sha256": "b" * 64}
        with mock.patch(
            "tools.package_manifest_delivery_candidate._fingerprint_optional",
            side_effect=[(first, None), (second, None)],
        ):
            report = build_report(self.input)
        self.assertEqual(report["validation_status"], "FAIL")
        self.assertIsNone(report["source"]["archive_sha256"])
        self.assertIn(
            "ARCHIVE_CHANGED", {d["code"] for d in report["diagnostics"]}
        )

    def test_cli_creates_single_bundle_and_refuses_repeat(self):
        self.assertEqual(main(["--archive", str(self.input), "--deliver", str(self.deliver)]), 0)
        before = self.deliver.read_bytes()
        self.assertEqual(main(["--archive", str(self.input), "--deliver", str(self.deliver)]), 2)
        self.assertEqual(before, self.deliver.read_bytes())

    def test_cli_validation_failure_returns_1_but_keeps_evidence(self):
        rows = [record(n, d) for n, d in FIXTURES]
        rows[0]["sha256"] = "0" * 64
        self.input.unlink()
        fixture_zip(self.input, records=rows)
        self.assertEqual(main(["--archive", str(self.input), "--deliver", str(self.deliver)]), 1)
        self.assertEqual(self.report_from_bundle()["validation_status"], "FAIL")

    def test_json_report_keeps_backward_compatible_issue_fields(self):
        rows = [record(n, d) for n, d in FIXTURES]
        rows[0]["sha256"] = "0" * 64
        self.input.unlink()
        fixture_zip(self.input, records=rows)
        report = check_archive(self.input).as_dict()
        self.assertEqual(report["status"], "FAIL")
        self.assertTrue(all("code" in i and "path" in i and "detail" in i
                            for i in report["issues"]))
        self.assertFalse(report["release_approved"])


if __name__ == "__main__":
    unittest.main()
