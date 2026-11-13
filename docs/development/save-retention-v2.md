# Explicit save archival — foundation batch 002

2026-11-03. Candidate source implementation and static review only. **NOT_RUN**: no game code, Godot import, tests, CI, Windows filesystem operation, export or deployment was run.

## Added APIs

`archive_older(slot: String, keep: int = 32) -> Dictionary`

This is an explicit application action, never an automatic consequence of saving, loading or constructing the store. It accepts only the existing `free` and `chapter` slots, and `keep` in 2..1024. It uses the same script-static write/reentrancy guard as `write_record`. Invalid arguments fail before scanning or creating directories.

The archiver first scans the active slot and validates every recognized committed record through the existing envelope/schema/UTF-8/size/hash checks. Invalid records are left in place and recorded in `diagnostics`; they do not count toward retention. A wholly corrupt slot fails `NO_VALID_RECORD`. The latest `keep` valid generations are retained; therefore at least two valid active records remain whenever any archive move is attempted. The active filename with the highest generation is additionally protected even when corrupt, preserving the existing next-generation rule.

Only older valid records are planned for relocation. They move, unchanged, from `user://game_runtime_v1/<slot>-<generation>.json` to `user://game_runtime_v1/archive/<slot>/<generation>.json`. Neither source nor destination content is rewritten. The archive root, slot directory and individual record paths receive link/reparse-point checks. A destination that already exists—including a directory or link—is skipped and explicitly reported; no equality-based overwrite or deduplication deletion occurs.

Before each rename the source is re-read and its complete file SHA-256 must still match the preflight record. After rename the destination is read through the same validator and its complete file hash must match. The two latest retained records are never part of this move set. Old saves, corrupt records and temporary records are not deleted.

`read_archived(slot: String, generation: Variant) -> Dictionary`

Explicitly reads one archived generation through the same record validator. Generation must be a positive bounded integer or a finite integral JSON number; booleans, strings, paths and out-of-range values are rejected. It constructs the filename itself and opens only the requested fixed path; it does not enumerate archive history, write a restored save, modify a quest/session, or change the `read_latest` fallback policy. Batch 002 connects this store API to explicit `load_archived` methods in the coordinator and application, which validate mode/schema/quest before changing the active session. A player-facing archive selector remains future UI work.

## Result and failure semantics

Every archive operation returns:

- `ok`, `code`: whether all eligible moves completed.
- `atomic: false`: the operation is explicitly a sequence of independent moves.
- `moved`: generation, source and destination path plus `readback_verified` for each successful rename.
- `remaining`: validated eligible records not yet moved, including target-name conflicts. It excludes deliberately retained generations and invalid records, which are reported separately.
- `retained`: protected valid active generations.
- `diagnostics`: invalid active records, target conflicts and I/O failures with names/generations where known.
- `partial`: `true` when the operation failed after at least one rename. A moved-but-unverified record is included in `moved` and makes the operation fail.
- `remaining_unknown`: `true` if scanning/availability failed before a reliable plan could be formed. An empty `remaining` in that case does not mean the slot is empty.

Conflicting destinations are left intact and the archiver may continue with other eligible files. Any source change, directory failure, rename failure, archive capacity limit or failed post-rename readback stops further moves. A failed readback does not attempt a potentially destructive rollback; its receipt reports that the file has moved but has not been verified. A future application must retain/report this receipt and inspect both locations before another action.

`ARCHIVED_WITH_WARNINGS` means all *eligible valid* records moved but corrupt active records were deliberately retained. `NOTHING_TO_ARCHIVE` may also carry diagnostics: it does not certify every active file as healthy. `NO_VALID_RECORD` is never represented as an empty new-game slot.

## Bounded storage and saturation

