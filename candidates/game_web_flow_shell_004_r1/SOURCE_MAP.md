# Source provenance, interfaces and missing dependencies

All sources below were fetched from **actual GitHub source files**, not inferred
from PR titles. This file records a public technical copy, not an approval of
its semantics or working compatibility.

| Origin | Exact source commit | Copied modules | Actual callable interface used |
|---|---|---|---|
| [PR #17](https://github.com/cao772/game/pull/17) | `5ed0602cfb7498900dee13936194bac69d7c9737` | shell scene/controller, registry, synthetic adapter, original future verifier, project baseline | `page_changed`, `assembly_changed`, `show_page`, `module_status`, `current_page` |
| [PR #10](https://github.com/cao772/game/pull/10) | `964876d33e7e5406648b6826e309dae974cc86eb` | `interaction_prompt_candidate.gd/.tscn` | `show_for_targets(Array,int)`, `hide_prompt()`, `interaction_requested(target_id)`; candidate adds focus/Escape handling |
| [PR #14](https://github.com/cao772/game/pull/14) | `ce88e48c2056c887232b98ebf73f4d61ab58ace2` | profile panel .gd/.tscn + required contract/layout/scroll scripts | `set_profile(Dictionary)`, `clear_profile()`, `profile_copy()`, `last_error()` |
| [PR #15](https://github.com/cao772/game/pull/15) | `a510986faf3c3ee0557196194d5f74f16e02de89` | input bindings and settings controller scripts | `current_profile()`, `key_display(int)`, `preview_rebind(StringName,Variant)`, `rebind`, `restore_defaults` |

All PRs were still Draft at source review. PR #15 targets the PR #6 branch,
not `main`. PR #17's original shell contains a **metadata-only** dependency
rule that staging #15 requires #6 to be staged; this shell preserves that
status display and never treats it as actual compatibility.

## Local copy alterations (only in new branch)

- Original PR #17 `project.godot`: project name and main_scene changed to
  `flow_entry.tscn`. All its other copied .gd/.tscn content unchanged.
- PR #10 prompt scene's `res://interaction_prompt_candidate.gd` changed to
  `res://vendor/prompt/interaction_prompt_candidate.gd`; prompt script unchanged.
- PR #14 profile scene's two script paths and profile panel's two helper
  preloads rewritten to `res://vendor/profile/`; other source unchanged.
- PR #15 settings facade's preload path rewritten to
  `res://vendor/input/input_bindings_candidate.gd`; settings and bindings
  semantics unchanged.
- No changes to the origin PR branches or existing files under their
  `candidates/game_web_module_*\` directories.

## Known missing components / conservative handling

1. PR #6's game input and round-state persistence coordinator: **not copied**.
   Keyboard binding values cannot dispatch any round action.
2. PR #15's optional keyboard router: **not copied**; it expects PR #6's
   `InputRouterCandidate` child and `request_button_action` contract.
3. PR #10 prompt Escape/focus ownership alongside #15 keyboard routing:
   not agreed; no global keyboard integration attempted.
4. Real interaction targets, character profiles and scene host: not provided;
   only synthetic labels and schema-complete fields are constructed.
5. Godot exact minor/platform, accessibility, native UI and runtime
   interoperability: unverified, **NOT_RUN**.

As a consequence, the result is an isolated **source integration candidate**,
NOT a claim that the upstream PRs are merged, approved or fully compatible.
All future acceptance cases remain NOT_RUN until individually executed.
