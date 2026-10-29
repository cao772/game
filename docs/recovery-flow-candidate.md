# GAME-WEB-CONTINUE-ENGINE-003 r1 — Previewed, non-overwrite recovery

**STATUS: NOT_RUN.** This is an independent, development-only extension of Draft PR #8. No source code or tests were executed for this delivery.

## Source and boundaries

Read PR #8 head 1cf7c6253a8cd63835795a3fc4012be286bb88d6: prototypes/save_recovery_candidate.py, tests/test_save_recovery_candidate.py and docs/save-recovery-candidate.md. The source still depends on PR #2 prototypes/save_candidate.py. These inputs, main, story materials and other workstreams are unchanged.

New public technical files:
- prototypes/recovery_flow_candidate.py — opt-in classified inspection, read-only preview, separate-directory recovery, audit-preserving rollback.
- tests/test_recovery_flow_candidate.py — **unexecuted** future acceptance cases and failure injection.
- docs/recovery-flow-candidate.md — this rationale and limitations.

These are experimental private-caller APIs, not approved shared interfaces, product UI, automatic recovery or gameplay timeline semantics. No files containing real save data, private story content or local operator evidence are published.

## Design choice A — classify damage without repairing it

classify_save(path) is read-only. It distinguishes missing, valid, corrupt, inaccessible and unsafe categories. Corruption codes include invalid_utf8, invalid_json, duplicate_json_key, nonfinite_json_number, version_type_invalid, unsupported_version, unknown_mode, invalid_clock, schema_invalid and oversized. The schema authority remains the existing baseline.validate; invalid booleans, negatives and unsupported versions are rejected, never normalized.

classify_backup(path) reports missing manifest/payload, digest or size mismatch, invalid manifest, invalid save schema, unsafe symlink or generic verification failure. It uses PR #8's original _verified_backup as the final archive authority. The error-string-derived classification is advisory; an unrecognized error remains backup_validation_failed, not guessed.

**Reason:** explicit diagnostic codes allow a future recovery UI to communicate damage accurately without inventing a fix or changing the original save structure. A SHA-256 match detects accidental alteration but not a malicious attacker who rewrites both manifest and payload.

## Design choice B — preview first, then revalidate before any write

preview_non_overwrite(snapshot_dir, original_save, output_root) reads the verified archive, classifies the existing primary save, checks the output root exists and is a directory, and emits a deterministic preview_sha256 of paths, classifications, hashes and policy warnings. It does not create directories or modify any file.

A preview is ready only when:
- archive verification succeeds;
- output_root is an existing, non-symlink directory;
- existing original is valid, missing, or corrupt with a complete-byte SHA-256 (not unreadable or oversized).

A valid original with a later free_clock produces a warning; creating an independent historical copy is allowed since no current-save time is changed. This does NOT approve time rollback in normal game saves.

recover_non_overwrite(preview) recomputes the plan, rejects any modified or stale preview, re-verifies the archive and re-checks the plan again just before publication. Preview fingerprint is a change detector, NOT a signed approval token, lock or guarantee against a race.

**Reason:** the author can later review a deterministic proposed operation. Refusing stale previews prevents common accidental restoration of out-of-date information, while accurately documenting concurrency limits.

## Design choice C — recovery can never overwrite the original

Recovery writes only into a new unique recovery-UTC-UUID directory inside an explicitly selected existing output_root. New files:
- save.json — exact verified backup bytes.
- receipt.json — recovery ID, creation time, source backup ID, content digest/size, preview fingerprint, original status/hash/clock, recovered clock and original_modified=false.

The directory is assembled as a hidden .recovering-* staging directory; files are flushed and fsynced, then directory rename publishes the recovered copy. The primary save file is NEVER rewritten, renamed, quarantined or deleted by this extension. The original PR #8 overwrite-capable restore_backup remains untouched and is not invoked here.

**Reason:** keep recovery and adoption separate. A future approved adoption step may require authorization and locking but is outside this scope. UUID collision prevention is best-effort without cross-process locks.

## Design choice D — rollback retracts only the recovered proposal

inspect_recovery(path) validates receipt version, directory identity, payload size/digest and original save schema, and reports active, rolled_back, corrupt, missing or unsafe.

rollback_non_overwrite(recovery_dir) operates only on intact active outputs, renaming the entire directory into a unique rolled-back-recovery-* directory in the same parent. Both bytes and receipt remain for audit. The original remains unchanged. A modified candidate or second rollback is rejected.

**Reason:** a rollback can retract a generated copy without risking game progress or deleting recovery evidence. Since the primary was never changed, there is no primary state to undo. An externally consumed recovered save cannot be unloaded by this function.

## Failure limitations and deliberate non-guarantees

- **Concurrency:** only a single-writer/trusted-local-filesystem candidate. A race between revalidation and publish still exists; there is no lock, optimistic CAS, transaction coordinator or cloud sync arbitration.
- **Power loss:** file fsync and same-directory rename mitigate incomplete data, but no fsync of containing directories, journal replay or cross-platform durable commit guarantee is implemented. A crash may leave hidden .recovering-* folders or require operator inspection.
- **Permissions and disk full:** missing/unsafe root is rejected in preview; permissions can still fail on staging creation, write, rename or cleanup. A failed operation may leave staging debris if cleanup itself fails. The primary remains untouched by this extension. Preview cannot promise permission success.
- **Trust:** no sandbox against untrusted paths, no path confinement, no ancestor-symlink protection, no cryptographic archive authentication; do not pass arbitrary user-supplied paths or force flags directly to the module.
- **Capacity:** 2 MiB maximum input is an inherited proposal, not a measured save-size limit. Oversized originals fail closed because a reliable full-file fingerprint cannot be created.
- **Usage:** no automatic backup, scheduled cleanup, retention policy, content merge, original-save replacement, player UI or shared event bus.
- **Dependency:** the extension calls two internal PR #8 helpers (_read_limited and _verified_backup / _valid_state). This is acceptable for the isolated stacked candidate but would require public contract review before production use.

## Future acceptance source — all cases NOT_RUN

tests/test_recovery_flow_candidate.py defines intended cases:
1. Preview does not write/change source, backup or destination; stable repeated fingerprint.
2. Valid separate recovery and receipt preserve original and unrelated files.
3. Repeated recovery yields independent unique directories.
4. Older archive warning, while current newer save is unchanged.
5. Corrupt or missing primary remains untouched and can have a separate recovery.
6. Invalid UTF-8/JSON, duplicate keys, nonstandard numbers, unknown version/mode, boolean/negative clocks are classified.
7. Oversized current save, missing output directory, invalid manifest or payload reject recovery.
8. Modified original, source manifest or preview after preflight reject stale execution.
9. Rollback is evidence-preserving and cannot repeat; damaged output refuses rollback.
10. Symlink rejection and injected permission/rename failures do not overwrite the primary.
11. Future revalidation of existing PR #8 tests and PR #2 baseline requires separate owner authorization.

Further isolated integration acceptance should check actual permission masks, disk-full, process crash, concurrent writes, filesystem rename differences and directory fsync behavior. No test passing claims are made.

## Handoff

task_id: GAME-WEB-CONTINUE-ENGINE-003
version: r1
input: PR #8 source at 1cf7c6253a8cd63835795a3fc4012be286bb88d6; PR #2 base dependency
scope: preview, damage categories, reversible non-overwrite recovery
deliverable: 3 independent technical files
acceptance: later author review and explicitly authorized tests
status: **NOT_RUN**
restrictions: no main changes, no other modules changed, no private data, no approved shared interface or game canon
