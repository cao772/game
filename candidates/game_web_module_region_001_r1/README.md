# GAME-WEB-MODULE-REGION-001 / W-REGION / r1

**Independent, public, technical Godot 4 interaction-prompt candidate. Status: NOT_RUN.**

## Purpose

A self-contained `PanelContainer` prompt accepts an explicit placeholder
target, offers an accessible focusable action button and dismiss button, and
supports show/hide, Enter/Space action activation and Escape dismissal.
There are **no world-state changes**: the action emits a local signal only.
The demonstration uses two intentionally generic placeholder IDs
(`placeholder_a` and `placeholder_b`), not real game content.

## Files

- `interaction_prompt_candidate.tscn`: reusable UI Control scene.
- `interaction_prompt_candidate.gd`: local show/hide, focus management,
  window/pause guards and `interaction_requested` signal.
- `demo.tscn` / `demo.gd`: standalone placeholder demo, separate from
  every existing game scene.
- `project.godot`: standalone Godot 4 project, no plugins or external art.
- `verify_interaction_prompt_candidate.gd`: **future** finite headless
  logic regression checks; not executed.
- `docs/acceptance-cases.md`: reproducible future QA steps.
- `docs/integration-boundaries.md`: scope, compatibility and limitations.

## Proposed local-only call surface (NOT an approved shared API)

Instantiate `interaction_prompt_candidate.tscn` under a UI `Control`
or `CanvasLayer`; the consuming scene is **not modified in this PR**.

```gdscript
var prompt = preload("res://interaction_prompt_candidate.tscn").instantiate()
add_child(prompt)
prompt.interaction_requested.connect(_on_candidate_request)
prompt.show_for_target(&"placeholder_a", "占位目标 A", "交互")
# Later: prompt.hide_prompt()

func _on_candidate_request(_target_id: StringName) -> void:
    pass # Host must explicitly decide behavior. No implicit actions.
```

`show_for_target` rejects empty/oversized captions and empty IDs, selects
the new placeholder, shows the panel and grants focus to its action Button.
If already shown, target replacement updates without an artificial hidden
transition. `hide_prompt` clears the target and attempts to return keyboard
focus to the valid, visible, focusable outside control that was focused
before the prompt opened. Repeated hide is a no-op.

Enter / Space are Godot's built-in focused Button activation. Tab and
Shift+Tab circulate between the two prompt buttons; arrow up/down
neighbors are also declared. Escape hides only if this prompt owns focus.
No global keyboard hooks, InputMap edits, core scene editing, save calls,
story semantics, interaction distance checking or automatic target
discovery are included.

`request_interaction(blocked_override = null)` provides a local injectable
gate for future contract tests; `null` uses real native window focus;
`true` blocks; `false` bypasses only window focus (not tree pause).
This is experimental and must not be treated as a production bypass.
Native Button press still uses real window focus.

## Suggested manual launch (DO NOT RUN in this task)

From the root of this candidate directory:

```sh
godot --path . --editor
godot --path .
```

## Future noninteractive checks (NOT_RUN)

```sh
godot --headless --path . --script res://verify_interaction_prompt_candidate.gd
```

Expected output on a passing future run (not observed here):
`PASS GAME-WEB-MODULE-REGION-001 r1 (headless contract checks)`
with process exit code 0. Any error requires investigation and recorded
evidence; the expected text is **not evidence of execution**.

## Relation to existing draft sources

- Reviewed `cao772/game` Draft PR #6:
  `candidates/game_web_integrate_001_r1/input_router_candidate.gd`
  and `integration_candidate.gd` (branch `codex/game-web-integrate-001-r1`).
- That PR's input routing handles keys 1/2/3/R/Escape, focus, pause and
  window blocking. This module **does not import** either script and does
  not register a parallel 1/2/3 keyboard route.
- Escape is consumed only while the prompt holds focus; host integration
  and conflict resolution require explicit owner review.
- Main currently contains only the repository README; module is additive.

## Status and handoff

- Source drafted and submitted for review; **NOT_RUN**.
- Godot parse/load, GUI keyboard behavior, window switching, tab-focus
  cycling, accessibility, screenshot comparison and CI: **NOT_RUN**.
- No changes to `main`, existing scenes, manuscript, canon, other
  draft PRs, shared interfaces or Notion/Drive evidence.
- Codex/owner to execute tests, inspect output, decide integration and
  archive authorized technical evidence separately. Never auto-merge.
