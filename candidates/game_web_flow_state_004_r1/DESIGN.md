# W-FLOW-STATE-004 r1 — Design and safety decisions

**Status: source proposal; NOT_RUN. No approval of shared interfaces or Canon.**

## Architectural choices, and why

| Decision | Why |
|---|---|
| Independent `codex/game-web-flow-state-004-r1` branch from `main` | Avoid editing PR #13, modifying other candidates, or carrying their diffs into the new Draft PR |
| Pin unchanged public inspector from PR #13 | This makes the scene independently buildable while neither accepting nor mutating upstream shared contracts |
| Keep the UI controller and RefCounted model separate | Future Codex can test model reports without a window; screen does not manipulate save or JSON |
| Only fixed names under manually entered `user://` folder | No arbitrary scan, directory enumeration, network fetch or hidden access |
| No default path / no scan during UI setup | Avoid accidentally reading a real save at startup |
| Exact story/free choice and clearing stale UI | No cross-mode mixing, no stale result presented after changing context |
| Redacted reports only | No raw JSON, round identifier, protected values or decoded text hashes in displayed result |
| Compare fields only for two validated v1 files | Unknown versions cannot be assumed to share field semantics |
| No-target preview as default | Unknown format should report missing mapping, not pretend to be migratable |
| Only phase / door_open for explicit hypothetical v1 preview | Offers a useful non-mutating difference preview without edit controls for version, mode, round ID or clock |
| Never write, export, print, copy or call OS commands | Any result remains an inspection artifact, not a migration or mutation |
| No rich screenshots/assets/dependencies | Keeps module standalone, testable and within public technical candidate scope |

The pinned dependency file was read directly from PR #13 HEAD
`be0b7813a37ca118f0eab045ad97ea8bc02d5b84` at development start.
Blob SHA: `89369cb3f6b7f80a508a608865a80a79c3855032`.
The copy is intentionally unmodified. A change to upstream PR #13 does not
automatically update this module. This is **not** a release of that API.

## Application flow

```text
User types folder A/B + chooses mode
               |
         [explicit click]
               |
  UI Control -> RefCounted browser model
               |
       lexical folder validation
               |
  pinned inspector read-only public report functions
               |
       sanitized status only
               |
         on-screen tabs
```

At startup only controls are constructed; nothing is read from disk.
All three views use the same **selected mode** and fixed filename; no
fallback to the other mode when a file is missing.

### Inspect and version tab

`inspect_folder` calls `report_snapshot` and
`report_version_delta` separately, and shows both results.
These are **not an atomic read**; if a writer changes the file between
calls, results could disagree. In an actual product, provenance or
snapshot-level locking would be required. We do not invent that
mechanism here.

### Version differences tab

`compare_folders` invokes the upstream
`compare_snapshot_versions` with two *independent* paths. If either
source is malformed, missing, mode-mismatched or oversized, comparison
is blocked. If a version is unsupported, only numerical ordering
and mapping-unavailable status may be shown. Only v1/v1 returns
allowlisted names and change kinds, without before/after values.

Even for a v1/v1 comparison, changes do not mean "transition legal"
or "migration safe". No gameplay rules or free/story clock policy is
inferred from the contents.

### Safe preview tab

`preview_without_target` intentionally does not invent a target;
an unsupported version yields `mapping_required`.

For a **user-initiated** hypothetical same-v1 preview,
`preview_candidate`:

1. Validates folder, mode, phase and strict boolean door_open input.
2. Reads a valid v1 snapshot using the upstream local detailed API,
   but keeps full values only in local function variables, never UI state.
3. Copies it in memory and changes only `phase`/`door_open`.
4. Invokes upstream `preview_migration_safe`. This returns only
   redacted field names, counts and blocked/review-only status.
5. Reads the original a second time and compares its **decoded-text
   hash** and file length to the first read. On mismatch or unreadable
   source, discards the preview and returns static
   `SOURCE_CHANGED_OR_UNREADABLE` with an empty changes list.
6. Returns only sanitized metadata to the screen. Does not store
   original data, proposed target or digest as UI model state.

This is **best-effort stale-source detection**, not an atomic transaction:
the source could change and change back, symlinks can redirect to different
files, the inspector can read an inconsistent file while a writer edits it,
and the middle preview read may differ despite matching first/last
hashes. The safeguard reduces accidental stale report presentation but
does not claim writer arbitration or serializability.

There is no "commit", "apply", "restore", "repair", "save",
"backup", "export" or "confirm migration" action. In the source
inspector's safe preview, all changes remain review-only and
`can_apply=false`, `mapping_approved=false`, `writes=false`.

## Boundaries of the known contract

The **only known save schema** is version 1 with exactly:
`version`, `mode`, `round_id`, `phase`, `door_open`, and
`clock_seconds`. Mode is `story` or `free`; phase is one of
`ready`, `observing`, `resolved`, `deferred`. The inspector
uses these known fields for format checks. Other schemas and migration
rules were **not provided**. Numeric v0/v2 in synthetic tests are
invalid/unsupported inputs, not actual past or future saves.

The UI cannot infer, explain, approve, or reconcile literary content,
time semantics, gameplay transitions or canonical story.
No private story notes, screenshots, raw chat evidence or production
save data are placed in this public module.

