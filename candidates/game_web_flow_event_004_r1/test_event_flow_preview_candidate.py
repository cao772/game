#!/usr/bin/env python3
"""Prospective acceptance for GAME-WEB-FLOW-EVENT-004 r1.

NOT_RUN. Synthetic identifiers only; no engine, save, or story imports.
Codex may execute after explicit validation authorization.
"""
from __future__ import annotations

import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from event_flow_preview_candidate import (
    CheckedEventPreview, IGNORE, MAX_CHOICES, PreviewFailure,
    main, render_text,
)


def event(event_id: str, actions: list[tuple[str, str | None]],
          *, ignore: str | None = None, include_ignore: bool = False):
    doc = {
        "event_id": event_id,
        "trigger": {
            "signal": "SIGNAL_READY",
            "conditions": ["FLAG_READY"],
        },
        "actions": [
            {"action_id": action, "next_event_id": target}
            for action, target in actions
        ],
    }
    if include_ignore:
        doc["on_ignore_event_id"] = ignore
    return doc


class FlowPreviewCandidateTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.a = self.write("a.json", event(
            "EVENT_ALPHA",
            [("ACTION_TO_BETA", "EVENT_BETA"),
             ("ACTION_STOP", None)],
            ignore="EVENT_GAMMA",
            include_ignore=True,
        ))
        self.b = self.write("b.json", event(
            "EVENT_BETA", [("ACTION_FINISH", None)]
        ))
        self.c = self.write("c.json", event(
            "EVENT_GAMMA", [("ACTION_RESTART", "EVENT_ALPHA")]
        ))

    def write(self, name, obj):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(obj, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        return path

    def loader(self, *paths):
        return CheckedEventPreview(
            [str(path) for path in paths] if paths else [str(self.root)]
        )

    def assert_error(self, code, operation):
        with self.assertRaises(PreviewFailure) as raised:
            operation()
        self.assertEqual(raised.exception.code, code)
        return raised.exception

    def test_initial_event_lists_configured_actions_and_ignore(self):
        view = self.loader()
        report = view.preview("EVENT_ALPHA")
        self.assertEqual(report["preview_status"], "offered")
        self.assertEqual(report["trace"], [])
        self.assertEqual(
            [x["choice"] for x in report["available_choices"]],
            ["ACTION_TO_BETA", "ACTION_STOP", IGNORE],
        )
        self.assertTrue(report["no_runtime_effects"])
        self.assertTrue(report["no_source_writes"])

    def test_explicit_link_to_another_event(self):
        report = self.loader().preview(
            "EVENT_ALPHA", ["ACTION_TO_BETA"]
        )
        self.assertEqual(report["preview_status"], "offered")
        self.assertEqual(report["current_event_id"], "EVENT_BETA")
        self.assertEqual(report["trace"][0]["to_event_id"], "EVENT_BETA")
        self.assertEqual(
            report["available_choices"][0]["choice"], "ACTION_FINISH"
        )

    def test_two_step_terminal(self):
        report = self.loader().preview(
            "EVENT_ALPHA", ["ACTION_TO_BETA", "ACTION_FINISH"]
        )
        self.assertEqual(report["preview_status"], "terminal")
        self.assertIsNone(report["current_event_id"])
        self.assertEqual(report["available_choices"], [])
        self.assertEqual(report["trace"][-1]["outcome"], "terminal")

    def test_explicit_terminal_branch(self):
        report = self.loader().preview("EVENT_ALPHA", ["ACTION_STOP"])
        self.assertEqual(report["preview_status"], "terminal")
        self.assertEqual(len(report["trace"]), 1)

    def test_ignore_option_follows_explicit_reference(self):
        report = self.loader().preview("EVENT_ALPHA", [IGNORE])
        self.assertEqual(report["current_event_id"], "EVENT_GAMMA")
        self.assertEqual(report["trace"][0]["kind"], "ignore")
        self.assertEqual(
            report["trace"][0]["reference_at"]["pointer"],
            "/on_ignore_event_id",
        )

    def test_ignore_not_offered_if_field_is_absent(self):
        view = self.loader()
        options = view.options_for("EVENT_BETA")
        self.assertNotIn(IGNORE, [x["choice"] for x in options])
        err = self.assert_error(
            "UNKNOWN_CHOICE",
            lambda: view.preview("EVENT_BETA", [IGNORE]),
        )
        self.assertEqual(err.available, ["ACTION_FINISH"])

    def test_ignore_null_explicitly_ends_preview(self):
        self.write(
            "a.json",
            event("EVENT_ALPHA", [("ACTION_STOP", None)],
                  include_ignore=True, ignore=None),
        )
        self.write(
            "b.json", event("EVENT_BETA", [("ACTION_FINISH", None)])
        )
        self.write(
            "c.json", event("EVENT_GAMMA", [("ACTION_DONE", None)])
        )
        result = self.loader().preview("EVENT_ALPHA", [IGNORE])
        self.assertEqual(result["preview_status"], "terminal")

    def test_unknown_choice_error_has_explicit_available_list(self):
        view = self.loader()
        err = self.assert_error(
            "UNKNOWN_CHOICE",
            lambda: view.preview("EVENT_ALPHA", ["ACTION_MISSING"]),
        )
        self.assertEqual(err.step, 0)
        self.assertEqual(
            err.available,
            ["ACTION_TO_BETA", "ACTION_STOP", IGNORE],
        )

    def test_invalid_start_event_is_rejected(self):
        view = self.loader()
        self.assert_error(
            "UNKNOWN_START_EVENT",
            lambda: view.preview("EVENT_MISSING"),
        )
        self.assert_error(
            "INVALID_START_EVENT",
            lambda: view.preview(42),
        )

    def test_invalid_selection_types_rejected(self):
        view = self.loader()
        for selections in ["ACTION_STOP", [None], [2], [""]]:
            with self.subTest(selections=selections):
                self.assert_error(
                    "INVALID_SELECTION",
                    lambda choices=selections: view.preview(
                        "EVENT_ALPHA", choices
                    ),
                )

    def test_extra_step_after_terminal_fails(self):
        view = self.loader()
        err = self.assert_error(
            "EXTRA_SELECTION_AFTER_TERMINAL",
            lambda: view.preview(
                "EVENT_ALPHA", ["ACTION_STOP", "ACTION_TO_BETA"]
            ),
        )
        self.assertEqual(err.step, 1)

    def test_cycle_requires_manual_steps_and_is_bounded(self):
        view = self.loader()
        outcome = view.preview(
            "EVENT_ALPHA", [IGNORE, "ACTION_RESTART"]
        )
        self.assertEqual(outcome["current_event_id"], "EVENT_ALPHA")
        self.assertEqual(len(outcome["trace"]), 2)

        chain = [IGNORE, "ACTION_RESTART"] * (MAX_CHOICES // 2)
        bounded = view.preview("EVENT_ALPHA", chain)
        self.assertEqual(len(bounded["trace"]), MAX_CHOICES)
        self.assert_error(
            "STEP_LIMIT",
            lambda: view.preview("EVENT_ALPHA", chain + [IGNORE]),
        )

    def test_preview_repeat_is_deterministic(self):
        view = self.loader()
        first = view.preview("EVENT_ALPHA", ["ACTION_TO_BETA"])
        second = view.preview("EVENT_ALPHA", ["ACTION_TO_BETA"])
        self.assertEqual(first, second)
        self.assertEqual(first["trace_sha256"], second["trace_sha256"])

    def test_separate_choices_do_not_share_mutable_runtime_state(self):
        view = self.loader()
        stop = view.preview("EVENT_ALPHA", ["ACTION_STOP"])
        link = view.preview("EVENT_ALPHA", ["ACTION_TO_BETA"])
        self.assertEqual(stop["preview_status"], "terminal")
        self.assertEqual(link["current_event_id"], "EVENT_BETA")
        self.assertEqual(
            view.preview("EVENT_ALPHA")["trace"], []
        )

    def test_returned_options_cannot_mutate_stored_events(self):
        view = self.loader()
        original = view.options_for("EVENT_ALPHA")
        original[0]["choice"] = "INJECTED"
        original[0]["source"]["pointer"] = "INJECTED"
        second = view.options_for("EVENT_ALPHA")
        self.assertEqual(second[0]["choice"], "ACTION_TO_BETA")
        self.assertEqual(second[0]["source"]["pointer"], "/actions/0")

    def test_trace_contains_source_pointer_and_content_sha(self):
        view = self.loader()
        trace = view.preview(
            "EVENT_ALPHA", ["ACTION_TO_BETA"]
        )["trace"][0]
        self.assertEqual(trace["selected_at"]["pointer"], "/actions/0")
        self.assertEqual(
            trace["reference_at"]["pointer"],
            "/actions/0/next_event_id",
        )
        self.assertEqual(
            trace["target_definition"]["pointer"], "/event_id"
        )
        self.assertEqual(len(trace["selected_at"]["sha256"]), 64)
        self.assertGreater(
            trace["reference_at"]["location"]["line"], 0
        )

    def test_selected_source_sha_matches_actual_bytes(self):
        import hashlib
        view = self.loader()
        trace = view.preview(
            "EVENT_ALPHA", ["ACTION_TO_BETA"]
        )["trace"][0]
        self.assertEqual(
            trace["selected_at"]["sha256"],
            hashlib.sha256(self.a.read_bytes()).hexdigest(),
        )

    def test_selection_of_directory_and_duplicate_paths(self):
        one = self.loader(self.a, self.b, self.c)
        two = self.loader(self.root, self.a, self.root)
        self.assertEqual(
            one.preview("EVENT_ALPHA")["snapshot_sha256"],
            two.preview("EVENT_ALPHA")["snapshot_sha256"],
        )

    def test_missing_dependency_input_rejects_before_preview(self):
        err = self.assert_error(
            "STRUCTURE_CHECK_FAILED",
            lambda: self.loader(self.a),
        )
        self.assertIsNotNone(err.checker_report)
        self.assertEqual(
            err.checker_report["status"], "FAIL"
        )

    def test_duplicate_event_id_rejected_by_checker(self):
        d = self.write(
            "d.json",
            event("EVENT_ALPHA", [("ACTION_UNUSED", None)])
        )
        err = self.assert_error(
            "STRUCTURE_CHECK_FAILED", lambda: self.loader()
        )
        self.assertTrue(
            any(x["code"] == "DUPLICATE_EVENT_ID"
                for x in err.checker_report["issues"])
        )

    def test_invalid_identifier_rejected_by_checker(self):
        data = event("bad_name", [("ACTION_STOP", None)])
        self.write("bad.json", data)
        err = self.assert_error(
            "STRUCTURE_CHECK_FAILED", lambda: self.loader()
        )
        self.assertTrue(
            any(x["code"] == "INVALID_ID"
                for x in err.checker_report["issues"])
        )

    def test_missing_input_rejected(self):
        self.assert_error(
            "INVALID_INPUT_SELECTION",
            lambda: self.loader(self.root / "not-present.json"),
        )
        self.assert_error(
            "MISSING_INPUTS", lambda: CheckedEventPreview([]),
        )

    def test_changed_bytes_during_check_fail_closed(self):
        import event_flow_preview_candidate as module
        real_check = module.check_event_data
        def changing(inputs):
            result = real_check(inputs)
            self.a.write_text(
                self.a.read_text(encoding="utf-8") + " ",
                encoding="utf-8",
            )
            return result

        with mock.patch.object(
            module, "check_event_data", side_effect=changing,
        ):
            self.assert_error("INPUT_CHANGED", lambda: self.loader())

    def test_changed_file_selection_during_check_fail_closed(self):
        import event_flow_preview_candidate as module
        real_check = module.check_event_data
        def changing(inputs):
            result = real_check(inputs)
            self.write("another.json", event(
                "EVENT_ANOTHER", [("ACTION_DONE", None)]
            ))
            return result
        with mock.patch.object(
            module, "check_event_data", side_effect=changing,
        ):
            self.assert_error("INPUT_CHANGED", lambda: self.loader())

    def test_no_input_files_are_written(self):
        before = {p: p.read_bytes() for p in (self.a, self.b, self.c)}
        view = self.loader()
        view.preview("EVENT_ALPHA", [IGNORE, "ACTION_RESTART"])
        self.assertEqual(
            before, {p: p.read_bytes() for p in (self.a, self.b, self.c)}
        )

    def test_text_renderer_contains_only_id_path_and_trace(self):
        report = self.loader().preview(
            "EVENT_ALPHA", ["ACTION_TO_BETA"]
        )
        text = render_text(report)
        self.assertIn("ACTION_TO_BETA", text)
        self.assertIn("/actions/0", text)
        self.assertIn("No runtime effects", text)
        self.assertIn("snapshot SHA256", text)

    def test_cli_text_lists_options(self):
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            code = main([
                "--event-id", "EVENT_ALPHA", "--format", "text",
                str(self.root),
            ])
        self.assertEqual(code, 0)
        self.assertIn("ACTION_TO_BETA", stdout.getvalue())

    def test_cli_json_multistep_trace(self):
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            code = main([
                "--event-id", "EVENT_ALPHA",
                "--choice", "ACTION_TO_BETA",
                "--choice", "ACTION_FINISH",
                "--format", "json",
                str(self.root),
            ])
        self.assertEqual(code, 0)
        doc = json.loads(stdout.getvalue())
        self.assertEqual(doc["preview_status"], "terminal")
        self.assertEqual(len(doc["trace"]), 2)
        self.assertTrue(doc["no_runtime_effects"])

    def test_cli_json_bad_action_returns_structured_error(self):
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            code = main([
                "--event-id", "EVENT_ALPHA",
                "--choice", "ACTION_BAD",
                "--format", "json",
                str(self.root),
            ])
        self.assertEqual(code, 1)
        doc = json.loads(stdout.getvalue())
        self.assertEqual(doc["status"], "REJECTED")
        self.assertEqual(doc["error"]["code"], "UNKNOWN_CHOICE")

    def test_cli_checker_failure_does_not_offer_branches(self):
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            code = main([
                "--event-id", "EVENT_ALPHA",
                "--format", "json",
                str(self.a),
            ])
        self.assertEqual(code, 1)
        doc = json.loads(stdout.getvalue())
        self.assertEqual(doc["error"]["code"], "STRUCTURE_CHECK_FAILED")
        self.assertNotIn("available_choices", doc)

    def test_trace_hash_changes_with_selection(self):
        view = self.loader()
        a = view.preview("EVENT_ALPHA", ["ACTION_STOP"])
        b = view.preview("EVENT_ALPHA", ["ACTION_TO_BETA"])
        self.assertNotEqual(a["trace_sha256"], b["trace_sha256"])

    def test_snapshot_fingerprint_changes_with_valid_source_change(self):
        view1 = self.loader()
        old = view1.preview("EVENT_ALPHA")["snapshot_sha256"]
        doc = json.loads(self.b.read_text(encoding="utf-8"))
        doc["trigger"]["signal"] = "SIGNAL_CHANGED"
        self.write("b.json", doc)
        view2 = self.loader()
        self.assertNotEqual(
            old, view2.preview("EVENT_ALPHA")["snapshot_sha256"]
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
