# GAME-WEB-MODULE-REGION-002 r1 — incremental Godot 4 prompt module

**Status: NOT_RUN.** Increment to Draft PR #10's existing independent
`candidates/game_web_module_region_001_r1/` directory.
There is no published or owner-approved shared UI, event, save, or input API.

## Compatibility / exact input

This increment was authored against PR #10's current source HEAD
`71f30ed6f67fab327902b51277e95dc14abed705`.
The nine baseline files were read before changes. Existing method names
`show_for_target`, `hide_prompt`, `request_interaction`,
`request_count`, `is_prompt_shown`, `active_target_id`,
and existing signals are retained. The former r1 test file remains present.
No other candidate directory was changed.

## Multi-target list (proposal)

The consuming standalone host supplies an **explicit** array of 1–16
generic target entries. An entry has these keys:

| Key | Type | Limit |
| --- | --- | --- |
| `id` | `StringName` or `String` | required, nonblank, <=64 chars, unique in list |
| `label` | `String` | required, nonblank, <=64 chars |
| `action_caption` | `String` | optional (default `交互`), nonblank, <=40 chars |

Example, **not coupled to a real scene**:

```gdscript
prompt.show_for_targets([
    {"id": &"placeholder_a", "label": "占位目标 A", "action_caption": "确认 A"},
    {"id": &"placeholder_b", "label": "占位目标 B", "action_caption": "确认 B"},
    {"id": &"placeholder_c", "label": "占位目标 C"}
], 1) # initial selection B
prompt.cycle_target(1) # B -> C
prompt.select_target(0) # C -> A
var selected: StringName = prompt.active_target_id()
prompt.hide_prompt()
```

Invalid inputs are rejected before modifying any displayed selection or
visibility. Index must be in range. List replacement while visible does
not emit a false hide/show transition. A selected-target change emits
`placeholder_changed` and **does not** emit `interaction_requested`.
Navigation wraps from last to first and vice versa. With one target the
navigation row is hidden. Hiding clears target list, index and ID.

## Keyboard and focus (proposal, runtime NOT_RUN)

- Show a previously hidden prompt: focus the action button.
- Replace targets while shown: preserve an already-focused prompt control;
  if focus moved outside the prompt, reclaim action focus on explicit show.
- Tab/Shift+Tab: explicit circular focus sequence for action/dismiss when
  one target; previous/next/action/dismiss when multiple targets.
- PageUp/PageDown: previous/next selection only while prompt owns focus,
  has multiple targets, native window focused and SceneTree not paused.
- Enter/Space: Godot's native Button activation; only the action Button
  emits `interaction_requested(selected_id)`. Navigation buttons select
  locally, and dismiss button hides. No 1/2/3/R input routing is added.
- Escape: hides only while a prompt control is focused; otherwise it
  leaves external host controls alone. Existing Draft PR #6 Escape
  arbitration is still unresolved.

`focus_state()` returns a **live** dictionary, not a synthetic focus
claim:

```gdscript
{
    "shown": true,
    "role": &"action", # none|previous|next|action|dismiss
    "target_id": &"placeholder_a",
    "target_index": 0, # -1 if none
    "target_count": 3
}
```

`focus_state_changed(role)` is emitted only when the observed role
changes; deferred focus-exit reconciliation avoids transient 'none' when
Tab moves within the widget. `target_list_changed(count)` reports
initial/updated count and 0 on hide. If native focus cannot be established
in a headless environment, the reported role is `none`; that is not a
failed or successful native focus verification by itself.

## Style configuration (proposal)

`apply_style(options: Dictionary) -> bool` supports partial updates,
validates all keys before mutation and returns `false` for unknown
keys, incompatible types or out-of-range numbers. Existing style stays
unchanged upon rejection. All overrides are local to this PanelContainer,
labels and buttons; there is no external theme asset, global project
setting, stylesheet or file persistence.

| Key | Type | Accepted values |
| --- | --- | --- |
| `background` | `Color` | panel background |
| `border` | `Color` | panel/button line |
| `text` | `Color` | main/button foreground |
| `hint` | `Color` | keyboard hint |
| `button_bg` | `Color` | normal/pressed button fill base |
| `button_hover` | `Color` | hover/pressed button fill |
| `focus` | `Color` | focused Button outline |
| `padding` | integer | 4–36 |
| `font_size` | integer | 12–30 |
| `corner_radius` | integer | 0–24 |
| `border_width` | integer | 0–5 |

```gdscript
prompt.apply_style_preset(&"high_contrast")
prompt.apply_style({
    "background": Color(0.08, 0.10, 0.17, 0.97),
    "focus": Color(1.0, 0.82, 0.25),
    "padding": 18,
    "font_size": 19
})
var safe_copy: Dictionary = prompt.style_snapshot()
prompt.apply_style_preset(&"default")
```

The built-in presets (`default`, `high_contrast`) are purely visual
candidates. Native readability, localization, high DPI, theme inheritance,
keyboard focus visibility and contrast ratio require manual verification.
Focus outlines are not a substitute for screen-reader accessibility.

## Future validation handoff

Use both independent future scripts in this candidate project:

```sh
godot --headless --path . --script res://verify_interaction_prompt_candidate.gd
godot --headless --path . --script res://verify_interaction_prompt_extension_candidate.gd
```

**NOT_RUN:** these commands have not been executed here. Their expected
success strings (inside source) are specifications, not observed evidence.
For manual cases M01–M28 see `docs/acceptance-cases.md`. Collect exact
Godot version, stdout/stderr, exit codes, keyboard-focus transitions,
native screenshots, and the reviewed commit SHA before acceptance.

## Outstanding owner decisions

1. Prompt focus vs other simultaneously active UI; whether modal behavior
   is required; handling multiple prompt instances.
2. Escape priority with the separate draft INPUT/STATE module.
3. Final UI sizes, language, contrast/accessibility requirements.
4. Actual target-discovery and interaction semantics, if ever approved.
5. Whether action activation should close the prompt (currently no).

This module emits technical placeholder IDs only. It does not read or
write original scenes, character data, novel text, canonical relations,
shared interfaces or saves. Branch stays Draft; do not merge `main`.