- Active directory enumeration retains a hard limit of 1,024 **active entries**, including hidden, temporary and unrelated entries. The single exact-name `archive` control directory is excluded only after verifying it is an actual directory and not a link/reparse point. Mixed-case aliases, links and non-directory control entries fail `ARCHIVE_CONTROL_INVALID`. At **exactly** 1,024 active entries `archive_older` can scan and move records; unlike a normal write, it does not require a spare temporary-record entry.
- A separate total root-entry limit is 1,025. Thus only that one verified control directory receives an exemption; unknown files/directories still consume the active budget. Counting remains bounded even if enumeration order places `archive` last. No recursive archive scan is used to obtain this exemption.
- The selected archive slot has a separate bound of 4,096 entries, counted with hidden entries and directories included. The first entry beyond this bound fails the scan. The archiver does not recursively enumerate archive content, inspect the other mode's history, or read every old archived payload.
- At archive capacity the operation stops without deleting anything. An explicit later archive-rotation/export design is needed for indefinite use; this source change does not introduce one.
- If active entries exceed 1,024, or total root entries exceed 1,025, the automatic operation refuses and reports `remaining_unknown`. Recovery requires deliberate non-deleting file relocation/inspection outside this API; it does not silently truncate the scan.
- Creating a previously absent `archive` directory adds one control entry without consuming active capacity. If the first move then fails at a full active root, a later archive retry remains scannable after correcting the I/O cause. This fixes the initially identified 1,024→1,025 self-lock case without deleting the new directory or any record. A normal save still waits for active capacity to be freed by a successful explicit archive action.

## Static review log

| Concern | Code decision |
| --- | --- |
| Moving the only recovery copy | Retention uses successfully validated records, not raw filename count; at least two remain outside the move list. |
| Generation rollback after retention | Highest active filename is protected; ordinary write generation selection is unchanged. |
| Corrupt older records | Not moved, not deleted and not counted as retained valid copies. |
| Archive overwrite | Presence checks before move; a collision remains active with `ARCHIVE_TARGET_EXISTS`. |
| Partial operation | Receipt is updated immediately after each successful rename, before its verification. |
| Full-root first-move failure | A verified fixed control directory has a separate one-entry allowance; a failed first rename does not permanently block archive retry. Unknown entries receive no allowance. |
| Mode/path confusion | Fixed slots and validated generation form every path; archive access verifies each directory component. |
| Cross-process races | Still unsupported. The existence check plus rename is not an OS compare-and-swap. No claim of new concurrency guarantees. |
| Crash/power loss | Sequential moves never target the retained valid generations; runtime durability and cross-directory rename behavior still need Windows evidence. |
| Old behavior | `read_latest` remains active-only; neither saves nor reads call retention or archived recovery. |

The store now exposes `record_sha256` on successful reads for archive preflight/readback comparison. This hash is integrity metadata, not authentication. The archived payload remains opaque to the store; the coordinator must still reject incompatible mode, content or quest state before using it.

## Deferred Windows acceptance — all NOT_RUN

1. Produce more than `keep` valid generations; archive and confirm exact-byte content in the fixed archive, latest generations unchanged and next save generation increasing.
2. Use `keep=2`, two valid records and many corrupt records; confirm no retained valid record is moved and corruption diagnostics remain visible.
3. Make the highest generation corrupt; archive older valid records and confirm the next generation does not reuse or go below that name.
4. Precreate a conflicting archive destination; confirm both original source and target survive unchanged and the result names the blocked record.
5. Fail rename after one successful move; inspect `partial`, `moved`, `remaining`, preserved active recovery records and unchanged content.
6. Fail post-rename verification; confirm moved-but-unverified receipt and no attempted destructive rollback.
7. Reach exactly 1,024 active entries and archive successfully; separately fail the first move after new archive-directory creation, correct the injected I/O cause, and retry without deleting anything. Check that 1,025 active entries, 1,026 total entries, a linked control directory and a mixed-case control alias still fail closed.
8. Reach or exceed 4,096 archive entries; confirm bounded scan/refusal and absence of deletion.
9. Read an explicit archived generation; reject malformed IDs, mode/path strings, booleans, links and invalid hashes; confirm active `read_latest` behavior stays unchanged.
10. Interrupt or terminate the process between moves; inspect both locations without assuming the whole batch was atomic. Run no second writer concurrently.
