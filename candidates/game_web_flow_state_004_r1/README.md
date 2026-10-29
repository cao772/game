# GAME-WEB-FLOW-STATE-004 r1 | Snapshot Browser (read-only)

**Independent Godot 4.x technical candidate · Canon N/A · NOT_RUN / NOT_VERIFIED.**

This is a complete standalone scene + UI model for **inspection, version
difference and guarded migration preview**, with no save writing, migration,
gameplay runtime connection or approved shared API. The main repository
branch, existing Draft PRs, and user-authored story files are unchanged.

## Reviewed source and exact dependency

Read GitHub's current Draft PR #13:
[Read-only snapshot inspector and version-difference candidate](https://github.com/cao772/game/pull/13),
head `be0b7813a37ca118f0eab045ad97ea8bc02d5b84` on
`codex/game-web-module-state-001-r1` at authoring time.

`snapshot_inspector_dependency.gd` is an **unchanged text copy** of
`candidates/game_web_module_state_001_r1/snapshot_inspector_candidate.gd`,
original Git blob **`89369cb3f6b7f80a508a608865a80a79c3855032`**.
Its status/error/version report semantics come from Draft PR #13 and the
sole known v1 snapshot schema from [Draft PR #6](https://github.com/cao772/game/pull/6).
Neither upstream PR is modified or endorsed.

Because this new Draft PR branches from `main` independently, it includes
this public, pinned dependency in its own isolated folder. It does **not**
merge the upstream candidate or silently import an unapproved shared module.
Any upstream changes require manual comparison and independent re-verification.

## Included files

- `project.godot` — separate Godot project, with main scene.
- `snapshot_browser.tscn` — standalone UI scene; no asset dependencies.
- `snapshot_browser_candidate.gd` — Control UI: mode selection, manual
  folder inputs, three report tabs, two-field hypothetical preview controls.
- `snapshot_browser_model_candidate.gd` — RefCounted read-only adapter,
  sanitizes folder paths, calls only pinned inspector APIs, checks preview
  source fingerprint stability on a best-effort basis.
- `snapshot_inspector_dependency.gd` — pinned **unchanged** upstream public
  inspector implementation, not a new shared contract.
- `DESIGN.md` — design decisions, user interaction, safeguards and limits.
- `ACCEPTANCE.md` — finite future test matrix and manual review procedure.
- `verify_browser_model.gd` — 34+ future model regression assertions.
- `verify_browser_ui.gd` — 22 future UI smoke assertions.

## UI and behavior

Use **only after the author authorizes running Godot**:

```sh
godot --path candidates/game_web_flow_state_004_r1
```

The main scene has these controls:

1. **Directory A:** manually type a `user://...` directory; the browser
   checks only the expected mode-specific snapshot filename. No implicit
   search, folder enumeration, raw data listing, or initial scan.
2. **Directory B:** independently typed comparison directory. Only the
   same selected mode is compared; story/free are never cross-compared.
3. **Mode:** explicit `story` or `free`. Changing mode or either folder
   clears stale reports immediately.
4. **Inspect A:** redacted status/error, v1 format compatibility, and
   version's numeric relation to reference 1. Two separate reads, not
   a transaction.
5. **Compare A/B:** redacted version relation and names/kinds of changed
   fields only when **both** inputs validate as v1. Other versions report
   missing mapping; corrupt/foreign/missing input blocks comparison.
6. **Preview migration need:** safely says v1 needs none; unsupported
   numeric versions need approved schema mapping, which was not supplied.
7. **Hypothetical preview:** a non-persisted v1 target derived from the
   current valid local read, changing *only* candidate `phase` and
   `door_open` from user-controlled widgets. Displays field-name-only
   differences, **never applies or saves** the result.

The UI does not display source JSON, round IDs, exact paths in reports,
hashes or before/after field values; manually typed folder paths remain
visible in their respective inputs as expected. Reports are held in UI
memory only. No buttons can save, overwrite, repair, export or migrate.

## Proposed API usage

`snapshot_browser_model_candidate.gd` exposes:
- `inspect_folder(folder, mode)`
- `compare_folders(folder_a, folder_b, mode)`
- `preview_without_target(folder, mode)`
- `preview_candidate(folder, mode, phase, door_open)`

All outputs are proposed sanitized dictionaries. A true migration cannot
be performed because no approved source schemas or transformation mapping
were supplied. The model never calls any `save_snapshot`, `FileAccess.WRITE`,
or platform process method.

## Status and acceptance

**AUTHORING ONLY. NO GODOT BINARY, SCENE OR TEST EXECUTED IN THIS TASK.**
All expected acceptance results in `ACCEPTANCE.md` are future requirements,
not pass evidence. The two tests will write **only their own synthetic
disposable `user://` fixtures** if Codex is later told to run them. The
production UI writes no fixture or save file.

Do **not** connect to a save core, runtime or event system, approve Canon,
merge main, or submit private save data as evidence. User is final reviewer.

---

## PLAY-STATE-005 r1 continuation — readable, guarded browser

**Source-only update, NOT_RUN / NOT_VERIFIED.** The same Draft PR #20 branch
is updated. No `main`, upstream PR #13, game runtime or manuscript edit.

### Additions

- `snapshot_report_presenter_candidate.gd`: separate pure presentation
  layer, with Chinese readable validation, compatibility, version-diff
  and preview summaries. All displayed status and error codes are
  **allowlisted**, and difference entries show only the six known field
  names and change type. No raw JSON/digest, actual round ID, source
  phase/door/clock values, path or arbitrary error text is rendered.
- `snapshot_browser_candidate.gd`: reorganized three-tab view, scrollable
  upper controls, explicit status feedback, manual-only inspection,
  context invalidation after mode/folder change, and preview invalidation
  after hypothetical field change. The UI no longer JSON-stringifies
  raw model results into its output fields.
- `snapshot_browser_model_candidate.gd`: control-character path rejection
  and best-effort first/last read checks to identify changed/unreadable
  sources. These checks do **not** establish an atomic snapshot.
- `verify_report_presenter_005.gd`: 22 additional future tests for
  redaction/allowlists, numeric-version summaries, blocked/invalid
  statuses, migration messaging. The previous model and UI future suites
  remain; UI cases U23–U26 add visibility/privacy assertions.

### Standalone vs integration

See [INTEGRATION.md](INTEGRATION.md) for separate-project startup,
resource path adaptation needed before embedding, and the important
Godot `user://` scope limitation: the standalone app cannot
automatically inspect a different Godot game's own save directory.
[SAFETY.md](SAFETY.md) documents private-data handling and known
filesystem/concurrency limitations. [DESIGN.md](DESIGN.md) records
tradeoffs without prompting for ordinary UI decisions.

No real file was loaded or modified during authoring; no executable
migration exists. Future verification commands and evidence templates
are in [ACCEPTANCE.md](ACCEPTANCE.md).

**All suites: NOT_RUN. Author is the final acceptor.**
