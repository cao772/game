"""GAME-WEB-EVENT-006 r1: pure diagnostic and navigation presentation helpers.

Static, synthetic, in-memory candidate only. No filesystem I/O, runtime
event dispatch, game engine imports, save writes or semantic inference.
Public contract is the PR #9 placeholder trigger/condition/branch format.
"""
from __future__ import annotations

from typing import Any, Mapping


def explain_gate(gate: Mapping[str, Any] | None) -> dict[str, Any]:
    """Explain the EXISTING EVENT-005 gate without changing eligibility."""
    if gate is None:
        return {
            "status": "terminal",
            "ready": False,
            "reason_codes": ["TERMINAL"],
            "reasons": [],
            "additional_observed_conditions": [],
            "next_step": "No next preview event is configured at this terminal link.",
        }

    reasons: list[dict[str, Any]] = []
    origin = gate.get("observation_origin")
    sources = gate.get("requirement_sources") or {}

    if origin == "not_supplied":
        reasons.append({
            "code": "OBSERVATION_NOT_SUPPLIED",
            "detail": "No synthetic observation was supplied for this event.",
            "source": sources.get("signal"),
        })
    else:
        if not gate.get("signal_matches", False):
            reasons.append({
                "code": "SIGNAL_MISMATCH",
                "detail": "The injected signal differs from the required identifier.",
                "required": gate.get("required_signal"),
                "observed": gate.get("observed_signal"),
                "source": sources.get("signal"),
            })
        missing = list(gate.get("missing_conditions") or [])
        if missing:
            reasons.append({
                "code": "REQUIRED_CONDITIONS_MISSING",
                "detail": "The injected condition set omits required identifiers.",
                "missing": missing,
                "source": sources.get("conditions"),
            })

    observed = gate.get("observed_conditions") or []
    required = gate.get("required_conditions") or []
    additional = sorted(set(observed) - set(required))
    ready = bool(gate.get("ready"))
    if not ready and not reasons:
        # Fail closed if the upstream gate has another blocking rule:
        # an unrecognized failure is NOT recast as ready.
        reasons.append({
            "code": "GATE_UNAVAILABLE",
            "detail": "The upstream synthetic gate is blocked for an unknown reason.",
            "source": sources.get("signal"),
        })

    return {
        "status": "ready" if ready else "blocked",
        "ready": ready,
        "reason_codes": [reason["code"] for reason in reasons],
        "reasons": reasons,
        "additional_observed_conditions": additional,
        "next_step": (
            "Review authored branches; choose explicitly if desired."
            if ready else
            "Inject a synthetic observation for this event."
            if origin == "not_supplied" else
            "Correct the supplied synthetic signal/condition identifiers."
        ),
    }


def breadcrumbs(
    start_event_id: str,
    history: list[dict[str, Any]],
    cursor: int,
) -> dict[str, Any]:
    """Return detached route positions. Future entries are not applied."""
    positions: list[dict[str, Any]] = [{
        "cursor": 0,
        "event_id": start_event_id,
        "via_choice": None,
        "from_event_id": None,
        "selected_prefix": True,
    }]
    for index, entry in enumerate(history, start=1):
        positions.append({
            "cursor": index,
            "event_id": entry["to_event_id"],
            "via_choice": entry["choice"],
            "from_event_id": entry["from_event_id"],
            "selected_prefix": index <= cursor,
        })
    return {
        "cursor": cursor,
        "length": len(history),
        "positions": positions,
        "back_available": cursor > 0,
        "redo_available": cursor < len(history),
        "rollback_cursor_range": [0, cursor],
        "navigation_is_preview_only": True,
    }


def first_changed_step(
    history: list[dict[str, Any]],
    cursor: int,
    event_id: str,
) -> int | None:
    """Index of first applied choice requiring the changed observation."""
    for index, step in enumerate(history[:cursor]):
        if step["from_event_id"] == event_id:
            return index
    return None


