# INPUT_FORMAT｜PR #26 的原始格式和 N20 结构规则

**Source:** `candidates/game_web_region_018_r1/synthetic_regions.json` + `region_model.gd::_valid_catalog` in Draft PR #26 at exact SHA `cd15ec7bc04cceb388f5174b3d8e83e620a23205`. Read-only review; these rules are not an approved shared production contract.

| JSON path | Source requirement | N20 diagnostic |
| --- | --- | --- |
| `$` | Dictionary/object | `ROOT_OBJECT` |
| `$.schema_version` | Exactly `public-synthetic-region-017-v1` | `VERSION` |
| `$.scenarios` | Array, **exactly 3** entries | `SCENE_ARRAY`, `SCENE_COUNT` |
| `$.scenarios[i]` | Dictionary/object | `SCENE_OBJECT` |
| `id` | One of `A`, `B`, `C`, each exactly once | `SCENE_ID`, `DUPLICATE_ID`, `MISSING_ID` |
| `title` | String length **1–40** | `TITLE` |
| `claimed` | Dictionary with **Boolean** `reachable` and `visible` | `CLAIM_OBJECT`, `CLAIM_BOOL` |
| `grid` | Array of **5–12** rows, each String | `GRID_ARRAY`, `GRID_HEIGHT`, `ROW_STRING` |
| `grid[y]` | Uniform width **5–16**, no ragged rows | `GRID_WIDTH`, `RAGGED_ROW` |
| `grid[y][x]` | Only `#`, `.`, `S`, `T` | `GRID_GLYPH` |
| Boundary cells | Exactly `#` on top/bottom/left/right perimeter | `PERIMETER` |
| Each complete grid | Exactly **one** `S` and **one** `T` | `START_COUNT`, `TARGET_COUNT` |
| `notice` | Source fixture has optional free-text description, ignored by model | N20 optionally warns `NOTICE_FORMAT` for non-string |
| Extra fields | PR #26 does not reject extra keys | N20 issues nonfatal `UNKNOWN_*` warnings only |

**Important non-requirements from PR #26:** no guarantee that T can be reached, no guarantee of straight-line visibility, no guarantee that `claimed` is factually true; no coordinates, time, story data, inventory, actors or navigation mesh. A/B/C claims can intentionally be wrong. N20 must **never** reject C merely for being disconnected.

**N20 conservative extensions (new design choices, not source facts):** reject oversized raw JSON strings before parsing (16000 chars); bound detailed diagnostics to 48 entries and reject if suppressed; inspect only up to three scene records / 12 rows / 16 columns on invalid oversized data; label unknown keys as warnings; keep source as accepted only if the entire structural input is valid. Avoid automatic repair, interpolation, mutation, truncation-to-fit or auto-correcting claims. A truncated diagnostics list is *not* evidence of valid input. These limits have not been performance-tested.

**Index convention:** paths use zero-based array indices like `$.scenarios[1].grid[3][4]`. Diagnostics correspond to the *input structure*, not to Godot object paths. Error/action strings are synthetic examples; issue format is **local to N20**, not a new shared JSON Schema or approved API.

**Recovery distinction:** `catalog_recovery.gd` is an independent demo adapter and is **not** plugged into or replacing PR #26's actual `load_catalog`. It only reads the project-local optional synthetic fixture. If that file is absent/invalid, a visibly labeled, embedded A/B/C fallback can be offered. If the fallback fails its own check, fail closed with no usable catalog. Real maps and private files are never candidate fallback sources.

**NOT_RUN:** no JSON parser, toolchain, runtime or tests were executed while authoring.
