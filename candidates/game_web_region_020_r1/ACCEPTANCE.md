# ACCEPTANCE｜future-only verification matrix

**Every case is NOT_RUN**, including syntax/import, Godot, parser, keyboard, UI and resilience tests. GitHub writes/readbacks prove source presence only, not implementation quality.

| ID | Future reviewer action | Required result / failure condition |
| --- | --- | --- |
| S01 | Compare PR diff against main | Only *new* files in `candidates/game_web_region_020_r1/`; no other PR, main or shared-interface edits |
| S02 | Read file sources against pinned PR #26 HEAD | Same publicly synthetic A/B/C input format and exact JSON blob SHA |
| S03 | Import project into authorized Godot 4 | `main.tscn`, scripts and UI import; any error is BLOCK, not PASS |
| V01 | Check valid A/B/C catalog | `SOURCE_ACCEPTED`, no structural ERROR |
| V02 | Check structurally valid but disconnected C | Accepted structurally; no made-up reachability guarantee |
| V03 | Root null / array | `ROOT_OBJECT`, `catalog={}` in failed report |
| V04 | Missing or wrong schema version | `VERSION`, precise `$.schema_version` action |
| V05 | Two or four scenes | `SCENE_COUNT`, source rejected |
| V06 | Duplicate A and missing B | `DUPLICATE_ID` plus `MISSING_ID` |
| V07 | Invalid, null, or out-of-range title | `TITLE` and path |
| V08 | Missing `claimed` or non-Boolean reachability | `CLAIM_OBJECT` or `CLAIM_BOOL` |
| V09 | Grid absent, non-array, non-string row | `GRID_ARRAY` / `ROW_STRING` |
| V10 | 4 or 13 rows | `GRID_HEIGHT`; no unchecked map passes |
| V11 | Width 4 or 17; ragged rows | `GRID_WIDTH`, `RAGGED_ROW`; no silent repair |
| V12 | Unknown glyph `X` | `GRID_GLYPH`, exact row/column path |
| V13 | Open perimeter | `PERIMETER`, closed-boundary action |
| V14 | No S, two S, no T, two T | Relevant `START_COUNT` / `TARGET_COUNT` |
| V15 | Extra unknown field with otherwise valid source | Warning, source can still be structurally accepted |
| V16 | Empty or invalid JSON source | `EMPTY_JSON` / `JSON_SYNTAX`, suggested fix |
| V17 | Exceed candidate 16000-character raw input | Early `INPUT_TOO_LARGE` with no partial acceptance |
| V18 | Exceed 48 diagnostics | `suppressed > 0`, rejected, truncated explicitly indicated |
| R01 | Missing optional `synthetic_regions.json` | Show `FILE_MISSING`, use *labeled* embedded synthetic fallback |
| R02 | File present but unreadable | Show `FILE_UNREADABLE`, never consult other paths |
| R03 | Malformed optional JSON | Preserve original diagnostics, `FALLBACK_SYNTHETIC` |
| R04 | Force invalid embedded fallback in isolated test copy | `BLOCKED`, no usable catalog |
| R05 | Source accepted but claims intentionally inaccurate | No structural ERROR merely for mismatch; gameplay truth not certified |
| R06 | Inspect recovered catalog content | Exactly A/B/C synthetic only, never copied from other PR or real file |
| U01 | Keyboard only, with mouse absent | Controls remain operable and diagnostics readable; log real findings |
| U02 | Use 150% OS scaling/smaller viewport | Details scroll and all field actions remain accessible, or report failure |
| U03 | No audio, textures or custom fonts | Text diagnostics stay usable without unsupported resource claim |
| B01 | Search new files for real names/story/locations | None; no private data or conversation evidence |
| B02 | Recheck source PR #26 and main HEAD | Both unchanged by this PR; PR remains Draft |
| B03 | Review tool invocation history | No Godot, parser, code, tests, CI or simulation actually executed |

**What to capture after later explicit permission:** authorized engine version, device/OS, exact commit, input sample ID, observed error code/path/action, fallback mode, expected vs actual behavior, failures, and explicit reviewer signature. Do not retroactively change this document from NOT_RUN to PASS without such evidence.

**Blocking failures:** missing field accepted silently; malformed source partially used; fallback masquerades as recovered original; invalid embedded fallback accepted; wrong input name treated as a real geography; unsafe dynamic file import; inability to distinguish errors from warnings; making a "successful parse" claim in this writing-only round.
