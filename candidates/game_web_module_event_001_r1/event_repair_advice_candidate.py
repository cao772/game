"""GAME-WEB-CONTINUE-EVENT-003 r1 — review-only repair advice.

Pure interpretation of public candidate diagnostics. Never edits JSON,
guesses story meaning, approves references or generates repair patches.
No file I/O, external services, or runtime imports.
"""
from __future__ import annotations

from collections import Counter, defaultdict
from difflib import get_close_matches
import re
from typing import Any, Mapping

VALID_ID = re.compile(r"[A-Z][A-Z0-9_]{0,63}\Z")

# Keyed to existing checker/diagnostic codes. These suggestions are
# intentionally conservative: every step requires a human decision.
RULES: dict[str, tuple[str, str, tuple[str, ...]]] = {
    "INVALID_JSON": (
        "format", "Repair JSON syntax in the reported file",
        ("Inspect the reported line and column if available.",
         "Correct syntax without discarding unrelated fields.",
         "Validate the entire selected file set again."),
    ),
    "DUPLICATE_JSON_KEY": (
        "format", "Resolve repeated members in the same JSON object",
        ("Compare the reported member with its first occurrence.",
         "Choose the intended single definition; do not trust last-key-wins.",
         "Review affected references before accepting a corrected file."),
    ),
    "INVALID_UTF8": (
        "encoding", "Provide a valid UTF-8 JSON file",
        ("Confirm the actual file encoding and source provenance.",
         "Convert a reviewed copy to UTF-8; preserve the original.",
         "Check the full file for unintended character changes."),
    ),
    "SOURCE_INDEX_ERROR": (
        "location", "Review JSON depth and source-index limitations",
        ("Inspect nesting or index complexity before changing any data.",
         "Reduce nesting only if the candidate format allows it.",
         "Escalate if the file is valid but cannot be located safely."),
    ),
    "OBJECT_REQUIRED": (
        "structure", "Supply a JSON object at the indicated location",
        ("Review the expected object fields in the candidate README.",
         "Replace the incorrect type only after confirming the input contract."),
    ),
    "ARRAY_REQUIRED": (
        "structure", "Supply a JSON array at the indicated location",
        ("Check the candidate README for allowed array contents.",
         "Keep existing data separate until any conversion is reviewed."),
    ),
    "MISSING_FIELD": (
        "structure", "Add the required member after confirming intent",
        ("Consult the candidate contract for the missing field and type.",
         "Add a reviewed value rather than a fabricated default."),
    ),
    "UNKNOWN_FIELD": (
        "structure", "Review an unrecognized member",
        ("Check whether this input belongs to the candidate format.",
         "Do not silently delete or rename a field that may carry data.",
         "Route non-candidate formats to a separately approved adapter."),
    ),
    "INVALID_ID": (
        "identifier", "Review identifier spelling and type",
        ("Use 1–64 characters: uppercase A–Z, digits and underscores.",
         "Start with an uppercase letter and avoid whitespace.",
         "Update all reference sites if changing an event identifier."),
    ),
    "DUPLICATE_EVENT_ID": (
        "cross_reference", "Resolve duplicate event definitions",
        ("Compare every reported definition and linked source location.",
         "Decide whether records duplicate content or need distinct IDs.",
         "Update and recheck every referring file as one review operation."),
    ),
    "DUPLICATE_ACTION_ID": (
        "structure", "Resolve action ID reuse within one event",
        ("Determine which actions are intended to be distinct.",
         "Review and assign IDs without changing event behavior implicitly."),
    ),
    "DUPLICATE_CONDITION": (
        "structure", "Resolve repeated trigger condition identifier",
        ("Inspect all condition entries before removing a duplicate.",
         "Preserve the intended trigger requirements."),
    ),
    "ACTION_COUNT": (
        "structure", "Review number of action definitions",
        ("Candidate format allows 1–16 action objects per event.",
         "Do not invent actions to satisfy the limit."),
    ),
    "CONDITION_COUNT": (
        "structure", "Review number of trigger conditions",
        ("Candidate format allows 1–16 condition identifiers.",
         "Do not invent conditions to satisfy the limit."),
    ),
    "UNKNOWN_EVENT_REFERENCE": (
        "cross_reference", "Review unresolved target identifier",
        ("Check the target identifier spelling at the indicated pointer.",
         "Check whether all intended event files were selected.",
         "Only add a missing event definition with separate approval."),
    ),
    "AMBIGUOUS_EVENT_REFERENCE": (
        "cross_reference", "Resolve ambiguous target definitions",
        ("Inspect each competing definition in related locations.",
         "Decide which ID and reference relationship is intended.",
         "Recheck the whole selected set; do not pick the first match."),
    ),
    "INVALID_EVENT_REFERENCE_TARGET": (
        "cross_reference", "Repair target structure before trusting the link",
        ("Open the referenced definition at its related location.",
         "Resolve the target's structural errors first.",
         "Revalidate source and target together."),
    ),
    "NO_JSON_FILES": (
        "input", "Select intended candidate JSON files",
        ("Check input paths and extensions.",
         "Do not infer records outside the selected set."),
    ),
    "INPUT_NOT_FOUND": (
        "input", "Confirm the explicit path exists",
        ("Check for spelling, path and case differences.",
         "Use the intended file or directory without creating guessed inputs."),
    ),
    "NOT_JSON_FILE": (
        "input", "Select a .json source file",
        ("Check the input's real file format before renaming.",
         "Do not treat non-JSON files as event definitions."),
    ),
    "SYMLINK_FORBIDDEN": (
        "input", "Use a reviewed non-symlink source",
        ("Confirm the actual source without following untrusted symlinks.",
         "Use a separately reviewed regular-file copy if authorized."),
    ),
    "SCAN_ERROR": (
        "input", "Resolve filesystem scan failure",
        ("Review access permissions and the reported directory.",
         "Avoid changing unrelated files."),
    ),
    "READ_ERROR": (
        "input", "Resolve source read failure",
        ("Inspect permissions, existence and file stability.",
         "Retry only against reviewed, stable input files."),
    ),
    "FILE_TOO_LARGE": (
        "input", "Review the file size limit",
        ("Candidate limit is 1 MiB for each selected JSON file.",
         "Do not truncate source data to force a pass."),
    ),
    "FILE_LIMIT": (
        "input", "Review selected file count",
        ("Candidate scan limit is 1,024 distinct JSON files.",
         "Split independent batches only if references remain in-scope."),
    ),
}


