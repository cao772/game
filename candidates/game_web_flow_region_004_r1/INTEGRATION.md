# GAME-WEB-PLAY-REGION-005 r1 — Isolated integration guide

**Development-only candidate, NOT_RUN.** This guide is for future owner/Codex
review, not approval of a shared game interface or real scene integration.

## 1. Standalone source hierarchy and provenance

Project directory:
`candidates/game_web_flow_region_004_r1/`.

Godot 4 standalone project `project.godot` points to `main.tscn`,
which hosts `flow_demo.gd`. At runtime that script constructs all trial
mesh geometry and a CanvasLayer from built-in engine classes. The
only read dependency is its **public** versioned
`synthetic_targets.json` containing A/B/C fake locations.
No network, asset, plugin, novel, save file, event bus or real level
is read.

`flow_model_candidate.gd` controls in-memory eligibility, current
selection, suppression and count. `target_picker_candidate.gd`
picks a synthetic cube by ground XZ and does not modify the model.
`feedback_journal_candidate.gd` keeps a bounded UI-only log.
`interaction_prompt_candidate.gd` and `.tscn` are pinned unchanged
copies of the unmerged [PR #10](https://github.com/cao772/game/pull/10)
candidate. They are **not** blessed shared APIs.

## 2. Candidate call chain for developers

The complete proposed path is:

```text
WASD / host approach button -> set_demo_position(Vector2)
   -> FlowModel.move_player
   -> _sync_prompt (show_for_targets / synchronize_targets / hide)
   -> prompt placeholder_changed -> FlowModel.mark_selected
   -> marker highlight + in-memory selection journal

Unhandled left mouse click in 3D world
   -> camera ray intersection with synthetic horizontal marker plane
   -> TargetPicker.choose_at(point, catalog, eligible_ids)
   -> rejected feedback if out-of-range / suppressed
   -> else prompt.select_target(index) -> placeholder_changed
   -> focus prompt ActionButton

Prompt action Button or host 'confirm' control
   -> prompt.interaction_requested(target_id)
   -> FlowModel.confirm(target_id) (revalidates current selected ID/range)
   -> FeedbackJournal append(success/rejected)
   -> visible feedback, journal preview, flow_snapshot()
```

**Click alone never confirms.** All confirmation effects are temporary
counts and local messages, not world actions or persistent events.

## 3. Standalone import instructions (future only)

When authorized, check out the exact Draft PR #23 branch and open
`candidates/game_web_flow_region_004_r1` as its own Godot 4 project.
No modifications to the real game's `main.tscn`, autoloads, InputMap,
novel manuscript or other candidate branches are required.
The standalone folder owns all `res://` paths and can be imported
independently. Do **not** copy only `flow_demo.gd`: it expects the
model, prompt, picker, journal and JSON within the same project root.

No code is executed in this authoring turn. Future commands appear
in `README.md` and future case tables in `PLAY_ACCEPTANCE.md`.

## 4. If approved later for actual game integration

This task **does not perform these steps**. A future separate task
would need real user-supplied target node definitions, spatial
ranges, occlusion/collision policy, approved input arbitration,
authoritative UI ownership, and gameplay action semantics.
The production scene should own those definitions; this demo
cannot infer them from the public draft repository.

A conservative proposed order for that future approval would be:
(1) replace synthetic catalog/coordinates with explicit vetted
scene target references; (2) replace planar picker with proper
collision/occlusion-aware selection; (3) resolve focus/Escape
precedence against other unmerged input drafts; (4) agree on a
single owner for the prompt and world action dispatch; (5) add
regression tests and screenshot evidence; (6) seek author approval.
Nothing in the present PR claims any one of these decisions is made.

## 5. Verification handoff

Code review checklist: verify only
`candidates/game_web_flow_region_004_r1/` changed, prompt pins
remain `89d78c42...` / `e7ac3524...`, and no user data or
private content is added.

Only **after future permission to execute**, use the original future
r004 scripts and two r005 suites:

- `verify_flow_model_candidate.gd` (r004 model)
- `verify_flow_scene_candidate.gd` (r004 scene)
- `verify_play_selection_candidate.gd` (r005 pure picker/journal)
- `verify_play_scene_candidate.gd` (r005 scene integration)

Manual Godot focus and click cases M41–M62 require native UI and
screenshots, not just headless script exit status. All remain
**NOT_RUN**. Commit SHA, device, renderer, logs and unexpected
behavior must be reported without concealing failures.

The user approves final integration/acceptance. This candidate
creates no shared interface and must not be merged into `main`
automatically.

---

## GAME-WEB-REGION-006 r1 local integration addendum (NOT_RUN)

The exact independent project root stays unchanged:
`candidates/game_web_flow_region_004_r1/`.
The scene coordinator now locally preloads two more RefCounted
policies, `navigation_candidate.gd` and
`focus_recovery_candidate.gd`; the pinned PR #10 prompt source
and scene are still unchanged.

Host navigation buttons explicitly start/pause/resume/cancel only
A/B/C synthetic marker travel; focus loss pauses active movement and
arms a key-release gate, while focus return may safely re-apply a
previous prompt Button role only after same-ID/host-focus checks.
No InputMap, other PR controller, real level, save or event bus is
linked. See [complete local data and signal flow](REGION_006_INTEGRATION.md).

The two new verification scripts are authored for future authorized
execution only; never present their expected output as an observed
result. Status **NOT_RUN**.
