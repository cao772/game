#!/usr/bin/env python3
"""GAME-WEB-EVENT-006 r1 — synthetic FUTURE acceptance (NOT_RUN).

All data are placeholder-only; deliberately no real game/event/story content.
No test, import or Python source has been executed as part of this handoff.
"""
from __future__ import annotations

import contextlib
import copy
import io
import json
import tempfile
import unittest
from pathlib import Path

from event_flow_preview_candidate import CheckedEventPreview, IGNORE
from event_play_preview_candidate import SyntheticPlaySession, main
from event_preview_diagnostics_006_candidate import (
    breadcrumbs, explain_gate, first_changed_step, present_error,
)


def event(event_id, signal, actions, conditions=None, *, ignore=None):
    result = {
        "event_id": event_id,
        "trigger": {
            "signal": signal,
            "conditions": (
                ["FLAG_READY"] if conditions is None else conditions
            ),
        },
        "actions": [
            {"action_id": choice, "next_event_id": target}
            for choice, target in actions
        ],
    }
    if ignore is not None:
        result["on_ignore_event_id"] = ignore
    return result


def observe(name, signal, conditions=None):
    return {
        "op": "observe", "event_id": name,
        "signal": signal,
        "conditions": (
            ["FLAG_READY"] if conditions is None else conditions
        ),
    }


