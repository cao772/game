# GAME-WEB-PLAY-INPUT-005 r1 — independent input-settings UI recovery

**Draft technical candidate. Code status: NOT_RUN. Canon: N/A. Shared interfaces: NOT APPROVED.**

## Exact source basis

Read [Draft PR #19](https://github.com/cao772/game/pull/19) at starting HEAD
`6fbb184989889d738f108a76dc9de85c3262ac4d` before implementation.
It is stacked on [Draft PR #15](https://github.com/cao772/game/pull/15).

Actual dependencies in the same independent Godot candidate project:

- `flow_input_004/input_settings_panel_004.gd`: current panel, including
  `begin_rebind`, `preview_key_candidate`, `apply_memory`,
  `apply_and_save`, `cancel_preview`, `open_for_router`, and `ui_state`.
- `flow_input_004/input_settings_ui_backend_004.gd`: original V2
  save/rebind/load, PR #15 Workflow/Migrator delegation, guarded disk writes.
- `input_settings_controller_candidate.gd`: conflicts, alternatives and
  reset previews; no InputMap mutations.
- `input_profile_workflow_003.gd` and `input_profile_migration_003.gd`:
  validated V1→V2 migration, one-use tokens and disk verification.
- `input_bindings_candidate.gd`: the five existing action IDs and
  1/2/3/R/Escape default logical-key mappings.

**All above remain unchanged.** PR #19 receives only new files in the
`flow_input_005` directory; no old source, game scene or main update.

## Module files

- `input_settings_panel_005.tscn` — standalone Godot Control scene.
- `input_settings_panel_005.gd` — complete derived panel that retains
  PR #19's UI and adds actual conflict-resolution controls, staged
  save-failure recovery, explicit retry, stale-review checks and safe
  capture/close behavior.
- `verify_input_settings_005.gd` — future-only finite SceneTree regression
  assertions, entirely synthetic configuration and isolated test fixtures.
- `README.md` — this integration contract and design decisions.
- `ACCEPTANCE.md` — future acceptance cases and manual validation plan.

Select `res://flow_input_005/input_settings_panel_005.tscn`, **not** the
previous `flow_input_004/input_settings_panel_004.tscn`, in any future
isolated host. The current PR remains stacked on PR #15; the relative path
is resolved by its existing independent `project.godot`.

## UI interaction flow

1. The panel displays the existing five action rows and logical keys;
   there is no startup load, save, snapshot write, or InputMap change.
2. Click a binding to begin one-key capture. During capture, `_input`
   consumes key events before the host's unhandled keyboard pathway;
   releases and key echo cannot trigger a binding preview. Modifier chords
   are rejected and native lost-focus/paused states ignore capture.
   Escape remains a valid configurable binding; use the visible **取消操作**
   button to cancel capture. In a host with other input handlers, supply
   the input-router Node via `open_for_router(router)` to temporarily
   suspend that specific Node; this is not a global input-suppression API.
3. If the chosen key is occupied, the panel displays the action owner,
   the conflict and up to three free-key suggestions from the existing
   controller. It creates real **改用...** buttons; clicking one only makes
   another *preview*, never automatically replaces an assignment.
4. An uncontested key can be applied in memory only, or via explicit V2
   disk-first save-and-apply. Each confirmation refers to an exact
   reviewed in-memory profile and V2/legacy path pair.
5. **取消操作** clears capture, pending action and any recoverable failure
   retry; it does not read, modify or delete disk configuration.
6. Single-action reset is permitted only if its default key is unused.
   Whole-map default restoration previews all changed entries, and
   confirmation uses one whole-profile update to avoid transient duplicate
   bindings. No automatic swap is performed.
7. **V1→V2 migration** keeps the old document intact, requires explicit
   preview and one-use confirmation, refuses an existing destination and
   delegates to the existing candidate Workflow.

## Save-failure decision matrix

| Result from existing backend | UI decision | Memory/disk behavior |
| --- | --- | --- |
| Success | Clear pending/retry; show outcome | Backend has verified disk-first update |
| TEMP_OCCUPIED | Preserve preview, show **重试保存** and **重新预览** | Does not touch occupied temporary file; no memory change |
| WRITE_FAILED / RENAME_FAILED | Same explicit retry route | Never silently fall back to memory-only |
| MISSING_DIRECTORY | Same explicit retry after parent directory correction | UI does not make directories automatically |
| LOAD_REQUIRED / EXTERNAL_CHANGE / EXTERNAL_DELETE | Clear pending; require explicit review/reload | Never overwrite unknown external configuration |
| INVALID_EXISTING / MALFORMED_JSON / INVALID_PROFILE | Clear pending; stop | Never auto-reset or repair corrupted file |
| TARGET_EXISTS / INVALID_PATH / OCCUPIED_PATH | Clear pending; show error | No silent destination replacement |
| POST_WRITE_VERIFY_FAILED / COMMITTED_NEEDS_RELOAD / migration commit unknown | Clear pending; **no retry** | Explicitly warn disk may already have committed; cannot promise rollback |
| Migration failure after confirm | Clear one-shot preview; require new preview | Do not replay a consumed token |
| Cancel | Clear pending and retry state | No disk/memory changes |
| Stale profile or edited path since preview | Reject confirmation as STALE_PREVIEW / STALE_PATH | No new destination write |

**Retries are never automatic.** A retry is only enabled for specified
transient write failures, and rechecks both the current profile fingerprint
and the same target path before delegating to the unchanged backend.
The backend revalidates existing document/digest during each attempt.
After a failure, the normal Apply buttons are disabled until explicit retry
or renewed preview; a user can always cancel.

A transient failed *save-current* operation is also explicitly retryable,
but no prior preview is resurrected. A successful preview alone does not
modify settings. A potentially committed failure must be manually reviewed;
the UI must not claim the disk was rolled back.

## Design decisions and reasons

- **Subclass the previous isolated panel rather than editing PR #19/PR #15**
  so existing delivered candidate source and test history remain intact.
  This PR only adds a complete optional revision scene and tests.
- **Reuse existing backend** instead of forking profile storage, avoiding
  a new competing V2 schema, duplicated write logic, or accidental changes
  to the shared action IDs.
- **Keep retry conditional and opt-in** because repeating a migration
  confirmation or a possibly committed file rename could corrupt the
  user's understanding of persistence. One-use migration tokens are
  intentionally not replayed.
- **Allow choose-free-key UI but never automatic swaps**, preserving the
  existing one-key-per-action candidate invariant.
- **Compare both profile and reviewed paths** so editing an exported scene's
  path mid-confirmation cannot write an unreviewed location.
- **Cancel on close or direct hide**, restore only the specific supplied
  router's original `is_processing_unhandled_key_input` flag, and never
  manipulate the global InputMap.
- **Report missing host integration explicitly** if the panel is opened
  without a router: the standalone candidate is usable, but noncapture
  events might reach an unspecified game handler behind it. No fictional
  production scene is created.

## Integration guide for future authorized host

Use the independent scene:

```gdscript
const InputSettingsPanel = preload(
    "res://flow_input_005/input_settings_panel_005.tscn"
)

var panel = InputSettingsPanel.instantiate()
panel.v2_profile_path = "user://input_bindings_candidate_v2.json"
panel.legacy_profile_path = "user://input_bindings_candidate.json"
add_child(panel)
# If a known host input adapter exists:
# panel.open_for_router(input_binding_router)
# Else: standalone scene only; heed the warning.
# panel.backend.workflow.settings.bindings may be explicitly shared with
# the PR #15 adapter, but no host is automatically wired.
```

The parent PR #15 adapter already has an optional `bindings` property;
a **future authorized** integration may set
`router.bindings = panel.backend.workflow.settings.bindings`.
This does not modify `InputMap`. Only one owner should write a profile at
a time; this candidate does not implement an OS-level lock.

The panel's public inherited methods still work:
`begin_rebind`, `preview_key_candidate`, `preview_reset_action`,
`preview_restore_all`, `preview_migration`, `apply_memory`,
`apply_and_save`, `save_current`, `load_current`,
`cancel_preview`, `open_for_router`, and `close_panel`.
New methods: `retry_save`, `repreview`, `ui_state_005`.
The additional `recoverable_save_failure(result)` signal notifies a
separate host without exposing private data.

### Constraints

- The backend uses `user://` V2 paths, fixed same-directory `.tmp`,
  schema validation and hash-based stale-write checks. This is not an
  inter-process lock, path sandbox, filesystem transaction guarantee or
  encrypted settings store. Actual OS behavior is unverified.
- This is a **module** with ordinary Control nodes and no production
  styling, scenes, audio, game narrative or global InputMap modification.
- Native keyboard focus, IME, actual buttons, disk-full and cross-platform
  permissions remain untested. No performance baselines exist.
- PR #19 and its upstream PR #15/#6 are DRAFT and not approved as shared
  interfaces or canonical gameplay.

## Future-only commands — NOT_RUN

From repo root **only after separately authorized verification**:

```bash
godot --headless --path candidates/game_web_module_input_001_r1   --script res://flow_input_005/verify_input_settings_005.gd
echo $?
```

Manual desktop scene (also **NOT_RUN**):

```bash
godot --path candidates/game_web_module_input_001_r1   res://flow_input_005/input_settings_panel_005.tscn
```

No Godot program, tests, parser checks, CI, GUI interactions, file writes
from the candidate itself, or benchmarks were executed in this authoring
task. GitHub source commits do **not** constitute runtime verification.
See `ACCEPTANCE.md` for deferred acceptance matrix.
