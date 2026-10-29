# GAME-WEB-MODULE-CHAR-002 r1 — incremental candidate design

**Status: SOURCE_SUBMITTED / NOT_RUN.** This document describes new code and proposed checks, **not** observed engine behavior. No shared UI/data API is approved.

## Baseline and narrow change boundary

Read Draft PR #14 at its 001 r1 HEAD \`5075c422a3705bd026adbd048fc27489499e8873\`, including the panel scene/script, schema validator, preview scene/script, placeholders, both READMEs and future headless harness. Keep the same PR branch \`codex/game-web-module-char-001-r1\`; do not modify other candidates or \`main\`.

Modified within the PR #14 candidate folder:

- \`character_profile_panel.tscn\`, \`character_profile_panel.gd\`: reflow content into one scroll container, unobstructed full-summary access and conditional engine accessibility metadata.
- \`preview_candidate.tscn\`, \`preview_candidate.gd\`: small-width toolbar, disabled controls on errors, explicit reload, status feedback and keyboard focus routing.
- \`verify_character_panel_candidate.gd\`: existing r1 test source only updated for the new scene-node paths.
- \`README.md\`, \`ACCEPTANCE.md\`: r2 design and future acceptance references.

New files within the same directory:

- \`profile_scroll_navigation.gd\`: isolated, focus-scoped keyboard reading commands.
- \`placeholder_fixture_loader_candidate.gd\`: atomic, bounded, pure fixture parser.
- \`verify_character_accessibility_candidate.gd\`: additional future-only headless cases.
- \`MODULE_CHAR_002_DESIGN.md\`: this specification.

No published role, character, plot, private input, avatar or new data schema fields.

## Accessibility design (candidate only)

- Every core text field uses \`Label\`: do not parse BBCode or evaluate markup. Text comes only from validated, deep-copied injected objects.
- Section headings, item labels/values and preview controls have semantic, human-readable names/descriptions when the installed Godot exposes \`accessibility_name\` / \`accessibility_description\`.
- The capability is guarded by runtime property inspection for engine-minor compatibility. Tooltips and visible titles provide fallback discoverability but are **not** equivalent to full screen-reader functionality.
- The preview status label attempts a polite \`accessibility_live\` hint on engines that expose this field; availability and actual narration require assistive-technology testing.
- A permanent, wrapped keyboard hint is visible below a populated panel. The scroll itself is focusable; the preview has standard focusable select/clear/reload controls.
- Dark surface and contrasting light body text are proposed visual styling, not measured/approved WCAG ratios. No custom or private fonts are included.
- No animations, flashing UI, forced focus changes, automatic audio, or external assistive middleware.

## Keyboard navigation

- Preview default tab flow: select -> clear -> reload -> scroll reading surface.
- Select uses native \`OptionButton\` semantics (arrow navigation and activation); clear/reload are native Buttons.
- The scroll itself consumes only key presses with focus and no Ctrl/Alt/Meta:
  Up / Down = 64 px, PageUp / PageDown = 80% of viewport height (minimum 64 px), Home / End = scroll boundaries.
- Key release, repeat/echo and unrelated or modified keys are ignored by the custom scroll handler. No globally hooked key listeners or InputMap changes.
- Only the reading region owns scroll keys; there is no game input routing, event synthesis, time change or save.
- Focusing a hidden/empty reading region is not forced; the preview status remains visible.

## Responsive layout

- Profile scene min width/height are no longer forced to 320x240. It is suitable for injection into a constrained Control layout.
- **One vertical scroll area contains the entire header, long summary, tags and sections.** The title cannot occupy non-scrollable space that prevents reaching section content.
- Horizontal scrolling is disabled; text uses Godot word-smart autowrap and expanding layout containers. Section cards use size flags and nested VBoxContainers.
- At widths below **480 px**, outer margins switch from 20 to 10 and card inner margins from 16 to 9. The preview outer margins switch from 18 to 8 and toolbar gaps from 10 to 5.
- The preview caption is a separate wrapped line, leaving space for the choice/clear/reload controls. Manual inspection at 320x240 and unusual text/font scales is still required.
- Because the precise project theme and target font are unknown, appearance/focus contrast and mixed-language glyph coverage are **NOT VERIFIED**.

## Placeholder failure handling

Only the optional standalone preview reads \`res://placeholder_profiles.json\`; the reusable panel never reads a fixture. The pure parser accepts a JSON string, with a 64 KiB UTF-8 byte limit and a maximum 12 records, rejects empty/non-array roots and malformed JSON, and validates every record against the existing 001 contract without changing it.

- All records must have unique \`profile_id\`; a duplicate or any invalid later record invalidates the *whole batch*, returning no partial profiles.
- An explicit reload first clears current profile and picker options, disables selection/clear and attempts a new read. Missing/unreadable file and oversize/invalid JSON produce a visible, generic status; no exception data or private contents are shown.
- A successful validated load adds options, enables selection and displays the first synthetic profile; an invalid index does not change the current profile.
- The panel still rejects bad injection **without mutating** its last accepted profile and emits \`profile_rejected\`; in a fresh preview import, the old batch is deliberately cleared before an attempted reload.
- File length checked before reading; post-read byte bound checked by the pure parser. No network/download, untrusted path selection, private imports or user-file upload.
- The parser's limits and labels are local, provisional UI choices and **not** changes to a shared data contract.

## Future acceptance (DO NOT RUN in this task)

1. Independent verifier executes prior r1 harness (node paths updated) and 002 harness; record exit codes, exact commit, logs, Godot version and failures, not just the expected PASS banner.
2. 002 harness covers invalid fixture types/sizes/JSON, duplicate identities, atomic rejection, valid two-profile load, focus flags and reading region location, explicit clear/reload.
3. Manual keyboard checks: Tab and Shift+Tab, OptionButton arrow/Enter, Button Enter/Space, scroll Up/Down/PageUp/PageDown/Home/End, focus-border visibility, modifier/repeat handling, no game commands.
4. Manual responsive checks at 320x240, 480x320, 960x680 and high scaling; long title/summary/tags/sections, single vertical scrollbar, no clipped overlays.
5. Native screen-reader/assistive checks on explicitly reported target Godot minor and OS must be done separately; source capability is not a certificate of accessibility.
6. Fixture malformed/unavailable/duplicate/oversize scenarios should use isolated local test fixtures in a verifier environment, never private story data.

Run commands (for a future verifier, **NOT executed in this submission**):

    godot --headless --path candidates/game_web_module_char_001_r1 --script res://verify_character_panel_candidate.gd
    godot --headless --path candidates/game_web_module_char_001_r1 --script res://verify_character_accessibility_candidate.gd

**Every automated/manual case remains NOT_RUN.** CI is not triggered intentionally by this task. Any externally triggered GitHub checks are independent and cannot be represented as locally executed tests.

## Unresolved owner inputs

Exact target Godot 4.x minor, OS/screen-reader matrix, game-wide theme/typography, focus policy with the surrounding UI, validated font set, screenshot acceptance thresholds and any eventual official data adapter. No canonical character data or integration is assumed.
