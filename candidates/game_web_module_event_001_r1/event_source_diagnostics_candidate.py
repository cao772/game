"""GAME-WEB-MODULE-EVENT-002 r1: additive source diagnostics candidate.

Used only by the isolated public placeholder-data checker.
No narrative sources, runtime imports, I/O, or approved shared interface.
This module indexes locations AFTER strict JSON decoding succeeds.
"""
from __future__ import annotations

from bisect import bisect_right
from collections import Counter, defaultdict
import json
from typing import Any, Mapping


MAX_INDEX_DEPTH = 128


def _pointer(parent: str, token: str | int) -> str:
    escaped = str(token).replace("~", "~0").replace("/", "~1")
    return parent + "/" + escaped


class SourceIndexError(ValueError):
    """Valid JSON exceeds the candidate indexer's supported complexity."""


class SourceIndex:
    """Locate keys and array entries in a strictly decoded JSON document.

    JSON itself is validated by the calling json.loads(...).
    Locations use 1-based Unicode character columns, NOT byte offsets.
    Duplicate member occurrences are recorded before overwritten values
    can hide them. Parent fallback is flagged as approximate.
    """

    def __init__(self, text: str) -> None:
        self.text = text
        self.starts = [0] + [
            index + 1 for index, character in enumerate(text)
            if character == "\n"
        ]
        self.positions: dict[str, int] = {}
        self.duplicates: list[tuple[str, int, int]] = []
        self.decoder = json.JSONDecoder()
        try:
            end = self._walk("", 0, 0)
            if self._skip(end) != len(self.text):
                raise SourceIndexError("Unexpected trailing characters")
        except (RecursionError, IndexError) as exc:
            raise SourceIndexError(
                "Source position index cannot parse this nesting"
            ) from exc

    def _skip(self, at: int) -> int:
        while at < len(self.text) and self.text[at] in " \t\n\r":
            at += 1
        return at

    def _walk(self, pointer: str, at: int, depth: int) -> int:
        if depth > MAX_INDEX_DEPTH:
            raise SourceIndexError(
                "Source location nesting exceeds %d" % MAX_INDEX_DEPTH
            )
        at = self._skip(at)
        if at >= len(self.text):
            raise SourceIndexError("Unexpected end of document")
        self.positions.setdefault(pointer, at)
        marker = self.text[at]

        if marker == "{":
            at = self._skip(at + 1)
            if self.text[at] == "}":
                return at + 1
            members: dict[str, int] = {}
            while True:
                key_at = self._skip(at)
                key, at = self.decoder.raw_decode(self.text, key_at)
                if type(key) is not str:
                    raise SourceIndexError("Object key is not a string")
                child = _pointer(pointer, key)
                self.positions.setdefault(child, key_at)
                if key in members:
                    self.duplicates.append((child, key_at, members[key]))
                else:
                    members[key] = key_at
                at = self._skip(at)
                if self.text[at] != ":":
                    raise SourceIndexError("Object member missing ':'")
                at = self._walk(child, at + 1, depth + 1)
                at = self._skip(at)
                if self.text[at] == "}":
                    return at + 1
                if self.text[at] != ",":
                    raise SourceIndexError("Object member missing ','")
                at += 1

        if marker == "[":
            at = self._skip(at + 1)
            if self.text[at] == "]":
                return at + 1
            index = 0
            while True:
                at = self._walk(_pointer(pointer, index), at, depth + 1)
                at = self._skip(at)
                if self.text[at] == "]":
                    return at + 1
                if self.text[at] != ",":
                    raise SourceIndexError("Array item missing ','")
                at += 1
                index += 1

        # json.loads has already rejected invalid JSON and NaN/Infinity.
        _, end = self.decoder.raw_decode(self.text, at)
        return end

    def coordinate(self, at: int, precision: str = "exact") -> dict[str, Any]:
        line = bisect_right(self.starts, at)
        return {
            "line": line,
            "column": at - self.starts[line - 1] + 1,
            "precision": precision,
            "column_unit": "unicode_character",
        }

    def locate(self, pointer: str) -> dict[str, Any] | None:
        current = pointer
        while True:
            if current in self.positions:
                quality = "exact" if current == pointer else "parent"
                return self.coordinate(self.positions[current], quality)
            if not current:
                break
            current = current.rsplit("/", 1)[0]
        return None