## Safety, privacy and limitations

- Public UI report data excludes round IDs, source JSON, path, full text
  fingerprints, before/after values and arbitrary keys. The folder input
  naturally shows the path typed by its local operator; do not screenshot
  or upload a session containing personal paths.
- Metadata such as file length, version number, source mode and changed
  field names may still be sensitive. No telemetry or output export is
  added. The user decides what to disclose.
- Godot JSON parser is not guaranteed to be strict RFC 8259; duplicate
  keys, UTF-8 errors, nonstandard syntax, overflow require separate review.
- A lexical `user://` filter is **not a symlink containment boundary**.
  The UI intentionally does not claim security against malicious
  filesystems; only use trusted local folders at future execution.
- No interprocess writer lock, file immutability, crash guarantee,
  multi-file transactional read, or cross-device migration is provided.
- 1 MiB inspection cap from pinned upstream is a **candidate safety limit**,
  not the storage format's accepted maximum.
- No UI application run, parser compile, mouse interaction, screen capture,
  performance check or automated test has been performed in this task.

## Future decisions deliberately left unresolved

No approved legacy-version schema or mapping; no save-core integration
contract; no event interface; no story/free clock rule; no author acceptance;
no production access policy. These are explicitly outside this scope.
The technical presentation choices were resolved above without requesting
author decisions prematurely.

For future acceptance and evidence see `ACCEPTANCE.md`.

---

## PLAY-STATE-005 r1 — design refinement and rationale

This revision is a **source-only improvement** inside the same independent
Draft PR #20. None of the following choices is author approval, a
gameplay rule or a shared interface.

1. **Human-readable reports instead of dumping JSON.** The prior UI
   showed the entire sanitized result dictionary. While model outputs
   were intended safe, later schema extensions could accidentally
   leak added keys. A separate **allowlisted presenter** formats known
   fields only. Its output remains deterministic and readable in Chinese.
2. **A stable three-tab layout with scrollable controls.** Three report
   purposes remain separated (validation/version, two-file comparison,
   migration preview). Scrollability is chosen over designing
   multiple game scenes, minimizing footprint and preserving
   candidate independence. Visual suitability is **not yet tested**.
3. **Clear statuses and stale-context invalidation.** Path/mode changes
   invalidate all previous reports. Hypothetical phase/door changes
   invalidate only the preview. This avoids presenting old results
   under a newly selected mode or proposed target.
4. **Basic path hygiene strengthened.** Reject ASCII control characters,
   length overflow, traversal, backslash, repeated/trailing separators,
   whitespace and non-`user://` paths. **Not a symlink sandbox**.
5. **Best-effort consistency checks** for inspection and comparison
   in addition to preview. A first/last detailed read is compared
   using decoded-text hash and file length, with inner report statuses
   checked. On detected changes, UI receives only a static
   `source_unstable` response. This costs extra reads but makes
   detected instability explicit; it cannot guarantee concurrency safety.
6. **Never introduce a write or migration control.** The screen offers
   inspection, comparison, a no-target migration-needs check and
   only an ephemeral v1 phase/door hypothetical preview. No version,
   mode, round-ID, clock editing or save/apply/restore control.
7. **Keep pinned upstream inspector unchanged.** The dependency
   originates from public PR #13 blob
   `89369cb3f6b7f80a508a608865a80a79c3855032`.
   The browser model wraps its existing APIs, and any upstream change
   requires manual review instead of implicitly approving a shared API.
8. **Avoid unrequested cross-project filesystem access.** In a separate
   Godot project `user://` is not necessarily the original game's
   user directory. This is documented instead of silently introducing
   an unrestricted absolute-path reader. A future authorized import
   or embedding design requires separate approval.

See [INTEGRATION.md](INTEGRATION.md) and [SAFETY.md](SAFETY.md).
No code/test execution or real-user-save access occurred. `NOT_RUN`.

---

## STATE-006 r1 design continuation: comparisons and exception indicators

The new [DIAGNOSTICS_POLICY.md](DIAGNOSTICS_POLICY.md) records the full
decision matrix. Ordinary design choices were resolved locally:

- A **separate pure diagnostics layer** is preferred to editing the
  upstream inspector, because PR #13 is still Draft and its exact
  pinned blob must remain unchanged here.
- **Static anomaly codes with allowlisted Chinese messages** are
  preferred to displaying exception text or serializing report
  dictionaries; source values cannot silently become UI output.
- Comparison requires **two fully valid v1 sources**. A numeric version
  label is diagnostic, not proof that fields have identical semantics.
- **Same lexical source** is made explicit so selecting A=B is not
  mistaken for comparing a real backup. Symlink aliasing remains unknown.
- Missing/unreadable data is marked `no_payload_to_verify`, so
  a repeated status does not imply observed source-byte stability.
- UI uses one neutral risk label and detailed notices inside the
  existing three tabs, avoiding additional complexity and action
  affordances that might suggest migration can be applied.
- Blocked comparisons and previews show **no field changes**, even
  if malformed, injected or untrusted metadata contains apparent
  change entries.
- No writer, backup, repair, export or migration API is introduced.

These choices describe source-only prototypes, NOT_RUN and not an
approved game/save contract.