class Event006FutureAcceptance(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.a = self.write("a.json", event(
            "EVENT_ALPHA", "SIGNAL_A",
            [("ACTION_B", "EVENT_BETA"), ("ACTION_STOP", None)],
            ignore="EVENT_GAMMA",
        ))
        self.b = self.write("b.json", event(
            "EVENT_BETA", "SIGNAL_B",
            [("ACTION_C", "EVENT_GAMMA"), ("ACTION_END", None)],
        ))
        self.c = self.write("c.json", event(
            "EVENT_GAMMA", "SIGNAL_C",
            [("ACTION_A", "EVENT_ALPHA"), ("ACTION_DONE", None)],
        ))
        self.checker = CheckedEventPreview([str(self.root)])
        self.session = SyntheticPlaySession(self.checker, "EVENT_ALPHA")

    def write(self, name, item):
        file = self.root / name
        file.write_text(
            json.dumps(item, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        return file

    def execute(self, op, expected=True):
        answer = self.session.apply(op)
        self.assertEqual(answer["ok"], expected, answer)
        return answer

    def ready(self, name, signal):
        return self.execute(observe(name, signal))

    def ready_all(self):
        self.ready("EVENT_ALPHA", "SIGNAL_A")
        self.ready("EVENT_BETA", "SIGNAL_B")
        self.ready("EVENT_GAMMA", "SIGNAL_C")

    def two_steps(self):
        self.ready_all()
        self.execute({"op": "choose", "choice": "ACTION_B"})
        self.execute({"op": "choose", "choice": "ACTION_C"})

    def test_initial_diagnosis_missing_observation(self):
        snapshot = self.session.snapshot()
        diagnostic = snapshot["condition_diagnostics"]
        self.assertFalse(diagnostic["ready"])
        self.assertEqual(diagnostic["reason_codes"], ["OBSERVATION_NOT_SUPPLIED"])
        self.assertEqual(
            diagnostic["reasons"][0]["source"]["pointer"],
            "/trigger/signal",
        )
        self.assertEqual(snapshot["available_choices"], [])

    def test_ready_diagnosis_has_no_reasons(self):
        self.ready("EVENT_ALPHA", "SIGNAL_A")
        diagnostic = self.session.snapshot()["condition_diagnostics"]
        self.assertTrue(diagnostic["ready"])
        self.assertEqual(diagnostic["reason_codes"], [])
        self.assertEqual(diagnostic["status"], "ready")

    def test_wrong_signal_has_precise_source(self):
        self.execute(observe("EVENT_ALPHA", "SIGNAL_WRONG"))
        diagnosis = self.session.snapshot()["condition_diagnostics"]
        self.assertEqual(diagnosis["reason_codes"], ["SIGNAL_MISMATCH"])
        site = diagnosis["reasons"][0]["source"]
        self.assertEqual(site["pointer"], "/trigger/signal")
        self.assertGreater(site["location"]["line"], 0)

    def test_missing_conditions_has_precise_source(self):
        self.execute(observe("EVENT_ALPHA", "SIGNAL_A", []))
        diagnosis = self.session.snapshot()["condition_diagnostics"]
        self.assertEqual(
            diagnosis["reason_codes"], ["REQUIRED_CONDITIONS_MISSING"],
        )
        self.assertEqual(
            diagnosis["reasons"][0]["missing"], ["FLAG_READY"],
        )
        self.assertEqual(
            diagnosis["reasons"][0]["source"]["pointer"],
            "/trigger/conditions",
        )

    def test_both_signal_and_flags_failed_in_order(self):
        self.execute(observe("EVENT_ALPHA", "SIGNAL_WRONG", []))
        diagnosis = self.session.snapshot()["condition_diagnostics"]
        self.assertEqual(
            diagnosis["reason_codes"],
            ["SIGNAL_MISMATCH", "REQUIRED_CONDITIONS_MISSING"],
        )

    def test_extra_flags_informational_not_blocking(self):
        self.execute(observe(
            "EVENT_ALPHA", "SIGNAL_A", ["FLAG_Z", "FLAG_READY"],
        ))
        diagnosis = self.session.snapshot()["condition_diagnostics"]
        self.assertTrue(diagnosis["ready"])
        self.assertEqual(
            diagnosis["additional_observed_conditions"], ["FLAG_Z"],
        )

    def test_terminal_diagnosis_explicit(self):
        self.ready("EVENT_ALPHA", "SIGNAL_A")
        self.execute({"op": "choose", "choice": "ACTION_STOP"})
        state = self.session.snapshot()
        self.assertIsNone(state["condition_gate"])
        self.assertEqual(
            state["condition_diagnostics"]["reason_codes"], ["TERMINAL"],
        )

    def test_unknown_reason_fails_closed(self):
        mocked = {
            "ready": False,
            "observation_origin": "caller_injected",
            "required_signal": "SIGNAL_A",
            "observed_signal": "SIGNAL_A",
            "signal_matches": True,
            "missing_conditions": [],
            "observed_conditions": ["FLAG_READY"],
            "required_conditions": ["FLAG_READY"],
            "requirement_sources": {},
        }
        diagnosis = explain_gate(mocked)
        self.assertFalse(diagnosis["ready"])
        self.assertEqual(diagnosis["reason_codes"], ["GATE_UNAVAILABLE"])

    def test_breadcrumbs_present_without_executing_branches(self):
        state = self.session.snapshot()
        positions = state["navigation"]["positions"]
        self.assertEqual(len(positions), 1)
        self.assertEqual(positions[0]["cursor"], 0)
        self.assertEqual(positions[0]["event_id"], "EVENT_ALPHA")
        self.assertFalse(state["navigation"]["redo_available"])

    def test_breadcrumbs_mark_redo_unselected(self):
        self.two_steps()
        self.execute({"op": "back", "steps": 1})
        points = self.session.snapshot()["navigation"]["positions"]
        self.assertEqual(
            [(point["cursor"], point["selected_prefix"]) for point in points],
            [(0, True), (1, True), (2, False)],
        )
        self.assertEqual(
            self.session.snapshot()["navigation"]["rollback_cursor_range"],
            [0, 1],
        )

    def test_first_changed_step_is_earliest_applied_selection(self):
        history = [
            {"from_event_id": "EVENT_ALPHA"},
            {"from_event_id": "EVENT_BETA"},
            {"from_event_id": "EVENT_ALPHA"},
        ]
        self.assertEqual(first_changed_step(history, 3, "EVENT_ALPHA"), 0)
        self.assertEqual(first_changed_step(history, 3, "EVENT_BETA"), 1)
        self.assertIsNone(first_changed_step(history, 1, "EVENT_BETA"))

    def test_changing_second_event_retains_safe_first_step(self):
        self.two_steps()
        effect = self.execute(observe("EVENT_BETA", "SIGNAL_WRONG"))
        self.assertEqual(
            effect["navigation_effect"]["policy"],
            "rollback_to_safe_prefix",
        )
        self.assertEqual(effect["navigation_effect"]["discarded_steps"], 1)
        state = effect["snapshot"]
        self.assertEqual(state["cursor"], 1)
        self.assertEqual(state["history_length"], 1)
        self.assertEqual(state["current_event_id"], "EVENT_BETA")
        self.assertEqual(state["preview_status"], "blocked")
        self.assertEqual(state["selected_path"], ["ACTION_B"])

    def test_changing_start_event_rolls_back_to_zero(self):
        self.two_steps()
        result = self.execute(observe("EVENT_ALPHA", "SIGNAL_WRONG"))
        self.assertTrue(result["history_reset"])
        self.assertEqual(result["snapshot"]["cursor"], 0)
        self.assertEqual(result["snapshot"]["history_length"], 0)

    def test_changing_only_redo_event_preserves_prefix(self):
        self.two_steps()
        self.execute({"op": "back", "steps": 1})
        result = self.execute(observe("EVENT_BETA", "SIGNAL_WRONG"))
        self.assertTrue(result["redo_cleared"])
        self.assertEqual(
            result["navigation_effect"]["policy"], "discard_redo",
        )
        self.assertEqual(result["snapshot"]["cursor"], 1)
        self.assertEqual(result["snapshot"]["history_length"], 1)

    def test_change_unvisited_event_preserves_applied_prefix(self):
        self.ready_all()
        self.execute({"op": "choose", "choice": "ACTION_B"})
        effect = self.execute(observe("EVENT_GAMMA", "SIGNAL_WRONG"))
        self.assertEqual(
            effect["navigation_effect"]["policy"], "observation_only",
        )
        self.assertEqual(effect["snapshot"]["selected_path"], ["ACTION_B"])

    def test_explicit_rollback_truncates_recorded_future(self):
        self.two_steps()
        result = self.execute({"op": "rollback", "cursor": 1})
        self.assertEqual(result["navigation_effect"]["discarded_steps"], 1)
        self.assertEqual(
            result["navigation_effect"]["policy"], "truncate_to_cursor",
        )
        self.assertEqual(result["snapshot"]["history_length"], 1)
        self.assertEqual(result["snapshot"]["cursor"], 1)
        self.assertFalse(result["snapshot"]["can_forward"])

    def test_rollback_can_clear_redo_at_current_cursor(self):
        self.two_steps()
        self.execute({"op": "back", "steps": 1})
        result = self.execute({"op": "rollback", "cursor": 1})
        self.assertTrue(result["changed"])
        self.assertEqual(result["snapshot"]["history_length"], 1)
        self.assertFalse(result["snapshot"]["can_forward"])

    def test_rollback_same_position_without_redo_is_noop(self):
        before = self.session.snapshot()
        result = self.execute({"op": "rollback", "cursor": 0})
        self.assertFalse(result["changed"])
        self.assertEqual(result["snapshot"], before)

    def test_rollback_forward_request_rejected_unchanged(self):
        self.two_steps()
        self.execute({"op": "back", "steps": 1})
        before = self.session.snapshot()
        result = self.execute(
            {"op": "rollback", "cursor": 2}, expected=False,
        )
        self.assertEqual(
            result["error"]["code"], "ROLLBACK_FORWARD_FORBIDDEN",
        )
        self.assertEqual(result["snapshot"], before)
        self.assertEqual(self.session.snapshot(), before)

    def test_rollback_invalid_cursor_rejected_unchanged(self):
        self.two_steps()
        before = self.session.snapshot()
        for cursor, code in [
            (True, "INVALID_CURSOR"),
            (None, "INVALID_CURSOR"),
            (1.2, "INVALID_CURSOR"),
            (-1, "CURSOR_OUT_OF_RANGE"),
        ]:
            with self.subTest(cursor=cursor):
                result = self.execute(
                    {"op": "rollback", "cursor": cursor}, expected=False,
                )
                self.assertEqual(result["error"]["code"], code)
                self.assertEqual(self.session.snapshot(), before)

    def test_rollback_after_terminal_restores_prior_event(self):
        self.ready("EVENT_ALPHA", "SIGNAL_A")
        self.execute({"op": "choose", "choice": "ACTION_STOP"})
        result = self.execute({"op": "rollback", "cursor": 0})
        self.assertEqual(result["snapshot"]["current_event_id"], "EVENT_ALPHA")
        self.assertEqual(result["snapshot"]["preview_status"], "offered")

    def test_back_forward_keep_redo_until_explicit_truncation(self):
        self.two_steps()
        before = self.session.snapshot()
        self.execute({"op": "back", "steps": 2})
        self.assertTrue(self.session.snapshot()["can_forward"])
        self.execute({"op": "forward", "steps": 2})
        self.assertEqual(self.session.snapshot(), before)

    def test_choose_after_back_truncates_old_redo(self):
        self.two_steps()
        self.execute({"op": "back", "steps": 2})
        result = self.execute({"op": "choose", "choice": "ACTION_STOP"})
        self.assertEqual(
            result["navigation_effect"]["policy"], "replace_redo_branch",
        )
        self.assertEqual(result["navigation_effect"]["discarded_steps"], 2)
        self.assertEqual(result["snapshot"]["history_length"], 1)
        self.assertFalse(result["snapshot"]["can_forward"])

    def test_error_echo_includes_condition_sources_and_unmodified_hash(self):
        before = self.session.snapshot()
        error = self.execute(
            {"op": "choose", "choice": "ACTION_B"}, expected=False,
        )
        presentation = error["error_view"]
        self.assertEqual(presentation["code"], "CONDITIONS_NOT_MET")
        self.assertEqual(presentation["category"], "condition")
        self.assertEqual(presentation["cursor"], 0)
        self.assertEqual(
            presentation["state_snapshot_sha256"], before["state_snapshot_sha256"]
        )
        self.assertFalse(presentation["auto_repair"])
        self.assertEqual(
            presentation["related_sources"][0]["source"]["pointer"],
            "/trigger/signal",
        )
        self.assertEqual(self.session.snapshot(), before)

    def test_bad_choice_shows_safe_suggestion_and_stable_snapshot(self):
        self.ready("EVENT_ALPHA", "SIGNAL_A")
        before = self.session.snapshot()
        result = self.execute(
            {"op": "choose", "choice": "ACTION_NOT_PRESENT"},
            expected=False,
        )
        self.assertEqual(result["error_view"]["category"], "branch")
        self.assertIn(
            "available_choices", result["error_view"]["suggestion"],
        )
        self.assertEqual(result["snapshot"], before)

    def test_unknown_error_uses_generic_manual_review(self):
        view = present_error({"code": "SYNTHETIC_UNRECOGNIZED"})
        self.assertEqual(view["category"], "review")
        self.assertTrue(view["manual_review_only"])
        self.assertEqual(view["related_sources"], [])

    def test_gate_diagnostics_detached_from_internal_state(self):
        self.ready("EVENT_ALPHA", "SIGNAL_A")
        copy_of_state = copy.deepcopy(self.session.snapshot())
        copy_of_state["navigation"]["positions"][0]["event_id"] = "INJECTED"
        copy_of_state["condition_diagnostics"]["next_step"] = "INJECTED"
        self.assertEqual(
            self.session.snapshot()["navigation"]["positions"][0]["event_id"],
            "EVENT_ALPHA",
        )
        self.assertNotEqual(
            self.session.snapshot()["condition_diagnostics"]["next_step"],
            "INJECTED",
        )

    def test_cli_json_rejection_includes_error_view(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = main([
                "--event-id", "EVENT_ALPHA",
                "--format", "json",
                "--command", json.dumps({
                    "op": "choose", "choice": "ACTION_B",
                }),
                str(self.root),
            ])
        envelope = json.loads(out.getvalue())
        self.assertEqual(code, 1)
        self.assertEqual(
            envelope["operations"][0]["error_view"]["category"],
            "condition",
        )
        self.assertEqual(envelope["snapshot"]["cursor"], 0)

    def test_cli_json_loader_failure_without_fabricated_snapshot(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = main([
                "--event-id", "EVENT_ALPHA",
                "--format", "json",
                str(self.a),
            ])
        result = json.loads(out.getvalue())
        self.assertEqual(code, 1)
        self.assertEqual(result["error"]["code"], "STRUCTURE_CHECK_FAILED")
        self.assertEqual(result["error_view"]["category"], "checker")
        self.assertNotIn("snapshot", result)

    def test_cli_malformed_command_json_error_has_guidance(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            status = main([
                "--event-id", "EVENT_ALPHA",
                "--format", "json",
                "--command", "{bad JSON",
                str(self.root),
            ])
        envelope = json.loads(out.getvalue())
        self.assertEqual(status, 1)
        self.assertEqual(
            envelope["operations"][0]["error_view"]["code"],
            "INVALID_COMMAND_JSON",
        )
        self.assertEqual(envelope["snapshot"]["history_length"], 0)

    def test_cli_text_diagnostic_and_error_source_echo(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            status = main([
                "--event-id", "EVENT_ALPHA",
                "--format", "text",
                "--command", json.dumps({
                    "op": "choose", "choice": "ACTION_B",
                }),
                str(self.root),
            ])
        self.assertEqual(status, 1)
        output = out.getvalue()
        self.assertIn("OBSERVATION_NOT_SUPPLIED", output)
        self.assertIn("guidance", output)
        self.assertIn("/trigger/signal", output)
        self.assertIn("Route positions:", output)

    def test_cli_text_rollback_shows_discarded_steps(self):
        out = io.StringIO()
        commands = [
            observe("EVENT_ALPHA", "SIGNAL_A"),
            observe("EVENT_BETA", "SIGNAL_B"),
            {"op": "choose", "choice": "ACTION_B"},
            {"op": "choose", "choice": "ACTION_C"},
            {"op": "rollback", "cursor": 1},
        ]
        argv = ["--event-id", "EVENT_ALPHA", "--format", "text"]
        for command in commands:
            argv.extend(["--command", json.dumps(command)])
        argv.append(str(self.root))
        with contextlib.redirect_stdout(out):
            status = main(argv)
        self.assertEqual(status, 0)
        self.assertIn("truncate_to_cursor", out.getvalue())
        self.assertIn("discarded=1", out.getvalue())

    def test_no_event_sources_or_runtime_are_written(self):
        before = {p: p.read_bytes() for p in (self.a, self.b, self.c)}
        self.ready_all()
        self.execute({"op": "choose", "choice": "ACTION_B"})
        self.execute({"op": "rollback", "cursor": 0})
        self.execute({"op": "choose", "choice": IGNORE})
        self.assertEqual(
            before, {p: p.read_bytes() for p in (self.a, self.b, self.c)}
        )
        self.assertTrue(self.session.snapshot()["no_runtime_effects"])

    def test_source_fingerprint_stays_constant_after_rollback(self):
        initial = self.session.snapshot()["source_snapshot_sha256"]
        self.two_steps()
        self.execute({"op": "rollback", "cursor": 1})
        self.assertEqual(
            initial, self.session.snapshot()["source_snapshot_sha256"]
        )

    def test_e006_does_not_change_static_flow_preview_semantics(self):
        result = self.checker.preview("EVENT_ALPHA", ["ACTION_B"])
        self.assertEqual(result["current_event_id"], "EVENT_BETA")
        self.assertEqual(result["preview_status"], "offered")


if __name__ == "__main__":
    unittest.main(verbosity=2)
