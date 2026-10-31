# GAME-WEB-STATE-006 r1 | Comparison, anomaly and redaction policy

**Independent public technical proposal. NOT_RUN / NOT_VERIFIED. Canon N/A.**

## Verified starting point

Before development, GitHub Draft PR #20 was read directly.
Repository `cao772/game`, branch `codex/game-web-flow-state-004-r1`,
current starting HEAD **`962822db414c3335eccc08cb22ede36d1f802d52`**,
target `main`, `draft=true`. Read the source of the browser
Control, RefCounted model, presenter, future test scripts and relevant
README/DESIGN/SAFETY/ACCEPTANCE documents. The existing pinned
inspector dependency is the unchanged public PR #13 candidate
blob `89369cb3f6b7f80a508a608865a80a79c3855032`.

This task modifies **only the existing PR #20 independent candidate
directory**. No other PR, novel manuscript, save core, canon, event
interface or shared contract is changed or approved.

## Decisions selected without author intervention

1. **Layer a pure diagnostic policy** instead of editing PR #13's pinned
   inspector. The new `snapshot_diagnostics_candidate.gd` returns only
   static risk classes, notice codes and allowlisted known field names.
   It has no filesystem or side-effect capabilities and cannot approve
   migration. This preserves the exact upstream blob and allows
   independent future unit-like tests.
2. **Fail closed on anomalous comparisons**. Field-level comparison is
   meaningful only when two matching-mode snapshots are both validated
   v1. An invalid/missing/unknown-version source results in an explicit
   blocked/unmapped warning and **no known-field differences** in the
   diagnostic output. A reported numeric ordering cannot establish
   schema compatibility.
3. **Make identical-folder comparison explicit**. If directory A and B
   strings match exactly, the UI warns that the operation is two reads
   of the *same reference*, not a backup comparison. Different input
   strings do **not** guarantee different underlying files: symlinks
   and aliases are not resolved.
4. **Separate risk level from technical success**. `informational`,
   `review_required`, `blocked` are UI advice labels, not claims
   of file authenticity, successful repair or game rules. A v1-valid
   snapshot is format-valid only.
5. **Redact at both the model and presenter boundary**. The model
   exposes fixed risk/notice codes and allowlisted field IDs only.
   The presenter maps them to Chinese strings from static dictionaries;
   unknown codes, unapproved keys, `before`/`after`, raw JSON,
   file path, round ID, clock value, text checksum or arbitrary
   untrusted content are never interpolated.
6. **Treat unavailable fingerprints as unavailable evidence**.
   If a source is missing, unreadable, oversized or rejected before
   decoding, the model labels consistency `no_payload_to_verify`.
   A prior status-only repeat must not imply the source bytes were
   checked. The existing first/last decoded-text hash comparison is
   best-effort race detection, not locking.
7. **Preserve the existing three-tab UI and four actions**, adding a
   concise status/severity label and expanded anomaly explanations
   inside the tab reports. No new save/restore/apply control is added,
   and path/mode/hypothetical changes still invalidate stale reports.
8. **No dynamic error text in the view**. Only named, statically listed
   codes are rendered, with fallback `未知状态` or `未知诊断`.
   The model may receive a complete copy of a valid v1 snapshot
   transiently for a hypothetical preview, but only the safe
   difference metadata reaches the Control.

## Classification matrix (new candidate)

| Context | Condition | Risk level | Notices / behavior |
|---|---|---|---|
| Inspection | `valid` v1 | informational | `V1_FORMAT_ONLY`, `NO_ATOMICITY` |
| Inspection | missing / unreadable | review_required | `FILE_UNAVAILABLE`, `NO_PAYLOAD_VERIFICATION` |
| Inspection | unsupported numeric version | review_required | `VERSION_MAPPING_ABSENT`; no upgrade claim |
| Inspection | invalid JSON/schema, oversized, mode mismatch | blocked | `CORRUPT_OR_INVALID` or `MODE_MISMATCH` |
| Inspection | invalid request / source unstable | blocked | `INVALID_REQUEST` or `SOURCE_UNSTABLE` |
| Comparison | two validated v1, zero known differences | informational | `NO_KNOWN_DIFF` **not** proven byte identity |
| Comparison | two validated v1, some known differences | review_required | `DIFF_PRESENT`; protected names also `PROTECTED_DIFFERENCE` |
| Comparison | A and B same lexical folder | additional note | `SAME_SOURCE_SELECTED`; not an independent backup |
| Comparison | unsupported numeric version | blocked | `VERSION_MAPPING_ABSENT`, no field comparison |
| Comparison | malformed, missing, invalid, foreign-mode, unstable | blocked | `UNCOMPARABLE` / `SOURCE_UNSTABLE` |
| Preview | valid v1, no target or identical target | informational | no version migration, **never an apply operation** |
| Preview | valid v1, phase / door hypothetical | review_required | `DIFF_PRESENT`, `PREVIEW_NEVER_APPLIES` |
| Preview | protected field change | blocked | `PROTECTED_DIFFERENCE`; no source mutation |
| Preview | unknown version/missing mapping/invalid source | blocked | `VERSION_MAPPING_ABSENT` / `UNCOMPARABLE` |
| All | any state | not executable | `can_apply=false`, `writes=false` |

Every diagnostic includes `verified=false` and
`contains_snapshot_payload=false`. There is **no claim**
that the underlying v1 snapshot is authorized or logically correct.

## UI output contract

- `snapshot_browser_candidate.gd` uses only the
  `snapshot_report_presenter_candidate.gd` allowlisted formatter.
- The presenter suppresses diff field lists when a comparison is
  not `comparable_v1`, or when a preview is blocked/mapping-required.
- The diagnostic policy's `known_changed_fields` likewise stays
  **empty** in noncomparable/blocked states.
- Risk labels are neutral language (information, manual review, blocked),
  not a "PASS"/"verified" badge.
- Only six known v1 field **names** may be shown with `add`,
  `remove`, or `change` (no field values, IDs or hashes).
- The local input fields necessarily display operator-typed folder
  paths; reports omit them. Do not screenshot or upload private paths.

## Nonfunctional boundaries and honest limitations

- No run/test/parser check performed in this authoring turn.
- No file writes in production UI/model/presenter/diagnostics; the
  standalone Godot engine may write its own cache/config, which
  is a separate runtime behavior **not verified**.
- No symlink containment guarantee, no strict RFC JSON/UTF-8 proof,
  no interprocess lock, no data authenticity, and no atomic multi-read
  consistency. A source can change and change back between observations.
- Different path strings may alias the same physical snapshot.
- The only known source schema is the PR #13 candidate v1; old
  versions and migration mappings are **NOT_PROVIDED**.
- Neither readable anomalies nor source-only tests promote a
  speculative UI to a product-shared API or story canon.

## Future evidence required

`verify_diagnostics_006.gd` is a pure in-memory future test suite;
the existing model, UI and presenter suites also remain.
Commands, acceptance matrix and evidence template are in
[ACCEPTANCE.md](ACCEPTANCE.md). A test **source** is not a test run.
Status remains **NOT_RUN** until later authorized Codex execution
with actual commit, Godot version, exit codes, outputs and review.
