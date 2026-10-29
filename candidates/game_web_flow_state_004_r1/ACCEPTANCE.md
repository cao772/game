# GAME-WEB-FLOW-STATE-004 r1 — Future acceptance (NOT_RUN)

**Everything below is a proposed test plan. No Godot execution, test run,
parse/compile check, CI result, screenshot or QA acceptance happened in
this authoring task. Status: NOT_RUN / NOT_VERIFIED.**

## Safe future procedures (Codex / author-authorized only)

The tests are **NOT RUN NOW**. After author authorization, Codex may run
the following from the repository root, using Godot 4.7.2 (check the actual
installed binary and record it, never assume):

```sh
godot --headless --path candidates/game_web_flow_state_004_r1 \
  --script res://verify_browser_model.gd
echo "model_exit=$?"

godot --headless --path candidates/game_web_flow_state_004_r1 \
  --script res://verify_browser_ui.gd
echo "ui_exit=$?"
```

For a later **manual** UI check only:

```sh
godot --path candidates/game_web_flow_state_004_r1
```

Only synthetic disposable fixtures are permitted. Tests create a fresh
per-run `user://w_flow_state_004_* / user://w_flow_state_ui_004_*`
test directory and record their own files before writing; cleanup is
limited to files and dirs they created. No other save path may be
removed, overwritten, exported, or opened by tests.

A successful future test must return **0** for both commands; any assertion
or cleanup failure must return **nonzero**. Output alone is not evidence
without recorded exit code, exact commit, Godot version and platform.

## Model tests: verify_browser_model.gd (M01–M34)

| IDs | Expected future assertion |
|---|---|
| M01–M06 | Invalid/unsafe/missing folder, traversal, wrong mode or missing second folder rejected before reading |
| M07–M08 | Missing file leads to safe blocked preview; sanitization preserves privacy |
| M09–M13 | v1 story inspection and version-relative report are distinct, redacted and explicitly non-atomic |
| M14–M15 | free and story mode isolation; free missing never falls back to story |
| M16–M19 | v1/v1 comparison only: two allowlisted changed fields, never before/after values, no migration approval |
| M20–M21 | no-target v1 preview is no migration needed, sanitized |
| M22–M25 | hypothetical phase / door_open changed fields shown only as review-only, no writes |
| M26–M27 | wrong phase / non-boolean target door explicitly rejected |
| M28–M31 | unknown numeric versions, malformed JSON, opposite mode and unknown-schema comparisons fail closed |
| M32–M34 | source file bytes unchanged; no temporary save file generated |

## UI SceneTree smoke cases: verify_browser_ui.gd (U01–U22)

| IDs | Expected future assertion |
|---|---|
| U01–U06 | UI builds folder controls, mode selector, three tabs, allowed phase controls, and starts without scanning |
| U07–U09 | Inspect control shows safe format report, redacted, chooses correct tab |
| U10–U12 | Compare control shows v1-v1 result, redacted, chooses correct tab |
| U13–U15 | No-target preview is safe and no migration needed for v1 |
| U16–U18 | Hypothetical phase preview is review-only, not applicable, and private values are absent |
| U19–U20 | Switching to free clears stale story reports and missing free never falls back to story |
| U21–U22 | Original bytes stay identical and no temp snapshot write occurs |

## Additional manual acceptance cases (not automated)

1. **One directory missing**: inspecting an absent or unreadable snapshot
   shows safe status/error codes; no exception, fallback, file creation or
   unexpected initial scan.
2. **Mode switch after comparison**: previously displayed story/free
   reports are cleared; new results require explicit click.
3. **Unknown version**: numeric version other than 1 is classified
   unsupported. Preview must say mapping required, not "convert now".
4. **Corrupt JSON**: safe fixed error code only; no parser text or user
   file contents visible; no preview applies.
5. **Sensitive test marker**: no round ID, raw JSON, hash, path or before/after
   value appears in result panel, stdout, clipboard or any public report.
   Manually typed path is visible only in the local input itself.
6. **Read-only behavior**: no UI element calls file WRITE, rename, remove,
   restore, backup, export, OS execution, network fetch or migration.
7. **Screen layout**: at 1200×760 and one smaller window, controls,
   report tabs, validation labels and text wrapping remain readable;
   keyboard navigation and text entry work. These were **not tested**.
8. **Corrupted output / permissions / symlink**: compare platform-specific
   behavior on approved **disposable** test directories. A lexical
   path check is not proven symlink-safe.
9. **Concurrent modification**: document best-effort
   `SOURCE_CHANGED_OR_UNREADABLE` behavior and possible races between
   multiple reads. No atomic read, lock, crash transaction or stale-data
   guarantee may be claimed.
10. **Pinned dependency drift**: verify PR #13 inspector blob
    `89369cb3f6b7f80a508a608865a80a79c3855032` is exactly copied.
    If upstream changes, re-review instead of automatically merging.
11. **No private data**: public PR must contain synthetic fixture names
    and source code only, never manuscript text, raw conversation evidence
    or production saves.
12. **No shared interface approval**: all functions remain isolated
    proposals until independent technical and author review.

## Acceptance outcome record (template only)

```json
{
  "task_id": "GAME-WEB-FLOW-STATE-004",
  "version": "r1",
  "scope": "W-FLOW-STATE",
  "canon": "N/A",
  "repository": "cao772/game",
  "branch": "codex/game-web-flow-state-004-r1",
  "commit": "TO_RECORD_AFTER_GITHUB_SUBMISSION",
  "upstream_pr": 13,
  "upstream_inspector_blob": "89369cb3f6b7f80a508a608865a80a79c3855032",
  "godot_version": "NOT_RUN",
  "platform": "NOT_RUN",
  "model_suite": {"status": "NOT_RUN", "exit_code": null},
  "ui_suite": {"status": "NOT_RUN", "exit_code": null},
  "manual_ui_review": "NOT_RUN",
  "source_byte_integrity": "NOT_VERIFIED",
  "privacy_review": "NOT_VERIFIED",
  "legacy_migration_mapping": "NOT_PROVIDED",
  "shared_api_approval": "NOT_APPROVED",
  "main_merged": false,
  "notion": "NOT_DONE",
  "drive": "NOT_DONE",
  "status": "NOT_RUN"
}
```

**Do not replace NOT_RUN with PASS merely because source was submitted
or this test script contains expected labels. Final acceptance belongs
to the author after actual Codex evidence review.**
