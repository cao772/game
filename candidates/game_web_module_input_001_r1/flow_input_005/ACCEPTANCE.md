# GAME-WEB-PLAY-INPUT-005 r1 — future acceptance and safety review

**Authoring status: NOT_RUN.** No Godot program, parser, tests, CI, GUI
interaction, file IO from the authored candidate, or performance benchmark
was executed during this task. All rows below are intended assertions,
not verified passes.

Source of this increment: [Draft PR #19](https://github.com/cao772/game/pull/19),
initial reviewed SHA `6fbb184989889d738f108a76dc9de85c3262ac4d`.
This increment adds only new files in `flow_input_005/`, without touching
PR #19's prior source, PR #15, PR #6 or main.

## Planned SceneTree headless checks

Future file: `verify_input_settings_005.gd`.

| ID | Future verification | Required expected outcome |
| --- | --- | --- |
| P501 | Instantiate standalone scene | Five inherited action rows and two new recovery controls exist |
| P502 | Startup persistence | No V2 file created or loaded without explicit request |
| P503 | Conflict key selected | owner explanation visible; apply disabled, map unchanged |
| P504 | Alternative suggestion displayed | at least one currently free key offered |
| P505 | Alternative clicked | produces valid preview, not automatic reassignment |
| P506 | Cancel after conflict preview | clears pending; no disk/memory change |
| P507 | Valid key preview | key shown, no write before confirmation |
| P508 | In-memory confirmation | mapped key updates; disk remains untouched |
| P509 | Single default reset | returns original key if not currently occupied |
| P510 | Temp file occupied on initial save | TEMP_OCCUPIED; temp contents unchanged |
| P511 | Recoverable failure | pending preview retained, memory unchanged |
| P512 | Recoverable failure UI | regular confirm disabled; explicit Retry/Cancel |
| P513 | Cancel failed save | retry cleared, pending dropped, no automatic write |
| P514 | Retry after clearing temp | explicit retry saves and applies exactly requested key |
| P515 | Save path changed post-preview | STALE_PATH; new destination not created |
| P516 | Valid external V2 edit | EXTERNAL_CHANGE; existing file unchanged |
| P517 | External edit recovery UI | retry disabled; explicit load needed |
| P518 | Explicit reload | validated external binding loaded |
| P519 | Default key held by another action | single reset refused, other action unaffected |
| P520 | Full-default preview | all differing action mappings listed |
| P521 | Full reset blocked by temp | memory/disk unchanged |
| P522 | Repreview on transient failure | fresh preview has no mutation |
| P523 | Persisted full reset after correction | one whole-map defaults file, memory follows successful save |
| P524 | Repeat restore | unchanged V2 bytes, no unnecessary disk commit |
| P525 | Uncertain post-write failure | retry disabled; manual review warning |
| P526 | Host input router suspension | disables supplied Node processing while panel is open |
| P527 | Panel closure | restores original processing state; no global InputMap changes |
| P528 | V1 migration preview | no early V2 creation |
| P529 | Migration cancellation | original V1 untouched; no V2 file |
| P530 | Explicit migration confirm | V2 created, V1 bytes preserved |
| P531 | Synthetic fixture isolation | only uniquely created user:// test fixture files removed |
| P532 | Operation signal | reports outcomes; never claims error as success |
| P533 | Finite exit | pass marker/zero only after all checks; nonzero on failures |

## Future commands (DO NOT RUN until explicitly authorized)

From repository root with intended Godot 4.7.2:

```bash
godot --headless --path candidates/game_web_module_input_001_r1 \
  --script res://flow_input_005/verify_input_settings_005.gd
echo $?
```

Separate regression review of prior PR #19 candidate (also **NOT_RUN**):

```bash
godot --headless --path candidates/game_web_module_input_001_r1 \
  --script res://flow_input_004/verify_input_settings_flow_004.gd
echo $?
```

## Manual desktop checks (all NOT_RUN)

- D501 — Host supplies PR #15 input adapter; ensure no gameplay input
  dispatches while panel is open, including noncapture keystrokes.
- D502 — Physical key capture: echo/release, modifiers, focus blur/restore
  and valid next press. No input routed while OS window is unfocused.
- D503 — Mouse-only cancellation from capture, conflict and retry states;
  Escape remains a configurable key, not a hidden cancellation shortcut.
- D504 — Verify conflict owners/free keys across all five actions, including
  reset-one collision and whole-map restore. Never silent swap or unbinding.
- D505 — Simulate a write error, temp occupancy, disk full and file permission
  rejection; live bindings remain intact and UI does not fake a save.
- D506 — After transient error, ensure Retry is enabled only on same
  reviewed profile/path and only on user click.
- D507 — V2 changed or deleted by external writer; recovery requires
  user-initiated reload, not blind overwrite or silent merge.
- D508 — Inject a case where rename might already have completed but
  post-write verification fails; UI must show "may be committed" and
  not automatically retry or roll back.
- D509 — UI focus/scroll/accessibility at narrow desktop dimensions;
  keyboard focus traversal, readable Chinese messages and large font scales.
- D510 — Confirm real V1 migration does not rewrite/delete original file.
- D511 — Hide/destroy panel during capture/failure; ensure supplied host
  router flag is restored and no pending operation is replayed.
- D512 — Validate actual Godot 4.7.2 syntax, resources and scene load.
- D513 — Windows/macOS/Linux rename semantics and multi-process writer races:
  no promises without separate instrumented evidence.
- D514 — CPU/GPU/RAM/latency and long-hold keyboard performance: NOT_RUN.

## Explicit review constraints

This is a new **isolated optional panel revision**, not an edit or
runtime certification of PR #19's original panel and not an approved game
settings API. No actual production game scene, host router instance, UI
design system, save failure fixture, or user profile data was provided;
only PR #19's public technical candidate sources were reviewed.

Do not merge into main or promote the candidate to Canon.
Pending proof consists of real Godot runtime output, precise version/OS,
final commit SHA, stdout/stderr/exit status, UI notes and observed failure
semantics. Until that evidence exists, keep every case **NOT_RUN**.
