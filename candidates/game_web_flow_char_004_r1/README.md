# GAME-WEB-FLOW-CHAR-004 r1 — synthetic list/detail/back Godot component

**Standalone technical candidate. Draft only. Status: NOT_RUN.**

This Godot 4 project supplies a complete independent character-information
list/detail flow **without any real character or narrative setting**. It
includes byte-identical public technical dependencies from Draft PR #14,
so the self-contained demo does not need another unmerged PR checked out.

## Contents

- \`profile_flow_candidate.tscn\` + \`profile_flow_candidate.gd\`: embeddable
  list/detail Control with search, back, exit-request, responsive presentation.
- \`profile_flow_model_candidate.gd\`: strict list validation, indexing,
  filtering, copies, route transitions and bounded source replacement.
- \`flow_demo.tscn\` + \`flow_demo_candidate.gd\`: synthetic stand-alone demo
  that shows an exit notice rather than changing any game application.
- \`shell_profile_adapter_candidate.gd\`: separate #17-compatible
  **simulation-only** metadata adapter (not a real shell UI mount).
- \`verify_profile_flow_candidate.gd\`: future-only headless assertions.
- \`DESIGN.md\`: architecture and decisions; \`SHELL_HANDOFF.md\`: shell limits.
- \`ACCEPTANCE.md\`: evidence and future acceptance matrix.
- \`project.godot\`: Godot 4 candidate project.
- Nine byte-identical PR #14 presentation/schema/fixture files:
  \`character_profile_panel.gd\`, \`character_profile_panel.tscn\`,
  \`profile_contract_candidate.gd\`, \`profile_scroll_navigation.gd\`,
  \`profile_text_layout_candidate.gd\`, \`preview_panel_resource_candidate.gd\`,
  \`placeholder_fixture_loader_candidate.gd\`, \`placeholder_profiles.json\`,
  \`data_contract.schema.json\`.

No source in PR #14, PR #17, any other candidate folder, or main was edited.

## Unapproved candidate API

Create a \`profile_flow_candidate.tscn\` instance in a Control host.
The root's local methods are:

- \`set_profiles(array_of_profiles) -> bool\`: validates all records against
  the byte-identical #14 profile schema; rejects duplicates/invalid batch
  without replacing existing data. Clears selection/search on success.
- \`load_placeholder_profiles() -> bool\`: loads only the fixed synthetic
  \`res://placeholder_profiles.json\` file. No arbitrary path selection.
- \`open_profile(profile_id) -> bool\`: opens only a known, currently
  filter-visible record; otherwise returns false.
- \`go_back() -> bool\`: detail to list; false for already on list.
- \`route_copy()\`, \`current_profile_copy()\`, \`visible_rows_copy()\`:
  in-memory read-only snapshots, including defensive copies.
- \`route_changed(route_name, profile_id)\`, \`exit_requested\`,
  \`collection_replaced(count)\`, \`collection_rejected(reason)\` signals.

All are **candidate-local**, not official shared interfaces. The
\`exit_requested\` signal is informational: no shell route, scene tree,
InputMap, save file or external window is changed by the module.

## Suggested future local start (NOT executed during development)

Use Godot 4.x. Open the project folder and run \`flow_demo.tscn\` as the
main scene. It calls the fixed synthetic fixture loader, shows a list,
detail and Back/Exit controls. There is no real character content.

For **future verifier use only**, from the repository root:

    godot --headless --path candidates/game_web_flow_char_004_r1 --script res://verify_profile_flow_candidate.gd

The expected success banner in source code is **not** evidence of passing.
No Godot binary, script, scene, automated test, UI, or benchmark has run in
this submission. Record exact Godot version, commit SHA and console/exit
code when separate independent verification is eventually authorized.

## Shell relation

PR #17's independent shell exposes an in-memory mock adapter seam for
slot \`profile\`, not a live Control host. This module supplies a corresponding
synthetic-only \`shell_profile_adapter_candidate.gd\` and an embeddable
Control scene, but **does not install either into PR #17**. See
\`SHELL_HANDOFF.md\` for explicit boundaries and potential later wiring.

## Change restrictions

- Branch based on main's README-only baseline; changes are entirely
  additive within \`candidates/game_web_flow_char_004_r1/\`.
- Do not merge main or other Drafts without final owner review.
- No private story/manuscript or raw chat evidence committed.
- No canonical character facts, assets, relationships or gameplay behavior.
- Exact Godot version, native focus arbitration, shell UI slot, theme and
  accessibility goals remain unresolved, not invented.

Task: GAME-WEB-FLOW-CHAR-004 r1.
Delivery: SOURCE_SUBMITTED. Verification: **NOT_RUN**.
