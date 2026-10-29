#!/usr/bin/env python3
"""GAME-WEB-FLOW-EVENT-004 r1: read-only synthetic event-flow preview.

This is an isolated experiment, not a game runtime or approved shared API.
Requires the unmodified public static checker from stacked Draft PR #9.
Python 3.12+ standard library only; no source writes, imports of scenes, or
persistent event state. All statuses are only preview labels.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

_CHECKER_DIR = Path(__file__).resolve().parent.parent / "game_web_module_event_001_r1"
if not _CHECKER_DIR.is_dir():
    raise ImportError(
        "Required public checker candidate is missing; use the stacked PR #9 base."
    )
sys.path.insert(0, str(_CHECKER_DIR))
from event_data_check_candidate import (  # noqa: E402
    MAX_BYTES_PER_FILE,
    _collect,
    _reject_constant,
    _unique_pairs,
    check_event_data,
)
from event_source_diagnostics_candidate import SourceIndex  # noqa: E402


TASK_ID = "GAME-WEB-FLOW-EVENT-004"
VERSION = "r1"
IGNORE = "@ignore"  # Preview-only sentinel, NOT an event action ID.
MAX_CHOICES = 24


class PreviewFailure(ValueError):
    def __init__(
        self, code: str, detail: str, *,
        step: int | None = None,
        available: list[str] | None = None,
        checker_report: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(detail)
        self.code = code
        self.step = step
        self.available = available
        self.checker_report = checker_report

    def to_dict(self) -> dict[str, Any]:
        error: dict[str, Any] = {"code": self.code, "detail": str(self)}
        if self.step is not None:
            error["step"] = self.step
        if self.available is not None:
            error["available_choices"] = list(self.available)
        if self.checker_report is not None:
            error["checker_report"] = self.checker_report
        return error


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _canonical_sha(value: Any) -> str:
    return _sha(json.dumps(
        value, ensure_ascii=True, sort_keys=True,
        separators=(",", ":"), allow_nan=False,
    ).encode("utf-8"))


@dataclass(frozen=True)
class EventSource:
    event_id: str
    path: str
    sha256: str
    document: dict[str, Any]
    index: SourceIndex

    def location(self, pointer: str) -> dict[str, Any]:
        return {
            "file": self.path,
            "sha256": self.sha256,
            "pointer": pointer,
            "location": self.index.locate(pointer),
        }


class CheckedEventPreview:
    """A per-invocation in-memory snapshot; never sends runtime actions."""

    def __init__(self, inputs: list[str]) -> None:
        if not inputs:
            raise PreviewFailure("MISSING_INPUTS", "No source paths supplied")

        collect_issues: list[dict[str, str]] = []
        paths = _collect(inputs, collect_issues)
        if collect_issues or not paths:
            raise PreviewFailure(
                "INVALID_INPUT_SELECTION",
                "Only existing, regular, selected JSON inputs are accepted",
                checker_report={"issues": collect_issues},
            )

        # Take one bounded byte snapshot, verify exact same selection
        # through the existing candidate checker, then compare bytes.
        # No claim of transactional filesystem consistency or TOCTOU safety.
        before: dict[str, bytes] = {}
        for path in paths:
            try:
                if path.is_symlink():
                    raise PreviewFailure(
                        "INPUT_CHANGED", "A selected file became a symlink"
                    )
                with path.open("rb") as handle:
                    data = handle.read(MAX_BYTES_PER_FILE + 1)
                if len(data) > MAX_BYTES_PER_FILE:
                    raise PreviewFailure(
                        "INPUT_LIMIT", "Selected input exceeds checker size limit"
                    )
                before[path.as_posix()] = data
            except OSError as exc:
                raise PreviewFailure(
                    "INPUT_READ_FAILED", "Cannot read selected input: " + str(exc)
                ) from exc

        report = check_event_data(inputs)
        if report["status"] != "PASS":
            raise PreviewFailure(
                "STRUCTURE_CHECK_FAILED",
                "The public candidate structure checker rejected the inputs",
                checker_report=report,
            )
        if report["files_selected"] != len(paths):
            raise PreviewFailure(
                "INPUT_CHANGED", "Selected file count changed during checking"
            )
        again_issues: list[dict[str, str]] = []
        again = _collect(inputs, again_issues)
        if (
            again_issues
            or [p.as_posix() for p in again] != [p.as_posix() for p in paths]
        ):
            raise PreviewFailure(
                "INPUT_CHANGED", "Input selection changed during checking"
            )

        records: dict[str, EventSource] = {}
        for path in paths:
            filename = path.as_posix()
            try:
                if path.is_symlink():
                    raise PreviewFailure(
                        "INPUT_CHANGED", "A selected file became a symlink"
                    )
                with path.open("rb") as handle:
                    current = handle.read(MAX_BYTES_PER_FILE + 1)
            except OSError as exc:
                raise PreviewFailure(
                    "INPUT_READ_FAILED", "Cannot reread selected input: " + str(exc)
                ) from exc
            if current != before[filename]:
                raise PreviewFailure(
                    "INPUT_CHANGED", "Selected input bytes changed during checking"
                )
            # Decode again from the checked immutable byte snapshot.
            try:
                decoded = current.decode("utf-8")
                doc = json.loads(
                    decoded,
                    object_pairs_hook=_unique_pairs,
                    parse_constant=_reject_constant,
                )
                index = SourceIndex(decoded)
            except (ValueError, UnicodeError, RecursionError) as exc:
                raise PreviewFailure(
                    "INPUT_CHANGED", "Checked source is no longer usable"
                ) from exc
            if type(doc) is not dict or type(doc.get("event_id")) is not str:
                raise PreviewFailure(
                    "INVALID_CHECKED_DOCUMENT", "Checked event is not an object"
                )
            event_id = doc["event_id"]
            if event_id in records:
                raise PreviewFailure(
                    "DUPLICATE_CHECKED_EVENT", "Checked identifier collision"
                )
            records[event_id] = EventSource(
                event_id, filename, _sha(current), doc, index,
            )

        # A snapshot hash never includes paths or source values:
        # hashes identify the exact selected bytes for trace review.
        self._events = records
        self._selected_files = len(paths)
        self._snapshot_sha256 = _canonical_sha([
            {"event_id": name, "sha256": records[name].sha256}
            for name in sorted(records)
        ])
        self._checker_status = report["status"]

    def event_ids(self) -> list[str]:
        return sorted(self._events)

    def options_for(self, event_id: str) -> list[dict[str, Any]]:
        event = self._events.get(event_id)
        if event is None:
            raise PreviewFailure(
                "UNKNOWN_START_EVENT", "Requested event is not in checked inputs"
            )
        choices: list[dict[str, Any]] = []
        for index, action in enumerate(event.document["actions"]):
            target = action["next_event_id"]
            choices.append({
                "choice": action["action_id"],
                "kind": "action",
                "target_event_id": target,
                "outcome": "terminal" if target is None else "linked",
                "source": event.location("/actions/%d" % index),
                "reference_source": event.location(
                    "/actions/%d/next_event_id" % index
                ),
            })
        # Do not invent an ignore option when the field is absent.
        if "on_ignore_event_id" in event.document:
            target = event.document["on_ignore_event_id"]
            choices.append({
                "choice": IGNORE,
                "kind": "ignore",
                "target_event_id": target,
                "outcome": "terminal" if target is None else "linked",
                "source": event.location("/on_ignore_event_id"),
                "reference_source": event.location("/on_ignore_event_id"),
            })
        return choices

    def preview(
        self, start_event_id: str, choices: list[str] | None = None,
    ) -> dict[str, Any]:
        if type(start_event_id) is not str:
            raise PreviewFailure(
                "INVALID_START_EVENT", "Starting event ID must be a string"
            )
        if start_event_id not in self._events:
            raise PreviewFailure(
                "UNKNOWN_START_EVENT", "Starting event is not in selected inputs",
                available=self.event_ids(),
            )
        if choices is None:
            choices = []
        if type(choices) is not list or any(
            type(value) is not str or not value for value in choices
        ):
            raise PreviewFailure(
                "INVALID_SELECTION", "Choices must be a list of nonempty strings"
            )
        if len(choices) > MAX_CHOICES:
            raise PreviewFailure(
                "STEP_LIMIT",
                "At most %d explicit choices may be previewed" % MAX_CHOICES,
            )

        current: str | None = start_event_id
        trace: list[dict[str, Any]] = []
        for index, selected in enumerate(choices):
            if current is None:
                raise PreviewFailure(
                    "EXTRA_SELECTION_AFTER_TERMINAL",
                    "A terminal link has no further preview choices",
                    step=index,
                )
            offered = self.options_for(current)
            chosen = next(
                (option for option in offered if option["choice"] == selected),
                None,
            )
            if chosen is None:
                raise PreviewFailure(
                    "UNKNOWN_CHOICE",
                    "Selection is not offered by the current checked event",
                    step=index,
                    available=[item["choice"] for item in offered],
                )
            # Trace is a proposed link walk; no event state is updated.
            trace.append({
                "step": index,
                "from_event_id": current,
                "selection": selected,
                "kind": chosen["kind"],
                "to_event_id": chosen["target_event_id"],
                "outcome": chosen["outcome"],
                "selected_at": chosen["source"],
                "reference_at": chosen["reference_source"],
                "target_definition": (
                    self._events[chosen["target_event_id"]].location("/event_id")
                    if chosen["target_event_id"] is not None
                    else None
                ),
            })
            current = chosen["target_event_id"]

        available = self.options_for(current) if current is not None else []
        result = {
            "task_id": TASK_ID,
            "version": VERSION,
            "candidate_only": True,
            "checker_status": self._checker_status,
            "snapshot_sha256": self._snapshot_sha256,
            "files_selected": self._selected_files,
            "events_selected": len(self._events),
            "start_event_id": start_event_id,
            "selected_choices": list(choices),
            "preview_status": "terminal" if current is None else "offered",
            "current_event_id": current,
            "current_definition": (
                self._events[current].location("/event_id")
                if current is not None else None
            ),
            "available_choices": available,
            "trace": trace,
            "no_runtime_effects": True,
            "no_source_writes": True,
        }
        # Deterministic digest includes selected path provenance; it is an
        # aid to review, not a signature or proof of event execution.
        result["trace_sha256"] = _canonical_sha(result)
        return result


def render_text(result: dict[str, Any]) -> str:
    lines = [
        "%s r1 | synthetic, read-only preview" % TASK_ID,
        "Checker: %s | snapshot SHA256: %s"
        % (result["checker_status"], result["snapshot_sha256"]),
        "Start: %s | preview: %s | current: %s"
        % (
            result["start_event_id"],
            result["preview_status"],
            result["current_event_id"] or "(terminal)",
        ),
    ]
    for step in result["trace"]:
        location = step["selected_at"]
        lines.append(
            "%d. %s --[%s]--> %s (%s)"
            % (
                step["step"] + 1,
                step["from_event_id"],
                step["selection"],
                step["to_event_id"] or "(terminal)",
                step["outcome"],
            )
        )
        lines.append(
            "   source: %s %s sha256=%s"
            % (
                location["file"], location["pointer"], location["sha256"],
            )
        )
    if result["available_choices"]:
        lines.append("Available choices:")
        for option in result["available_choices"]:
            place = option["source"]
            lines.append(
                "  %s -> %s [%s %s]"
                % (
                    option["choice"],
                    option["target_event_id"] or "(terminal)",
                    place["file"],
                    place["pointer"],
                )
            )
    else:
        lines.append("No further choices in the selected preview.")
    lines.append("trace SHA256: " + result["trace_sha256"])
    lines.append("No runtime effects or input-file modifications.")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Read-only preview of checked synthetic event branches",
    )
    parser.add_argument(
        "inputs", nargs="+", help="JSON files and/or directories (PR #9 contract)"
    )
    parser.add_argument("--event-id", required=True, help="Start event ID")
    parser.add_argument(
        "--choice", action="append", default=[],
        metavar="ACTION_ID",
        help="One explicit branch choice; repeat to walk links. "
             "Use @ignore only where on_ignore_event_id is present.",
    )
    parser.add_argument("--format", choices=("text", "json"), default="text")
    args = parser.parse_args(argv)
    try:
        checked = CheckedEventPreview(args.inputs)
        result = checked.preview(args.event_id, args.choice)
    except PreviewFailure as exc:
        error = {
            "task_id": TASK_ID,
            "version": VERSION,
            "status": "REJECTED",
            "no_runtime_effects": True,
            "error": exc.to_dict(),
        }
        if args.format == "json":
            print(json.dumps(error, ensure_ascii=False, indent=2))
        else:
            print(
                "REJECTED %s: %s" % (exc.code, str(exc)), file=sys.stderr
            )
            if exc.checker_report is not None:
                print(
                    "Structure checker reported %d issue(s)."
                    % len(exc.checker_report.get("issues", [])),
                    file=sys.stderr,
                )
        return 1
    if args.format == "json":
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        sys.stdout.write(render_text(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
