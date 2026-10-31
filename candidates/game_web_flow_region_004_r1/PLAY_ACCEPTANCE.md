# GAME-WEB-PLAY-REGION-005 r1 — Future acceptance plan

**ALL CASES NOT_RUN. THIS TASK IS DEVELOPMENT-ONLY.**
Previous r004 model/scene cases F001–F026 and manual G001–G020
continue to apply. Any changed behavior must be demonstrated, not
assumed. Do not mark PASS based on this authored plan.

## Future pure checks (only if Codex later receives permission)

```sh
godot --headless --path candidates/game_web_flow_region_004_r1 \
  --script res://verify_play_selection_candidate.gd
```

Expected *only on later actual success*: 
`PASS GAME-WEB-PLAY-REGION-005 r1 (future pure checks)`.
Proposed assertions P001–P030 include strict public fixture,
in/out-of-range cube picking, invalid radii and nonfinite points,
selecting B from A/B overlap, clicked-but-not-confirmed state,
visible journal success, rejected arbitrary IDs, defensive export,
FIFO capacity and monotonic sequence after roll/clear.

## Future scene checks (only if authorized)

```sh
godot --headless --path candidates/game_web_flow_region_004_r1 \
  --script res://verify_play_scene_candidate.gd
```

Expected *only on later actual success*:
`PASS GAME-WEB-PLAY-REGION-005 r1 (future scene checks)`.
Proposed scene assertions S001–S029 include:
- Initial model and prompt available, empty feedback journal.
- Approach A/B overlap; multi-choice prompt visible.
- Direct coordinate picking of B selects but does not auto-confirm.
- Picking far C produces rejection without stealing selected B.
- Separate prompt confirmation emits one success and counter +1.
- Leave all hides prompt; unrelated floor click is ignored.
- Manual hide suppresses automatic reopening and click confirmation.
- Explicit reopen restores prompt without changing confirm count.
- Reset returns initial state and a single local `reset` journal item.

Headless calls to `select_marker_at` **cannot prove native mouse ray
projection, GUI pass-through, actual keyboard focus or frame render**.

## Future manual desktop cases (all NOT_RUN)

| Case | Setup and operation | Required visible result |
| --- | --- | --- |
| M41 | Launch at 1280×720 and inspect | Single public synthetic floor, A/B/C marker, prompt panel, focus/state feedback and rolling history only |
| M42 | Click cube A when far | One visible rejected feedback; no selected ID, confirmation or unintended focus |
| M43 | Move near A then click cube A | A selection visible, amber marker, prompt action Button focused; no confirmation yet |
| M44 | Move to A/B overlap; click B, then press Enter | One B confirmation, exactly one local count increase |
| M45 | Move near A/B; click outside markers on floor | No target selection, no target confirmation, unrelated floor click unhandled |
| M46 | Use host 'previous'/'next' and prompt PgUp/PgDown | Selection and amber highlighting change without confirmation; no stale ID |
| M47 | Prompt action focused, hold WASD | No background movement while prompt owns keyboard focus |
| M48 | Click 'release focus to world' then press WASD | Trial marker can move; prompt state reads role none |
| M49 | Prompt action focused; Tab/Shift+Tab repeatedly | Focus cycles visibly over prompt controls; no hidden focus traps |
| M50 | Press Escape while prompt focused; move slightly within range | Prompt stays hidden and no confirmations are emitted |
| M51 | Click a nearby cube while prompt manually hidden | Rejection displayed; does not reopen or confirm |
| M52 | Click host 'reopen' then select and confirm | Prompt visible and one confirmation for current selected ID |
| M53 | Leave all targets, approach again | Prompt reappears; suppression cleared |
| M54 | Switch to another native OS window | Mouse selection and WASD movement suspended; verify role after return |
| M55 | Pause SceneTree through controlled future QA | All native selection/movement/confirmation gates block |
| M56 | Confirm once, perform several rejected clicks | Counter remains unchanged for rejected attempts; history records kind=rejected |
| M57 | Trigger more than 12 statuses | History displays at most 12 underlying records, newest 6 visible |
| M58 | Reset demo | Position away, prompt hidden, confirmation zero, history contains only one reset entry |
| M59 | Repeat approach / click / focus / confirm / leave 10 times | Exactly ten valid confirmations and no duplicate action per click |
| M60 | Resize to smaller viewports/HiDPI | Capture visible clipping, clickable areas and unreadable text as failure rather than assuming responsive success |
| M61 | Compare existing copied PR #10 sources by blob SHA | Both copies unchanged, no duplicate external integration |
| M62 | Review PR diff | Only the existing isolated flow candidate folder changes, main unchanged |

## Evidence rules and triage

For each actually executed test, record `case_id`, `expected`,
`observed`, `status`, exact Git commit SHA, Godot version and
build, renderer, OS, command/exit code/log and (for GUI cases) actual
viewport screenshots/focus transitions. Never invent proof. Failures
and unsupported platforms are `FAIL` or `INCOMPLETE`, not PASS.
Proposed feedback enum, picking radius 0.52, keyboard-focus gating,
history retention 12 and visible history 6 are all **trial values**.

A successful test of this standalone synthetic project would not
approve plot/canon, real target discovery, shared interfaces or merger
to `main`. Author retains final acceptance and integration decision.
