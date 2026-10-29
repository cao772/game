"""GAME-WEB-CONTINUE-EVENT-003 r1: human-readable diagnostics renderer.

In-memory formatting only. Does not access files or propose code patches.
Report JSON continues to be emitted by the original CLI --json flag.
"""
from __future__ import annotations

from collections import defaultdict
from typing import Any, Mapping


def _where(location: Any) -> str:
    if type(location) is not dict:
        return "location-unavailable"
    line = location.get("line")
    column = location.get("column")
    if type(line) is not int or type(column) is not int:
        return "location-unavailable"
    precision = location.get("precision", "unspecified")
    return "%d:%d (%s)" % (line, column, precision)


def render_text_report(report: Mapping[str, Any]) -> str:
    """Return a deterministic complete diagnostic report as a string.

    No source excerpts are included. Source paths are shown only because
    the user explicitly selected those paths; do not publish a report of
    private data or absolute local paths in a public issue.
    """
    lines = [
        "%s: %d file(s), %d event(s), %d issue(s)"
        % (
            report["status"],
            report["files_selected"],
            report["event_objects_read"],
            report["issue_count"],
        ),
        "Static public placeholder contract only; not engine validation.",
    ]
    if not report["issues"]:
        lines.append("No diagnostics for the selected candidate inputs.")
        return "\n".join(lines) + "\n"

    grouped: dict[str, list[Mapping[str, Any]]] = defaultdict(list)
    for issue in report["issues"]:
        grouped[issue["file"]].append(issue)

    for filename in sorted(grouped):
        entries = grouped[filename]
        lines.append("")
        lines.append("%s (%d error(s))" % (filename, len(entries)))
        for number, issue in enumerate(entries, start=1):
            pointer = issue.get("pointer", "") or "(root)"
            lines.append(
                "  [%d] %s @ %s | %s"
                % (
                    number,
                    issue["code"],
                    _where(issue.get("location")),
                    pointer,
                )
            )
            lines.append("      " + issue["detail"])
            target = issue.get("target_id")
            if type(target) is str:
                lines.append("      target_id: " + target)
            for related in issue.get("related", []):
                lines.append(
                    "      related: %s @ %s | %s"
                    % (
                        related["file"],
                        _where(related.get("location")),
                        related.get("pointer", "") or "(root)",
                    )
                )
            fix = issue.get("repair_advice")
            if type(fix) is dict:
                lines.append(
                    "      suggestion [%s; manual]: %s"
                    % (fix["suggestion_id"], fix["title"])
                )
                for step, action in enumerate(fix["steps"], start=1):
                    lines.append("        %d. %s" % (step, action))
                near = fix.get("possible_spelling_matches", [])
                if near:
                    lines.append(
                        "      possible spelling matches (UNCONFIRMED): "
                        + ", ".join(near)
                    )

    lines.append("")
    lines.append(
        "No repairs applied. Review every suggestion before changing data."
    )
    return "\n".join(lines) + "\n"
