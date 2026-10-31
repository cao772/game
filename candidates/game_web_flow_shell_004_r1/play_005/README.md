# GAME-WEB-PLAY-SHELL-005 r1 — standalone candidate play/navigation flow

**Source submitted; NOT_RUN; DRAFT only; canon N/A.** Nothing in this folder
is validated gameplay. All public references remain unapproved candidates.

## Executable-intended module

The existing PR #24 shell is retained unchanged except its own
`project.godot` main scene is pointed at
`res://play_005/play_entry.tscn`. This new scene instantiates the existing
`flow_entry.tscn` and uses `play_shell.gd` to append five buttons to
the existing shell sidebar: synthetic region, public event choice, read-only
save browser, synthetic profile list, and memory-only input settings.
Original PR #24 menu, prompts, profile, bindings, history, module assembly
and degraded states still live inside its original scene.

The overlay is a separate Control with a **Return to menu** button.
No #24 source script/scene is rewritten. The overlay creates and removes
each child module explicitly. The region is a Node3D hosted under a
SubViewportContainer + SubViewport. All others are candidate-only local
Control views. Missing scenes/scripts show `BLOCKED` plus an explanation.

## Connected navigation (explicit, synthetic)

1. **Menu → region:** pinned PR #23 graybox. It loads its own public
   `synthetic_targets.json`, shows its own prompt and exposes
   `flow_snapshot()`. The shell's `读取已确认占位目标` button
   reads `confirm_count` and `last_confirmed` via that actual method.
   With no confirmed synthetic target, it rejects transition.
2. **Region → event choice:** after the explicit button is accepted,
   the shell navigates to a **separate** fixed start fixture EVENT_START.
   No mapping from a region target to a real event was supplied or invented.
3. **Event choices:** local Godot event-preview model reads the three
   literal public PR #18 JSON fixtures. Shows ACTION_TO_NEXT, ACTION_END,
   ACTION_FINISH, ACTION_STOP, ACTION_COMPLETE and opt-in `@ignore`
   *where the fixture provides that route*. It enforces known destination,
   bounded choices and in-memory trace. No event bus, story state,
   file writes, or canonical choice semantics.
4. **Event → save browser:** explicit "前往只读存档浏览" button opens
   the real pinned PR #20 `snapshot_browser.tscn` source copy.
   Its UI reads only on manually provided `user://` folders and
   explicit inspect/compare/preview presses. **No automatic discovery**.
   It does not create, modify, delete, rename or commit snapshots.
5. **Menu → character list:** pinned PR #21 synthetic
   `profile_flow_candidate.tscn` loads its *own* fixed public fixture
   through `load_placeholder_profiles()`, enabling list/detail/back.
6. **Menu → input #19:** pinned real PR #19
   `input_settings_ui_backend_004.gd` with its dependency chain.
   The shell uses only `profile`, `preview`, `rebind_memory`,
   `restore_defaults_memory`, and `key_label` through a new
   minimalist memory-only Control. None of its V2 disk load/save/
   migration functions are called or made accessible. Original PR #24
   #15 input editor remains accessible independently.

## File boundaries

- New `play_005/play_entry.tscn`, `play_005/play_shell.gd`,
  `play_005/event_preview_model.gd`, `play_005/verify_play_candidate.gd`.
- Fixed public source copies and exact JSON fixtures under
  `play_005/vendor/` and `play_005/fixtures/`.
- `play_005/INTEGRATION.md`, `play_005/ACCEPTANCE.md`,
  `play_005/ORIGINS.md`.
- Only the **existing branch's** `project.godot` main_scene/name changed.
- No other files in PR #24 or any other PR touched. No main changes.
- No private lore, original text, real character, personal file, chat
  evidence or production asset committed.

## Unapproved/deliberately missing dependency

PR #18 is Python 3.12+ and imports its checker/location index from
stacked Draft PR #9. This Godot project **does not execute or reimplement**
that checker. The `event_preview_model.gd` only validates its local sample
fixtures for demo traversal; it is **not equivalent** to #18's checked
preview, has no SHA/line-pointer provenance and reports
`checker_status: NOT_RUN`. A formal event adapter cannot be claimed
without a separately approved cross-language validation boundary.

The #19 full UI includes optional disk persistence and PR #6 keyboard
router interfaces. Those are intentionally *not* mounted here. The
memory-only backend retains actual local preview/rebind logic; this does
not mean PR #19's full UI is integrated or approved.

The region confirmation is **not** event invocation. The event preview
and save browser are separate, explicitly navigated views; no synthetic
event is committed to or restored from a save.

## Future-only verification — do NOT run for this request

```sh
godot --headless --path candidates/game_web_flow_shell_004_r1 --script res://play_005/verify_play_candidate.gd
```

All parser, Godot runtime, tests, GUI, CI, headless, native input,
subviewport, keyboard focus and performance: **NOT_RUN**. Source
copy/read-back alone cannot prove any of those.

**Record:** task GAME-WEB-PLAY-SHELL-005 r1;
source review GitHub PR #24/#18/#19/#20/#21/#23;
branch `codex/game-web-flow-shell-004-r1`;
status SOURCE_SUBMITTED / NOT_RUN / DRAFT;
author approval PENDING; main not merged.


## SHELL-006 r1 continuation (new, NOT_RUN)

This README describes the original PLAY-SHELL-005 r1 baseline. The later
`play_006/` continuation introduces a **new, expressly unapproved and
non-canonical** target→event mapping for *three public synthetic IDs*:
`placeholder_a→EVENT_START`, `placeholder_b→EVENT_NEXT`,
`placeholder_c→EVENT_END`. There is **still no approved gameplay mapping,
event bus or saving**. The explicit region-confirmation button now checks
both public fixture catalogues, requires a validated proposed mapping,
and rejects unknown/missing entries instead of defaulting to START.

The new bounded previous-module stack preserves the local event preview
when coming back from the read-only save browser, reconstructs the synthetic
region on back, and clears provenance on main-menu return. All UI/compiler/
test status remains **NOT_RUN**.

Authoritative continuation: [play_006/README.md](../play_006/README.md),
[design](../play_006/DESIGN.md),
[future acceptance](../play_006/ACCEPTANCE.md).
