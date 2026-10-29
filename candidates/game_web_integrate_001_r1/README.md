# GAME-WEB-INTEGRATE-001 / W-INTEGRATE / r1

**Isolated technical proposal. Not canon. Not an approved shared interface.**
This directory is an independent Godot 4 test project; no main repository
scene, InputMap, story, save core, or user-provided source is modified.

## Contents

- `integration_candidate.gd` — new isolated input-to-snapshot coordinator.
- `verify_integration_candidate.gd` — finite headless SceneTree checks.
- `project.godot` — separate minimal Godot project.
- `input_router_candidate.gd` — isolated copy of provided INPUT r1, unchanged.
- `round_snapshot_candidate.gd` — isolated copy of provided STATE r1, unchanged.

The original sources were supplied in the task, not read from other chats.
An identical copy of each is needed because main contains no corresponding
dependencies. The integration candidate imports these copies only.

## Proposed action mapping (not approved)

| Key | Action | Allowed phase | Candidate snapshot effect |
| --- | --- | --- | --- |
| 1 | observe | ready | phase = observing |
| 2 | open_door | ready / observing | phase = resolved; door_open = true |
| 3 | withdraw | ready / observing | phase = deferred; door_open = false |
| R | reset_round | any | phase = ready; door_open = false |
| Escape | cancel | any | no state change, no write |

No gameplay, progression, clock advancement, narrative, or new round identity
is inferred. **reset_round preserves** version/mode/round_id/clock_seconds;
repeated reset is idempotent. `cancel` is explicitly a non-mutating
acknowledgement pending product semantics. Invalid transitions are rejected.

## Input and snapshot invariants

- Keyboard uses the unchanged INPUT r1 Node and its
  `action_requested(action_id)` signal.
- A UI button can use
  `button.pressed.connect(integration.request_button_action.bind(&"observe"))`.
  The original router's `request_action` validates the action and blocks
  pause/native-window-unfocused events; the integration signal listener
  checks actual viewport text focus as well. In headless tests an injected
  `dispatch_action` exercises the same mutation/save path.
- Echo, key releases, unrelated keys, paused tree, injected loss of focus,
  focused LineEdit/TextEdit or descendants are rejected without mutation.
- Initial configuration validates seed and path; existing valid snapshot
  overrides seed; corrupt or foreign-mode files are not replaced.
- Per successful changed action: **one** call to STATE r1 `save_snapshot`,
  then update the private snapshot and emit a copied `snapshot_changed`.
  Failures do not publish a new in-memory state. No-op/cancel/invalid actions
  do not save. The attempt counter counts attempts, **not** successful writes.
- Single-writer protection is **cooperative in-process, among instances of
  this candidate only**. STATE r1 uses its existing fixed temp filename.
  It is **not** an inter-process lock or concurrency-proof storage format.
- `user://<isolated folder>/<mode>.round_snapshot.json` is the only
  accepted file shape. The parent folder must exist; the test creates its
  own unique fixture folder and removes only its fixture files.

## Run (from repo root)

```bash
godot --headless --path candidates/game_web_integrate_001_r1 \
  --script res://verify_integration_candidate.gd
echo $?
```

Expected: `PASS GAME-WEB-INTEGRATE-001 r1` and exit status 0; assertion
failure yields 1. A Godot parser failure may return another nonzero code.
A Godot 4.7.2 executable can be used if available; actual binary/version
is **not verified** here.

## Validation status / hand-off

- Source is ready for Codex review and execution, **NOT_RUN** by this window.
- SceneTree injected-gate checks: **NOT_RUN**.
- Native desktop window loss/recovery and actual GUI focus: **NOT_RUN**.
- Real button click, multi-process writers, rename behavior across platforms,
  and performance benchmarks: **NOT_RUN**.
- GitHub PR is Draft; do not merge main until Codex tests and reviews results.
- No Notion or Drive changes made by this window.

Task: GAME-WEB-INTEGRATE-001; revision: r1; Canon: N/A.
