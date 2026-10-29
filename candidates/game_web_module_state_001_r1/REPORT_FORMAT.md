# GAME-WEB-MODULE-STATE-002 r1 — report and error contract (candidate)

**NOT_RUN; independent proposal; Canon N/A.**
No production or shared API has been approved.

## Public-safe report (still subject to metadata review)

`report_snapshot(path, expected_mode)` returns a new Dictionary.
It has no source path, round_id, phase, door_open, clock_seconds, raw JSON,
fingerprint or before/after values.

| Key | Shape | Meaning |
|---|---|---|
| `report_version` | int = 1 | Version of this *candidate report layout*, not the save |
| `task_id` | constant string | Technical task identifier |
| `status` | enum string | Inspection result |
| `valid` | bool | True only if fully validated v1 + expected mode |
| `error_code` | static uppercase code or empty | Never interpolates file content |
| `error_field` | known six-field name or empty | No arbitrary source key emitted |
| `version_label` | sanitized string | "1", finite numeric label, "unknown", "invalid_type", "nonfinite", or out-of-display-range marker |
| `expected_mode` | story/free/invalid | Safe enum |
| `source_mode` | story/free/empty | Safe enum; invalid raw input not echoed |
| `byte_length` | nonnegative integer | File length measured while opened; zero if unavailable |
| `compatibility` | structured object | See below |
| `read_only` | true | No file writes by inspector |
| `contains_snapshot_payload` | false | This report excludes payloads |
| `verified` | false | Source-only proposal is not test evidence |

`compatibility` contains `classification`, `reason_code`,
`source_version`, `target_version=1`, and
`automatic_migration_supported=false`.

### Compatibility classifications

| Inspection status | Classification | Meaning |
|---|---|---|
| `valid` | `compatible_v1` | Exactly known v1, correct mode; *format only* |
| `unsupported_version` | `unsupported` | Finite numeric !=1 + verified matching mode; **no mapping** |
| `mode_mismatch` | `incompatible_mode` | Valid enum source mode differs from expected (takes precedence over version) |
| `invalid_schema` | `invalid` | Untrustworthy version, missing/invalid mode or malformed known v1 fields |
| `malformed_json`, `too_large`, `missing`, `unreadable`, `invalid_request` | `indeterminate` | No reliable positive compatibility determination |

**Important:** An unsupported source version does not imply the format is
migratable. A valid v1 shape does not imply compatibility with gameplay,
story/free clock behavior, or any other runtime.

### Safe inspection and issue codes

Codes are stable candidate diagnostics, not source-derived text:

- Path/access: `INVALID_EXPECTED_MODE`, `UNSUPPORTED_PATH_SCHEME`,
  `UNSAFE_PATH`, `FILENAME_MODE_MISMATCH`, `PATH_IS_DIRECTORY`,
  `FILE_MISSING`, `OPEN_FAILED`, `FILE_TOO_LARGE`.
- Decoding/JSON: `JSON_PARSE_FAILED`, `ROOT_NOT_OBJECT`.
- Version/mode: `MISSING_FIELD` (`version` or a known v1 field),
  `INVALID_VERSION_TYPE`, `NONFINITE_VERSION`,
  `UNSUPPORTED_VERSION`, `INVALID_MODE`, `SOURCE_MODE_MISMATCH`.
- v1 schema: `UNEXPECTED_FIELD`, `INVALID_ROUND_ID_TYPE`,
  `BLANK_ROUND_ID`, `INVALID_PHASE`, `INVALID_DOOR_OPEN`,
  `INVALID_CLOCK_TYPE`, `NONFINITE_CLOCK`, `NEGATIVE_CLOCK`.

An error code does not embed JSON text, file path, unrecognized field names
or parser diagnostics. Multiple problems can coexist; **one deterministic
first-found code** is returned, in the validation order defined by source.
No promise to enumerate all errors or recover damaged content.

## Detailed (private/local) APIs

`inspect_snapshot` is retained for existing candidate callers. It returns
`data` (full v1 snapshot) only for valid v1; `text_sha256` represents
a decoded-text hash if text was read. The data and hash must not be blindly
published to GitHub or CI logs.

`preview_migration` is not a public-share-safe report by itself because it
retains `text_sha256`. Its `changes` array **is redacted**, containing
only known candidate field identifiers and `kind` (`add`, `remove`,
`change`). A source may contain unrecognized keys; only
`unrecognized_source_field_count` is revealed, **never their names**.
It cannot infer field meaning or apply an upgrade.

