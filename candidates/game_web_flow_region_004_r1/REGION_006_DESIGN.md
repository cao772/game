# GAME-WEB-REGION-006 r1 — isolated target navigation, focus recovery, feedback

**Development deliverable; NOT_RUN. No canon or shared-interface approval.**

## Source evidence and baseline

Before changing any source, retrieved the actual open Draft
[PR #23](https://github.com/cao772/game/pull/23) metadata and changed-file
list from GitHub. Its exact starting HEAD was
`d1d9d7d8f85dfdc035aae6d1d9f1ddebdfa1ae57`, branch
`codex/game-web-flow-region-004-r1`, base `main`. Read the actual
current `flow_demo.gd`, `flow_model_candidate.gd`,
`target_picker_candidate.gd`, `feedback_journal_candidate.gd`,
pinned `interaction_prompt_candidate.gd` and documentation/test sources.

The copied prompt script and scene still originated from a **separate
unmerged Draft PR #10**. They are deliberately not changed in this
task. No file, code, or UI from any other PR is modified or imported.

## Implemented incremental modules

- `navigation_candidate.gd` (**new**): independent RefCounted
  navigation policy with finite valid XZ targets, bounded per-frame
  straight-line stepping, target-by-ID lookup, arrive/pause/manual
  resume/cancel/reset modes, reason/revision snapshots.
- `focus_recovery_candidate.gd` (**new**): pure policy for the native
  window losing/regaining focus; remembers the previously focused prompt
  role + selected ID, arms a held-WASD release gate, allows a one-shot
  restoration claim only if target and prompt remain valid, and explicitly
  refuses to steal focus from a host control.
- `flow_demo.gd` (**extended**): host navigation controls for A/B/C,
  pause/continue/cancel buttons, automatic finite trial steps,
  notification on approach, landing/goal selection, cancelled motion
  when host teleports, native Window.focus_exited/focus_entered
  listeners, deferred prompt-focus restoration and visible in-memory
  feedback. The trial side panel now uses a ScrollContainer to bound
  the growing host controls.
- `feedback_journal_candidate.gd` (**extended**): only adds the
  `navigation` and `focus` feedback categories; retains the rolling
  12-entry in-memory limit and defensive-copy behavior.
- `verify_region_006_pure_candidate.gd` and
  `verify_region_006_scene_candidate.gd` (**new future scripts**):
  deliberately not executed; finite policy and coordinator checks.
- `REGION_006_ACCEPTANCE.md` and `REGION_006_INTEGRATION.md`:
  future test and local standalone implementation handoff.

Existing `synthetic_targets.json`, `flow_model_candidate.gd`, model,
picker, PR #10 prompt copies, project settings and earlier test scripts
are unchanged.

## Navigation policy and rationale

**Purpose:** connect the existing A/B/C synthetic cubes, proximity
model and PR #10 prompt via a clearly observable, cancellable approach
flow, rather than introducing real game navigation.

1. A host button explicitly invokes `start_navigation(placeholder_id)`.
   The navigator validates the ID by looking it up in the existing
   synthetic target catalog; invalid IDs do nothing.
2. Starting navigation programmatically hides the trial prompt without
   recording a *manual* dismiss, and releases prompt keyboard focus.
3. The navigator advances the synthetic marker along a single straight
   XZ segment at a proposed 2.0 m/s, with per-frame delta capped at
   0.10 s to avoid a large jump after frame stalls. No physics, navmesh,
   obstacles, NPC navigation, action dispatch or real scene coordinates.
4. It stops approximately **1.20 m before the target center**,
   within the existing synthetic 1.55 m entry radius, rather than
   overlapping the target cube. This is an unapproved trial value.
5. On arrival the coordinator selects the destination by stable
   placeholder ID, not whichever other target happened to enter first.
   It then shows/synchronizes the existing multi-target prompt and
   provides `navigation` feedback. No implicit confirmation occurs.
6. `pause` and `resume` are explicit; an OS-window focus loss pauses
   an active route. Window return **never** resumes navigation.
   The user must release WASD and press Continue.
7. Cancel stops the route; manual host position changes also cancel
   ongoing navigation. Other surrounding prompt/selection behavior
   remains the preexisting candidate behavior.
8. On reset all navigation/focus state returns to idle and only the
   public synthetic fixture is reloaded.

**Why straight line, not A* or a navmesh?** The existing independent
scene has only a flat floor and three cubes; there is no approved
collision/obstacle geometry to define traversability. Claiming
real pathfinding would invent a missing requirement. This candidate
must remain separate from true world navigation and cannot be merged
as a final level controller.

**Why stop within approach range?** It exercises the complete
navigate→approach→prompt→choose→confirm loop without passing the
synthetic player through a cube. It also makes UI focus takeover
predictable at the moment of arrival.

## Focus-loss/restore policy

- Remember only a previously focused prompt button role:
  `action`, `previous`, `next`, `dismiss`.
  Never store a real game object, external UI history or private text.
- On actual Window.focus_exited, record a pending restoration claim,
  arm a key-release gate and pause the route if it was moving.
  A prompt with no focused button does not acquire a restoration claim.
- On Window.focus_entered, schedule a **deferred** restoration attempt.
  No confirmation/selection event is triggered by restoration.
- A claim succeeds at most once, only when the window is focused, the
  same selected placeholder ID is still displayed and the host has
  no independent focused Control. If the target changed, the prompt
  was hidden, or a host control owns focus, do **not** steal focus.
- If a navigation row disappeared since loss (e.g. multi-target
  reduced to single target), the candidate falls back to the
  visible ActionButton rather than focusing a hidden button.
- Manual focus can always be reassigned using the existing host
  "focus prompt action" and "release world focus" controls.
- WASD input remains disabled after returning to the native window
  until **all four movement keys are released** at least once.
  No simulated keypress is injected or replayed after return.

**Why require release?** Prevent a held movement key at Alt+Tab from
continuing as an apparent new deliberate movement, particularly when
an interactive prompt may have been open.

**Why not automatically resume navigation?** Focus return is not
an explicit gameplay command and must not cause surprise movement.
This is a conservative candidate safety policy, not a final product
decision.

## Feedback and state integration

Only coarse synthetic outcomes are journaled: `navigation`,
`focus`, `enter`, `leave`, `selection`, `success`,
`rejected`, `dismiss`, `reset`, `info`.
The existing 12-record rolling in-memory journal is preserved.
The status panel now includes navigation mode and destination plus
pending focus claim. The candidate-only `flow_snapshot()` includes
`navigation` and `focus_recovery` dictionaries returned by pure
state machines. There is no save file, external logging, telemetry,
event bus, gameplay time or story semantics.

## Explicit missing inputs and unresolved boundaries

The existing Draft PR does **not** provide an approved real bedroom
scene, navigation mesh, colliders, physical occlusion policy, definitive
controls, protagonist object, active event context, final UI design,
or shared input/effects API. Therefore the implementation uses
only public synthetic A/B/C points and its earlier provisional
geometry. It does not create a story scene or decide canon.

The standalone trial's handling of native focus return, actual
keyboard key-up events, scroll positioning, demo renderer clipping
and click-to-confirm sequence **remains unverified**. Real Godot
screen/render testing is reserved for later owner approval.

**Status NOT_RUN: no executable, test, parser, UI, CI or performance run.**
GitHub submission alone is not proof of functional correctness.
