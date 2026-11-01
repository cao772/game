# GAME-WEB-REGION-017 r1 — future acceptance matrix

**EVERY CASE BELOW IS PLANNED / NOT_RUN.** No parser, Godot import, UI test, script execution, CI, screenshot or benchmarking was executed. Successful source upload is not a test result.

| ID | Future action | Expected behavior / stop condition |
| --- | --- | --- |
| S01 | Import standalone project when authorized | Scene opens; absence of required script is reported as failure, not silently substituted |
| S02 | Start A | Synthetic report reach=yes sight=yes, marker on S, no audit |
| S03 | Preview A target | BFS shows route around the # obstruction; marker does not move |
| S04 | Inspect A from start | Sight=false, target reachable=true; no auto correction |
| S05 | Correct A after inspect | Only in-memory sight field changes; original JSON remains intact |
| S06 | Start B | Original reported reachable=false, visible=false |
| S07 | Preview target B | Distinct perimeter route exists despite direct obstruction |
| S08 | Inspect/correct B | Only explicit second action records reachable=true |
| S09 | Start C | Source claims reachable=true although T isolated |
| S10 | Ask for target route C | Show unreachable text and no false route |
| S11 | Ask for recovery route C | Route from current reachable tile back to S exists |
| S12 | Move toward wall | Marker does not cross #; feedback explains block |
| S13 | Click an open tile | Selects route preview; does not move or correct |
| S14 | Click solid tile | Refuses preview and retains previous safe state |
| S15 | Move after Inspect then Correct | Reject stale correction until inspection repeated |
| S16 | Click Correct without Inspect | No mutation; explanatory feedback |
| S17 | Correct twice | Second call is informational no-op; no duplicate outcome |
| S18 | Reset scene | Restores original synthetic claim, marker, preview and cleared audit |
| S19 | Change A→B→A | No user/world state persists; original A claims restored |
| S20 | Missing external JSON | Embedded A/B/C fallback plus visible warning |
| S21 | Invalid/malformed JSON | All-or-nothing fallback; no partial external data |
| S22 | Duplicate IDs or missing T | Invalid catalog rejected, no crash or traversal outside bounds |
| S23 | External malicious text/asset path | Schema and glyph/ID restrictions reject arbitrary scenario data |
| K01 | Map-focused WASD and arrows | Only one legal grid step per non-echo key press |
| K02 | UI button/selector focused | Movement keys do not move marker; Tab traverses native controls |
| K03 | Shift+Tab / Escape | Reverse UI focus; Escape releases map focus |
| K04 | Alt+Tab with held movement key | No movement until keys released after focus return |
| K05 | Focus returns while another control focused | Never steals host UI focus; never auto-confirms/corrects |
| K06 | Resize window and click boundaries | Click coordinates map to displayed tile or safely ignore |
| K07 | Keyboard-only route/inspect/correct | All actions accessible via visible buttons/focus |
| K08 | No custom fonts/textures/audio | Text, map grid, claims and correction remain understandable |
| F01 | Close/reopen project | No previous journal, claim updates or history persisted |
| F02 | Compare with PR #23 head | No edits to PR #23 branch, source, pinned prompt or other PR files |
| F03 | Inspect complete Git diff | All new files solely under new candidate directory |
| F04 | Review source for private material | No canon, geographical names, original novel or personal identifiers |
| F05 | Check scene performance/accessibility | Record actual evidence only after authorized execution; never copy NOT_RUN into PASS |

## Manual source review (without executing)
After the author approves future validation, first inspect syntax/API compatibility with the chosen Godot 4 version. Review BFS edge handling, LOS sampling/corner behavior, and focus notifications before treating any behavior as verified. Check fixture provenance and ensure no private data was added. Then run permitted tests and record exact version, platform, result, screenshots, performance and any failures. This PR has **not** run these steps.

## Blocking acceptance criteria
A critical block is: actual scene cannot import; player can cross #; an inaccessible target is shown reachable; original fixture or real save file is modified; focus return injects movement/confirmation; UI requires sound or color alone; files outside this candidate directory were changed. Any such finding fails this candidate and must be addressed on its own future branch after permission.
