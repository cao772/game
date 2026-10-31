# GAME-WEB-FLOW-INPUT-004 r1 — isolated Godot input settings panel

**Status: TECHNICAL PROPOSAL / NOT_RUN. Canon not applicable. No shared API approval.**

Source inspected before authoring: [PR #15](https://github.com/cao772/game/pull/15)
head `a510986faf3c3ee0557196194d5f74f16e02de89`, stacked on
[PR #6](https://github.com/cao772/game/pull/6). This new Draft PR has its own
`codex/game-web-flow-input-004-r1` branch and is based on PR #15 so that
its review diff contains only newly created, separate UI candidate files.
Do not merge or change `main`.

## Delivered files

| File | Responsibility |
| --- | --- |
| `input_settings_panel_004.tscn` | Separate reusable Godot Control scene |
| `input_settings_panel_004.gd` | Complete programmatic UI: five rows, capture, previews, conflicts, confirmation/cancellation, restore, migration, V2 read/save |
| `input_settings_ui_backend_004.gd` | Explicit PR #15 Workflow/Settings/Migrator wrapper; disk-first V2 rebind/save, memory-only changes, loaded-disk checks |
| `verify_input_settings_flow_004.gd` | Future-only finite headless SceneTree test source |
| `README.md` | Technical decisions and integration limits |
| `ACCEPTANCE.md` | Future test case matrix, manual GUI cases and NOT_RUN status |

The existing project root remains
`candidates/game_web_module_input_001_r1/`, which already contains
`project.godot` and the required PR #15 scripts. No other files were changed.
The new scene is
`res://flow_input_004/input_settings_panel_004.tscn`.

## Real dependencies reused, not rewritten

- `input_bindings_candidate.gd`: five exact actions and default logical keys
  (1, 2, 3, R, Escape), supported-key whitelist and one-key-per-action rule.
- `input_settings_controller_candidate.gd`: display labels, collision owner
  lists, alternative suggestions, single/all default previews.
- `input_profile_workflow_003.gd`: explained conflict preview, V1-to-V2
  confirmation tokens and explicit `load_v2`.
- `input_profile_migration_003.gd`: strict V1/V2 validation, guarded
  `user://` IO, digest-aware V2 writes and post-write verification.
- `input_binding_router_candidate.gd`: optional real keyboard routing remains
  **unchanged**; this panel never attaches itself automatically.

## UI operation flow

1. **Display**. List all five action identifiers as human-facing titles with
   current logical key labels and an "(已修改)" indicator for nondefault keys.
   Initial view uses defaults in memory. It does **not** read existing user
   files or write/replace them on startup.
2. **Rebind**. Press a row's current-key button, then press a logical key.
   Echo/releases and modifier chords are ignored during capture. The event is
   marked handled so capture does not dispatch gameplay input. Escape is a
   legitimate configurable key; to cancel capture, click the visible
   "取消操作" button.
3. **Preview and conflict**. The unchanged PR #15
   `Workflow.preview_conflict` determines validity. Show owning actions,
   proposed key, next steps, and free-key suggestions. Collisions never
   silently swap/erase bindings; apply buttons remain disabled on conflict.
4. **Apply temporarily**. "仅本次应用" updates the shared candidate
   bindings object in memory through PR #15 `Settings.rebind`.
   There is **no implicit disk write**; if another UI or adapter must see the
   new mapping, it must share this same bindings instance.
5. **Save then apply**. "保存后应用" validates the full profile, creates a
   versioned V2 document via the PR #15 Migrator using a same-directory
   temporary file, verifies it, and only then invokes `Workflow.load_v2`
   to publish new in-memory bindings. A pre-existing file must have been
   explicitly loaded in this backend first; it refuses blind overwrite.
6. **Reset one action**. A row's "恢复此项" previews the original key.
   If that default is now owned by another action, show a conflict and
   disable confirmation. Either manual conflict resolution or whole-map
   default restore is required.
7. **Reset all**. "恢复全部默认" previews every changed binding.
   Memory-only or V2 persisted reset both require explicit confirmation.
   Persisted reset prepares one whole-map V2 profile, so no intermediate
   duplicate bindings are emitted. Failed writes leave live mappings intact.
8. **Load saved**. Explicit V2 load only. Corrupt, unsupported, missing or
   foreign profiles are reported and do not silently trigger a reset.
9. **Migrate V1**. Explicit preview and one-use confirmation via PR #15
   Workflow. Target is a distinct V2 file; V1 bytes are not deleted or
   overwritten by migration. UI supplies no automatic migration.
10. **Cancel**. Clears pending action and confirmation state, invalidates
    migration workflow token, leaves memory and disk untouched. Closing the
    panel also cancels any pending confirmation and emits `panel_closed`.

The UI contains an accessible status label for outcome codes; failures are
reported rather than displaying false success. Labels are limited to generic
action descriptions: no story or private data are contained in this PR.

## Design choices and rationale

- **Re-use V2 and PR #15 workflow rather than inventing another schema.**
  Previous candidate already provides explicit V1→V2 migration and strict
  validation; UI should not become an independent format authority.
- **No automatic file load/save** avoids unexpected writes to an existing
  profile. Default V2 path is
  `user://input_bindings_candidate_v2.json` and V1 path is
  `user://input_bindings_candidate.json`; both are editable export
  properties on the scene. A host should set controlled path values and
  ensure a parent directory exists for any custom nested path.
- **Separate memory-only and persistent actions** makes unsaved changes
  obvious and prevents a blocked disk write from producing a partly applied
  in-memory configuration. "Save current" explicitly persists previously
  temporary changes.
- **Two-stage preview and confirmation** makes invalid remaps,
  lossy whole-map resets and migration visible before they have effects.
  Preview results are compared with a fingerprint of current bindings before
  the UI allows any confirmation; PR #15 persistence additionally checks
  the previously loaded destination's content digest.
- **Escape can be rebound** and therefore is not an unconditional UI cancel
  hotkey during capture. The cancel button is always visible.
- **No third-party UI framework or theme overrides**. The panel builds
  ordinary `PanelContainer`, `Label` and `Button` controls; it is a
  grayscale/system-theme-friendly Godot prototype, not a production visual
  design mandate or a substitute for a real tested frontend.
- **No InputMap changes**. All key representations remain logical
  `InputEventKey.keycode`, and no `InputMap` calls exist in new scripts.

## Optional game-host keyboard isolation

A real host that has a PR #15 keyboard adapter may call
`panel.open_for_router(adapter_node)`. While the panel is visible,
it temporarily disables **that exact supplied Node's**
`process_unhandled_key_input` flag, remembers its previous state, and
restores it on close / tree exit. This does not change the global InputMap.

If a host never supplies the actual input adapter, the panel cannot know
which game router to suspend. In that case its standalone scene still works
as a configuration editor, but **non-capture keyboard events in an
unprovided host may reach that host's own input handlers**. No global
suppression, unknown scene integration or production routing guarantee is
invented. The actual interface in PR #6 and PR #15 remains unmodified.
Do not put a game world behind the panel without wiring this adapter
suspension contract and testing it on a real desktop.

## Persistence and failure limits

The new backing adapter holds one PR #15 `Workflow` instance and a
process-local `path → sha256` baseline for the V2 document. Any existing
target must be explicitly loaded before overwriting; stale external writes,
deletion, temporary-file collisions, invalid schema and failed rename are
rejected. It delegates disk IO and schema validation to unmodified PR #15
code. It cannot guarantee multi-process exclusive ownership, atomicity
under all operating systems, power-loss durability, or symlink-safe paths.
A post-rename verification/reload failure is explicitly reported as a
potentially committed transaction, not falsely rolled back.

The panel **does not modify** round snapshots, time, story, scripts outside
this new directory, shared interfaces, or main. The default recovery policy
is to refuse unknown/corrupted files and ask for an explicit external
decision, never silently repair/reset existing settings.

## Future-only verification (not executed)

When author grants test permission and Godot 4.7.2 is available, from the
repository root:

```bash
godot --headless --path candidates/game_web_module_input_001_r1 \
  --script res://flow_input_004/verify_input_settings_flow_004.gd
echo $?
```

Future desktop UI preview (also **NOT_RUN**):

```bash
godot --path candidates/game_web_module_input_001_r1 \
  res://flow_input_004/input_settings_panel_004.tscn
```

No Godot invocation, parser check, CI run, interactive click, focus test,
performance measurement or file IO test was executed by the authoring
window. The existence of source is **NOT** evidence that it runs.
See `ACCEPTANCE.md` and record actual stdout/stderr, exit status, Godot
version, OS and commit SHA before any later PASS claim.

**Review dependency**: PR #15 and parent PR #6 are Draft proposals, not
approved product contracts. This branch is stacked on PR #15 for review
isolation; its base should not be merged into main by this window.