def _eligible_candidates(
    documents: Mapping[str, Any],
    issues: list[dict[str, Any]],
) -> list[str]:
    """Only unique IDs on structurally healthy decoded documents.

    A candidate spelling is NEVER a proposed automatic replacement.
    """
    owners: dict[str, set[str]] = defaultdict(set)
    for file, document in documents.items():
        if type(document) is not dict:
            continue
        name = document.get("event_id")
        if type(name) is str and VALID_ID.fullmatch(name):
            owners[name].add(file)

    unhealthy = {
        issue["file"] for issue in issues
        if issue["code"] not in (
            "UNKNOWN_EVENT_REFERENCE",
            "DUPLICATE_EVENT_ID",
            "AMBIGUOUS_EVENT_REFERENCE",
            "INVALID_EVENT_REFERENCE_TARGET",
        )
    }
    return sorted(
        event_id
        for event_id, files in owners.items()
        if len(files) == 1 and next(iter(files)) not in unhealthy
    )


def advice_for_issue(
    issue: Mapping[str, Any],
    eligible_ids: list[str],
) -> dict[str, Any]:
    code = issue["code"]
    category, title, steps = RULES.get(code, (
        "review", "Investigate this diagnostic before changing any data",
        ("Review the source and candidate contract.",
         "Do not apply automatic changes to unknown data."),
    ))
    suggestion: dict[str, Any] = {
        "suggestion_id": "REVIEW_" + code,
        "category": category,
        "title": title,
        "steps": list(steps),
        "auto_apply": False,
        "requires_review": True,
    }
    if code == "UNKNOWN_EVENT_REFERENCE":
        target = issue.get("target_id")
        if type(target) is str:
            # get_close_matches is a search hint, not identity inference.
            near = get_close_matches(
                target, eligible_ids, n=3, cutoff=0.70
            )
            if near:
                suggestion["possible_spelling_matches"] = near
                suggestion["match_note"] = (
                    "Spelling candidates only; none is a confirmed target."
                )
    if code in (
        "AMBIGUOUS_EVENT_REFERENCE",
        "INVALID_EVENT_REFERENCE_TARGET",
        "DUPLICATE_EVENT_ID",
        "DUPLICATE_JSON_KEY",
    ) and issue.get("related"):
        suggestion["review_related_locations"] = True
    return suggestion


def attach_review_advice(
    issues: list[dict[str, Any]],
    documents: Mapping[str, Any],
) -> dict[str, Any]:
    """Mutate the caller's private per-report issue list, not source data."""
    candidates = _eligible_candidates(documents, issues)
    file_counts: Counter[str] = Counter()
    rules: Counter[str] = Counter()
    match_hints = 0
    for issue in issues:
        issue["repair_advice"] = advice_for_issue(issue, candidates)
        file_counts[issue["file"]] += 1
        rules[issue["repair_advice"]["suggestion_id"]] += 1
        if issue["repair_advice"].get("possible_spelling_matches"):
            match_hints += 1
    return {
        "policy": "manual_review_only",
        "auto_fixes_applied": 0,
        "files_with_diagnostics": len(file_counts),
        "diagnostics_by_file": [
            {"file": file, "issue_count": count}
            for file, count in sorted(file_counts.items())
        ],
        "advice_counts_by_rule": dict(sorted(rules.items())),
        "reference_spelling_hints": match_hints,
    }
