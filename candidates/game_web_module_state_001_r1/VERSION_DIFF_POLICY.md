# GAME-WEB-CONTINUE-STATE-003 r1 — Version Difference & Safe Preview Design

**Design status: independent proposal, NOT_RUN, Canon N/A.** Extends Draft PR #13 only. This document explains choices made without asking for ordinary implementation decisions.

## Source checked

At the start of this increment, Draft PR #13 was open and Draft:
`codex/game-web-module-state-001-r1` HEAD `a43a361bb98fafbd4e857eaf5f5705abcb31c2a1`.
Reviewed its `snapshot_inspector_candidate.gd` and README, REPORT_FORMAT,
MIGRATION_POLICY, ACCEPTANCE and future tests. The sole known snapshot
schema is v1 (six fields) sourced by the previous candidate from
Draft PR #6. No v0, v2, or other schema, mapping table, runtime save,
clock semantics, or author-approved conversion rules were provided.
**None are invented.**

## New read-only APIs (candidate, not shared)

### `report_version_delta(path, expected_mode, reference_version = 1)`

A single-source version comparison **against the only known protocol v1**.
Requires numeric 1 (int or float, not bool) as reference; other references
return `invalid_reference`, `REFERENCE_NOT_APPROVED_V1`, without inspecting
a file. Source version is classified by the existing inspector.

Returns only sanitized `status`, `error_code`, expected mode enum,
safe source version label, `numeric_relation` and
`format_compatibility`. Version order values are:
`lower_numeric_version`, `same_numeric_version`,
`higher_numeric_version`, or `unknown`.

Why: numeric order is useful diagnostics, but it is **not** migration
direction, source schema understanding, backwards compatibility or
automatic version upgrade. Always returns `can_migrate=false` and
`migration_mapping=not_provided`, even for a valid v1 source.
Any version input other than finite numeric is *invalid*, not unknown
future version.

### `compare_snapshot_versions(left_path, right_path, expected_mode)`

Two separate reads, each with its own path/mode validation. The response
contains a **sanitized** report for each side, numeric version relation
and an ordered list of known field names/kinds **only when BOTH snapshots
are fully validated v1**. Field diff reports contain no field values.
JSON number 1 and 1.0 are equivalent where schema allows numbers.

- Both valid v1: `comparable_v1`, `known_v1_fields_only`,
  ordered field change descriptors and count.
- Either validated same-mode unsupported numeric version:
  `unmapped_versions`, `VERSION_MAPPING_NOT_PROVIDED`,
  numeric relation may be known but **no payload field comparison**.
- Missing, damaged, unreadable, oversized, invalid-schema or foreign mode:
  `blocked`, `UNCOMPARABLE_SOURCES`; no payload diff.
- `atomic_pair=false`: even comparing a file to itself is two independent
  reads and cannot prove stable filesystem state or concurrent consistency.

Why: a field called `clock_seconds` in an unknown version might no longer
represent the same semantic data. Comparing it to v1 as if it did would
suggest compatibility without evidence. Therefore comparison across
unknown schema is intentionally refused.

### `preview_migration_safe(path, expected_mode, proposed_target = null)`

This is the **preferred redacted API**. Prior detailed
`preview_migration` is retained for source compatibility and still
contains a local decoded-text fingerprint; it must not be published.
The new safe method returns no path, checksum, old/new values, round
ID or raw JSON.

- Invalid, unreadable, corrupt, mode mismatched, oversized source:
  `blocked` even with a valid caller target.
- Unsupported numeric source version, valid matching mode:
  `mapping_required` **whether or not a target is provided**.
  No inferred or superficial field mapping to unknown schemas.
- Fully valid v1 source with no proposed target: `no_migration_needed`.
- Fully valid v1 + identical complete target: `no_changes`.
- Fully valid v1 + different complete target: comparison only; always
  unappliable. If `version`, `mode`, `round_id`, or `clock_seconds`
  changes, status `protected_field_review_blocked`, reason
  `PROTECTED_FIELDS_DIFFER`. Otherwise
  `same_version_review_only`. Neither status accepts a gameplay change.
- Target must exactly pass the known v1 schema and expected mode; a
  wrong-mode target is `invalid_target`.
- Changes only contain **allowlisted known field names and operation kind**;
  never before/after values or unknown field names.
- `requires_review=true`, `mapping_approved=false`, `can_apply=false`,
  `writes=false`, `contains_snapshot_payload=false`, `verified=false`
  in **all** branches.

Why protect version/mode/round ID/clock? These fields are identity,
isolation or time-bearing, where a careless preview could imply that a
cross-mode or cross-timeline mutation is safe. No time movement,
round-ID change or gameplay semantics can be approved by this candidate.
Phase and door changes are visible **only as field names** and still
review-only, never an accepted write.

## Public/private boundary

`report_snapshot`, `report_pair`, `report_version_delta`,
`compare_snapshot_versions`, `preview_migration_safe`: deliberately
exclude path, decoded-text hash, private round ID, raw JSON and source
values (though metadata such as mode/version and changed field names
can itself be sensitive). Share only after an operational privacy review.

`inspect_snapshot`, `inspect_pair`, and the historical
`preview_migration`: **detailed internal candidate APIs**; these may
contain validated snapshot data or decoded-text hashes. Never forward
their raw responses to public GitHub/Notion/Drive.

## Failure and security boundaries

- No `WRITE`, `rename`, `remove`, `mkdir`, external command,
  commit/apply or interprocess lock in the inspector.
- The `user://` filter is lexical only and does NOT prove that symbolic
  links cannot escape a directory. The source could change between reads.
- Godot JSON parser acceptance is not advertised as strict RFC 8259;
  duplicate-key behavior, invalid Unicode and numeric overflow are
  separate validation risks.
- 1 MiB inspection cap is candidate-only, not the writer's maximum.
- No cross-file atomic snapshot; no crash-transaction claim.
- No authenticity or authorization check for source file, so results
  **cannot** establish a save's provenance.
- New methods are proposal interfaces only; not an approved public or
  shared API. Do not connect them to runtime, save core, event triggers
  or UI until a separate decision and tests.

## Later Codex acceptance gates

The future SceneTree tests in `verify_version_diff_003.gd` exercise:
numeric order, unknown versions and missing mapping, two-file v1 structural
differences, corrupted/foreign/missing-field blocked states, preview
identity/time guards, redaction and byte preservation.
Original suites remain present.

Expected results in scripts are **not execution evidence**. Status remains
`NOT_RUN` until Codex separately runs and records process exit codes.
See `ACCEPTANCE.md` for the future procedure and evidence requirements.
