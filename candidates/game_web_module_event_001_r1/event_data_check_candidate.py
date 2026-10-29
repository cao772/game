#!/usr/bin/env python3
"""GAME-WEB-MODULE-EVENT-001 r1: isolated event-data checker candidate.

Standard-library only. Public synthetic contract, NOT the private EVENT001
schema, NOT a game runtime, NOT an approved shared interface.
No network access, repair operation, or output-file writes.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

from event_source_diagnostics_candidate import (
    SourceIndex, SourceIndexError, enhance_issues,
)
from event_repair_advice_candidate import attach_review_advice
from event_report_candidate import render_text_report

ID_PATTERN = re.compile(r"^[A-Z][A-Z0-9_]{0,63}$")
MAX_BYTES_PER_FILE = 1024 * 1024
MAX_FILES = 1024
MAX_ACTIONS = 16
MAX_CONDITIONS = 16


class DuplicateJSONKey(ValueError):
    """Raised before object construction silently loses a duplicate key."""


def _unique_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateJSONKey("Duplicate JSON member: " + repr(key))
        result[key] = value
    return result


def _reject_constant(value: str) -> None:
    raise ValueError("Nonstandard JSON numeric constant: " + value)


def _issue(
    issues: list[dict[str, str]],
    code: str,
    file: str,
    pointer: str,
    detail: str,
) -> None:
    issues.append({
        "code": code,
        "file": file,
        "pointer": pointer,
        "detail": detail,
    })


def _pointer(parent: str, member: str | int) -> str:
    token = str(member).replace("~", "~0").replace("/", "~1")
    return parent + "/" + token


def _object_fields(
    value: Any,
    required: set[str],
    optional: set[str],
    issues: list[dict[str, str]],
    file: str,
    pointer: str,
) -> bool:
    if type(value) is not dict:
        _issue(issues, "OBJECT_REQUIRED", file, pointer, "Expected JSON object")
        return False
    for key in sorted(required - value.keys()):
        _issue(issues, "MISSING_FIELD", file, _pointer(pointer, key), "Required field")
    for key in sorted(value.keys() - required - optional):
        _issue(issues, "UNKNOWN_FIELD", file, _pointer(pointer, key), "Unknown field")
    return True


def _identifier(
    value: Any,
    issues: list[dict[str, str]],
    file: str,
    pointer: str,
) -> bool:
    if type(value) is str and ID_PATTERN.fullmatch(value):
        return True
    _issue(
        issues, "INVALID_ID", file, pointer,
        "Expected uppercase A-Z, 0-9, underscore; leading letter; 1..64 chars",
    )
    return False


def _reference(
    value: Any,
    issues: list[dict[str, str]],
    file: str,
    pointer: str,
    references: list[tuple[str, str, str]],
) -> None:
    if value is None:
        return
    if _identifier(value, issues, file, pointer):
        references.append((file, pointer, value))


def _validate_event(
    doc: Any,
    file: str,
    issues: list[dict[str, str]],
    ids: dict[str, tuple[str, str]],
    references: list[tuple[str, str, str]],
) -> bool:
    if not _object_fields(
        doc, {"event_id", "trigger", "actions"},
        {"on_ignore_event_id"}, issues, file, "",
    ):
        return False

    event_id = doc.get("event_id")
    if "event_id" in doc and _identifier(event_id, issues, file, "/event_id"):
        previous = ids.get(event_id)
        if previous is not None:
            _issue(
                issues, "DUPLICATE_EVENT_ID", file, "/event_id",
                "Already defined at %s%s" % previous,
            )
        else:
            ids[event_id] = (file, "/event_id")

    trigger = doc.get("trigger")
    if "trigger" in doc and _object_fields(
        trigger, {"signal", "conditions"}, set(), issues, file, "/trigger",
    ):
        if "signal" in trigger:
            _identifier(trigger["signal"], issues, file, "/trigger/signal")
        if "conditions" in trigger:
            conditions = trigger["conditions"]
            if type(conditions) is not list:
                _issue(
                    issues, "ARRAY_REQUIRED", file,
                    "/trigger/conditions", "Expected array",
                )
            elif not 1 <= len(conditions) <= MAX_CONDITIONS:
                _issue(
                    issues, "CONDITION_COUNT", file,
                    "/trigger/conditions", "Expected 1..16 conditions",
                )
            if type(conditions) is list:
                seen_conditions: set[str] = set()
                for index, condition in enumerate(conditions):
                    at = _pointer("/trigger/conditions", index)
                    if _identifier(condition, issues, file, at):
                        if condition in seen_conditions:
                            _issue(
                                issues, "DUPLICATE_CONDITION", file, at,
                                "Repeated condition identifier",
                            )
                        seen_conditions.add(condition)

    actions = doc.get("actions")
    if "actions" in doc:
        if type(actions) is not list:
            _issue(issues, "ARRAY_REQUIRED", file, "/actions", "Expected array")
        else:
            if not 1 <= len(actions) <= MAX_ACTIONS:
                _issue(
                    issues, "ACTION_COUNT", file,
                    "/actions", "Expected 1..16 actions",
                )
            seen_actions: set[str] = set()
            for index, action in enumerate(actions):
                at = _pointer("/actions", index)
                if not _object_fields(
                    action, {"action_id", "next_event_id"},
                    set(), issues, file, at,
                ):
                    continue
                if "action_id" in action and _identifier(
                    action["action_id"], issues, file, _pointer(at, "action_id"),
                ):
                    action_id = action["action_id"]
                    if action_id in seen_actions:
                        _issue(
                            issues, "DUPLICATE_ACTION_ID", file,
                            _pointer(at, "action_id"), "Repeated action in one event",
                        )
                    seen_actions.add(action_id)
                if "next_event_id" in action:
                    _reference(
                        action["next_event_id"], issues, file,
                        _pointer(at, "next_event_id"), references,
                    )

    if "on_ignore_event_id" in doc:
        _reference(
            doc["on_ignore_event_id"], issues, file,
            "/on_ignore_event_id", references,
        )
    return True


def _collect(
    roots: list[str],
    issues: list[dict[str, str]],
) -> list[Path]:
    found: dict[str, Path] = {}
    for root_text in roots:
        root = Path(root_text)
        if root.is_symlink():
            _issue(
                issues, "SYMLINK_FORBIDDEN", str(root), "",
                "Explicit symlink input not allowed",
            )
            continue
        if root.is_file():
            if root.suffix.lower() != ".json":
                _issue(
                    issues, "NOT_JSON_FILE", str(root), "",
                    "Explicit file must have .json extension",
                )
                continue
            resolved = root.resolve()
            found[str(resolved)] = resolved
        elif root.is_dir():
            def walking_error(exc: OSError) -> None:
                _issue(
                    issues, "SCAN_ERROR", str(root), "",
                    str(exc),
                )
            for current, dirs, files in os.walk(
                root, topdown=True, followlinks=False, onerror=walking_error,
            ):
                for name in list(dirs):
                    child = Path(current) / name
                    if child.is_symlink():
                        _issue(
                            issues, "SYMLINK_FORBIDDEN", str(child), "",
                            "Directory symlink not traversed",
                        )
                        dirs.remove(name)
                for name in sorted(files):
                    if not name.lower().endswith(".json"):
                        continue
                    child = Path(current) / name
                    if child.is_symlink():
                        _issue(
                            issues, "SYMLINK_FORBIDDEN", str(child), "",
                            "File symlink not followed",
                        )
                        continue
                    resolved = child.resolve()
                    found[str(resolved)] = resolved
        else:
            _issue(
                issues, "INPUT_NOT_FOUND", str(root), "",
                "Expected existing file or directory",
            )

    candidates = [found[key] for key in sorted(found)]
    if len(candidates) > MAX_FILES:
        _issue(
            issues, "FILE_LIMIT", "<inputs>", "",
            "At most %d distinct JSON files allowed" % MAX_FILES,
        )
        return []
    if not candidates:
        _issue(
            issues, "NO_JSON_FILES", "<inputs>", "",
            "No JSON files selected",
        )
    return candidates


def check_event_data(inputs: list[str]) -> dict[str, Any]:
    """Read-only, deterministic candidate validation. Not an approved API."""
    issues: list[dict[str, str]] = []
    paths = _collect(inputs, issues)
    ids: dict[str, tuple[str, str]] = {}
    references: list[tuple[str, str, str]] = []
    parsed_count = 0
    # Source indices and decoded objects belong solely to this in-memory run.
    indexes: dict[str, SourceIndex] = {}
    documents: dict[str, Any] = {}
    syntax_locations: dict[str, dict[str, Any]] = {}

    for path in paths:
        name = path.as_posix()
        try:
            size = path.stat().st_size
            if size > MAX_BYTES_PER_FILE:
                _issue(
                    issues, "FILE_TOO_LARGE", name, "",
                    "Per-file limit is %d bytes" % MAX_BYTES_PER_FILE,
                )
                continue
            raw = path.read_bytes()
            if len(raw) > MAX_BYTES_PER_FILE:
                _issue(
                    issues, "FILE_TOO_LARGE", name, "",
                    "File grew beyond per-file limit during read",
                )
                continue
        except OSError as exc:
            _issue(issues, "READ_ERROR", name, "", str(exc))
            continue

        try:
            decoded = raw.decode("utf-8")
        except UnicodeError:
            _issue(issues, "INVALID_UTF8", name, "", "Strict UTF-8 required")
            continue

        try:
            document = json.loads(
                decoded,
                parse_constant=_reject_constant,
            )
        except json.JSONDecodeError as exc:
            _issue(issues, "INVALID_JSON", name, "", exc.msg)
            syntax_locations[name] = {
                "line": exc.lineno,
                "column": exc.colno,
                "precision": "exact",
                "column_unit": "unicode_character",
            }
            continue
        except (ValueError, RecursionError) as exc:
            _issue(issues, "INVALID_JSON", name, "", str(exc))
            continue

        try:
            index = SourceIndex(decoded)
        except (SourceIndexError, ValueError) as exc:
            _issue(issues, "SOURCE_INDEX_ERROR", name, "", str(exc))
            continue

        indexes[name] = index
        if index.duplicates:
            # The JSON parser normally uses last-key-wins. Fail closed on
            # ALL duplicated members, including deeply nested ones, and
            # retain each repeated key's precise source coordinate.
            for pointer, offset, first_offset in index.duplicates:
                _issue(
                    issues, "DUPLICATE_JSON_KEY", name, pointer,
                    "Repeated JSON member; first at %s"
                    % index.coordinate(first_offset),
                )
                issues[-1]["location"] = index.coordinate(offset)
                issues[-1]["related"] = [{
                    "file": name,
                    "pointer": pointer,
                    "location": index.coordinate(first_offset),
                }]
            continue

        documents[name] = document
        if _validate_event(document, name, issues, ids, references):
            parsed_count += 1

    for file, pointer, target in references:
        if target not in ids:
            _issue(
                issues, "UNKNOWN_EVENT_REFERENCE", file, pointer,
                "Reference target not present in selected inputs: " + target,
            )

    issues, by_code, references_checked = enhance_issues(
        issues, indexes, documents, syntax_locations,
    )
    advice_summary = attach_review_advice(issues, documents)
    return {
        "task_id": "GAME-WEB-MODULE-EVENT-001",
        "version": "r1",
        "enhancement_task_id": "GAME-WEB-MODULE-EVENT-002",
        "enhancement_version": "r1",
        "diagnostic_format": "2.0-candidate",
        "continuation_task_id": "GAME-WEB-CONTINUE-EVENT-003",
        "continuation_version": "r1",
        "advice_format": "3.0-candidate",
        "status": "FAIL" if issues else "PASS",
        "files_selected": len(paths),
        "event_objects_read": parsed_count,
        "unique_event_ids": len(ids),
        "references_checked": references_checked,
        "issue_count": len(issues),
        "issue_counts_by_code": by_code,
        "repair_review_summary": advice_summary,
        "issues": issues,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Read-only checker for synthetic candidate event JSON files."
    )
    parser.add_argument(
        "inputs", nargs="+", help="JSON files and/or recursive directories"
    )
    parser.add_argument(
        "--json", action="store_true",
        help="Print machine-readable JSON report (legacy alias)",
    )
    parser.add_argument(
        "--format", choices=("text", "json"), default=None,
        help="Diagnostic report format, defaults to text",
    )
    args = parser.parse_args(argv)
    if args.json and args.format == "text":
        parser.error("--json and --format text cannot be combined")
    report = check_event_data(args.inputs)
    output_format = "json" if args.json else (args.format or "text")
    if output_format == "json":
        print(json.dumps(report, indent=2, ensure_ascii=False))
    else:
        sys.stdout.write(render_text_report(report))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