If sharing a preview summary externally, extract only safe status/error code
and redacted change entries after authorization. Do not include the original
path, SHA-256 or private in-memory data.

## Preview failure/status matrix

| Source state | Proposed target | Preview status | `ok` | Changes |
|---|---|---|---|---|
| Valid v1 | absent | `no_migration_needed` | true | none |
| Valid v1 | valid unchanged v1 | `no_changes` | true | none |
| Valid v1 | valid changed v1 | `same_version_proposal` | true | Known-field structural diff |
| Unsupported numeric version, same mode | absent | `mapping_required` | false | none |
| Unsupported numeric version, same mode | explicitly provided valid v1 | `manual_unverified_preview` | true* | Known-field structural diff only |
| Valid/unsupported source | invalid target | `invalid_target` | false | none |
| Invalid path, foreign mode, damaged/invalid-schema, missing, unreadable, oversized | anything | `blocked` | false | none |

`*ok=true` means **a comparison was formed**, NOT "migration possible"
or "source compatible". All outcomes keep
`requires_review=true`, `mapping_approved=false`,
`can_apply=false`, and `writes=false`.

## Example (synthetic, not execution output)

```json
{
  "report_version": 1,
  "task_id": "GAME-WEB-MODULE-STATE-002",
  "status": "unsupported_version",
  "valid": false,
  "error_code": "UNSUPPORTED_VERSION",
  "error_field": "version",
  "version_label": "0",
  "expected_mode": "story",
  "source_mode": "story",
  "byte_length": 0,
  "compatibility": {
    "classification": "unsupported",
    "reason_code": "NO_APPROVED_MAPPING",
    "source_version": "0",
    "target_version": 1,
    "automatic_migration_supported": false
  },
  "read_only": true,
  "contains_snapshot_payload": false,
  "verified": false
}
```

The example's byte_length=0 is a **placeholder**, not the actual length
of a fixture or evidence of an executed inspection.

## Privacy and reliability limits

- File size and version are metadata; treat even these as private where
  disclosure is sensitive.
- No file-lock, snapshot consistency, symlink containment, byte-level
  UTF-8 validity proof, strict RFC JSON parser guarantee, or OS crash
  transaction guarantee.
- Only the six fields from the GitHub-visible PR #6 candidate are known.
  Neither backward nor forward migration rules exist.
- Everything in this file is **source-only**; tests and Godot 4.7.2
  runtime semantics await Codex verification.

---

## CONTINUE-STATE-003 / report extensions (candidate, NOT_RUN)

Refer to [VERSION_DIFF_POLICY.md](VERSION_DIFF_POLICY.md). The new safe
methods use only enums, bounded version labels, known field names and
static error codes. They exclude raw input, file path and text hash.

**`report_version_delta`**: `status`, `error_code`,
`reference_version=1`, `source_version`,
`numeric_relation` (lower/same/higher/unknown),
`format_compatibility`, `migration_mapping=not_provided`,
`can_migrate=false`, `read_only=true`, `verified=false`.
Only the known version 1 is a permitted reference. Other references
return `invalid_reference` / `REFERENCE_NOT_APPROVED_V1`.

**`compare_snapshot_versions`**: `left` and `right` redacted
snapshot reports, `version_relation`, `status`,
`error_code`, `payload_comparison`, `changed_fields`,
`changed_field_count`, `mapping_approved=false`,
`can_migrate=false`, `atomic_pair=false`, `verified=false`.
Two fully valid v1 inputs yield `comparable_v1` and field-name-only
changes. Any unsupported numeric version yields `unmapped_versions`
and `VERSION_MAPPING_NOT_PROVIDED`, with no payload diff. Other
non-comparable source statuses yield `blocked` /
`UNCOMPARABLE_SOURCES`.

**`preview_migration_safe`**: `status`, `error_code`,
`source_status`, compatibility, changed known fields and kinds,
`protected_field_changes` (known names only), count, and constant
`requires_review=true`, `mapping_approved=false`,
`can_apply=false`, `writes=false`,
`contains_snapshot_payload=false`, `verified=false`.
Statuses: `blocked`, `mapping_required`,
`invalid_target`, `no_migration_needed`, `no_changes`,
`same_version_review_only`, `protected_field_review_blocked`.
Unknown versions do not become comparable with an invented target.
The protected field set is version/mode/round_id/clock_seconds.

The old detailed APIs are retained for future compatibility checks,
but **are not safe to post publicly as raw report dictionaries**.
All new outputs are provisional and remain NOT_RUN.
