#!/usr/bin/env python3
"""GAME-WEB-CONTINUE-EVENT-003 r1 — future synthetic checks ONLY.

Do not execute as part of the development/submission task.
No private narratives, real event records or game runtime imports.
"""
from __future__ import annotations

import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path

from event_data_check_candidate import check_event_data, main
from event_report_candidate import render_text_report


def sample(event_id="EVENT_ALPHA", target=None, ignore=None):
    return {
        "event_id": event_id,
        "trigger": {
            "signal": "SIGNAL_ALPHA",
            "conditions": ["FLAG_READY"],
        },
        "actions": [
            {"action_id": "ACTION_ONE", "next_event_id": target},
            {"action_id": "ACTION_TWO", "next_event_id": None},
        ],
        "on_ignore_event_id": ignore,
    }


class CandidateRepairAdviceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def write(self, name, document):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        text = (
            document
            if type(document) is str
            else json.dumps(document, ensure_ascii=False, indent=2) + "\n"
        )
        path.write_text(text, encoding="utf-8")
        return path

    def report(self, *paths):
        return check_event_data([str(x) for x in paths])

    def issue(self, report, code):
        found = [x for x in report["issues"] if x["code"] == code]
        self.assertTrue(found, "Expected diagnostic " + code)
        return found[0]

    def test_missing_reference_gets_review_only_near_match(self):
        a = self.write(
            "a.json", sample(target="EVENT_BET")
        )
        b = self.write("b.json", sample("EVENT_BETA"))
        report = self.report(a, b)
        issue = self.issue(report, "UNKNOWN_EVENT_REFERENCE")
        advice = issue["repair_advice"]
        self.assertEqual(
            advice["suggestion_id"], "REVIEW_UNKNOWN_EVENT_REFERENCE"
        )
        self.assertFalse(advice["auto_apply"])
        self.assertTrue(advice["requires_review"])
        self.assertIn(
            "EVENT_BETA", advice["possible_spelling_matches"]
        )
        self.assertEqual(
            report["repair_review_summary"]["auto_fixes_applied"], 0
        )

    def test_missing_reference_with_no_close_match_does_not_guess(self):
        a = self.write("a.json", sample(target="EVENT_ZZZZZZ"))
        b = self.write("b.json", sample("EVENT_ALPHA2"))
        advice = self.issue(
            self.report(a, b), "UNKNOWN_EVENT_REFERENCE"
        )["repair_advice"]
        self.assertNotIn("possible_spelling_matches", advice)

    def test_candidates_exclude_structurally_invalid_definitions(self):
        a = self.write(
            "a.json", sample(target="EVENT_BET")
        )
        bad = sample("EVENT_BETA")
        bad["trigger"]["conditions"] = []
        b = self.write("b.json", bad)
        advice = self.issue(
            self.report(a, b), "UNKNOWN_EVENT_REFERENCE"
        )["repair_advice"]
        self.assertNotIn("possible_spelling_matches", advice)

    def test_candidates_exclude_duplicate_definitions(self):
        source = self.write(
            "source.json", sample(target="EVENT_BET")
        )
        a = self.write("a.json", sample("EVENT_BETA"))
        b = self.write("b.json", sample("EVENT_BETA"))
        issue = self.issue(
            self.report(source, a, b), "UNKNOWN_EVENT_REFERENCE"
        )
        self.assertNotIn(
            "possible_spelling_matches", issue["repair_advice"]
        )

    def test_ambiguous_reference_never_selects_definition(self):
        source = self.write(
            "source.json", sample(target="EVENT_BETA")
        )
        a = self.write("a.json", sample("EVENT_BETA"))
        b = self.write("b.json", sample("EVENT_BETA"))
        advice = self.issue(
            self.report(source, a, b),
            "AMBIGUOUS_EVENT_REFERENCE",
        )["repair_advice"]
        self.assertTrue(advice["review_related_locations"])
        self.assertNotIn("possible_spelling_matches", advice)
        self.assertFalse(advice["auto_apply"])

    def test_invalid_target_review_locations(self):
        a = self.write(
            "a.json", sample(ignore="EVENT_BETA")
        )
        target = sample("EVENT_BETA")
        target["unexpected"] = True
        b = self.write("b.json", target)
        issue = self.issue(
            self.report(a, b), "INVALID_EVENT_REFERENCE_TARGET"
        )
        self.assertTrue(
            issue["repair_advice"]["review_related_locations"]
        )
        self.assertEqual(issue["related"][0]["file"], b.as_posix())

    def test_duplicate_event_id_advises_references_review(self):
        a = self.write("a.json", sample("EVENT_BETA"))
        b = self.write("b.json", sample("EVENT_BETA"))
        advice = self.issue(
            self.report(a, b), "DUPLICATE_EVENT_ID"
        )["repair_advice"]
        self.assertTrue(advice["review_related_locations"])
        self.assertIn(
            "reference", " ".join(advice["steps"]).lower()
        )

    def test_duplicate_json_key_advice_links_origin(self):
        file = self.write(
            "duplicates.json",
            '{"event_id":"EVENT_ALPHA","event_id":"EVENT_BETA",'
            '"trigger":{},"actions":[]}',
        )
        issue = self.issue(
            self.report(file), "DUPLICATE_JSON_KEY"
        )
        self.assertTrue(
            issue["repair_advice"]["review_related_locations"]
        )
        self.assertEqual(
            issue["related"][0]["location"]["precision"], "exact"
        )

    def test_missing_field_advice_not_fabricated_default(self):
        data = sample()
        del data["trigger"]["signal"]
        issue = self.issue(
            self.report(self.write("bad.json", data)),
            "MISSING_FIELD",
        )
        self.assertEqual(issue["location"]["precision"], "parent")
        self.assertFalse(issue["repair_advice"]["auto_apply"])
        self.assertIn(
            "reviewed value",
            " ".join(issue["repair_advice"]["steps"]),
        )

    def test_unknown_field_advice_prevents_silent_deletion(self):
        data = sample()
        data["extra_field"] = "PRIVATE_VALUE_NOT_FOR_REPORT"
        issue = self.issue(
            self.report(self.write("bad.json", data)),
            "UNKNOWN_FIELD",
        )
        self.assertIn(
            "Do not silently delete",
            " ".join(issue["repair_advice"]["steps"]),
        )

    def test_unknown_source_values_never_copied_into_reports(self):
        data = sample()
        data["extra_field"] = "SECRET_VALUE_IN_SYNTHETIC_FIXTURE"
        report = self.report(self.write("bad.json", data))
        self.assertNotIn(
            "SECRET_VALUE_IN_SYNTHETIC_FIXTURE",
            render_text_report(report),
        )
        self.assertNotIn(
            "SECRET_VALUE_IN_SYNTHETIC_FIXTURE",
            json.dumps(report),
        )

    def test_invalid_id_has_generic_not_automatic_repair(self):
        issue = self.issue(
            self.report(self.write("bad.json", sample("lowercase"))),
            "INVALID_ID",
        )
        advice = issue["repair_advice"]
        self.assertEqual(advice["category"], "identifier")
        self.assertFalse(advice["auto_apply"])
        self.assertNotIn("possible_spelling_matches", advice)

    def test_invalid_json_advice_with_exact_syntax_location(self):
        file = self.write("bad.json", '{\n  "a": 1,\n}\n')
        issue = self.issue(self.report(file), "INVALID_JSON")
        self.assertEqual(issue["location"]["line"], 3)
        self.assertEqual(issue["repair_advice"]["category"], "format")

    def test_missing_path_advice_has_no_fake_source_line(self):
        report = self.report(self.root / "missing.json")
        issue = self.issue(report, "INPUT_NOT_FOUND")
        self.assertIsNone(issue["location"])
        self.assertEqual(issue["repair_advice"]["category"], "input")

    def test_report_summary_counts_and_versions(self):
        a = self.write("a.json", sample(target="EVENT_MISSING"))
        report = self.report(a)
        self.assertEqual(
            report["continuation_task_id"], "GAME-WEB-CONTINUE-EVENT-003"
        )
        self.assertEqual(report["continuation_version"], "r1")
        self.assertEqual(report["advice_format"], "3.0-candidate")
        self.assertEqual(report["diagnostic_format"], "2.0-candidate")
        summary = report["repair_review_summary"]
        self.assertEqual(summary["policy"], "manual_review_only")
        self.assertEqual(summary["auto_fixes_applied"], 0)
        self.assertEqual(summary["files_with_diagnostics"], 1)
        self.assertEqual(
            summary["diagnostics_by_file"][0]["issue_count"],
            report["issue_count"],
        )

    def test_text_report_has_file_line_pointer_and_advice(self):
        a = self.write("a.json", sample(target="EVENT_MISSING"))
        report = self.report(a)
        output = render_text_report(report)
        self.assertIn(a.as_posix() + ":", output)
        self.assertIn("/actions/0/next_event_id", output)
        self.assertIn("suggestion [REVIEW_UNKNOWN_EVENT_REFERENCE", output)
        self.assertIn("No repairs applied.", output)

    def test_text_report_contains_related_file_locations(self):
        ref = self.write(
            "ref.json", sample(target="EVENT_BETA")
        )
        a = self.write("a.json", sample("EVENT_BETA"))
        b = self.write("b.json", sample("EVENT_BETA"))
        output = render_text_report(self.report(ref, a, b))
        self.assertIn("AMBIGUOUS_EVENT_REFERENCE", output)
        self.assertIn("related: " + a.as_posix(), output)
        self.assertIn("related: " + b.as_posix(), output)

    def test_text_report_without_issues(self):
        file = self.write("ok.json", sample())
        report = self.report(file)
        output = render_text_report(report)
        self.assertIn("PASS:", output)
        self.assertIn("No diagnostics", output)
        self.assertNotIn("suggestion [", output)

    def test_cli_legacy_json_still_supported(self):
        file = self.write(
            "bad.json", sample(target="EVENT_UNKNOWN")
        )
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = main(["--json", str(file)])
        report = json.loads(output.getvalue())
        self.assertEqual(status, 1)
        self.assertIn("repair_review_summary", report)
        self.assertFalse(report["issues"][0]["repair_advice"]["auto_apply"])

    def test_cli_explicit_json_format(self):
        file = self.write(
            "bad.json", sample(target="EVENT_UNKNOWN")
        )
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = main(["--format", "json", str(file)])
        report = json.loads(output.getvalue())
        self.assertEqual(status, 1)
        self.assertEqual(report["advice_format"], "3.0-candidate")

    def test_cli_explicit_text_format(self):
        file = self.write(
            "bad.json", sample(target="EVENT_UNKNOWN")
        )
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = main(["--format", "text", str(file)])
        self.assertEqual(status, 1)
        self.assertIn("No repairs applied", output.getvalue())

    def test_cli_conflicting_format_flags_reject(self):
        file = self.write("ok.json", sample())
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr):
            with self.assertRaises(SystemExit) as context:
                main(["--json", "--format", "text", str(file)])
        self.assertEqual(context.exception.code, 2)

    def test_no_input_json_modified_by_advice(self):
        a = self.write("a.json", sample(target="EVENT_BETA"))
        b = self.write("b.json", sample("EVENT_BETA"))
        before = {x: x.read_bytes() for x in (a, b)}
        report = self.report(a, b)
        self.assertEqual(report["status"], "PASS")
        self.assertEqual(
            before, {x: x.read_bytes() for x in (a, b)}
        )

    def test_multiple_input_order_report_stable(self):
        a = self.write("a.json", sample(target="EVENT_MISSING"))
        b = self.write("b.json", sample("EVENT_OTHER"))
        self.assertEqual(
            self.report(a, b), self.report(b, a)
        )

    def test_unknown_issue_falls_back_to_manual_review(self):
        from event_repair_advice_candidate import advice_for_issue
        advice = advice_for_issue({"code": "FUTURE_UNKNOWN_CODE"}, [])
        self.assertFalse(advice["auto_apply"])
        self.assertTrue(advice["requires_review"])
        self.assertEqual(advice["category"], "review")

    def test_all_existing_error_categories_have_review_only_guidance(self):
        from event_repair_advice_candidate import RULES, advice_for_issue
        self.assertIn("DUPLICATE_EVENT_ID", RULES)
        self.assertIn("UNKNOWN_EVENT_REFERENCE", RULES)
        for code in RULES:
            advice = advice_for_issue({"code": code}, [])
            self.assertTrue(advice["steps"])
            self.assertFalse(advice["auto_apply"])
            self.assertTrue(advice["requires_review"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
