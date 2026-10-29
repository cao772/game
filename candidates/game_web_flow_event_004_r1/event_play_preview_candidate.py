#!/usr/bin/env python3
"""GAME-WEB-PLAY-EVENT-005 r1: conditional synthetic flow preview.

This overlay is NOT a gameplay event runtime, shared interface, canonical
story system, scene controller or persisted save. It is a finite read-only
developer aid on top of the PR #18 preview and PR #9 checker candidates.
All observations are explicitly supplied synthetic inputs.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import sys
from typing import Any

from event_flow_preview_candidate import (
    CheckedEventPreview, MAX_CHOICES, PreviewFailure,
)

TASK_ID = "GAME-WEB-PLAY-EVENT-005"
VERSION = "r1"
MAX_COMMANDS = 64
MAX_OBSERVED_CONDITIONS = 16
ID = re.compile(r"[A-Z][A-Z0-9_]{0,63}\Z")


def _fingerprint(value: Any) -> str:
    return hashlib.sha256(json.dumps(
        value, sort_keys=True, ensure_ascii=True,
        separators=(",", ":"), allow_nan=False,
    ).encode("utf-8")).hexdigest()


def _failure(code: str, message: str, **details: Any) -> dict[str, Any]:
    return {"code": code, "message": message, **details}


class SyntheticPlaySession:
    """Preview-only navigation, observation gates and detached snapshots.

    Important: observations are NOT event state. They are manually supplied
    pretend sensor/flag values used solely to demonstrate which checked
    branch selections would be eligible for a static preview.
    """

    def __init__(self, checked: CheckedEventPreview, start_event_id: str):
        if not isinstance(checked, CheckedEventPreview):
            raise PreviewFailure(
                "INVALID_PREVIEW_SOURCE", "A checked event preview is required"
            )
        if type(start_event_id) is not str:
            raise PreviewFailure(
                "INVALID_START_EVENT", "Starting event ID must be a string"
            )
        checked.preview(start_event_id)
        self._checked = checked
        self._start = start_event_id
        self._observations: dict[str, dict[str, Any]] = {}
        # Future steps remain available for navigation until the route
        # branches or an observation relevant to that route changes.
        self._history: list[dict[str, Any]] = []
        self._cursor = 0

    def _current(self) -> str | None:
        if self._cursor == 0:
            return self._start
        return self._history[self._cursor - 1]["to_event_id"]

    def _gate(self, event_id: str) -> dict[str, Any]:
        requirements = self._checked.requirements_for(event_id)
        observed = self._observations.get(event_id)
        signal = observed["signal"] if observed is not None else None
        conditions = (
            list(observed["conditions"]) if observed is not None else []
        )
        missing = [
            condition for condition in requirements["conditions"]
            if condition not in conditions
        ]
        matching = signal == requirements["signal"]
        return {
            "event_id": event_id,
            "ready": matching and not missing,
            "required_signal": requirements["signal"],
            "observed_signal": signal,
            "signal_matches": matching,
            "required_conditions": list(requirements["conditions"]),
            "observed_conditions": conditions,
            "missing_conditions": missing,
            "requirement_sources": {
                "signal": requirements["signal_source"],
                "conditions": requirements["conditions_source"],
            },
            "observation_origin": (
                "caller_injected" if observed is not None else "not_supplied"
            ),
        }

    def snapshot(self) -> dict[str, Any]:
        """No writes, no clocks. Always build a fresh detached view."""
        path = [entry["choice"] for entry in self._history[:self._cursor]]
        trace = self._checked.preview(self._start, path)
        current = self._current()
        gate = self._gate(current) if current is not None else None
        configured = (
            self._checked.options_for(current) if current is not None else []
        )
        ready = bool(gate and gate["ready"])
        status = (
            "terminal" if current is None else
            "offered" if ready else "blocked"
        )
        result = {
            "task_id": TASK_ID,
            "version": VERSION,
            "candidate_only": True,
            "preview_status": status,
            "start_event_id": self._start,
            "current_event_id": current,
            "cursor": self._cursor,
            "history_length": len(self._history),
            "can_back": self._cursor > 0,
            "can_forward": self._cursor < len(self._history),
            "navigation_history": copy.deepcopy(self._history),
            "selected_path": path,
            "condition_gate": gate,
            "configured_choices": configured,
            "available_choices": copy.deepcopy(configured) if ready else [],
            "observations": copy.deepcopy(self._observations),
            "source_snapshot_sha256": trace["snapshot_sha256"],
            "trace": trace["trace"],
            "trace_sha256": trace["trace_sha256"],
            "no_runtime_effects": True,
            "no_source_writes": True,
            "no_persistence": True,
        }
        result["state_snapshot_sha256"] = _fingerprint(result)
        return result

    def _rejected(
        self, operation: str, code: str, message: str, **details: Any,
    ) -> dict[str, Any]:
        # Errors are returned, not thrown; no history or observation mutation.
        return {
            "ok": False,
            "status": "REJECTED",
            "operation": operation,
            "changed": False,
            "error": _failure(code, message, **details),
            "snapshot": self.snapshot(),
        }

    def _accepted(
        self, operation: str, *, changed: bool = True,
        **info: Any,
    ) -> dict[str, Any]:
        return {
            "ok": True,
            "status": "APPLIED" if changed else "UNCHANGED",
            "operation": operation,
            "changed": changed,
            **info,
            "snapshot": self.snapshot(),
        }

    def _set_observation(
        self, operation: str, event_id: Any,
        signal: Any = None, conditions: Any = None,
    ) -> dict[str, Any]:
        if type(event_id) is not str or event_id not in self._checked.event_ids():
            return self._rejected(
                operation, "UNKNOWN_EVENT", "Observation event ID is not selected"
            )

        if operation == "observe":
            if type(signal) is not str or not ID.fullmatch(signal):
                return self._rejected(
                    operation, "INVALID_SIGNAL",
                    "Observed signal must be a candidate uppercase identifier",
                )
            if type(conditions) is not list or len(conditions) > MAX_OBSERVED_CONDITIONS:
                return self._rejected(
                    operation, "INVALID_CONDITIONS",
                    "Observed conditions must be a list of 0..16 identifiers",
                )
            if any(
                type(value) is not str or not ID.fullmatch(value)
                for value in conditions
            ) or len(set(conditions)) != len(conditions):
                return self._rejected(
                    operation, "INVALID_CONDITIONS",
                    "Observed conditions must be unique valid identifiers",
                )
            replacement = {
                "signal": signal,
                "conditions": sorted(conditions),
            }
        else:
            replacement = None

        existing = self._observations.get(event_id)
        if existing == replacement:
            return self._accepted(operation, changed=False)

        # A previously chosen step may have been validated against the
        # observation being changed. Erase the full route rather than
        # retain a stale or misleading trace. Otherwise retain the
        # verified prefix and discard redo steps only.
        touched_past = any(
            item["from_event_id"] == event_id
            for item in self._history[:self._cursor]
        )
        if touched_past:
            self._history = []
            self._cursor = 0
        else:
            self._history = self._history[:self._cursor]

        if replacement is None:
            self._observations.pop(event_id, None)
        else:
            self._observations[event_id] = replacement
        return self._accepted(
            operation, history_reset=touched_past,
            redo_cleared=not touched_past,
        )

    def apply(self, command: Any) -> dict[str, Any]:
        """Apply one preview-only command with non-mutating error echo.

        Commands: observe, clear_observation, choose, back, forward, jump.
        Unknown keys are rejected to avoid quietly ignoring mistyped input.
        """
        if type(command) is not dict:
            return self._rejected(
                "(invalid)", "INVALID_COMMAND", "Command must be a JSON object"
            )
        op = command.get("op")
        allowed_fields = {
            "observe": {"op", "event_id", "signal", "conditions"},
            "clear_observation": {"op", "event_id"},
            "choose": {"op", "choice"},
            "back": {"op", "steps"},
            "forward": {"op", "steps"},
            "jump": {"op", "cursor"},
        }
        if type(op) is not str or op not in allowed_fields:
            return self._rejected(
                "(unknown)", "UNKNOWN_OPERATION", "Unsupported preview operation"
            )
        expected = allowed_fields[op]
        if set(command) != expected:
            return self._rejected(
                op, "COMMAND_FIELDS",
                "Command field names must match the documented operation",
                required_fields=sorted(expected),
            )

        if op in ("observe", "clear_observation"):
            return self._set_observation(
                op, command["event_id"],
                command.get("signal"), command.get("conditions"),
            )

        if op == "choose":
            choice = command["choice"]
            if type(choice) is not str or not choice:
                return self._rejected(
                    op, "INVALID_CHOICE", "Choice must be a nonempty string"
                )
            current = self._current()
            if current is None:
                return self._rejected(
                    op, "TERMINAL_LOCKED",
                    "There is no next branch after a terminal preview link",
                )
            gate = self._gate(current)
            if not gate["ready"]:
                return self._rejected(
                    op, "CONDITIONS_NOT_MET",
                    "Caller-supplied signal/conditions do not match",
                    condition_gate=gate,
                )
            offered = self._checked.options_for(current)
            selected = next(
                (item for item in offered if item["choice"] == choice),
                None,
            )
            if selected is None:
                return self._rejected(
                    op, "UNKNOWN_CHOICE",
                    "Requested branch was not defined in this event",
                    available_choices=[
                        item["choice"] for item in offered
                    ],
                )
            if self._cursor >= MAX_CHOICES:
                return self._rejected(
                    op, "STEP_LIMIT",
                    "Preview has reached the 24 explicit selection limit",
                )
            # Mutate ONLY this in-memory navigation record after validation.
            self._history = self._history[:self._cursor]
            self._history.append({
                "from_event_id": current,
                "choice": choice,
                "to_event_id": selected["target_event_id"],
                "kind": selected["kind"],
                "gate_at_selection": copy.deepcopy(gate),
            })
            self._cursor += 1
            return self._accepted(op)

        if op in ("back", "forward"):
            steps = command["steps"]
            if type(steps) is not int or not 1 <= steps <= MAX_CHOICES:
                return self._rejected(
                    op, "INVALID_STEPS", "Steps must be an integer in 1..24"
                )
            new_cursor = (
                self._cursor - steps if op == "back" else
                self._cursor + steps
            )
        else:
            new_cursor = command["cursor"]
            if type(new_cursor) is not int:
                return self._rejected(
                    op, "INVALID_CURSOR", "Cursor must be an integer"
                )

        if not 0 <= new_cursor <= len(self._history):
            return self._rejected(
                op, "CURSOR_OUT_OF_RANGE",
                "Requested navigation position is not recorded",
                current_cursor=self._cursor,
                history_length=len(self._history),
            )
        changed = new_cursor != self._cursor
        self._cursor = new_cursor
        return self._accepted(op, changed=changed)


def _parse_command(text: str) -> dict[str, Any]:
    try:
        command = json.loads(text)
    except (ValueError, RecursionError):
        return {"ok": False, "error": _failure(
            "INVALID_COMMAND_JSON", "Command is not valid JSON",
        )}
    return {"ok": True, "command": command}


def render_text(envelope: dict[str, Any]) -> str:
    snapshot = envelope.get("snapshot")
    lines = [
        TASK_ID + " r1 | synthetic, in-memory preview",
        "Result: " + envelope["status"],
    ]
    if snapshot is not None:
        lines.extend([
            "Current: %s | gate: %s | cursor: %d/%d"
            % (
                snapshot["current_event_id"] or "(terminal)",
                snapshot["preview_status"],
                snapshot["cursor"],
                snapshot["history_length"],
            ),
            "Source SHA256: " + snapshot["source_snapshot_sha256"],
            "State SHA256: " + snapshot["state_snapshot_sha256"],
        ])
        gate = snapshot["condition_gate"]
        if gate and not gate["ready"]:
            lines.append(
                "Gate blocked: signal_matches=%s missing_conditions=%s"
                % (gate["signal_matches"], ",".join(gate["missing_conditions"]))
            )
        for item in snapshot["available_choices"]:
            lines.append(
                "  available %s -> %s"
                % (item["choice"], item["target_event_id"] or "(terminal)")
            )
        if not snapshot["available_choices"] and snapshot["configured_choices"]:
            lines.append("Configured choices are not selectable until gate is ready.")
    for index, result in enumerate(envelope.get("operations", [])):
        lines.append(
            "%d. %s %s" % (
                index + 1, result["operation"], result["status"],
            )
        )
        if not result["ok"]:
            lines.append(
                "   ERROR %s: %s"
                % (result["error"]["code"], result["error"]["message"])
            )
    if envelope.get("error") is not None:
        lines.append(
            "ERROR %s: %s"
            % (envelope["error"]["code"], envelope["error"]["message"])
        )
    lines.append("No gameplay state, source data or save files were modified.")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Synthetic conditional flow preview (no game effects)",
    )
    parser.add_argument("inputs", nargs="+", help="Synthetic JSON files/directories")
    parser.add_argument("--event-id", required=True, help="Selected start event ID")
    parser.add_argument(
        "--command", action="append", default=[], metavar="JSON",
        help="One preview command as JSON object; repeat in order",
    )
    parser.add_argument("--format", choices=("json", "text"), default="text")
    args = parser.parse_args(argv)

    try:
        checked = CheckedEventPreview(args.inputs)
        session = SyntheticPlaySession(checked, args.event_id)
    except PreviewFailure as exc:
        envelope = {
            "task_id": TASK_ID,
            "version": VERSION,
            "status": "REJECTED",
            "error": exc.to_dict(),
            "operations": [],
            "no_runtime_effects": True,
        }
        if args.format == "json":
            print(json.dumps(envelope, ensure_ascii=False, indent=2))
        else:
            sys.stdout.write(render_text(envelope))
        return 1

    if len(args.command) > MAX_COMMANDS:
        envelope = {
            "task_id": TASK_ID,
            "version": VERSION,
            "status": "REJECTED",
            "error": _failure(
                "COMMAND_LIMIT", "At most 64 commands may be supplied",
            ),
            "operations": [],
            "snapshot": session.snapshot(),
            "no_runtime_effects": True,
        }
    else:
        operations: list[dict[str, Any]] = []
        for raw in args.command:
            parsed = _parse_command(raw)
            if not parsed["ok"]:
                operations.append({
                    "ok": False,
                    "status": "REJECTED",
                    "operation": "(invalid_json)",
                    "changed": False,
                    "error": parsed["error"],
                    "snapshot": session.snapshot(),
                })
                break
            applied = session.apply(parsed["command"])
            operations.append(applied)
            if not applied["ok"]:
                break
        envelope = {
            "task_id": TASK_ID,
            "version": VERSION,
            "status": (
                "REJECTED" if operations and not operations[-1]["ok"]
                else "PREVIEW"
            ),
            "operations": operations,
            "snapshot": session.snapshot(),
            "no_runtime_effects": True,
        }

    if args.format == "json":
        print(json.dumps(envelope, ensure_ascii=False, indent=2))
    else:
        sys.stdout.write(render_text(envelope))
    return 1 if envelope["status"] == "REJECTED" else 0


if __name__ == "__main__":
    sys.exit(main())
