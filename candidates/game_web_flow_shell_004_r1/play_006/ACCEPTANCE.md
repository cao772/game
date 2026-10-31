# GAME-WEB-SHELL-006 r1 — Future acceptance inventory

**All scenarios NOT_RUN.** This file and
`verify_shell_006_candidate.gd` contain *planned* assertions only.
No Godot launch, script execution, tests, CI, code parsing, screenshots,
performance measurement or gameplay acceptance was performed.

## A. Authored future script checks: mapping and event model

| ID | Input/procedure | Expected | Status |
|---|---|---|---|
| M01 | Load three public PR #18 JSON fixtures | Local preview loads, Python checker still NOT_RUN | NOT_RUN |
| M02 | Resolve before bridge preparation | Rejected | NOT_RUN |
| M03 | start_at nonexistent event | Rejected; no default substitution | NOT_RUN |
| M04 | Check EVENT_START | Present in fixture catalogue | NOT_RUN |
| M05 | Check EVENT_NEXT | Present | NOT_RUN |
| M06 | Check EVENT_END | Present | NOT_RUN |
| M07 | Read both fixed public mapping/target JSON | Valid JSON objects | NOT_RUN |
| M08 | Validate original synthetic mapping | Accepted proposal shape, not approved | NOT_RUN |
| M09 | Explicitly prepare bridge | Candidate-only success | NOT_RUN |
| M10 | Read status | Exactly three authored mapping entries | NOT_RUN |
| M11 | Confirm placeholder_a | Maps to EVENT_START | NOT_RUN |
| M12 | Confirm placeholder_b | Maps to EVENT_NEXT | NOT_RUN |
| M13 | Confirm placeholder_c | Maps to EVENT_END | NOT_RUN |
| M14 | loaded=false despite confirmation | Rejected | NOT_RUN |
| M15 | confirmation count zero | Rejected | NOT_RUN |
| M16 | unknown target | Rejected, not START fallback | NOT_RUN |
| M17 | confirmation count as String | Rejected (not int) | NOT_RUN |
| M18 | null confirmation target | Rejected | NOT_RUN |
| M19 | snapshot as Array | Rejected | NOT_RUN |
| M20 | wrong mapping schema_version | Rejected | NOT_RUN |
| M21 | candidate_only=false | Rejected | NOT_RUN |
| M22 | entry refers to nonexistent event | Rejected | NOT_RUN |
| M23 | entry refers to nonexistent target | Rejected | NOT_RUN |
| M24 | duplicate mapping target entry | Rejected | NOT_RUN |
| M25 | empty mapping reason | Rejected | NOT_RUN |
| M26 | extra field in mapping row | Rejected | NOT_RUN |
| M27 | incompatible target catalogue version | Rejected | NOT_RUN |
| M28 | Call pure reject cases, inspect live bridge status | No unintended registry mutation | NOT_RUN |
| M29 | start_at(EVENT_NEXT) | Accepted, active NEXT | NOT_RUN |
| M30 | Read current event | EVENT_NEXT | NOT_RUN |
| M31 | start_at nonexistent | Rejected | NOT_RUN |
| M32 | Read after rejection | Still EVENT_NEXT | NOT_RUN |
| M33 | start_at(EVENT_END) | Accepted | NOT_RUN |
| M34 | Read trace after new entry | Cleared | NOT_RUN |
| M35 | Bridge clear; resolve again | Rejected | NOT_RUN |

## B. Authored future integration/nav checks

| ID | Future input | Expected | Status |
|---|---|---|---|
| N01 | Open independent Play scene | Main menu active | NOT_RUN |
| N02 | Menu → region | Synthetic region mounted | NOT_RUN |
| N03 | Try region→event without confirmation | Stay on region | NOT_RUN |
| N04 | Inspect confirmation signal count | Zero | NOT_RUN |
| N05 | Approach/confirm placeholder_a; explicitly enter event | Event opens | NOT_RUN |
| N06 | Read event entry | EVENT_START | NOT_RUN |
| N07 | Inspect mapped context | placeholder_a, explicitly synthetic | NOT_RUN |
| N08 | Inspect signal count | One notification only | NOT_RUN |
| N09 | Return to previous module | Accepted | NOT_RUN |
| N10 | Check previous module | Fresh region | NOT_RUN |
| N11 | Check context on region return | Old mapped context cleared | NOT_RUN |
| N12 | Confirm placeholder_b | Event opens | NOT_RUN |
| N13 | Check entry after B | EVENT_NEXT | NOT_RUN |
| N14 | Check checker status | NOT_RUN, never PASS | NOT_RUN |
| N15 | Event → save browser | Navigation succeeds, no writes | NOT_RUN |
| N16 | Return from save browser | Navigation succeeds | NOT_RUN |
| N17 | Inspect current module | Event | NOT_RUN |
| N18 | Inspect entry | Still EVENT_NEXT, no forced START | NOT_RUN |
| N19 | Return to prior module again | Accepted | NOT_RUN |
| N20 | Inspect current module | Fresh region | NOT_RUN |
| N21 | Confirm placeholder_c | Event opens | NOT_RUN |
| N22 | Inspect C entry | EVENT_END | NOT_RUN |
| N23 | Return to menu | Menu active | NOT_RUN |
| N24 | Inspect module history | Cleared | NOT_RUN |
| N25 | Inspect mapped provenance | Cleared | NOT_RUN |
| N26 | Inspect last confirmed target | Cleared | NOT_RUN |
| N27 | Attempt unknown module | Rejected | NOT_RUN |
| N28 | Open event directly from menu | Opens independent preview | NOT_RUN |
| N29 | Inspect direct entry | EVENT_START, labelled unmapped | NOT_RUN |
| N30 | Return previous with empty history | Returns false (menu instead) | NOT_RUN |
| N31 | Inspect after empty-history return | Menu active | NOT_RUN |
| N32 | Reopen region | Accepted | NOT_RUN |
| N33 | Attempt focus-blocked transition | Remains on region | NOT_RUN |
| N34 | Inspect emitted confirmations | No extra signal | NOT_RUN |

