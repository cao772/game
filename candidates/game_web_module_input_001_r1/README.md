# GAME-WEB-MODULE-INPUT-001 r1 — Independent input-binding configuration

**STATUS: PROPOSAL / NOT_RUN. Canon: N/A. Not an approved shared interface.**

## Exact reviewed dependency

Read actual [GAME-WEB-INTEGRATE-001 Draft PR #6](https://github.com/cao772/game/pull/6)
at `f5143fb72db6083cab6364b8caa5daf7d6995dc2`. Its supplied
`input_router_candidate.gd` translates KEY_1/2/3/R/ESCAPE into five named
actions, rejects echo, release, focus and pause; `integration_candidate.gd`
owns one in-process snapshot writer and accepts `request_button_action(action_id)`.
Its child input node is named `InputRouterCandidate`.

This branch **stacks on PR #6**, adds **only new files in this directory**
and targets the PR #6 branch, not `main`. It does not edit either dependency.
Do not merge this child PR before parent PR #6 has been reviewed.

## Files

- `input_bindings_candidate.gd` — independent in-memory configuration,
  strict schema inspection, conflict diagnostics, per-action remap, restore
  one/all defaults, lossless snapshots, guarded JSON save/load.
- `input_binding_router_candidate.gd` — optional transient Node adapter to
  route a configurable keyboard map into unchanged PR #6
  `request_button_action`, suppressing duplicate dispatch from the old
  fixed-key handler only while attached. Detach restores previous flag.
- `verify_input_module_candidate.gd` — **future only** finite SceneTree
  checks, nonzero exit on failure.
- `project.godot` — standalone smoke/acceptance project without autoloads.
- `ACCEPTANCE.md` — review criteria and NOT_RUN requirements.

## Default action IDs and keycodes (from PR #6)

| Logical key | Action ID | Can be remapped? |
| --- | --- | --- |
| 1 | `observe` | yes |
| 2 | `open_door` | yes |
| 3 | `withdraw` | yes |
| R | `reset_round` | yes |
| Escape | `cancel` | yes |

The five action IDs are frozen **for this candidate only**. Remapping changes
a logical `InputEventKey.keycode`, not the game action ID. Supported keycodes:
0–9, A–Z, F1–F12, Escape, Enter, keypad Enter, Space, arrow keys.
No physical-keyboard layout mapping, modifiers/chords, gamepads, mouse keys,
text entry, unapproved action IDs, or configurable double-bindings.

## Configuration invariants

1. A keycode can be bound to **at most one** action. `rebind` returns
   `{ok,changed,error,conflicts}`; collision rejects without mutation.
   `check_conflicts` reports the owners of a proposed keycode.
2. `restore_defaults` atomically resets all five keys. `reset_action`
   refuses an occupied default rather than silently removing another binding.
3. `profile` returns a detached `Dictionary` with `version:1` and
   `bindings:[{action_id,keycode},...]`. `inspect_profile` verifies exact
   fields, all five unique known actions, supported integer keycodes and
   uniqueness; finite integral floats from Godot JSON are accepted and
   normalized. `apply_profile` is transactional in memory.
4. Only a `user://` path ending in `input_bindings_candidate.json`
   can be loaded or saved. Parent directory must already exist. An invalid
   existing configuration must not be silently replaced. Save uses a fixed
   same-directory .tmp and rename with **single-writer assumption**; no
   inter-process lock or crash-durable guarantee is claimed.
5. Key resolution is side-effect-free: no event if key release, echo, any
   modifier, blocked gate, or focused `LineEdit`/`TextEdit` or their child
   controls. Eligible consecutive keydown events after release remain eligible:
   there is **no stale latch**. A neutral focused Control does not block.
6. `InputMap` is never referenced or mutated. The module never touches
   round snapshots or emits game state directly.

## Optional PR #6 runtime connection

To use the adapter in a **separate test host** after the parent integration is
ready, instantiate `InputBindingRouterCandidate` as a Node and call
`attach_integration(parent_integration_node)`. The parent must contain the
existing `InputRouterCandidate` child and callable
`request_button_action(StringName)`. No scene, integration, or shared
interface is changed in PR #6.

When attached, the adapter:

1. Claims the target against another adapter of this class *in-process*.
2. Remembers the old input Node's `is_processing_unhandled_key_input()` flag.
3. Calls `set_process_unhandled_key_input(false)` on that specific old Node
   to prevent duplicate native key dispatch.
4. Processes only unhandled keyboard events with its own configurable map.
5. Calls the unchanged PR #6 `request_button_action(action_id)`, which
   retains its pause/window-focus/text-focus checks and snapshot semantics.
6. Restores the original flag on `detach_integration`/`_exit_tree`.

If the target interface differs, attachment is refused: **missing dependency**,
not a fabricated compatibility promise. Use `adapter.bindings.rebind(...)`,
`adapter.bindings.restore_defaults()`, `adapter.bindings.save_profile(...)`,
or `adapter.bindings.load_profile(...)` before or during attachment.
Buttons still send action IDs, independent of remapped keyboard bindings.

Adapter ownership, event ordering against other user-added input nodes,
actual OS focus events and the parent PR's native Godot compatibility all
require a later runtime review. The adapter is **not** a replacement for the
parent's STATE r1 single-writer responsibility.

## Future verification command — DO NOT claim it ran

From the repository root, with the intended Godot 4.7.2 binary:

```bash
godot --headless --path candidates/game_web_module_input_001_r1 \
  --script res://verify_input_module_candidate.gd
echo $?
```

Expected contract: `PASS GAME-WEB-MODULE-INPUT-001 r1` and exit 0, or
`FAIL` with nonzero exit. These are **expectations**, not evidence.
Actual execution: **NOT_RUN**, as requested. See `ACCEPTANCE.md`.

## Scope & handoff

No global InputMap changes, old source edits, story changes, save or clock
schema changes, private files, or PR merges. GitHub Draft PR holds public
technical-only candidate source. Canon N/A. Codex may review/test separately
when the author authorizes execution; do not treat this as production approval.
