# GAME-WEB-MODULE-CHAR-001 r1 — standalone character-information panel

**DRAFT TECHNICAL CANDIDATE / NOT_RUN / NOT CANON / NO APPROVED SHARED API**

An independent Godot 4.x presentation component using only synthetic,
injectable placeholders. No real character name, appearance, relationships,
abilities, plot, portrait, manuscript text, or canon is included.

## Existing source inspected before this implementation

- Repository: cao772/game, main at 533b11f50c0d359cd0a5424d5216b0145727699a (README-only baseline).
- Draft PR #6 at f5143fb72db6083cab6364b8caa5daf7d6995dc2:
  inspected independent project.godot, input_router_candidate.gd,
  round_snapshot_candidate.gd, integration_candidate.gd and verifier.
- The existing PR's INPUT/STATE action and persistence APIs are NOT approved
  shared dependencies. This panel does not import or modify them.
- Only new files under this candidate folder are proposed.

## Complete file list

- character_profile_panel.tscn — embeddable Control scene with a scrollable
  information area, labels, tag chips and empty state.
- character_profile_panel.gd — input injection, render, clear, signals,
  deep-copy isolation and literal-text display.
- profile_contract_candidate.gd — strict schema/identifier/text validation.
- data_contract.schema.json — JSON Schema Draft 2020-12 candidate.
- placeholder_profiles.json — two synthetic sample records, nothing private.
- preview_candidate.tscn — a standalone interactive preview shell.
- preview_candidate.gd — fixture selection and clear action for preview only.
- verify_character_panel_candidate.gd — future headless acceptance source.
- ACCEPTANCE.md — case-by-case acceptance and evidence requirements.
- project.godot — standalone Godot 4 project (GL compatibility renderer).

## Proposed injection contract — explicitly NOT a shared interface

1. Instantiate character_profile_panel.tscn inside a Control-based scene.
2. Pass a Dictionary to set_profile(input). Returns true when valid and false
   on invalid input; validation is always repeated by the module.
3. Accepted profiles are deep-copied into local memory. They render
   immediately after ready, or on ready if injected beforehand.
   profile_accepted(profile_id) is emitted on acceptance.
4. Rejected profiles leave the prior valid data and visible UI in place.
   profile_rejected(reason) is emitted; last_error() returns that reason.
5. profile_copy() returns a deep copy. clear_profile() clears in-memory
   display data, restores the empty state and emits profile_cleared.
6. The panel does not write files, change save or story state, register
   an InputMap action, make network calls or load outside resources.

All injected strings are rendered through plain Godot Labels, not
RichTextLabels. Markup-looking text is displayed literally rather than
interpreted or evaluated. Tags and sections are dynamically recreated when
profile data changes, removing stale nodes. Scroll is reset on replacement.

### Required fields and limits

- schema_version: numeric 1 (JSON floating-point 1.0 also accepted).
- profile_id: ASCII letter/digit initial character followed by ASCII
  letters/digits/underscore/hyphen, 1–64 characters.
- display_name: required nonblank 1–80 Unicode characters.
- subtitle: string, 0–120 characters; summary: 0–1200; status_label: 0–40.
- tags: 0–8 unique nonblank strings of at most 24 characters each.
- sections: 0–8, each having a unique ASCII section_id, nonblank heading
  of at most 80 characters, and 0–12 items.
- each item: nonblank label <=50 characters and value <=600 characters.
- Unknown fields are rejected at all levels; null characters are rejected.

The Godot validator rejects duplicate section identifiers and null text.
Those constraints are more stringent than what is represented by the
accompanying JSON Schema. Neither is a validated shared contract yet.

## Future-only usage / verification — no execution performed

Open candidates/game_web_module_char_001_r1/project.godot in an appropriate
Godot 4.x editor and run its preview_candidate.tscn main scene. The preview
only loads local synthetic placeholder_profiles.json.

An independent reviewer may later run the finite headless suite from the
repo root:

    godot --headless --path candidates/game_web_module_char_001_r1 --script res://verify_character_panel_candidate.gd

Only an actual completed run with zero exit code and matching assertion
output could establish a local test PASS. This authoring window has
performed **NO Godot execution, tests, CI, native GUI acceptance, benchmark,
compile, installation or runtime verification**.

Desktop reviewers should separately check 960x680 and narrow screens,
scrollbars, Chinese/Latin wrapping, preview switching, keyboard focus,
legibility and error console. A headless source suite alone cannot certify
visual quality, accessibility or performance.

## Boundaries and unresolved inputs

- Godot exact target minor, supported desktop/mobile targets: not provided.
- Approved visual theme, typography, accessibility baseline: not provided.
- Actual character-data adapter / content approval: not provided.
- Portrait/asset policy, navigation and save integration: not approved.
- This candidate defines no canonical character, lore, world logic or
  persistence. No manuscript, private material or raw chat was uploaded.
- No changes to main, other Draft PRs, Notion, Drive, or shared APIs.
- Owner/Codex review and a separately recorded test run are required
  before any merge or product-level integration.

Task GAME-WEB-MODULE-CHAR-001; version r1; status SOURCE_SUBMITTED / NOT_RUN.


---

## Incremental follow-up: GAME-WEB-MODULE-CHAR-002 r1 (NOT_RUN)

The same Draft PR #14 branch now includes a **002 r1** incremental candidate:
keyboard-only focus-scoped scrolling, guarded accessibility metadata, visible
keyboard hints, full-content vertical scroll layout, compact breakpoint,
bounded atomic placeholder parsing, and explicit preview status/reload behavior.
See [MODULE_CHAR_002_DESIGN.md](MODULE_CHAR_002_DESIGN.md) for the complete
source inventory, exact policies, 480px layout breakpoint and limitations.

Additional proposed source files:
- \`profile_scroll_navigation.gd\` — scroll input handler only while focused.
- \`placeholder_fixture_loader_candidate.gd\` — pure, bounded, atomic parser.
- \`verify_character_accessibility_candidate.gd\` — additional future tests.
- \`MODULE_CHAR_002_DESIGN.md\` — implementation decisions and acceptance plan.

The existing r1 verifier was updated only to reflect moved scene-node paths,
since all displayed data (including long summaries) now lives under
\`Layout/Scroll/Content/\`. Fixture schema fields are unchanged and no
external/shared interface has been approved. Runtime assistive properties are
conditionally applied when supported by the installed Godot version; screen
reader support is **not asserted**.

Future independent verification (not run in this submission):

    godot --headless --path candidates/game_web_module_char_001_r1 --script res://verify_character_panel_candidate.gd
    godot --headless --path candidates/game_web_module_char_001_r1 --script res://verify_character_accessibility_candidate.gd

**002 status: SOURCE_SUBMITTED / NOT_RUN.** No source execution, Godot
launch, tests, CI runs or manual UI verification requested or claimed.
