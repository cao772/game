# GAME-WEB-PLAY-STATE-005 r1 — Integration notes (proposal only)

**Status: NOT_RUN. No shared-interface or Canon approval.**
This document gives a future integration route; **nothing here was
executed**, and no production save was opened or modified.

## The self-contained, supported candidate arrangement

The standalone directory is a complete Godot application project:

- `project.godot`: independent, candidate-only project settings.
- `snapshot_browser.tscn`: root Control scene.
- `snapshot_browser_candidate.gd`: view and explicit UI actions.
- `snapshot_browser_model_candidate.gd`: path validation and safe
  read-only report mediation.
- `snapshot_report_presenter_candidate.gd`: strict allowlisted
  formatting (no raw dictionaries serialized in the UI).
- `snapshot_inspector_dependency.gd`: unchanged pinned public
  Draft PR #13 inspector.
- Future-only `verify_browser_model.gd`,
  `verify_browser_ui.gd`, `verify_report_presenter_005.gd`.
- `README.md`, `DESIGN.md`, `SAFETY.md`,
  `ACCEPTANCE.md`, `INTEGRATION.md`.

**Self-contained launch is a future option, not an instruction to execute now**.
At a later authorized review, from the repository root:

```sh
godot --path candidates/game_web_flow_state_004_r1
```

The project main scene is already set. No changes to repository `main`
or to any other candidate's Godot project are required to view this
standalone prototype.

### Important `user://` containment limitation

Godot's `user://` resolves relative to the **current Godot project**.
The separate browser's own `user://` is not necessarily the main game's
user directory. The inspector intentionally accepts only `user://`,
fixed mode-specific filenames, and manually specified directories.
Consequently **this standalone build does not directly enumerate or
open another game's existing save directory**. It may report missing
even when the main game has saves elsewhere.

For later safe demonstration, an authorized operator can prepare
**synthetic or explicitly approved non-private copies** in the
standalone project's `user://` directory. This module neither imports
those files nor copies them or offers a folder picker. Any cross-project
read capability would require a separately reviewed capability with
explicit consent, path security and privacy assessment. Do not bypass
this by opening arbitrary absolute filesystem paths.

## Possible later embedding into a Godot project (NOT DONE)

Only after author and engineering approval:

1. Review exact upstream blob `89369cb3f6b7f80a508a608865a80a79c3855032`,
   branch HEAD, Godot version and privacy constraints.
2. Copy the **isolated candidate module** into a distinct project
   subdirectory, without altering the game save core.
3. Because the scripts currently use
   `preload("res://snapshot_browser_model_candidate.gd")`,
   `preload("res://snapshot_report_presenter_candidate.gd")`,
   `preload("res://snapshot_inspector_dependency.gd")`, and
   the scene's `res://snapshot_browser_candidate.gd`,
   adjust all those resource paths to the new subdirectory.
   This is a **future proposed edit**, not already delivered/tested.
4. Instantiate `snapshot_browser.tscn` as a separate utility view
   (or tool-only scene) **without autoloads, runtime signals, data
   mutation hooks or save writers**. A direct integration must not
   rely on or modify unrelated PR #6/#13 candidate semantics.
5. Keep explicit `story` / `free` selection and `user://` lexical
   path constraints; never default to active production saves or
   automatically scan them.
6. Verify status codes, missing file, corrupted file and best-effort
   consistency guards on **approved copies only**. Do not screenshot
   paths/private data or export raw diagnostic dictionaries.
7. Require a separate author sign-off and code review before treating
   any UI action as a supported product interface.

A same-directory import in the *main* game's project changes the meaning
of `user://`; merely embedding a UI does not authorize reading real saves.
There is intentionally no integration with Python saves, events, history
chapter clocks or runtime state.

## Exposed proposal model contract

These four methods are local to this candidate, not shared APIs:

| Method | Result | Side effects |
|---|---|---|
| `inspect_folder(folder, mode)` | Sanitized format + version reports, non-atomic read marker | Reads fixed file only |
| `compare_folders(left, right, mode)` | Redacted v1/v1 differences, unknown-version block, consistency metadata | Reads two fixed files only |
| `preview_without_target(folder, mode)` | Known-v1 no-migration status or missing-mapping/block | Read only |
| `preview_candidate(folder, mode, phase, door_open)` | Ephemeral v1 hypothetical field names and review-only status | Read only, no save |

The report presenter formats allowlisted status/error/field names into
readable Chinese strings. It neither logs nor serializes raw input.
The UI is intentionally **unable** to propose edits to version, mode,
round ID or clock. No action applies a diff.

## Future verification and handoff

See `ACCEPTANCE.md` for commands, synthetic fixture boundaries,
manual layout and privacy checks and NOT_RUN evidence template.
Record exact commit, Godot 4.7.2 actual version, platform,
per-suite exit codes and redacted logs. Keep the PR as Draft until
the author gives final acceptance.

**Missing authoritative data:** approved old-version schemas,
migration rules, timeline and save-core integration contracts,
cross-project safe read policy. Treat all as unavailable; do not
infer defaults, promote candidate to Canon or implement conversion.

---

## STATE-006 r1 integration delta (not performed)

The module remains a standalone, optional Godot project.
`snapshot_browser_model_candidate.gd` now loads
`snapshot_diagnostics_candidate.gd` (additional relative
`res://` dependency). A future approved embedding must copy that
file **alongside** the pre-existing browser/model/presenter/pinned
inspector and adjust all `res://` references consistently.

Only the view may format human-readable issue messages; it must keep
using the presenter allowlist. The diagnostics instance is pure and
may not call the game's save core or request a writer.
The new `diagnostics` dictionary is **module-local candidate
presentation metadata**, not an approved external interface.

For future integration validation: compare A and B within the same
selected story/free mode, examine `no_payload_to_verify` and
`source_unstable`, assert that A=B reports the same-source
warning and that unknown schemas cannot show v1 field differences.

No embedding was done; nothing changed in `main`, PR #13,
live story chronology or save semantics. **NOT_RUN.**
