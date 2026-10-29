#!/usr/bin/env python3
"""EVENT-002 r1 future acceptance cases: NOT_RUN.

Synthetic placeholders exclusively. No runtime or private story data.
Run only after author/Codex explicitly permits verification.
"""
from __future__ import annotations

import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path

from event_data_check_candidate import check_event_data, main


def placeholder(event_id="EVENT_ALPHA", target=None, ignore=None):
    return {
        "event_id": event_id,
        "trigger": {
            "signal": "SIGNAL_ALPHA",
            "conditions": ["FLAG_READY"],
        },
        "actions": [{
            "action_id": "ACTION_ONE",
            "next_event_id": target,
        }],
        "on_ignore_event_id": ignore,
    }


class EventSourceDiagnosticsCandidateTests(unittest.TestCase):
    def setUp(self):
        self._temp = tempfile.TemporaryDirectory()
        self.addCleanup(self._temp.cleanup)
        self.directory = Path(self._temp.name)

    def write(self, filename, value):
        path = self.directory / filename
        path.parent.mkdir(parents=True, exist_ok=True)
        if type(value) is str:
            path.write_text(value, encoding="utf-8")
        else:
            path.write_text(
                json.dumps(value, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
        return path

    def report(self, *paths):
        return check_event_data([str(path) for path in paths])

    def one(self, report, code):
        candidates = [
            issue for issue in report["issues"]
            if issue["code"] == code
        ]
        self.assertTrue(candidates, "Missing diagnostic " + code)
        return candidates[0]

    def test_json_trailing_comma_line_column(self):
        file = self.write(
            "bad.json",
            '{\n  "event_id": "EVENT_ALPHA",\n  "actions": [],\n}\n',
        )
        issue = self.one(self.report(file), "INVALID_JSON")
        self.assertEqual(issue["location"]["line"], 4)
        self.assertEqual(issue["location"]["column"], 1)
        self.assertEqual(issue["location"]["precision"], "exact")

    def test_invalid_nested_action_identifier_exact_pointer(self):
        value = placeholder()
        value["actions"][0]["action_id"] = "lowercase"
        issue = self.one(
            self.report(self.write("bad.json", value)), "INVALID_ID"
        )
        self.assertEqual(issue["pointer"], "/actions/0/action_id")
        self.assertEqual(issue["location"]["precision"], "exact")
        self.assertEqual(issue["location"]["line"], 11)
        self.assertGreater(issue["location"]["column"], 1)

    def test_missing_field_anchors_parent_not_fake_exact(self):
        value = placeholder()
        del value["trigger"]["signal"]
        issue = self.one(
            self.report(self.write("bad.json", value)), "MISSING_FIELD"
        )
        self.assertEqual(issue["pointer"], "/trigger/signal")
        self.assertEqual(issue["location"]["precision"], "parent")
        self.assertEqual(issue["location"]["line"], 3)

    def test_nested_duplicate_json_member_exact_second_key(self):
        file = self.write(
            "bad.json",
            '{\n'
            '  "event_id": "EVENT_ALPHA",\n'
            '  "trigger": {\n'
            '    "signal": "SIGNAL_ALPHA",\n'
            '    "signal": "SIGNAL_BETA",\n'
            '    "conditions": ["FLAG_READY"]\n'
            '  },\n'
            '  "actions": [{"action_id": "ACTION_ONE",'
            ' "next_event_id": null}]\n'
            '}\n',
        )
        issue = self.one(self.report(file), "DUPLICATE_JSON_KEY")
        self.assertEqual(issue["pointer"], "/trigger/signal")
        self.assertEqual(issue["location"]["line"], 5)
        self.assertEqual(issue["related"][0]["location"]["line"], 4)
        self.assertEqual(issue["location"]["precision"], "exact")

    def test_multiple_duplicate_members_all_reported(self):
        file = self.write(
            "bad.json",
            '{"event_id":"EVENT_ALPHA","event_id":"EVENT_BETA",'
            '"event_id":"EVENT_GAMMA","trigger":{}, "actions":[]}',
        )
        report = self.report(file)
        self.assertEqual(report["issue_counts_by_code"]["DUPLICATE_JSON_KEY"], 2)
        self.assertEqual(report["event_objects_read"], 0)

    def test_reference_pointer_and_target_id(self):
        file = self.write(
            "missing.json", placeholder(target="EVENT_UNKNOWN")
        )
        issue = self.one(
            self.report(file), "UNKNOWN_EVENT_REFERENCE"
        )
        self.assertEqual(issue["pointer"], "/actions/0/next_event_id")
        self.assertEqual(issue["target_id"], "EVENT_UNKNOWN")
        self.assertEqual(issue["location"]["precision"], "exact")

    def test_ambiguous_reference_has_both_definitions(self):
        source = self.write(
            "source.json", placeholder(target="EVENT_BETA")
        )
        definition_a = self.write("a.json", placeholder("EVENT_BETA"))
        definition_b = self.write("b.json", placeholder("EVENT_BETA"))
        report = self.report(source, definition_a, definition_b)
        issue = self.one(report, "AMBIGUOUS_EVENT_REFERENCE")
        self.assertEqual(issue["target_id"], "EVENT_BETA")
        self.assertEqual(issue["pointer"], "/actions/0/next_event_id")
        self.assertEqual(len(issue["related"]), 2)
        self.assertTrue(all(item["location"] for item in issue["related"]))
        self.assertNotIn(
            "UNKNOWN_EVENT_REFERENCE",
            report["issue_counts_by_code"],
        )
        self.assertEqual(report["status"], "FAIL")

    def test_duplicate_event_id_links_other_definition(self):
        first = self.write("a.json", placeholder("EVENT_BETA"))
        second = self.write("b.json", placeholder("EVENT_BETA"))
        report = self.report(first, second)
        issue = self.one(report, "DUPLICATE_EVENT_ID")
        self.assertEqual(issue["pointer"], "/event_id")
        self.assertEqual(len(issue["related"]), 1)
        self.assertEqual(issue["related"][0]["file"], first.as_posix())

    def test_reference_to_structurally_bad_definition(self):
        source = self.write("a.json", placeholder(target="EVENT_BETA"))
        malformed = placeholder("EVENT_BETA")
        malformed["trigger"]["conditions"] = []
        target = self.write("b.json", malformed)
        report = self.report(source, target)
        issue = self.one(report, "INVALID_EVENT_REFERENCE_TARGET")
        self.assertEqual(issue["target_id"], "EVENT_BETA")
        self.assertEqual(issue["related"][0]["file"], target.as_posix())
        self.assertEqual(
            issue["related"][0]["pointer"], "/event_id"
        )

    def test_reference_to_bad_field_definition_with_same_id(self):
        source = self.write(
            "source.json", placeholder(ignore="EVENT_BETA")
        )
        malformed = placeholder("EVENT_BETA")
        malformed["extra_field"] = "PLACEHOLDER_ONLY"
        target = self.write("target.json", malformed)
        issue = self.one(
            self.report(source, target), "INVALID_EVENT_REFERENCE_TARGET"
        )
        self.assertEqual(issue["pointer"], "/on_ignore_event_id")

    def test_forward_and_backward_references_both_resolve(self):
        a = self.write(
            "a.json", placeholder("EVENT_ALPHA", "EVENT_BETA")
        )
        b = self.write(
            "b.json", placeholder("EVENT_BETA", "EVENT_ALPHA")
        )
        report = self.report(a, b)
        self.assertEqual(report["status"], "PASS")
        self.assertEqual(report["references_checked"], 2)
        self.assertEqual(report["issue_counts_by_code"], {})

    def test_self_reference_is_static_valid_not_loop_semantics(self):
        path = self.write(
            "a.json", placeholder(target="EVENT_ALPHA")
        )
        report = self.report(path)
        self.assertEqual(report["status"], "PASS")
        self.assertEqual(report["references_checked"], 1)

    def test_ignore_and_action_references_both_counted(self):
        a = self.write(
            "a.json", placeholder(
                target="EVENT_BETA", ignore="EVENT_GAMMA"
            )
        )
        b = self.write("b.json", placeholder("EVENT_BETA"))
        c = self.write("c.json", placeholder("EVENT_GAMMA"))
        report = self.report(a, b, c)
        self.assertEqual(report["status"], "PASS")
        self.assertEqual(report["references_checked"], 2)

    def test_format_rejects_invalid_root_with_structured_location(self):
        path = self.write("root.json", "[1,2,3]")
        issue = self.one(self.report(path), "OBJECT_REQUIRED")
        self.assertEqual(issue["pointer"], "")
        self.assertEqual(issue["location"]["line"], 1)
        self.assertEqual(issue["location"]["column"], 1)

    def test_null_and_nonstring_references_do_not_generate_target(self):
        value = placeholder()
        value["actions"][0]["next_event_id"] = 123
        file = self.write("bad.json", value)
        report = self.report(file)
        self.assertIn("INVALID_ID", report["issue_counts_by_code"])
        self.assertEqual(report["references_checked"], 0)
        self.assertNotIn(
            "UNKNOWN_EVENT_REFERENCE", report["issue_counts_by_code"]
        )

    def test_escaped_json_pointer_token_for_unknown_field(self):
        value = placeholder()
        value["un~known/field"] = True
        issue = self.one(
            self.report(self.write("bad.json", value)), "UNKNOWN_FIELD"
        )
        self.assertEqual(issue["pointer"], "/un~0known~1field")
        self.assertEqual(issue["location"]["precision"], "exact")

    def test_unicode_character_column_not_byte_column(self):
        # A synthetic non-ASCII key before a later invalid action value.
        value = (
            '{"EXTRA_示例":true,"event_id":"EVENT_ALPHA",'
            '"trigger":{"signal":"SIGNAL_ALPHA",'
            '"conditions":["FLAG_READY"]},'
            '"actions":[{"action_id":"invalid",'
            '"next_event_id":null}]}'
        )
        file = self.write("unicode.json", value)
        report = self.report(file)
        issue = next(
            x for x in report["issues"]
            if x["pointer"] == "/actions/0/action_id"
        )
        self.assertEqual(
            issue["location"]["column_unit"], "unicode_character"
        )
        self.assertEqual(
            issue["location"]["column"],
            value.index('"action_id"') + 1,
        )

    def test_unknown_symlink_location_explicitly_unavailable(self):
        # Missing file path is an input-level finding, never a made-up
        # source line/column.
        report = self.report(self.directory / "missing.json")
        issue = self.one(report, "INPUT_NOT_FOUND")
        self.assertIsNone(issue["location"])

    def test_machine_report_diagnostic_metadata(self):
        file = self.write(
            "bad.json", placeholder(target="EVENT_UNKNOWN")
        )
        report = self.report(file)
        self.assertEqual(
            report["enhancement_task_id"], "GAME-WEB-MODULE-EVENT-002"
        )
        self.assertEqual(report["enhancement_version"], "r1")
        self.assertEqual(report["diagnostic_format"], "2.0-candidate")
        self.assertEqual(
            report["issue_counts_by_code"]["UNKNOWN_EVENT_REFERENCE"],
            1,
        )
        self.assertTrue(
            all(issue["severity"] == "error" for issue in report["issues"])
        )

    def test_text_cli_prints_line_and_column(self):
        file = self.write(
            "bad.json", placeholder(target="EVENT_UNKNOWN")
        )
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            exit_code = main([str(file)])
        self.assertEqual(exit_code, 1)
        self.assertIn(
            "UNKNOWN_EVENT_REFERENCE", out.getvalue()
        )
        self.assertIn(str(file) + ":", out.getvalue())

    def test_json_cli_round_trip_diagnostics(self):
        file = self.write(
            "bad.json", placeholder(target="EVENT_UNKNOWN")
        )
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            exit_code = main(["--json", str(file)])
        result = json.loads(out.getvalue())
        self.assertEqual(exit_code, 1)
        self.assertEqual(result["diagnostic_format"], "2.0-candidate")
        self.assertTrue(result["issues"][0]["location"])

    def test_source_files_are_not_modified(self):
        a = self.write(
            "a.json", placeholder(target="EVENT_BETA")
        )
        b = self.write("b.json", placeholder("EVENT_BETA"))
        before = {p: p.read_bytes() for p in (a, b)}
        self.report(a, b)
        self.assertEqual(
            before, {p: p.read_bytes() for p in (a, b)}
        )

    def test_report_order_independent_of_input_order(self):
        a = self.write("a.json", placeholder(target="MISSING_A"))
        b = self.write("b.json", placeholder(target="MISSING_B"))
        self.assertEqual(self.report(a, b), self.report(b, a))


if __name__ == "__main__":
    unittest.main(verbosity=2)
