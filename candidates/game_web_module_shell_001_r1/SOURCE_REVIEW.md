# Pin-point upstream source review — informational only

All four references were **open Draft PRs** when reviewed on 2026-10-29.
Their code is real, but **unapproved and NOT_RUN** as evidence for this shell.
No assumption that any candidate is a stable game-level shared interface.

| PR | Reviewed commit | Relevant actual source | What it shows | Why the shell isolates it |
|---|---|---|---|---|
| [#6](https://github.com/cao772/game/pull/6) | `f5143fb72db6083cab6364b8caa5daf7d6995dc2` | `input_router_candidate.gd`, `integration_candidate.gd`, `round_snapshot_candidate.gd` | InputRouter emits `action_requested(StringName)`; coordinator has `request_button_action` and `dispatch_action`, writes a constrained round snapshot on candidate mutations; current focus/paused gates; local writer claim is not a process lock | Never attach to a writer or infer permission to save from menu clicks |
| [#10](https://github.com/cao772/game/pull/10) | `71f30ed6f67fab327902b51277e95dc14abed705` | `interaction_prompt_candidate.gd`, `interaction_prompt_candidate.tscn`, `docs/integration-boundaries.md` | `show_for_target`, `hide_prompt`, `interaction_requested`, prompt-managed Escape and focus restoration | Escape priority with #6 is undecided; no scene/target host API supplied |
| [#14](https://github.com/cao772/game/pull/14) | `5075c422a3705bd026adbd048fc27489499e8873` | `character_profile_panel.gd`, `profile_contract_candidate.gd`, `README.md` | Strict validated Dictionary injection by `set_profile`, clear/copy APIs, display-only panel | No approved profile producer, schema migration or screen composition contract |
| [#15](https://github.com/cao772/game/pull/15) | `c7b85464ae3b67e762329e9cab86957adc92747c` | `input_bindings_candidate.gd`, `input_binding_router_candidate.gd`, `README.md` | Local binding profile/conflict rejection, optional input adapter `attach_integration` to #6; disables old router keyboard handling during attachment | Stacked PR: #15 base is #6 draft branch, not main. Detach and conflicting keyboard/UI priority need future evidence |

## Actual branch context

- Repository: `cao772/game`; baseline `main` commit reviewed:
  `533b11f50c0d359cd0a5424d5216b0145727699a`.
- #6, #10 and #14 are independent Drafts based on main; #15 is a stacked Draft
  targeting the #6 branch. No assumption of simultaneous loadability.
- #6 snapshot schema includes `mode` and `clock_seconds` constraints, but this
  shell **never builds or saves** a snapshot; generic fake page text is not schema data.
- #10 prompt may consume Escape when its own controls hold focus; #6 routes Escape
  through its candidate input router, and #15 proposes further keyboard takeover.
  No priority contract was provided, so no direct wiring is attempted.
- #14 panel script preloads its own validation script. A host would need the
  entire component-local resource set, an accepted data contract and permission.
- #15's proposed path-based input profile writer is not called here. Menu sample
  key text is intentionally unrelated to actual `user://` configuration.

## Missing / unresolved

1. Author approval of any candidate API, action semantics or UI composition.
2. Confirmed Godot 4 minor and headless/native platform matrix.
3. Real host scene and lifecycle, keyboard/focus priority, pause and modal policy.
4. Adapter authority boundaries: which object can request a real action, who owns
   state persistence, and what explicit user action authorizes writes.
5. Approved data format and source for character, target and input settings.
6. Accessibility, scaling, localization, error/telemetry and styling requirements.
7. Tests, native screenshots, CI, performance and interop execution evidence.

**Decision for r1:** remain independent; private synthetic shell adapter only.
Never rename this interface as an existing API or claim integration occurred.

## Continuation review — GAME-WEB-CONTINUE-SHELL-003 r1

Before this continuation, the real Draft PR #17 was read from GitHub at
head `0e668ef60e1355c0de2a9de75096fdd50a01183c`, base
`main` / `533b11f50c0d359cd0a5424d5216b0145727699a`.
Its nine changed files were enumerated, and the **complete contents** of
`shell_candidate.gd`, `placeholder_adapter_candidate.gd`,
`shell_demo.tscn`, `verify_shell_candidate.gd`, `project.godot`,
`README.md`, `DESIGN.md`, `ACCEPTANCE.md` and `SOURCE_REVIEW.md`
were retrieved. No source was inferred from PR title or description.

Actual r1 methods available were `show_page`, `install_adapter`,
`remove_adapter`, `has_adapter`, `current_page`, `_adapter_preview`
and `_on_preview_pressed`. Its navigation had no history, the four
slots had no explicit assembly/dependency state, and malformed mock action
replies were not required to carry a `simulated: true` marker.
The continuation adds these functions only to this shell.

Review of the real #17 source is **source inspection**, not execution,
Godot syntax certification, CI evidence, visual acceptance or proof of
upstream PR interoperability. Its prior source remains a Draft; changes
here are restricted to its existing candidate directory.

**Chosen isolation:** no cross-branch cherry-pick, preload, feature
probing, live adaptation or API version assumptions. Source PR numbers
are metadata; executable adapters are synthetic shell-local objects only.
