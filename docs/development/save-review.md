# Save store source review — 2026-11-03

Status: implementation written and manually source-reviewed; **NOT_RUN**. No Godot import, GDScript execution, filesystem fault injection, game tests, CI, preview, Windows export or deployment was performed. This document records intended code behavior, not observed runtime results.

## Scope and choices

`game/runtime/save_store.gd` implements the two methods in `runtime-contract.md`. It is an instance-free-until-called `RefCounted` utility; constructing it does not create directories. The fixed `free` and `chapter` slots prevent caller-controlled paths. It preserves prior records and never deliberately overwrites or deletes a save.

Each successful write allocates a generation above every recognized committed filename, serializes the payload using sorted keys and full float precision, hashes its exact UTF-8 JSON bytes, writes a random temporary filename, closes and verifies it, then renames and reads the committed file back. A successful result requires matching payload content after both readbacks. A failed promotion leaves its temporary record for inspection. A post-promotion `COMMIT_READBACK_FAILED` means the new committed name may already exist; do not describe this result as a confirmed save.

Reads inspect canonical generation names in descending order. An invalid newest record is skipped with its filename and reason in `skipped`; finding an older valid record returns `RECOVERED_OLDER_RECORD`. The UI should communicate that recovery and the generation. All-invalid committed records return `NO_VALID_RECORD`, whereas a genuinely absent slot returns `NO_SAVES`. A write also refuses to cover up an all-invalid slot. No recovery branch silently creates a new game.

JSON numbers have a single numeric type. The store rejects nonfinite numbers and integers outside ±9,007,199,254,740,991; boolean metadata cannot masquerade as generation/format. Parsed integer-valued floats are accepted for format and generation. JSON integer/float representation differences are accepted only when numeric value is unchanged. Resources, objects, packed arrays, non-string dictionary keys and oversized/deep structures are rejected. Cyclic input containers hit the depth limit before serialization, so serialization does not traverse them indefinitely.

The quest/session semantic schema is intentionally checked by the coordinator. The store checks the envelope and JSON-safe data, not whether a saved quest choice is legal. A syntactically intact but incompatible newest payload must be reported by the coordinator, not silently reset or mistaken for an older compatible game.

## Static review decisions

| Area | Source reasoning and result |
| --- | --- |
| Partial writes | Temporary names are `.pending-…tmp`, never interpreted as committed `.json` records. Temporary and final paths are under the same fixed directory. |
| No overwrite | Destination existence is checked before creation and immediately before promotion. The next generation derives from the highest filename, including corrupt higher generations, rather than the most recent intact record. |
| Reentrancy | A script-static flag covers writes across instances of this script; public reads refuse during a write. Functions contain no `await`. This is not an OS or thread lock. |
| Bounds | At most 1 MiB serialized payload, bounded outer record, 32 recursive levels, 8,192 visited values, and 1,024 directory entries. Hidden temporary records count toward the directory budget. A full directory fails explicitly rather than deleting history. |
| Filename ambiguity | Zero, leading zeros, non-ASCII decimal digits, mixed-case record names and overflowing generations fail closed. Scans do not silently reinterpret Windows case aliases. |
| Directory/symlink safety | Root and record links/reparse points are rejected before access. Paths originate from the fixed root and enumerated filenames. These checks do not defeat hostile concurrent replacement or hard-link attacks. |
| Integrity | SHA-256 verifies the exact payload JSON bytes. It is not authentication and does not stop an intentional editor from recomputing hashes. |
| Error surfaces | No valid record is distinct from no saves. Readback, promotion, directory saturation, open/read/write and generation failures have explicit codes. Existing files are preserved. |

## Remaining limitations

- **Single main-thread writer, one process:** `DirAccess.rename` can overwrite an existing destination. The immediately preceding existence check is sufficient only under the stated single-writer ownership; it is not an atomic compare-and-swap against another process. Do not enable a second writer without an OS-level locking/commit design.
- `flush`/`close` and rename do not establish cross-platform fsync or power-loss durability. Hardware, antivirus/file locks and Windows filesystem behavior require real validation.
- The built-in JSON parser is used. This is an owned local save format, not a hardened arbitrary-untrusted-JSON service; duplicate JSON keys are not independently detected. The hash protects accidental changes in payload bytes, not malicious rewrites.
- Records are append-only. There is no automatic retention, deletion, save-slot migration, user-selected directory or cross-machine sync. Reaching the directory bound needs an explicit later retention/archive policy.
- Lookup and hashing are synchronous. The bounded worst case may still be expensive when many large corrupt records exist. UI scheduling and performance are not measured.
- Mode clocks, inventory, rewards and content-version compatibility remain coordinator/domain responsibilities; none are claimed implemented by this utility.

## Deferred Windows acceptance

All rows are **NOT_RUN** and require later authorized execution on the target Windows build.

1. Save both modes, restart the process, load each slot and compare complete payloads.
2. Truncate or corrupt the newest record; receive the older generation plus corruption diagnostics without changing files.
3. Corrupt every committed record; loading and saving both fail without a new-game fallback.
4. Interrupt before temporary close, before promotion and immediately after promotion; retain the old committed generation and classify leftover files correctly.
5. Deny directory/write/rename access, exhaust disk space, and lock the destination using Windows file semantics; no prior save is overwritten.
6. Submit invalid slot/path strings, boolean/overflow generation, Unicode, cycle/deep data, nonfinite numbers, resources and objects; reject without commits.
7. Reach the entry bound using committed and hidden temporary records; fail explicitly and preserve all existing files.
8. Create link/reparse-point aliases and case-variant names; reject them under the supported Windows filesystem.
9. Confirm that two game processes are disallowed by the launcher before any write; otherwise this store is not approved for that deployment.
10. Measure ordinary and corrupt-history load/save latency on the intended machine. No latency target has been validated.

## API references checked

- [Godot JSON](https://docs.godotengine.org/en/4.6/classes/class_json.html): `stringify` sorting/full precision and JSON number semantics.
- [Godot DirAccess](https://docs.godotengine.org/en/4.6/classes/class_diraccess.html): bounded enumeration, links/reparse points and rename API.
- [Godot FileAccess](https://docs.godotengine.org/en/4.5/classes/class_fileaccess.html): error inspection, flush and close. API documentation is not evidence of target-runtime success.