These are *intended* headless assertions, not proof of native UI or
source compatibility. Any compile error, broken fixture path, failed
assertion or nonzero process exit must be recorded **FAIL** after an
explicitly authorized future execution.

## C. Future native/error/manual validation (not yet scripted)

| ID | Procedure | Required observation | Status |
|---|---|---|---|
| U01 | Open Godot scene from project.godot | Main menu and appended public buttons render | NOT_RUN |
| U02 | Inspect region→event on all three sample targets | Explicit proposed mapping visible in event status | NOT_RUN |
| U03 | Confirm while no target selected/nearby | No transition, visible BLOCKED | NOT_RUN |
| U04 | Move away after confirming and then press bridge | Confirm-count semantics evaluated; note any stale design risk | NOT_RUN |
| U05 | Remove mapping JSON in a disposable worktree | BLOCKED on region, no default event | NOT_RUN |
| U06 | Remove/rename any event fixture | BLOCKED on region, no transition | NOT_RUN |
| U07 | Change map to unknown target ID | BLOCKED, no source/scene mutation | NOT_RUN |
| U08 | Change map to unknown event ID | BLOCKED, no trace reset | NOT_RUN |
| U09 | Duplicate target mapping entry | Rejected and lookup cleared | NOT_RUN |
| U10 | Wrong schema, approval or candidate flag | Rejected; clearly not approved | NOT_RUN |
| U11 | Direct menu → event | Unmapped EVENT_START, no prior target label | NOT_RUN |
| U12 | Mapped event → reset | Restarts mapped event, not necessarily START | NOT_RUN |
| U13 | Choose branch, open saves, return previous | Event trace preserved in memory only | NOT_RUN |
| U14 | Event → previous region | Brand-new region; old mapping/provenance removed | NOT_RUN |
| U15 | From any module choose ReturnMenu | Visible main menu, bounded/cleared navigation history | NOT_RUN |
| U16 | Repeated 30 route/return cycles | No duplicate signals, stale UI or leaked nodes | NOT_RUN |
| U17 | Native window unfocused, attempt transition | Refused, no synthetic confirmation emitted | NOT_RUN |
| U18 | Pause tree, attempt transition/return | Pause gate respected; ReturnMenu still safe | NOT_RUN |
| U19 | 1024×640, 960×680, narrow/high-DPI UI | Back/menu/choice controls accessible; document clipping | NOT_RUN |
| U20 | Remove PR #23 scene; then open region | BLOCKED with menu return, no replacement game scene | NOT_RUN |
| U21 | Remove PR #20 browser; then open saves | BLOCKED with menu return, no file created | NOT_RUN |
| U22 | Check InputMap before/after | Unchanged | NOT_RUN |
| U23 | Check user:// files before/after synthetic flow | No save/config writes | NOT_RUN |
| U24 | Inspect diff against prior PR #24 HEAD | Only `play_006/` and own `play_005` source/docs edits | NOT_RUN |
| U25 | Review public strings/assets | No real character, plot, manuscript, secrets or chat evidence | NOT_RUN |
| U26 | Confirm PR #18 Python checker cannot claim PASS | checker_status remains NOT_RUN | NOT_RUN |
| U27 | Compare exact SHA and original PRs | Original PRs and main unchanged | NOT_RUN |
| U28 | Validate Godot minor/platform, SubViewport and keyboard focus | Record actual observed evidence, no guessing | NOT_RUN |
| U29 | Inject invalid mapped event after previous successful trace | Old model/trace remains unchanged on failed proposal | NOT_RUN |
| U30 | Test malformed UTF-8, oversized and empty mapping JSON | Reject atomically and visibly | NOT_RUN |

## D. Future-only command (do not run under this task)

```sh
godot --headless --path candidates/game_web_flow_shell_004_r1 --script res://play_006/verify_shell_006_candidate.gd
```

Runtime validation **not authorized**. The previous
`play_005/verify_play_candidate.gd` and PR #24 historical acceptance
plans also remain **NOT_RUN**; authoring additional tests does not
change their status.

Future evidence requirements: exact commit SHA, source files/fixtures
hashes, Godot version, OS/GPU, execution date/operator, command, stdout,
stderr, exit code, screenshots, per-case result and full repro for
failures. Never label a test PASS merely because source exists.

```json
{
  "task_id": "GAME-WEB-SHELL-006",
  "version": "r1",
  "input_head": "e7a567d578156113d315282eac0e8dadc96e8590",
  "tested_commit": null,
  "case_id": "N05",
  "result": "NOT_RUN",
  "godot_version": null,
  "command": null,
  "exit_code": null,
  "evidence": [],
  "author_approval": "PENDING"
}
```

All components remain public **technical candidates**, not story canon
or approved shared/runtime interfaces.
