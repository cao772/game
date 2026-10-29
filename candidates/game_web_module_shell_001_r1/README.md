# GAME-WEB-MODULE-SHELL-001 r1 — standalone Godot shell candidate

**DRAFT / NOT_RUN / SYNTHETIC ONLY / NOT CANON / NO APPROVED SHARED API**

This is an entirely separate Godot 4 candidate project, intended as a menu/navigation
entrance for technical demonstration. No scripts, tests, editor, GUI or builds have
been executed by this development window.

## Layout and contents

- `project.godot`: standalone root project; no autoloads and no InputMap override.
- `shell_demo.tscn`: self-contained Control scene with dark placeholder menu,
  overview, round, prompt, profile, input pages, mock-request button and status.
- `shell_candidate.gd`: navigation and private adapter registry with missing/failure
  fallback; never instantiates another PR component or calls a save API.
- `placeholder_adapter_candidate.gd`: four synthetic `preview()` providers.
- `verify_shell_candidate.gd`: authored **future-only** finite test source,
  never invoked in this submission.
- `SOURCE_REVIEW.md`: inspected exact upstream Draft source and missing decisions.
- `DESIGN.md`: private injection seam, navigation, UX and safety boundaries.
- `ACCEPTANCE.md`: future automated/manual cases, each NOT_RUN.

## Navigation

`概览 → 回合候选 / 交互提示 / 角色信息占位 / 输入配置占位`.
Every slot starts with a **local synthetic adapter**. Selecting a page only renders
static text. The button labelled "发送模拟请求" invokes only the corresponding
synthetic adapter's `preview_action("sample_request")` method.
It does not dispatch game input, update round state, or write files.

`install_adapter(slot, adapter)`, `remove_adapter(slot)`,
`has_adapter(slot)`, `show_page(page_id)`, `current_page()` are **new,
private proposals**, NOT actual #6/#10/#14/#15 APIs. They accept shell-local
RefCounted adapters exposing `preview() -> Dictionary` and
`preview_action(request_id) -> Dictionary`. See DESIGN.md.

## Author boundary

- All changes are additive under this folder only, branched from `main`.
- No changes to `main`, other candidates, existing components or shared interfaces.
- No manuscript, actual character, narrative text, character identity, assets,
  production configuration, private evidence or hidden content.
- No direct import, copy, preload, inheritance or invocation of other PR code.
- No file I/O, network, actual game action, save/state mutation or global InputMap.
- No automatic key listener in this shell; native Button keyboard focus remains
  subject to future manual review.
- UI and screenshots, real input, focus, pause, compatibility, CI and performance
  remain **NOT_RUN**. A source commit is not proof of working Godot behavior.
- Never merge to main, approve shared interfaces or assume canon approval.

## Future-only commands (DO NOT RUN under this r1 instruction)

From an authorized reviewer environment with a compatible Godot 4 executable:

```sh
godot --headless --path candidates/game_web_module_shell_001_r1 --script res://verify_shell_candidate.gd
```

For visual checks, open `candidates/game_web_module_shell_001_r1/project.godot`
in the Godot editor and launch its `shell_demo.tscn` main scene. These are
instructions for future review, **not** run evidence.

**Task:** GAME-WEB-MODULE-SHELL-001
**Version:** r1
**Input references:** Draft PR #6, #10, #14, #15, all unapproved
**Deliverable:** standalone code + source review + design + future acceptance
**Verification:** NOT_RUN by author instruction
**Notion/Drive:** not written; GitHub candidate branch/PR only
**Open issues:** upstream approval, UI integration, input arbitration,
exact engine version, accessibility, persistence ownership, review evidence.
