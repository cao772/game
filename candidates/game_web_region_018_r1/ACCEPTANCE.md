# GAME-WEB-REGION-018 r1 — future-only acceptance cases

**ALL ITEMS: NOT_RUN.** No Godot import, GDScript parser, code execution, test runner, native UI interaction, screenshot, CI, screen reader or performance measurement occurred while writing this candidate. The following are future procedures and expected outcomes, not actual PASS results.

## Build / source integrity

| ID | Future action | Required result |
| --- | --- | --- |
| SRC01 | Import this folder as a standalone Godot 4 project | `main.tscn` and all three required scripts import; if not, record actual failure |
| SRC02 | Inspect complete PR diff vs main | Only new `candidates/game_web_region_018_r1/` paths; no shared APIs, canon or other PR changes |
| SRC03 | Compare JSON blob to PR #25 pin | Identical public A/B/C fixture and no real geographic, story or private values |
| SRC04 | Search and inspect source for external dependencies | None except built-in Godot classes and optional synthetic JSON |
| SRC05 | Open with no custom media assets installed | Default fonts/controls and text-grid display remain usable or failure explicitly documented |

## Synthetic correctness, recovery and undo

| ID | Future action | Required result |
| --- | --- | --- |
| A01 | Select A, preview T | Walls block direct view; four-neighbor detour exists; preview only, no movement |
| A02 | Inspect A from S, then Correct | Claims show reachable yes/visible no after explicit correction, not before |
| B01 | Select B, preview and inspect | T has a detour despite initial report reachable no; source not overwritten |
| B02 | Correct B, then Undo | In-memory claim reverts, journal adds transparent undo entry, Inspect must be repeated |
| C01 | Select C, preview T | No route through isolated walls; message explicitly says not reachable |
| C02 | Preview S from reachable tile | Return route available; user is not teleported |
| REC01 | Try to walk into a wall | Position unchanged, text explains block and next recovery action |
| REC02 | Move legally, then Undo | Exactly last successful position restored, preview removed, inspection invalidated |
| REC03 | Inspect, move, Correct without reinspecting | Correction refused; user receives actionable warning |
| REC04 | Correct before Inspect | No mutation and guidance to Inspect first |
| REC05 | Correct an already matching claim | No-op, not an additional undo event |
| REC06 | Undo on empty stack | No crash/mutation; guidance to preview return or reset |
| REC07 | Exceed provisional 16-entry undo capacity | No unbounded history; only most recent 16 successful mutations reversible |
| REC08 | Generate >12 audit messages | Journal bounded, with correct order and no private info |
| REC09 | Reset A, change A→B→A | Local observations, undo and corrected values reset; no persistence across scenes |
| REC10 | Click a blocked or unreachable tile | Clear refusal/route failure; click does not move marker |
| REC11 | Clear route preview | Map/text path markers removed; movement and claim unchanged |

## Accessibility / keyboard and focus

| ID | Future action | Required result |
| --- | --- | --- |
| KB01 | Unplug/ignore mouse, start with Tab | All scene/settings and movement/inspect/correct/undo/reset controls operable using Tab/Shift+Tab and Enter/Space |
| KB02 | Focus any direction Button and activate | P moves one legal grid step; no map focus required |
| KB03 | Focus grid explicitly, press WASD and arrows | Single legal step per non-echo key event; obstacle blocks with textual reason |
| KB04 | Press Escape while grid focused | Map focus released; no action confirmed and no record corrected |
| KB05 | Move focus between selector/Buttons/map | Current focus named in words and outlined; no dependence on white border alone |
| KB06 | Shift+Tab backwards past Buttons to selectors | No focus trap; tooltip and visible labels remain readable |
| KB07 | Alt+Tab away while movement key held | On return, no movement until all mapped movement keys released |
| KB08 | Restore native window when a Button has focus | No focus stolen, auto-move, auto-inspect, auto-correct or auto-undo |
| KB09 | Select 100%, 125%, 150% text | Labels, buttons and grid text change in size; no essential control becomes permanently unreachable (scroll allowed) |
| KB10 | Resize narrow window at 150% | Controls stay keyboard reachable, scroll works, text not clipped into non-readable UI; document any failure |
| KB11 | Turn motion Off during animated mode | Decorative pulse stops; static symbols and status continue to convey everything |
| KB12 | Switch Off/Slow/Normal | Only player outline decoration changes; actual position, reachable/visible facts and correction unaffected |
| KB13 | Simulate inability to distinguish colors | `# . : S T P` plus row-by-row text and status/recovery messages convey equivalent state |
| KB14 | Disable audio / no textures / no private assets | Full task path remains understandable; no media cue carries unique information |
| KB15 | Test Chinese fallback glyphs and assistive technologies | Record real OS/Godot/version/screen-reader results; **do not infer compatibility from Label text** |
| KB16 | Test IME and focus navigation keys | No unwanted key capture while typing/selecting; real behavior recorded, not guessed |

## Missing resource downgrade / isolation

| ID | Future action | Required result |
| --- | --- | --- |
| DEG01 | Remove optional synthetic JSON in authorized isolated test copy | Embedded equivalent A/B/C fallback; conspicuous notice; never search real game directory |
| DEG02 | Corrupt schema, duplicate A/B/C ID or remove T in JSON | Reject entire external catalog; fallback atomically; no partial content |
| DEG03 | Remove an optional visual/audio resource (there are none) | No change to the documented content/operation; missing required scripts is **not** silently hidden |
| DEG04 | Remove required `.gd`/scene source in isolated authorized test | Actual import failure reported as blocker; no fake fallback/PASS |
| DEG05 | Close and reopen candidate | No previous corrections, undo or event history persisted |
| DEG06 | Compare PR #25 HEAD and main before/after submission | Their refs unchanged by this submission; exact commit/file evidence |
| DEG07 | Inspect repository for fiction/private material | Only public synthetic A/B/C technical data and code/docs included |

## Acceptance block conditions
Any of these blocks validation: cannot import scene, focus trap for keyboard-only navigation, wrong focus owner leading to movement, false reachability through walls, undo incorrectly affecting external data, corrected record persisting without consent, misleading silent fallback, state distinguishable only by colors or motion, or modifications outside new candidate path.

**Required future evidence:** authorized reviewer records Godot version, device/OS, date, exact commit, case IDs, observed outputs and failures, screenshots only if permitted, focus/assistive technology evidence, and measured performance only after genuine execution. This document provides **no observed result**.
