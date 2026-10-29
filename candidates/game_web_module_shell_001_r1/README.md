# Standalone Godot shell — GAME-WEB-CONTINUE-SHELL-003 r1

**DRAFT / NOT_RUN / SYNTHETIC ONLY / NOT CANON / NO APPROVED SHARED API**

This continuation updates Draft PR #17 on its existing `codex/game-web-module-shell-001-r1`
branch. It extends, rather than overwrites, the r1 standalone Godot candidate.
No scripts, editor, build, CI, parser, headless test, native GUI or performance
checks were executed as part of this request.

## Complete standalone source

| File | Actual responsibility |
|---|---|
| `project.godot` | Original independent Godot 4 project; no autoload/global InputMap |
| `shell_demo.tscn` | Existing dark shell extended with module assembly menu, selectable slot/mode controls, manual refresh and back button |
| `shell_candidate.gd` | Page switching, bounded history, UI updates, registry routing, assembly operations and guarded simulation dispatch |
| `module_registry_candidate.gd` | NEW: in-memory module slot model, mount/unmount, disable, stage metadata-only candidate, status/dependency evaluation, preview validation and fail-closed simulation |
| `placeholder_adapter_candidate.gd` | Existing four synthetic demo adapters, unchanged |
| `verify_shell_candidate.gd` | Future-only finite test suite: 12 original smoke categories plus 29 continuation categories; NOT_RUN |
| `README.md` | This usage/behavior summary |
| `DESIGN.md` | Architecture, method contracts, design decisions and limitations |
| `SOURCE_REVIEW.md` | Pinned upstream technical source and cross-PR uncertainties |
| `ACCEPTANCE.md` | Detailed future cases and required execution evidence |

All files remain under `candidates/game_web_module_shell_001_r1/`. No existing
module under another candidate folder was changed or copied. Public code
contains no original manuscript, story, real character, private data or assets.

## Standalone demonstration and menu

Overview → Round / Prompt / Profile / Input / Module Assembly → Back.
A page is always navigable even when its module is missing. The module page
provides **four local-only assembly modes** per slot:

1. **Restore synthetic:** constructs one shell-local placeholder adapter.
2. **Missing:** removes the adapter and displays a fallback explanation.
3. **Disabled:** no adapter execution; module view remains navigable.
4. **Stage candidate:** records the corresponding PR number **as metadata
   only**, without importing its source, loading scenes or running actions.

Module Assembly also offers **manual refresh** for a local placeholder and
**restore all synthetic**. Navigation history is capped at 24 previous pages.
Unknown navigation IDs are rejected without mutating the current page.

The four origin labels are #6 round, #10 prompt, #14 profile and #15 input.
These are **references to unapproved Draft candidates**, not a combined build.
Staged #15 displays `blocked_dependency` until #6 is also staged; then it
displays `pending_review`, NOT `connected` or `passed`. Staging has no
side effects outside this in-memory registry.

## Fail-closed statuses

| Status | Meaning | Simulated button |
|---|---|---|
| `synthetic_ready` | Only a valid local mock preview | Enabled |
| `missing` | No local adapter | Disabled |
| `disabled` | Explicitly disabled slot | Disabled |
| `degraded` | Mock preview or request contract invalid | Disabled |
| `blocked_dependency` | Staged #15 without staged #6 | Disabled |
| `pending_review` | PR metadata recorded; no executable wiring | Disabled |
| `unknown` | Invalid caller slot | Rejected |

The only accepted demo action ID is `sample_request`, and successful mock
responses must explicitly contain `simulated: true`. A game event, UI
interaction, round mutation, keyboard config or persisted save is **never**
inferred from this response. Rendered strings are simple Label text.

## Proposed local methods — not shared APIs

- `show_page(page_id) -> bool`, `go_back() -> bool`,
  `current_page() -> String`, `history_copy() -> Array[String]`.
- `assembly_snapshot() -> Array[Dictionary]`, `module_status(slot) -> Dictionary`,
  `current_view() -> Dictionary`.
- `install_adapter(slot, trusted_synthetic_adapter) -> bool`,
  `remove_adapter(slot) -> bool`, `has_adapter(slot) -> bool`.
- `stage_candidate(slot) -> bool`, `disable_module(slot) -> bool`,
  `restore_mock(slot) -> bool`, `restore_all_mocks()`.
- `request_demo(blocked_override = null) -> Dictionary` is a **test seam**:
  actual UI uses native window focus; test override can replace focus only,
  never pause, and **never** authorizes a real game action.
- Shell signals: `page_changed`, `assembly_changed`,
  `simulated_request` (last one only represents local fake acceptance).
- Registry's `mount_mock`, `refresh`, `view`, `invoke_mock` are all
  **private proposals**; not APIs taken from upstream PRs.

**Security caveat:** GDScript `RefCounted` injection does not isolate arbitrary
code. Only explicitly reviewed *synthetic local* adapters may be installed.
A hostile or real upstream adapter could have side effects even in `preview()`.
This shell intentionally performs no filesystem discovery, scene imports, network
lookups or automatic plugin loading; do not supply unapproved executable objects.

## Future verification (NOT_RUN, do not run in this development task)

```sh
godot --headless --path candidates/game_web_module_shell_001_r1 --script res://verify_shell_candidate.gd
```

Separately, a reviewer may open the isolated `project.godot` in a selected
Godot 4 minor and inspect layout, keyboard focus, viewport scaling, pause and
window-focus behavior. An authored test file is **not** test evidence.
See `ACCEPTANCE.md` for exact cases and negative checks.

## Record

- `task_id`: GAME-WEB-CONTINUE-SHELL-003
- `version`: r1
- `parent`: Draft PR #17 / GAME-WEB-MODULE-SHELL-001 r1
- `scope`: standalone shell assembly, fallback and navigation only
- `input_versions`: PR #17 head at start `0e668ef60e1355c0de2a9de75096fdd50a01183c`; upstream #6/#10/#14/#15 pinned in SOURCE_REVIEW
- `source_presence`: GitHub commits / remote read-back, **not** runtime approval
- `execution / CI / GUI / interop`: **NOT_RUN**
- `author_review`: pending
- `main`: no changes / no merge
- `Notion / Drive`: NOT_WRITTEN
