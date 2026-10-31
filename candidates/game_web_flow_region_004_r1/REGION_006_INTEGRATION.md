# GAME-WEB-REGION-006 r1 — Standalone integration notes (NOT_RUN)

## Files and boundaries

Only use the independent Godot 4 project rooted at
`candidates/game_web_flow_region_004_r1/`.
Its `res://main.tscn` loads `flow_demo.gd`, which directly imports:
`flow_model_candidate.gd`, `target_picker_candidate.gd`,
`feedback_journal_candidate.gd`, the locally pinned
`interaction_prompt_candidate.tscn`,
`navigation_candidate.gd`, and `focus_recovery_candidate.gd`.
All records come from public `synthetic_targets.json` (A/B/C).

Existing model and prompt ownership stays unchanged; navigation and
focus policies are **internal trial modules only**, not stable APIs.
Do not copy this candidate into the real scene, enable as autoload,
merge into main, link PR #6/10/15/17 or write gameplay events/saves.

## Host call chain

```text
Navigation button (A/B/C)
  -> start_navigation(id)
  -> Navigation.start_to_target(id, public catalog, current XZ)
  -> programmatic hide of prompt (not manual dismissal)
  -> _process / Navigation.advance(current, bounded frame delta)
  -> set_demo_position, FlowModel.move_player
  -> arrival -> FlowModel.mark_selected(goal ID)
  -> _sync_prompt -> existing show_for_targets/synchronize_targets
  -> prompt selection and explicit confirmation only

OS window focus_exited
  -> FocusRecovery.capture_window_loss(cached role, ID, shown)
  -> Navigation.pause_for_focus_loss
  -> in-memory 'focus' feedback
OS window focus_entered
  -> FocusRecovery.mark_window_returned
  -> deferred claim (no host focus theft, same target ID only)
  -> optional Button.grab_focus, never auto action
  -> held-WASD release gate remains armed until all keys released
User explicitly presses Continue Navigation
  -> native focus, pause state and key-release guards
  -> Navigation.resume_after_focus_return(true)
  -> _process proceeds with synthetic steps only

User changes position through host/manual operation
  -> cancel current synthetic navigation
  -> recompute proximity and existing prompt state
```

## State checks

`flow_snapshot()` retains existing `loaded`, `player`,
`nearby_ids`, `selected_id`, `prompt_shown`,
`prompt_target`, `confirm_count`, `feedback_history`.
The following **candidate-only** fields are additive:

- `navigation`: `mode` (idle/moving/paused/arrived/cancelled),
  `target_id`, `destination`, `reason`, `revision`.
- `focus_recovery`: `window_inactive`, `pending_restore`,
  `saved_role`, `saved_id`, `require_key_release`, `revision`.

These are in-memory readouts, *not* a shared data schema, save
format, persistent event record or promise of future compatibility.

## Future operator workflow (DO NOT EXECUTE IN THIS TASK)

Check out the Draft PR #23 branch, open only the standalone project,
and review `REGION_006_ACCEPTANCE.md`. After explicit authorization,
Codex may run the original r004/r005 future scripts, then the new
r006 pure and scene scripts. Desktop GUI cases require actual
window focus, keyboard and screenshot evidence; pure headless tests
cannot verify native focus recovery or Godot rendering.

Do not silently integrate with real-world targets, scene collision,
input mappings, other Draft PR candidates or novel canon. Missing
actual scene and gameplay interfaces are known limitations, not
implicit author decisions.