_ERROR_GUIDANCE: dict[str, tuple[str, str, str]] = {
    "CONDITIONS_NOT_MET": (
        "condition", "The current synthetic conditions block this choice.",
        "Review condition_diagnostics and inject a matching observation.",
    ),
    "UNKNOWN_CHOICE": (
        "branch", "That branch is not configured at the current event.",
        "Select an ID from available_choices; do not invent branches.",
    ),
    "TERMINAL_LOCKED": (
        "navigation", "A terminal link has no next branch.",
        "Navigate backward or jump to an earlier recorded cursor.",
    ),
    "STEP_LIMIT": (
        "navigation", "The explicit preview path is at its step bound.",
        "Use back or rollback; no step is applied automatically.",
    ),
    "CURSOR_OUT_OF_RANGE": (
        "navigation", "The requested cursor is not recorded or allowed.",
        "Review navigation.positions and the allowed cursor range.",
    ),
    "INVALID_STEPS": (
        "navigation", "The step count is not an allowed integer.",
        "Use an integer in the documented interval, excluding booleans.",
    ),
    "INVALID_CURSOR": (
        "navigation", "The cursor must be an integer, excluding booleans.",
        "Use a recorded position from navigation.positions.",
    ),
    "ROLLBACK_FORWARD_FORBIDDEN": (
        "navigation", "Rollback cannot move to a future cursor.",
        "Use forward to inspect redo, or rollback to a prior position.",
    ),
    "UNKNOWN_EVENT": (
        "input", "The observed event is outside the checked file set.",
        "Review the explicitly selected placeholder event IDs.",
    ),
    "INVALID_SIGNAL": (
        "input", "The injected signal identifier is invalid.",
        "Use a valid synthetic uppercase identifier.",
    ),
    "INVALID_CONDITIONS": (
        "input", "Injected condition identifiers are invalid.",
        "Use unique uppercase identifiers and obey the count limit.",
    ),
    "COMMAND_FIELDS": (
        "input", "The command fields differ from the documented contract.",
        "Review the operation's required fields without guessing defaults.",
    ),
    "INVALID_COMMAND": (
        "input", "The command is not a JSON object.",
        "Supply a single JSON command object.",
    ),
    "UNKNOWN_OPERATION": (
        "input", "The operation name is unsupported.",
        "Choose a documented preview-only operation.",
    ),
    "INVALID_COMMAND_JSON": (
        "input", "The command argument is not valid JSON.",
        "Correct JSON syntax without changing event source files.",
    ),
    "STRUCTURE_CHECK_FAILED": (
        "checker", "The required public structure checker rejected inputs.",
        "Review checker_report; no branches should be offered.",
    ),
}


def present_error(
    error: Mapping[str, Any],
    snapshot: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    """Produce safe, structured error UI metadata, never a repair patch."""
    code = error.get("code", "UNKNOWN_ERROR")
    category, title, suggestion = _ERROR_GUIDANCE.get(
        code,
        ("review", "Preview request could not be completed.",
         "Inspect the structured error and its candidate source limits."),
    )
    gate = snapshot.get("condition_gate") if snapshot else None
    position = snapshot.get("navigation") if snapshot else None
    related: list[dict[str, Any]] = []

    if code == "CONDITIONS_NOT_MET" and gate is not None:
        for reason in explain_gate(gate)["reasons"]:
            if reason.get("source") is not None:
                related.append({
                    "reason_code": reason["code"],
                    "source": reason["source"],
                })

    return {
        "code": code,
        "category": category,
        "title": title,
        "message": error.get("message", error.get("detail", "")),
        "suggestion": suggestion,
        "related_sources": related,
        "cursor": position["cursor"] if position else None,
        "state_snapshot_sha256": (
            snapshot.get("state_snapshot_sha256") if snapshot else None
        ),
        "source_state_changed": False,
        "auto_repair": False,
        "manual_review_only": True,
    }
