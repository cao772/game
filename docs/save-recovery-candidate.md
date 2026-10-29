# GAME-WEB-MODULE-ENGINE-001 — Save backup, integrity and recovery candidate (r1)

**Status: source implementation only — NOT EXECUTED, NOT TESTED.**

Dependency: existing Draft PR #2, commit cb0026ec668b96832efed5bf452a90548bc31c20, file prototypes/save_candidate.py. This is a stacked Draft PR targeting the PR #2 branch, not main. If PR #2 changes, re-check the dependency before review or merge.

## Delivery

- prototypes/save_recovery_candidate.py — independent standard-library backup, damage detection and explicit recovery.
- tests/test_save_recovery_candidate.py — future unittest acceptance candidates, deliberately not executed.
- docs/save-recovery-candidate.md — scope, storage format, safety policy, acceptance and limitations.
- Existing prototypes/save_candidate.py is not modified. Its validate, SaveError and VERSION are reused. Existing save_game, load_game, clocks and serialization are unchanged.

All new functions are opt-in experimental APIs only; they are NOT approved shared game interfaces. There is no automatic recovery, archive deletion, migration, scheduler, deployment, startup hook, third-party dependency or player UI.

## Candidate functions

- inspect_save(save_path): read-only status (missing, corrupt, valid) with checksum and metadata for valid saves.
- create_backup(save_path, backup_dir=None): validate a current save, then create a new snapshot without modifying that save.
- inspect_backup(snapshot_dir): read-only archive verification.
- list_backups(save_path, backup_dir=None): enumerate published snapshot folders, newest directory names first.
- restore_backup(snapshot_dir, save_path, *, replace_valid=False, allow_rollback=False, backup_dir=None): explicit, guarded restore; no restore runs without a caller.

The default backup directory is a sibling path named <save_path>.backups. Explicit backup_dir can override it. Source files and payloads are never copied into this Git repository by these functions unless a future caller explicitly chooses a repository path.

## Format and detection

A published directory is named backup-<UTC timestamp>-<random UUID> and contains:

- save.json: exact original validated UTF-8 JSON bytes, unchanged.
- manifest.json: backup format 1; backup ID; UTC time; fixed payload name; byte length; SHA-256; original schema version; free_clock; mode.

A snapshot is prepared in a .pending-* directory under the same backup root; both files are flushed and fsynced before the directory is renamed to a published name. Interrupted .pending-* directories are not offered by list_backups. They are not deleted automatically.

Verification checks the file byte size, digest, JSON decoding, disallows duplicate JSON object keys and NaN/Infinity, applies original validate, and compares manifest fields with decoded save fields. The proposed byte-size ceiling is 2 MiB; this is not a measured production requirement.

A matching SHA-256 verifies accidental byte integrity, not authenticity. Someone able to change both a payload and manifest can generate a matching digest. Filesystem ACLs, signed manifests, external backups, permission models, multi-device synchronization and authenticated storage need separate design approval.

## Restore policy

| Destination | Default operation | Override / preservation |
| --- | --- | --- |
| Missing | Restore verified payload by atomic replace | No override |
| Invalid or corrupt | Copy exact original bytes to unique .NAME.corrupt-*.bin quarantine, then replace | Unreadable or >2 MiB source refuses restore |
| Valid and byte-identical | Return unchanged | No rewrite |
| Valid but different | Refuse | Explicit replace_valid=True, with automatic pre-restore backup of valid target |
| Valid and later free_clock | Refuse | Both replace_valid=True and allow_rollback=True; pre-restore backup still required |
| Backup invalid or inconsistent | Refuse | No destination write |

The original save_game monotonic guard is NOT changed. allow_rollback is an explicit restore-operator override, not permission for regular game time to move backwards. Pausing the free clock during history mode remains only the prior technical experiment strategy, not approved game product semantics.

## Safety and unproven edges

- Single writer only. There is no process lock, compare-and-swap on destination revision, nor atomic multi-file transaction. A concurrent game save could race restoration.
- File fsync plus rename lowers partial-write risk, but no cross-platform full power-loss durability or fsync-on-directory guarantee is claimed.
- If saving a quarantine succeeds and the subsequent atomic replace fails, the original primary remains in place and the quarantine copy also remains. Manual reconciliation may be necessary.
- Backup and restore do not automatically create missing destination parent directories; no path confinement or user authentication is provided. Do not accept paths or force overrides from untrusted callers.
- No automatic retention/pruning: storage exhaustion, orphaned pending folders and lifecycle policies remain future decisions.
- A corrupt backup can never be used for restoration. JSON schema correctness cannot guarantee gameplay semantic correctness.

## Acceptance cases — intentionally NOT RUN

Future tests/test_save_recovery_candidate.py contains scenarios for:

1. Exact original byte preservation, manifest consistency, listing and verified backup.
2. Missing/invalid file rejection; bad JSON, UTF-8, duplicate keys, NaN, oversize data.
3. Payload or manifest tampering rejection without modifying a valid destination.
4. Restoring a missing destination with exact byte equality.
5. Preserving a corrupt destination's original bytes in quarantine before restoring.
6. Blocking silent valid replacement and rollback; explicit overrides, pre-restore backup, and monotonic clock enforcement.
7. Equal-clock divergent state versus same-bytes no-op behavior.
8. Pending snapshot exclusion and corrupt archive reporting.
9. Negative and boolean clock, unknown mode, unknown schema version, and symlink path rejection.
10. Separately rechecking the original three save tests and existing CI when the author later approves execution.

This submission creates test source files but **does not invoke them**. No command or CI success claim is part of this delivery.

## Future owner decisions

File locking / concurrent save coordination; recovery confirmation UI; source size limits; backups in other physical media; data confidentiality and authenticating the manifest; retention/quota; power-failure verification; two-stage maintenance and recovery; integration interface promotion and whether historic chapter time is paused as product semantics.

## Handoff

- task_id: GAME-WEB-MODULE-ENGINE-001
- version: r1
- input: PR #2, prototypes/save_candidate.py at cb0026ec668b96832efed5bf452a90548bc31c20
- scope: independent public technical candidate, backup + damage detection + recovery
- acceptance: proposed cases above, all pending owner-approved execution
- status: code and docs committed to a separate Draft PR branch, not tested, not approved
- privacy: no manuscript, private scene, story data, personal path or raw chat archive included
- repository: cao772/game; never write the historical dash-named repository; never merge main automatically
