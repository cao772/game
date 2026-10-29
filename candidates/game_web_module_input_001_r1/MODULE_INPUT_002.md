# GAME-WEB-MODULE-INPUT-002 r1 — Configuration feedback, reset and persistence

**Independent technical candidate | Canon N/A | Shared API NOT APPROVED | NOT_RUN**

Task: \`GAME-WEB-MODULE-INPUT-002 r1\`. All newly authored files live in
\`candidates/game_web_module_input_001_r1/\`, on the existing
\`codex/game-web-module-input-001-r1\` Draft PR #15 branch. This is an incremental
enhancement to PR #15, not a rewrite or approval of PR #6/PR #15 contracts.

## Grounded dependencies and limits

Source-of-truth reviewed on PR #15 before editing:
- \`input_bindings_candidate.gd\` — five action IDs, default logical keycodes,
  \`inspect_profile\`, \`apply_profile\`, \`rebind\`, \`check_conflicts\`,
  \`restore_defaults\`, and optional \`user://\` JSON format.
- \`input_binding_router_candidate.gd\` — \`adapter.bindings\` and optional PR #6
  hook; it does not mutate the global \`InputMap\`.
- \`verify_input_module_candidate.gd\`, \`README.md\`, \`ACCEPTANCE.md\`,
  and isolated \`project.godot\`.

No full game scene/UI implementation, gamepad requirements, key chord policy,
cross-process locking implementation, cloud synchronization, or approved shared
settings API was supplied. The proposal implements none of these.

## Added implementation

\`input_settings_controller_candidate.gd\` is a fully isolated
\`RefCounted\` settings façade owning an unchanged PR #15 bindings candidate.

- **Conflict feedback**: \`preview_rebind(action_id, keycode)\` returns
  \`ok,can_apply,changed,code,message,action_id,current_keycode,
  current_key_label,proposed_keycode,proposed_key_label,conflicts,alternatives\`.
  Conflicts list each occupied logical keycode plus action owners; available
  alternatives come from a fixed, deterministic small pool of existing
  supported keys. Preview is pure and never emits, writes or remaps.
- **Single reset preview**: \`preview_reset_action(action_id)\` is the same
  conflict check using that action's PR #15 default.
- **Whole reset preview**: \`preview_restore_defaults()\` returns an ordered
  array of per-action from/to codes. No mutation.
- **In-memory commit**: \`rebind\`, \`reset_action\`, \`restore_defaults\` delegate
  to PR #15 validation and emit one \`configuration_changed\` on a real change;
  no persistence is performed implicitly. Conflict/invalid/no-op is explicit.
- **Persistence with guards**: \`load(path)\` and \`save(path)\` use PR #15's
  exact JSON shape and strict \`user://.../input_bindings_candidate.json\`
  path validation. Caller must create parent directory. Read is parse +
  validate before any in-memory mutation. There is no silent fallback to
  defaults on corrupt/missing files.
- **Optimistic external-change detection**: an existing valid file must first
  be explicitly loaded before overwriting. Save records its SHA-256 bytes
  after successful load/save and refuses a changed or removed file with
  \`EXTERNAL_CHANGE\` / \`EXTERNAL_DELETE\`. An existing corrupt file is
  rejected rather than overwritten; an unchanged valid disk profile is
  detected and avoids an unnecessary write.
- **Disk-first atomic *intent***:
  \`rebind_and_save\`, \`reset_action_and_save\`,
  \`restore_defaults_and_save\` prepare a valid new profile in isolation,
  attempt one same-directory temporary-file write and rename, and only
  change the live bindings *after* persistence succeeds. On validation, IO,
  stale-disk, or .tmp collision failure, both live bindings and signals remain
  unchanged. This is **not an OS-level filesystem transaction**, and does
  not make claims about crash durability or multi-process races.

New \`verify_input_settings_002.gd\` contains future-only finite SceneTree
assertions for preview, conflict owners, defaults, signals, explicit save/load,
file corruption, disk change detection and failure rollback.

## Configuration lifecycle and example hookup

A separate test host may create the new \`Settings\` object and attach the
**same bindings instance** to the existing optional PR #15 adapter:

\`\`\`gdscript
# Example only; no real host scene was edited or run.
const Settings = preload("res://input_settings_controller_candidate.gd")
var settings = Settings.new()
adapter.bindings = settings.bindings
# GUI may call settings.preview_rebind(&"observe", KEY_Z)
# or settings.rebind_and_save(&"observe", KEY_Z, configured_path)
\`\`\`

Buttons continue to send action IDs, not keycodes. The PR #15 adapter still
owns the native keyboard dispatch and real focus/pause checks.
The new controller neither intercepts events nor writes any round snapshots.
An attached host must manage object lifetime and only invoke
persistence in one writer at a time.

The controller deliberately does **not** add an \`InputMap\` entry, alter
existing PR #15 / PR #6 files, change story/Canon, or approve a shared API.

## Response fields

Operation results return:
- \`ok\`: caller-visible success.
- \`code\`: stable proposal status identifier; see table below.
- \`message\`: diagnostic intended for UI display, not a localized string.
- \`changed\`: memory bindings actually changed.
- \`persisted\`: disk content is known to match desired profile when the
  operation succeeded. Does not mean a physical write was always necessary.
- \`action_id\` and \`conflicts\` for relevant operations.

\`operation_reported(result)\` emits one result for every explicit mutating
or persistence operation. **Preview emits no signal**.
\`configuration_changed(profile)\` only emits when the in-memory bindings
actually change.

| Status | Meaning | Mutates memory on failure? |
| --- | --- | --- |
| READY / UNCHANGED | Preview is valid / same key | Never (preview) |
| CONFLICT | Another action owns the requested key | No |
| INVALID_KEY / UNKNOWN_ACTION | Invalid input | No |
| APPLIED / DEFAULTS_RESTORED | Changed in-memory profile | Yes, no disk |
| SAVED / ALREADY_PERSISTED | Disk updated / already identical | No |
| SAVED_AND_APPLIED | Disk succeeded then bindings changed | Yes, once |
| INVALID_PATH / MISSING_DIRECTORY / OCCUPIED_PATH | Unsafe or unavailable destination | No |
| READ_FAILED / MALFORMED_JSON / INVALID_PROFILE | Can't read or validate | No |
| INVALID_EXISTING | Existing destination fails schema validation | No |
| LOAD_REQUIRED | Existing valid file not explicitly loaded here | No |
| EXTERNAL_CHANGE / EXTERNAL_DELETE | Stale baseline detected | No |
| TEMP_OCCUPIED / WRITE_FAILED / RENAME_FAILED | Save cannot commit | No |
| BUSY | A save is already in progress | No |
| POST_SAVE_IMPORT_FAILED | Unexpected post-save apply failure | No; caller must reload |

**Human/UI decision policy**: collisions are refused; no silent swap,
auto-unbinding, replacement, or fallback to a different key. Restore-all is an
explicit command and may overwrite the previously configured map, but never
writes disk unless the caller requests the \`_and_save\` method.

## Persistence caveats

- Single-writer assumption. Hash checking is advisory optimistic concurrency
  control, not a lock. There is still a read/rename race across processes.
- Fixed \`.tmp\` filename; existing temp is left untouched and reported.
- No automatic backup, user-specific encryption, sync, migration or recovery.
- \`save\` on a brand-new nonexistent path is permitted; an external writer
  that wins a race before rename is not detected. Only candidate isolation is
  promised, not system-wide atomicity.
- Persisted default reset is disk-first. A prior **in-memory-only**
  restore is intentionally not rolled back if a *later separate* save fails.
  Use the combined \`restore_defaults_and_save\` to get rollback behavior.
- Rejected external edits require an explicit \`load\` to accept external
  disk content; never silently merge or discard another writer's changes.

## Future-only verification

\`\`\`bash
godot --headless --path candidates/game_web_module_input_001_r1 \
  --script res://verify_input_settings_002.gd
echo $?
\`\`\`

This command and every other program/test have **NOT_RUN** in this task.
Expected output strings and exit codes are proposals, not test evidence.
See \`ACCEPTANCE_INPUT_002.md\` for the deferred case matrix.

**Handoff:** Codex may later run parser/headless/GUI integration tests if
explicitly requested. Desktop native focus, CI, performance, multi-process
writers, and OS-level rename durability remain NOT_RUN / unverified. No
Notion/Drive/private material uploaded in this task.
