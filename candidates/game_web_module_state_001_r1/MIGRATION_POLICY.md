# Migration-preview policy (proposal only)

Task: `GAME-WEB-MODULE-STATE-001 r1`. Canon version: **N/A**.
Source contract: `GAME-WEB-STATE-001 r1` as copied unchanged into
[Draft PR #6](https://github.com/cao772/game/pull/6).
This document **does not approve any legacy schema or future target schema**.

## Authoritative input available

The only observed complete protocol is `version: 1` with the six strict
fields in README. Neither a `version: 0` schema nor a `version: 2`
schema, approved migration rules, or actual production saves were
provided. Therefore auto-conversion, default field values, preservation
of unknown fields, time adjustment and schema upgrade are **unspecified**.

The synthetic `version: 0` test fixture tests version detection and
human-supplied comparison **only**. It is not historical evidence.

## Candidate preview workflow

1. Inspect selected path with explicitly chosen expected mode. Check the
   path's exact mode-specific filename; never search for "any save" and
   never move a file between the two modes.
2. Recognize `valid`, `unsupported_version`, `invalid_schema`,
   `mode_mismatch`, `malformed_json`, missing/unreadable and oversize.
3. For a fully valid v1 snapshot, report `no_migration_needed` without
   changes unless the caller explicitly proposes a different complete
   valid v1 object. Such a diff is **same-version content proposal**.
4. For an unsupported version, `mapping_required` is the default and
   **nothing is inferred**. If a reviewer supplies a complete target v1
   JSON object, preview field differences and label the result
   `manual_unverified_preview`.
5. No apply button, save/rename hook, in-memory publisher, or overwrite
   action exists. `can_apply` and `writes` are both always false.
6. Do not share runtime difference values publicly: `round_id` and
   future source-specific keys can be sensitive.

## Decision gates before any future executable migration

- **Author/product** must provide explicit source schemas, target schema,
  verified examples, permitted field mappings, handling for missing /
  unknown fields, clock policy and mode handling.
- **Technical reviewer** must specify failure / rollback behavior, write
  coordination and corruption handling in a separate approved design.
- **Codex** must first run this standalone test suite and then independently
  test the proposed mapping with synthetic fixture data. Nothing in this
  module writes real saves or approves a mapping.
- **QA** must record Godot version, commit, exact command, exit status,
  output and any platform differences before marking verified.

## Limitations requiring attention

- JSON parser behavior may accept some non-strict forms, including
  duplicate keys; a stricter JSON syntax requirement needs separate design.
- No multi-file snapshot consistency or concurrent writer lock.
- Text fingerprint is not a guarantee that source content is unchanged
  between separate calls.
- Size cap 1 MiB is candidate-only; it is not an official save limit.
- The matching v1 rules are duplicated from PR #6, not dynamically bound
  to a shared codec; changes upstream require explicit review.
- Invalid source with a supplied valid target produces **review data only**
  and says nothing about whether the proposed values are correct.
