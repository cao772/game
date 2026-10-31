#!/usr/bin/env python3
"""GAME-WEB-PLAY-EVENT-005 r1 — PROSPECTIVE TESTS, NOT_RUN.

All fixtures are generated from public synthetic identifiers only.
Do not run without the author's later verification authorization.
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


def event(event_id, signal, actions, *, ignore=None, include_ignore=False):
    document = {
        "event_id": event_id,
        "trigger": {
            "signal": signal, "conditions": ["FLAG_READY"],
        },
        "actions": [
            {"action_id": action, "next_event_id": target}
            for action, target in actions
        ],
    }
    if include_ignore:
        document["on_ignore_event_id"] = ignore
    return document


def observe(event_id, signal, conditions=None):
    return {
        "op": "observe", "event_id": event_id,
        "signal": signal, "conditions": (
            ["FLAG_READY"] if conditions is None else conditions
        ),
    }


def choose(choice):
    return {"op": "choose", "choice": choice}


class PlayOverlayCandidateFutureTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.a = self.write(
            "a.json", event(
                "EVENT_ALPHA", "SIGNAL_A",
                [("ACTION_B", "EVENT_BETA"), ("ACTION_END", None)],
                include_ignore=True, ignore="EVENT_GAMMA",
            ),
        )
        self.b = self.write(
            "b.json", event(
                "EVENT_BETA", "SIGNAL_B",
                [("ACTION_DONE", None), ("ACTION_BACK", "EVENT_ALPHA")],
            ),
        )
        self.c = self.write(
            "c.json", event(
                "EVENT_GAMMA", "SIGNAL_C",
                [("ACTION_FINISH", None)],
            ),
        )
        self.checked = CheckedEventPreview([str(self.root)])
        self.session = SyntheticPlaySession(self.checked, "EVENT_ALPHA")

    def write(self, filename, document):
        path = self.root / filename
        path.write_text(
            json.dumps(document, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        return path

    def do(self, command, *, ok=True):
        response = self.session.apply(command)
        self.assertEqual(response["ok"], ok)
        return response

    def ready_alpha(self):
        return self.do(observe("EVENT_ALPHA", "SIGNAL_A"))

    def ready_beta(self):
        return self.do(observe("EVENT_BETA", "SIGNAL_B"))

    def ready_all(self):
        self.ready_alpha()
        self.ready_beta()
        self.do(observe("EVENT_GAMMA", "SIGNAL_C"))

    def test_initial_snapshot_blocked_without_observation(self):
        state = self.session.snapshot()
        self.assertEqual(state["preview_status"], "blocked")
        self.assertEqual(state["current_event_id"], "EVENT_ALPHA")
        self.assertEqual(state["available_choices"], [])
        self.assertEqual(
            [item["choice"] for item in state["configured_choices"]],
            ["ACTION_B", "ACTION_END", IGNORE],
        )
        self.assertEqual(state["condition_gate"]["observation_origin"],
                         "not_supplied")
        self.assertTrue(state["no_runtime_effects"])

    def test_correct_signal_and_all_conditions_unlock(self):
        self.ready_alpha()
        state = self.session.snapshot()
        self.assertEqual(state["preview_status"], "offered")
        self.assertTrue(state["condition_gate"]["ready"])
        self.assertEqual(
            [x["choice"] for x in state["available_choices"]],
            ["ACTION_B", "ACTION_END", IGNORE],
        )

    def test_signal_mismatch_retains_block(self):
        self.do(observe("EVENT_ALPHA", "SIGNAL_WRONG"))
        state = self.session.snapshot()
        self.assertFalse(state["condition_gate"]["signal_matches"])
        self.assertEqual(state["preview_status"], "blocked")
        result = self.do(choose("ACTION_B"), ok=False)
        self.assertEqual(result["error"]["code"], "CONDITIONS_NOT_MET")

    def test_missing_condition_retains_block(self):
        self.do(observe("EVENT_ALPHA", "SIGNAL_A", []))
        state = self.session.snapshot()
        self.assertEqual(
            state["condition_gate"]["missing_conditions"], ["FLAG_READY"]
        )
        result = self.do(choose("ACTION_B"), ok=False)
        self.assertEqual(result["snapshot"], state)

    def test_extra_valid_conditions_do_not_block(self):
        self.do(observe(
            "EVENT_ALPHA", "SIGNAL_A", ["FLAG_EXTRA", "FLAG_READY"],
        ))
        self.assertEqual(self.session.snapshot()["preview_status"], "offered")

    def test_step_to_beta_requires_separate_observation(self):
        self.ready_alpha()
        self.do(choose("ACTION_B"))
        state = self.session.snapshot()
        self.assertEqual(state["current_event_id"], "EVENT_BETA")
        self.assertEqual(state["preview_status"], "blocked")
        self.assertEqual(len(state["trace"]), 1)
        self.do(choose("ACTION_DONE"), ok=False)
        self.ready_beta()
        self.assertEqual(self.session.snapshot()["preview_status"], "offered")
        self.do(choose("ACTION_DONE"))
        self.assertEqual(self.session.snapshot()["preview_status"], "terminal")

    def test_explicit_ignore_branch_has_trace_and_gate(self):
        self.ready_all()
        self.do(choose(IGNORE))
        state = self.session.snapshot()
        self.assertEqual(state["current_event_id"], "EVENT_GAMMA")
        self.assertEqual(state["trace"][0]["kind"], "ignore")
        self.assertEqual(state["preview_status"], "offered")

    def test_terminal_prevents_next_selection(self):
        self.ready_alpha()
        self.do(choose("ACTION_END"))
        before = self.session.snapshot()
        result = self.do(choose("ACTION_B"), ok=False)
        self.assertEqual(result["error"]["code"], "TERMINAL_LOCKED")
        self.assertEqual(self.session.snapshot(), before)

    def test_unknown_action_error_echo_does_not_mutate(self):
        self.ready_alpha()
        before = self.session.snapshot()
        error = self.do(choose("ACTION_UNKNOWN"), ok=False)
        self.assertEqual(error["error"]["code"], "UNKNOWN_CHOICE")
        self.assertIn("ACTION_B", error["error"]["available_choices"])
        self.assertEqual(error["snapshot"], before)
        self.assertEqual(self.session.snapshot(), before)

    def test_missing_gate_error_echo_contains_requirements(self):
        before = self.session.snapshot()
        error = self.do(choose("ACTION_B"), ok=False)
        self.assertEqual(error["error"]["code"], "CONDITIONS_NOT_MET")
        self.assertEqual(
            error["error"]["condition_gate"]["required_signal"], "SIGNAL_A"
        )
        self.assertEqual(error["snapshot"], before)

    def test_back_then_forward_preserves_trace(self):
        self.ready_all()
        self.do(choose("ACTION_B"))
        self.do(choose("ACTION_BACK"))
        path = self.session.snapshot()
        self.assertEqual(path["cursor"], 2)
        self.do({"op": "back", "steps": 1})
        self.assertEqual(self.session.snapshot()["current_event_id"],
                         "EVENT_BETA")
        self.assertTrue(self.session.snapshot()["can_forward"])
        self.do({"op": "forward", "steps": 1})
        self.assertEqual(self.session.snapshot(), path)

    def test_jump_navigation_to_root_and_forward(self):
        self.ready_all()
        self.do(choose("ACTION_B"))
        self.do(choose("ACTION_BACK"))
        self.do({"op": "jump", "cursor": 0})
        state = self.session.snapshot()
        self.assertEqual(state["cursor"], 0)
        self.assertEqual(state["current_event_id"], "EVENT_ALPHA")
        self.do({"op": "jump", "cursor": 2})
        self.assertEqual(self.session.snapshot()["cursor"], 2)

    def test_branch_from_history_truncates_future(self):
        self.ready_all()
        self.do(choose("ACTION_B"))
        self.do(choose("ACTION_BACK"))
        self.do({"op": "back", "steps": 2})
        self.do(choose("ACTION_END"))
        state = self.session.snapshot()
        self.assertEqual(state["history_length"], 1)
        self.assertFalse(state["can_forward"])
        self.assertEqual(state["preview_status"], "terminal")
        self.assertEqual(state["selected_path"], ["ACTION_END"])

    def test_invalid_navigation_positions_do_not_mutate(self):
        self.ready_alpha()
        before = self.session.snapshot()
        for command in [
            {"op": "back", "steps": 1},
            {"op": "forward", "steps": 1},
            {"op": "jump", "cursor": -1},
            {"op": "jump", "cursor": 1},
            {"op": "back", "steps": True},
            {"op": "jump", "cursor": 1.0},
            {"op": "forward", "steps": 0},
        ]:
            result = self.do(command, ok=False)
            self.assertIn(
                result["error"]["code"],
                ("CURSOR_OUT_OF_RANGE", "INVALID_CURSOR", "INVALID_STEPS"),
            )
            self.assertEqual(result["snapshot"], before)

    def test_rejected_command_fields_do_not_mutate(self):
        before = self.session.snapshot()
        for command in [
            {},
            [],
            {"op": "unknown"},
            {"op": "observe", "event_id": "EVENT_ALPHA", "signal": "SIGNAL_A"},
            {"op": "choose", "choice": "ACTION_B", "extra": True},
            {"op": "jump", "index": 0},
        ]:
            self.do(command, ok=False)
            self.assertEqual(self.session.snapshot(), before)

    def test_invalid_observation_inputs_rejected_atomically(self):
        before = self.session.snapshot()
        for command in [
            observe("EVENT_MISSING", "SIGNAL_A"),
            observe("EVENT_ALPHA", ""),
            observe("EVENT_ALPHA", "SIGNAL_A", ["FLAG_READY", "FLAG_READY"]),
            observe("EVENT_ALPHA", "SIGNAL_A", [123]),
            observe("EVENT_ALPHA", "SIGNAL_A", ["bad"]),
            observe("EVENT_ALPHA", "SIGNAL_A", "FLAG_READY"),
        ]:
            self.do(command, ok=False)
            self.assertEqual(self.session.snapshot(), before)

    def test_change_past_observation_resets_history(self):
        self.ready_all()
        self.do(choose("ACTION_B"))
        self.do(choose("ACTION_DONE"))
        changed = self.do(observe("EVENT_ALPHA", "SIGNAL_OTHER"))
        self.assertTrue(changed["history_reset"])
        state = self.session.snapshot()
        self.assertEqual(state["history_length"], 0)
        self.assertEqual(state["cursor"], 0)
        self.assertEqual(state["preview_status"], "blocked")

    def test_change_future_observation_discards_redo_only(self):
        self.ready_all()
        self.do(choose("ACTION_B"))
        self.do(choose("ACTION_BACK"))
        self.do({"op": "back", "steps": 1})
        changed = self.do(observe("EVENT_BETA", "SIGNAL_OTHER"))
        self.assertTrue(changed["redo_cleared"])
        state = self.session.snapshot()
        self.assertEqual(state["cursor"], 1)
        self.assertEqual(state["history_length"], 1)
        self.assertEqual(state["current_event_id"], "EVENT_BETA")

    def test_change_observation_of_unvisited_event_preserves_prefix(self):
        self.ready_all()
        self.do(choose("ACTION_B"))
        self.do(observe("EVENT_GAMMA", "SIGNAL_OTHER"))
        state = self.session.snapshot()
        self.assertEqual(state["cursor"], 1)
        self.assertEqual(state["history_length"], 1)

    def test_clear_observation_blocks_current_event(self):
        self.ready_alpha()
        self.do({"op": "clear_observation", "event_id": "EVENT_ALPHA"})
        self.assertEqual(self.session.snapshot()["preview_status"], "blocked")
        self.assertEqual(self.session.snapshot()["observations"], {})

    def test_clear_missing_observation_is_noop(self):
        first = self.session.snapshot()
        response = self.do({
            "op": "clear_observation", "event_id": "EVENT_ALPHA",
        })
        self.assertFalse(response["changed"])
        self.assertEqual(first, response["snapshot"])

    def test_repeat_identical_observation_is_noop(self):
        self.ready_alpha()
        before = self.session.snapshot()
        result = self.do(observe("EVENT_ALPHA", "SIGNAL_A"))
        self.assertFalse(result["changed"])
        self.assertEqual(result["snapshot"], before)

    def test_snapshot_is_detached(self):
        self.ready_alpha()
        first = self.session.snapshot()
        clone = copy.deepcopy(first)
        clone["observations"]["EVENT_ALPHA"]["signal"] = "INJECTED"
        clone["available_choices"][0]["choice"] = "INJECTED"
        clone["condition_gate"]["required_conditions"].clear()
        second = self.session.snapshot()
        self.assertEqual(first, second)

    def test_snapshot_hash_changes_with_observation_and_choice(self):
        a = self.session.snapshot()["state_snapshot_sha256"]
        self.ready_alpha()
        b = self.session.snapshot()["state_snapshot_sha256"]
        self.do(choose("ACTION_B"))
        c = self.session.snapshot()["state_snapshot_sha256"]
        self.assertNotEqual(a, b)
        self.assertNotEqual(b, c)

    def test_source_snapshot_sha_stays_constant_across_preview(self):
        original = self.session.snapshot()["source_snapshot_sha256"]
        self.ready_all()
        self.do(choose("ACTION_B"))
        self.do(choose("ACTION_DONE"))
        self.assertEqual(
            original, self.session.snapshot()["source_snapshot_sha256"]
        )

    def test_no_source_json_modified_by_session(self):
        before = {x: x.read_bytes() for x in (self.a, self.b, self.c)}
        self.ready_all()
        self.do(choose("ACTION_B"))
        self.do({"op": "back", "steps": 1})
        self.do(choose("ACTION_END"))
        self.assertEqual(before, {
            x: x.read_bytes() for x in (self.a, self.b, self.c)
        })

    def test_cli_json_multiple_commands_and_snapshots(self):
        result = io.StringIO()
        commands = [
            observe("EVENT_ALPHA", "SIGNAL_A"),
            observe("EVENT_BETA", "SIGNAL_B"),
            choose("ACTION_B"),
            choose("ACTION_DONE"),
        ]
        argv = ["--event-id", "EVENT_ALPHA", "--format", "json"]
        for command in commands:
            argv.extend(["--command", json.dumps(command)])
        argv.append(str(self.root))
        with contextlib.redirect_stdout(result):
            code = main(argv)
        data = json.loads(result.getvalue())
        self.assertEqual(code, 0)
        self.assertEqual(data["status"], "PREVIEW")
        self.assertEqual(data["snapshot"]["preview_status"], "terminal")
        self.assertEqual(data["snapshot"]["cursor"], 2)

    def test_cli_missing_conditions_error_echo(self):
        out = io.StringIO()
        argv = [
            "--event-id", "EVENT_ALPHA", "--format", "json",
            "--command", json.dumps(choose("ACTION_B")),
            str(self.root),
        ]
        with contextlib.redirect_stdout(out):
            code = main(argv)
        response = json.loads(out.getvalue())
        self.assertEqual(code, 1)
        self.assertEqual(response["status"], "REJECTED")
        self.assertEqual(
            response["operations"][0]["error"]["code"],
            "CONDITIONS_NOT_MET",
        )
        self.assertEqual(response["snapshot"]["cursor"], 0)

    def test_cli_invalid_command_json_rejects_without_trace(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = main([
                "--event-id", "EVENT_ALPHA", "--format", "json",
                "--command", "{broken}", str(self.root),
            ])
        response = json.loads(out.getvalue())
        self.assertEqual(code, 1)
        self.assertEqual(
            response["operations"][0]["error"]["code"],
            "INVALID_COMMAND_JSON",
        )
        self.assertEqual(response["snapshot"]["trace"], [])

    def test_cli_checker_gate_fails_before_conditions(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = main([
                "--event-id", "EVENT_ALPHA", "--format", "json",
                str(self.a),
            ])
        response = json.loads(out.getvalue())
        self.assertEqual(code, 1)
        self.assertEqual(response["error"]["code"], "STRUCTURE_CHECK_FAILED")
        self.assertNotIn("snapshot", response)

    def test_cli_text_echo_and_branches(self):
        out = io.StringIO()
        argv = [
            "--event-id", "EVENT_ALPHA", "--format", "text",
            "--command", json.dumps(observe("EVENT_ALPHA", "SIGNAL_A")),
            str(self.root),
        ]
        with contextlib.redirect_stdout(out):
            status = main(argv)
        self.assertEqual(status, 0)
        self.assertIn("ACTION_B", out.getvalue())
        self.assertIn("No gameplay state", out.getvalue())

    def test_original_flow_candidate_still_unmodified_semantics(self):
        base = self.checked.preview("EVENT_ALPHA", ["ACTION_B"])
        self.assertEqual(base["current_event_id"], "EVENT_BETA")
        self.assertEqual(base["preview_status"], "offered")
        self.assertEqual(len(base["trace"]), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
