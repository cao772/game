# BOUNDARY_CASES｜static expected outcomes, not executed

The following are **planned boundary specimens** in `synthetic_boundary_cases.gd` and not actual test results. A future authorized reviewer may load the independent project and select any case. All examples are purely fictional A/B/C grids and make no contact with private resources.

| Case | In-memory mutation / source | Expected leading diagnostics | Proposed recovery |
| --- | --- | --- | --- |
| `VALID_ABC` | Embedded 3-scene A/B/C candidate | `SOURCE_ACCEPTED`; no structural error | Retain deep-copied synthetic catalog |
| `VALID_DISCONNECTED_C` | Embedded catalog including C's isolated T | `SOURCE_ACCEPTED` | **Do not** reject reachability; structural ≠ navigable |
| `ROOT_NULL` | Replace root object with null | `ROOT_OBJECT` | Provide object with version and scenarios; demo uses labeled fallback |
| `VERSION_MISMATCH` | Change `schema_version` to unsupported value | `VERSION` | Restore exact pinned version; no auto migration |
| `SCENE_COUNT_TWO` | Drop third scene | `SCENE_COUNT`, `MISSING_ID` | Add missing C; do not replicate another ID |
| `DUPLICATE_A` | Set B ID to A | `DUPLICATE_ID`, `MISSING_ID` | Keep unique A/B/C |
| `CLAIM_AS_TEXT` | `claimed.reachable = "true"` | `CLAIM_BOOL` | Use actual JSON Boolean, not string |
| `MISSING_T` | Remove T from A row | `TARGET_COUNT` | Restore one T inside boundary, no guessed position |
| `RAGGED_ROW` | Shorten A row | `RAGGED_ROW` and maybe other dependent issues | Make rows equal width; do not truncate or pad automatically |
| `OPEN_EDGE` | Put `.` at top-left boundary | `PERIMETER` | Change boundary back to # |
| `UNKNOWN_GLYPH` | Insert `X` inside A grid | `GRID_GLYPH` | Use only `# . S T` |
| `NONSTRING_ROW` | Replace a row with null | `ROW_STRING` and possibly counts | Replace with valid string row |
| `TOO_FEW_ROWS` | Reduce A to 3 lines | `GRID_HEIGHT` (plus further issues possible) | Return to 5–12 rows, keep perimeter |
| `EXTRA_FIELD_WARNING` | Add `extra_synthetic_note` to A | Warning `UNKNOWN_SCENE_FIELD`, no structural ERROR | Optional typo warning; no unknown field interpreted |
| `INVALID_JSON_SYNTAX` | Deliberately invalid **synthetic text** | `JSON_SYNTAX` with line/message | Fix syntax, or use explicit labeled fallback |

**Additional future test data to construct only under separate permission:** empty input, unsupported top-level array, missing scenes, 4 scenes, empty and 13 rows, widths 4/5/16/17, S on perimeter, two S, zero T, unknown keys, malformed claims, oversized raw text, oversized issues list, read-denied optional file, deliberately broken embedded fallback. These are **design cases**, not generated or executed test results.

**Decision point:** source accepted with warnings is not "business data clean"; all validation results are **structural only**. A source can be structurally accepted but have claimed reachability deliberately wrong. The fallback is always visibly labeled `FALLBACK_SYNTHETIC`, not "fixed source" or "verified game map".

**Every expected outcome above = NOT_RUN.** No test scripts, parser calls or user-facing runtime were executed.
