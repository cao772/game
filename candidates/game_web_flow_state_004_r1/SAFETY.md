# GAME-WEB-PLAY-STATE-005 r1 — Read-only safety boundary

**Candidate, NOT_RUN. Not a security certification. No live saves opened.**

## Protected assets and attack surfaces

Protected: existing story/free snapshot files, private round IDs and values,
user-authored story manuscripts, runtime state, clocks, event transitions
and any source material outside the public GitHub candidate.

Inputs: manual `user://` folder A/B strings, selected mode,
a hypothetical enum phase and boolean door-open toggle. The UI never
accepts raw JSON content, an absolute filesystem path, an arbitrary
filename, a source version override or an executable migration mapping.

Output: on-screen, allowlisted, **metadata-only** reports. Displayed
version numbers, mode, field names and error codes can still be sensitive
in a specific project; no automatic telemetry/export is implemented.

## Write surface

The production candidate application consists of `snapshot_browser_*.gd`,
`snapshot_report_presenter_candidate.gd`, and pinned
`snapshot_inspector_dependency.gd`. Source contains **no save/
apply/repair/restore call, file WRITE, rename, remove, mkdir, shell,
HTTP, telemetry or export action**. The only file access in the
pinned inspector is read-oriented plus metadata. The UI changes
Control nodes' text *in memory*, not on-disk saves.

The **future SceneTree tests**, separate from the production UI,
create and delete synthetic files only in their own fresh `user://`
fixture directories and never target actual saves. The author
explicitly forbids running them during this task.

This does not claim Godot itself, its editor or the operating system
never writes caches/configuration on startup; it claims the
candidate does not implement snapshot writes.

## Content disclosure barriers

The browser controller does **not** use JSON.stringify on arbitrary
returned dictionary objects anymore. The new presenter reads only:

- recognized status enum and fixed error-code allowlist;
- expected mode story/free;
- safe numeric version label and compatible_v1 etc.;
- allowlisted changed known field names and `add/remove/change` kinds.

It never formats `round_id`, `clock_seconds`, `phase` value,
`door_open` value, before/after values, raw JSON, unknown field
names, source path or decoded-text fingerprint. Even error codes
are rendered only if present in a hard-coded list. Unknown statuses
are rendered as "未知状态" rather than echoed raw.

Caution: the two folder input widgets necessarily show whatever
directory an operator typed; avoid screenshots and logs of a real
session. The pinned dependency still offers **detailed private**
inspection methods that include valid source data and text hashes.
They remain needed internally for best-effort consistency checks,
but their raw results are never passed to the UI/presenter.

## Validation and controls

- Require manually provided `user://` subdirectory with nonempty,
  bounded, safe lexical segments. Reject `..`, repeated slashes,
  trailing slash, colon, backslash, control characters and leading/
  trailing whitespace; this is **not realpath/symlink security**.
- Restrict mode to story/free and fixed mode filename. No fallback
  from a missing free to story or vice versa.
- No automatic scan at startup or on typing.
- Changing mode or path clears all report tabs; changing phase or
  door flag invalidates old preview text.
- The inspector accepts only fully validated v1 for field-level diff.
  An unsupported version requires an approved mapping which **does
  not exist in supplied sources**. No guessed migration or repair.
- Hypothetical controls can only alter an ephemeral v1 copy's phase
  and door-open flag; UI never edits version, mode, round ID or clock.
- Best-effort first/last decoded-text hash and byte-length reads
  discard a report when change is observed; this is **not** a lock,
  serializable read or guarantee of immutability. A file can change
  back or change during an intermediate read.
- No trusted record of author approval, provenance or schema
  authenticity is available. Candidate status remains unverified.

## Known unresolved security limitations

1. Symlinks inside `user://` may point outside the expected directory.
   Lexical path filters do not establish filesystem containment.
2. Godot JSON may admit syntax extensions/duplicate keys; the pinned
   v1 checker is not a strict RFC JSON or UTF-8 proof.
3. Filesystem/OS races exist. A hash match on two reads does not
   establish absence of intermediate changes.
4. No concurrent writer lock or cross-file atomicity.
5. 1 MiB guard is inspection-only, not an approved storage limit.
6. Pinned upstream Draft PR #13 is not a stable approved dependency.
   Any future update requires explicit code review and test.
7. User's final review and authorized runtime tests are still
   required. No code has been run in this task.

Nothing here elevates the prototype, snapshots, names or field
semantics to authoritative game canon or an approved shared interface.