def enhance_issues(
    original: list[dict[str, Any]],
    indexes: Mapping[str, SourceIndex],
    documents: Mapping[str, Any],
    syntax_locations: Mapping[str, dict[str, Any]],
) -> tuple[list[dict[str, Any]], dict[str, int], int]:
    """Enrich existing diagnostics and detect ambiguous/invalid targets.

    Keeps original issue codes/pointers stable for the EVENT001 test suite.
    Cross-file target resolution remains selected-input-only.
    """
    issues: list[dict[str, Any]] = [dict(issue) for issue in original]

    definitions: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for filename in sorted(documents):
        doc = documents[filename]
        if type(doc) is not dict:
            continue
        event_id = doc.get("event_id")
        if type(event_id) is str:
            # A definition is indexed only if it conforms to the public
            # placeholder ID format. The caller validates this separately.
            import re
            if re.fullmatch(r"[A-Z][A-Z0-9_]{0,63}", event_id):
                definitions[event_id].append((filename, "/event_id"))

    def related_location(filename: str, pointer: str) -> dict[str, Any]:
        index = indexes.get(filename)
        return {
            "file": filename,
            "pointer": pointer,
            "location": index.locate(pointer) if index else None,
        }

    structural_invalid = {
        issue["file"]
        for issue in issues
        if issue["code"] not in {
            "UNKNOWN_EVENT_REFERENCE", "DUPLICATE_EVENT_ID"
        }
    }

    # A reference pointing at multiple definitions must not look resolved
    # merely because the original first-definition symbol table found one.
    # A sole malformed target is explicitly differentiated from an unknown
    # reference; this is a target-file structural diagnostic, not runtime QA.
    references_checked = 0
    for filename in sorted(documents):
        doc = documents[filename]
        if type(doc) is not dict:
            continue
        references: list[tuple[str, Any]] = []
        if "on_ignore_event_id" in doc:
            references.append(("/on_ignore_event_id", doc["on_ignore_event_id"]))
        actions = doc.get("actions")
        if type(actions) is list:
            for number, action in enumerate(actions):
                if type(action) is dict and "next_event_id" in action:
                    references.append((
                        _pointer(_pointer("/actions", number), "next_event_id"),
                        action["next_event_id"],
                    ))
        for pointer, target in references:
            if type(target) is not str:
                continue
            import re
            if not re.fullmatch(r"[A-Z][A-Z0-9_]{0,63}", target):
                continue
            references_checked += 1
            found = definitions.get(target, [])
            if len(found) > 1:
                issues.append({
                    "code": "AMBIGUOUS_EVENT_REFERENCE",
                    "file": filename,
                    "pointer": pointer,
                    "detail": "Multiple definitions for referenced identifier",
                    "target_id": target,
                    "related": [
                        related_location(file, where) for file, where in found
                    ],
                })
            elif len(found) == 1 and found[0][0] in structural_invalid:
                target_file, target_pointer = found[0]
                issues.append({
                    "code": "INVALID_EVENT_REFERENCE_TARGET",
                    "file": filename,
                    "pointer": pointer,
                    "detail": "Referenced event has structural errors",
                    "target_id": target,
                    "related": [related_location(target_file, target_pointer)],
                })

    for issue in issues:
        issue["severity"] = "error"
        filename = issue["file"]
        pointer = issue["pointer"]
        index = indexes.get(filename)

        # JSON syntax offsets are authoritative, even without a source index.
        if issue["code"] == "INVALID_JSON" and filename in syntax_locations:
            issue["location"] = dict(syntax_locations[filename])
        else:
            issue.setdefault(
                "location", index.locate(pointer) if index else None
            )

        if issue["code"] == "DUPLICATE_EVENT_ID":
            doc = documents.get(filename)
            event_id = doc.get("event_id") if type(doc) is dict else None
            locations = [
                related_location(file, at)
                for file, at in definitions.get(event_id, [])
                if file != filename
            ]
            if locations:
                issue["related"] = locations

        if issue["code"] == "UNKNOWN_EVENT_REFERENCE":
            doc = documents.get(filename)
            target = None
            if pointer == "/on_ignore_event_id" and type(doc) is dict:
                target = doc.get("on_ignore_event_id")
            elif pointer.startswith("/actions/") and type(doc) is dict:
                parts = pointer.split("/")
                if len(parts) == 4 and parts[3] == "next_event_id":
                    actions = doc.get("actions")
                    if type(actions) is list and parts[2].isdigit():
                        number = int(parts[2])
                        if number < len(actions) and type(actions[number]) is dict:
                            target = actions[number].get("next_event_id")
            if type(target) is str:
                issue["target_id"] = target

    issues.sort(key=lambda issue: (
        issue["file"], issue["pointer"], issue["code"], issue["detail"]
    ))
    by_code = dict(sorted(Counter(
        issue["code"] for issue in issues
    ).items()))
    return issues, by_code, references_checked
