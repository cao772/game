#!/usr/bin/env python3
"""Future acceptance cases only. DO NOT infer a test pass from this file.

Run only when Codex/author explicitly authorizes test execution.
All data are synthetic, identifiers are intentionally non-narrative.
"""
import contextlib
import io
import json
import os
import tempfile
import unittest
from pathlib import Path

from event_data_check_candidate import check_event_data, main


def sample(event_id="EVENT_ALPHA", target=None):
    return {
        "event_id": event_id,
        "trigger": {
            "signal": "SIGNAL_ALPHA",
            "conditions": ["FLAG_READY"]
        },
        "actions": [
            {"action_id": "ACTION_ONE", "next_event_id": target},
            {"action_id": "ACTION_TWO", "next_event_id": None}
        ],
        "on_ignore_event_id": None
    }


class EventDataCheckerCandidateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def write(self, name, value):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(value, ensure_ascii=False), encoding="utf-8"
        )
        return path

    def run_check(self, *paths):
        return check_event_data([str(p) for p in paths])

    def codes(self, report):
        return {item["code"] for item in report["issues"]}

    def test_valid_two_file_forward_reference(self):
        a = self.write("a.json", sample(target="EVENT_BETA"))
        b = self.write("b.json", sample("EVENT_BETA"))
        report = self.run_check(a, b)
        self.assertEqual(report["status"], "PASS")
        self.assertEqual(report["unique_event_ids"], 2)
        self.assertEqual(report["issue_count"], 0)

    def test_valid_terminal_null_target_and_ignore(self):
        path = self.write("a.json", sample())
        self.assertEqual(self.run_check(path)["status"], "PASS")

    def test_missing_action_reference_fails(self):
        path = self.write("a.json", sample(target="EVENT_NOT_PRESENT"))
        report = self.run_check(path)
        self.assertIn("UNKNOWN_EVENT_REFERENCE", self.codes(report))
        self.assertEqual(report["status"], "FAIL")

    def test_missing_ignore_reference_fails(self):
        value = sample()
        value["on_ignore_event_id"] = "EVENT_UNKNOWN"
        path = self.write("a.json", value)
        report = self.run_check(path)
        self.assertIn("UNKNOWN_EVENT_REFERENCE", self.codes(report))

    def test_duplicate_event_id_across_files(self):
        a = self.write("a.json", sample("EVENT_A"))
        b = self.write("b.json", sample("EVENT_A"))
        report = self.run_check(a, b)
        self.assertIn("DUPLICATE_EVENT_ID", self.codes(report))
        self.assertEqual(report["unique_event_ids"], 1)

    def test_duplicate_action_id(self):
        value = sample()
        value["actions"][1]["action_id"] = "ACTION_ONE"
        path = self.write("a.json", value)
        self.assertIn(
            "DUPLICATE_ACTION_ID", self.codes(self.run_check(path))
        )

    def test_duplicate_condition_id(self):
        value = sample()
        value["trigger"]["conditions"].append("FLAG_READY")
        path = self.write("a.json", value)
        self.assertIn(
            "DUPLICATE_CONDITION", self.codes(self.run_check(path))
        )

    def test_missing_required_fields(self):
        path = self.write("a.json", {"event_id": "EVENT_A"})
        report = self.run_check(path)
        self.assertGreaterEqual(
            sum(i["code"] == "MISSING_FIELD" for i in report["issues"]), 2
        )

    def test_unknown_fields_rejected(self):
        value = sample()
        value["story_text"] = "SYNTHETIC_PLACEHOLDER"
        value["actions"][0]["unexpected"] = True
        path = self.write("a.json", value)
        report = self.run_check(path)
        self.assertIn("UNKNOWN_FIELD", self.codes(report))

    def test_invalid_identifier_types_and_values(self):
        for index, candidate in enumerate(["lowercase", 10, "", "9START"]):
            path = self.write("%d.json" % index, sample(candidate))
            report = self.run_check(path)
            self.assertIn("INVALID_ID", self.codes(report))

    def test_trigger_shape_and_conditions(self):
        value = sample()
        value["trigger"]["conditions"] = "FLAG_READY"
        path = self.write("a.json", value)
        self.assertIn(
            "ARRAY_REQUIRED", self.codes(self.run_check(path))
        )
        value["trigger"] = None
        self.write("a.json", value)
        self.assertIn(
            "OBJECT_REQUIRED", self.codes(self.run_check(path))
        )

    def test_action_shape_and_limits(self):
        value = sample()
        value["actions"] = []
        path = self.write("a.json", value)
        self.assertIn("ACTION_COUNT", self.codes(self.run_check(path)))
        value["actions"] = [None]
        self.write("a.json", value)
        self.assertIn(
            "OBJECT_REQUIRED", self.codes(self.run_check(path))
        )

    def test_duplicate_json_member_rejected_before_overwrite(self):
        path = self.root / "a.json"
        path.write_text(
            '{"event_id":"EVENT_A","event_id":"EVENT_B",'
            '"trigger":{},"actions":[]}',
            encoding="utf-8",
        )
        report = self.run_check(path)
        self.assertIn("DUPLICATE_JSON_KEY", self.codes(report))

    def test_invalid_json(self):
        path = self.root / "a.json"
        path.write_text("{", encoding="utf-8")
        report = self.run_check(path)
        self.assertIn("INVALID_JSON", self.codes(report))

    def test_nonstandard_nan_rejected(self):
        path = self.root / "a.json"
        path.write_text(
            '{"event_id":"EVENT_A","trigger":NaN,"actions":[]}',
            encoding="utf-8",
        )
        self.assertIn("INVALID_JSON", self.codes(self.run_check(path)))

    def test_invalid_utf8(self):
        path = self.root / "a.json"
        path.write_bytes(b"\xff\xfe")
        self.assertIn("INVALID_UTF8", self.codes(self.run_check(path)))

    def test_no_json_files(self):
        self.assertIn("NO_JSON_FILES", self.codes(self.run_check(self.root)))

    def test_missing_path(self):
        report = self.run_check(self.root / "missing.json")
        self.assertIn("INPUT_NOT_FOUND", self.codes(report))
        self.assertIn("NO_JSON_FILES", self.codes(report))

    def test_duplicate_input_path_does_not_duplicate_event(self):
        path = self.write("a.json", sample())
        report = self.run_check(path, path, self.root)
        self.assertEqual(report["files_selected"], 1)
        self.assertEqual(report["status"], "PASS")

    def test_recursive_directory_json_only(self):
        self.write("nested/event.json", sample())
        (self.root / "notes.txt").write_text("not JSON", encoding="utf-8")
        report = self.run_check(self.root)
        self.assertEqual(report["files_selected"], 1)
        self.assertEqual(report["status"], "PASS")

    def test_symlink_file_is_rejected_without_reading(self):
        original = self.write("original.json", sample())
        linked = self.root / "linked.json"
        try:
            linked.symlink_to(original)
        except (OSError, NotImplementedError):
            self.skipTest("Symlink creation not allowed on this machine")
        report = self.run_check(linked)
        self.assertIn("SYMLINK_FORBIDDEN", self.codes(report))
        self.assertEqual(report["files_selected"], 0)

    def test_json_file_size_limit(self):
        path = self.root / "oversized.json"
        path.write_bytes(b" " * (1024 * 1024 + 1))
        report = self.run_check(path)
        self.assertIn("FILE_TOO_LARGE", self.codes(report))

    def test_checker_leaves_source_unchanged(self):
        path = self.write("a.json", sample())
        before = path.read_bytes()
        self.run_check(path)
        self.assertEqual(path.read_bytes(), before)

    def test_issue_order_is_deterministic(self):
        a = self.write("a.json", sample(target="MISSING_A"))
        b = self.write("b.json", sample(target="MISSING_B"))
        first = self.run_check(b, a)
        second = self.run_check(a, b)
        self.assertEqual(first, second)

    def test_cli_json_output_and_nonzero_on_invalid(self):
        path = self.write("a.json", sample(target="NOT_FOUND"))
        stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            code = main(["--json", str(path)])
        report = json.loads(stream.getvalue())
        self.assertEqual(code, 1)
        self.assertEqual(report["status"], "FAIL")

    def test_cli_success_zero_for_valid(self):
        path = self.write("a.json", sample())
        stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            code = main([str(path)])
        self.assertEqual(code, 0)
        self.assertIn("PASS:", stream.getvalue())


if __name__ == "__main__":
    unittest.main(verbosity=2)
