# GAME-WEB-CONTINUE-INPUT-003 r1 — opt-in profile migration, conflict explanation, restore workflow

**Independent technical candidate / Canon: N/A / shared API: NOT APPROVED / execution: NOT_RUN**

This increment is on [Draft PR #15](https://github.com/cao772/game/pull/15)
at \`codex/game-web-module-input-001-r1\`. Source was read from the actual
PR head before the increment: \`54f08865ccde7508aabd02227a9db886039a032d\`.

## Source-based constraints

Existing \`input_bindings_candidate.gd\` (PR #15) defines exactly five actions
(\`observe\`, \`open_door\`, \`withdraw\`, \`reset_round\`, \`cancel\`) and
a strict V1 JSON shape:

\`\`\`json
{
  "version": 1,
  "bindings": [
    {"action_id":"observe","keycode":49},
    {"action_id":"open_door","keycode":50},
    {"action_id":"withdraw","keycode":51},
    {"action_id":"reset_round","keycode":82},
    {"action_id":"cancel","keycode":4194305}
  ]
}
\`\`\`

Illustrative numeric keycodes must be checked against the actual Godot constants
before use: the scripts use \`KEY_1\`, \`KEY_2\`, \`KEY_3\`, \`KEY_R\`,
\`KEY_ESCAPE\` directly, never rely on this example as a verified encoding.
The V1 implementation requires all five actions, no duplicate keycodes,
and supported logical keycodes. Its persistence filename is fixed:
\`input_bindings_candidate.json\`. Previous \`input_settings_controller_candidate.gd\`
adds preview/conflict feedback and guarded V1 save/load, but has no migration
format or confirmation state. This increment does not edit either source.

## New sources

- \`input_profile_migration_003.gd\`:
  strict V1 validation, normalized V2 encoder/decoder, conflict reports,
  scoped path validation, explicit JSON read and guarded V2 write with
  preflight/late external-change checks and post-rename readback verification.
- \`input_profile_workflow_003.gd\`:
  optional RefCounted orchestration with richer conflict explanation,
  explicit migration preview/confirm, explicit V2 load, default-reset
  preview/confirm, invalidated one-use confirmation tokens, and cancellation.
- \`verify_input_migration_003.gd\`:
  future-only finite SceneTree headless verification with synthetic data;
  creates/removes only a uniquely named \`user://\` fixture directory.
- \`ACCEPTANCE_INPUT_003.md\`: deferred headless/desktop checklist.
- This document: source assumptions, design rationale, boundaries.

All 5 are **new files in the existing isolated PR #15 candidate directory**.
PR #6 and existing PR #15 scripts/tests/docs remain unchanged.

## Migration version decision and rationale

**Choose opt-in V1 → V2 side-by-side migration.** No other historical schema
was supplied; inventing V0, auto-correcting conflicting mappings, or
changing an unapproved shared interface would be unsafe.

Actual V1 is the only supported input. Proposed **V2** is:

\`\`\`json
{
  "schema_version": 2,
  "format": "game_web_input_bindings",
  "bindings": [
    {"action_id": "observe", "keycode": 49},
    {"action_id": "open_door", "keycode": 50},
    {"action_id": "withdraw", "keycode": 51},
    {"action_id": "reset_round", "keycode": 82},
    {"action_id": "cancel", "keycode": 4194305}
  ]
}
\`\`\`

Again, keycode integers are illustrative rather than runtime test evidence.

The **reason for a separate V2 filename**
(\`input_bindings_candidate_v2.json\`) is backward isolation. PR #15's
unmodified V1 loader rejects any extra/renamed fields; swapping V2 into
the V1 filename would break it. Migration **never overwrites or deletes V1**.

- Migrate only exact validated V1 (including Godot's numeric JSON decoding).
- Retain the same five action IDs, key assignments and logical-key policy.
- Reject unknown versions, fields, actions, unsupported codes and collisions.
- Normalize V2 bindings into action-list order for stable output.
- Require same parent directory and \`user://\` for old/new paths.
- Refuse migrating onto any existing V2 destination: user must explicitly
  \`load_v2\` instead; never silently replace an existing file.
- Avoid auto migration at startup. No default snapshot or game setting changes.

## API and explicit user-facing workflow (candidate only)

The optional \`Workflow\` owns an unchanged PR #15 \`Settings\` instance.
To share keyboard routing state in a future test host, keep one instance:

\`\`\`gdscript
const Workflow = preload("res://input_profile_workflow_003.gd")
var workflow = Workflow.new()
# A future host *may* use:
# adapter.bindings = workflow.settings.bindings
\`\`\`

No existing scene was edited or run.

**Migration:**
1. Call \`preview_migration(legacy_path, v2_path)\` to read and validate V1.
   It returns source and destination version labels, a diff of changed keys,
   \`legacy_retained=true\` and a \`confirmation_token\`. Preview **does not
   write disk or change the live map**.
2. Present the plan. Explicit caller confirmation invokes
   \`confirm_migration(token)\`, which re-reads V1, checks its SHA-256
   fingerprint and the current in-memory map, refuses an existing V2,
   validates the V2 object, writes/renames/re-reads the destination, then
   (only after success) applies the validated V1 bindings in memory.
3. A cancelled or superseded preview cannot be committed. A token is
   **one-use sequencing data, not an authentication secret**.
4. To resume with a saved V2 document, explicitly call \`load_v2(path)\`;
   missing/malformed/unsupported files remain errors, never trigger an
   automatic default reset or legacy-file deletion.

**Conflict explanation:**
- Call \`preview_conflict(action_id, proposed_keycode)\`.
- Reuses original \`Settings.preview_rebind\`, adds readable explanation,
  currently assigned action owners and suggested corrective steps.
- No silent swap, automatic key reassignment or hidden InputMap override.
- Does not itself persist a rebind: prior explicit PR #15 configuration
  methods remain available.

**Restore defaults:**
1. \`preview_restore_defaults(v2_path)\` shows exact from/to key changes,
   whether the disk file is already defaults, and if the V2 file needs creation.
2. Existing V2 requires \`load_v2(path)\` first; the file's original bytes
   fingerprint must still match (no blind overwrite). If it disappeared,
   fail \`EXTERNAL_DELETE\`.
3. \`confirm_restore_defaults(token)\` verifies current memory fingerprint,
   validates candidate defaults with the unchanged PR #15 rules, persists V2
   first and only then updates live bindings.
4. A repeated restore with an already identical V2 file is a no-op disk-wise.
   A failed write does not change the live mappings. A first-time reset at an
   empty path can create a V2 defaults file **only on explicit confirmation**.
5. \`cancel_pending()\` invalidates outstanding approval without memory or
   disk effects.

A preview alone is not a state transition. Only explicit confirm or
explicit \`load_v2\` can apply bindings. The current configurable input
router remains the unchanged PR #15 adapter; \`InputMap\` remains untouched.

## Conservative failure policy

| Condition | Behavior |
| --- | --- |
| V1 with duplicate keycodes | \`CONFLICT\` and action-owner list; no repair |
| Missing/invalid V1 | Fail with reason, no V2 creation |
| Unsupported V1/V2 schema | Reject, do not guess a migration |
| Target V2 exists when migrating | \`TARGET_EXISTS\`, no overwrite |
| Wrong confirmation token, cancellation | \`STALE_PREVIEW\`, no commit |
| Source changed since preview | \`SOURCE_CHANGED\`, no commit |
| Live bindings changed since preview | \`MEMORY_CHANGED\`, no commit |
| Loaded V2 changed/deleted externally | \`EXTERNAL_CHANGE\`/\`EXTERNAL_DELETE\` |
| Corrupt V2 or unexpected filename | Error, no silent fallback to defaults |
| Existing fixed temporary file | \`TEMP_OCCUPIED\`, leave file untouched |
| Rename failed | Error and best-effort cleanup of candidate-created temp |
| Successful rename, failed verification | \`POST_WRITE_VERIFY_FAILED\`, \`committed=true\`, **no false rollback** |
| Existing V2 already has desired defaults | \`ALREADY_PERSISTED\`, no repeat disk write |

This is a cooperative **single-writer** candidate. SHA-256 checks cannot
eliminate time-of-check/time-of-use races, multiple writers, symlink attacks,
disk/power failure, or cross-platform rename semantics. The path guard checks
string segments but does not resolve symlink escapes; do not treat it as a
security sandbox. No backups, encryption, cloud sync or file migrations of
historical unknown formats are implemented. No filesystem atomicity is
claimed beyond using a same-directory temporary file and rename attempt.

**Design choices are proposals, not approved shared APIs.** Final product
integration, UX wording, backup policy and migrations beyond known V1 remain
subject to author acceptance.

## Future verification only — DO NOT RUN in this authoring task

From the repository root using the requested Godot 4.7.2 installation,
**when separately authorized**:

\`\`\`bash
godot --headless --path candidates/game_web_module_input_001_r1 \
  --script res://verify_input_migration_003.gd
echo $?
\`\`\`

Expected test contract: pass marker and exit 0; assertion failures return
nonzero. **This has not been executed.** Parser/runtime behavior is NOT_RUN,
as are desktop focus, GUI interaction, concurrent writers, performance, CI,
and platform-specific file rename. See \`ACCEPTANCE_INPUT_003.md\`.
