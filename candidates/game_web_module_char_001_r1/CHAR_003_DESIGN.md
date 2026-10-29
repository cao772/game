# GAME-WEB-CONTINUE-CHAR-003 r1 — isolated character-data UI continuation

**SOURCE SUBMITTED • NOT_RUN • DRAFT PR #14 • no canon • no shared interface approval**

This file records the actual design choices and source scope for the third
incremental revision of the synthetic-character-information UI, building on
GAME-WEB-MODULE-CHAR-001/002. It is not a runtime or test report.

## Baseline and strictly isolated scope

- Repository: \`cao772/game\`.
- Draft PR: \`#14\`, head branch \`codex/game-web-module-char-001-r1\`.
- **Source snapshot actually read first:** \`8c55b2a25a7e7da8f194fc7976630ea4d8a90997\`.
- This increment is a child of that commit; only files in
  \`candidates/game_web_module_char_001_r1/\` may change.
- The 001 presentation-schema proposal and its JSON Schema are left unchanged.
- No other candidate/branch, main, story chapter, save system, InputMap, or
  non-public data is touched.

## Delivered source and behavior

| Source | Implemented candidate responsibility |
| --- | --- |
| \`character_profile_panel.gd\` | Existing in-memory API, full-text-safe labels, optional section chooser/jump and focus descriptions |
| \`character_profile_panel.tscn\` | Adds keyboard-focusable section navigation above the full-content scroll |
| \`profile_text_layout_candidate.gd\` | Pure CRLF/tab presentation normalization and long-unbroken-token wrap selection |
| \`profile_scroll_navigation.gd\` | Pure key-to-scroll decision, honors focus/modifiers and refuses to trap boundary keys |
| \`placeholder_fixture_loader_candidate.gd\` | Fixed-path bounded file read, strict UTF-8 and BOM checks, atomic parse |
| \`preview_panel_resource_candidate.gd\` | Check scene resource class and instantiation/root contract before exposing a panel |
| \`preview_candidate.tscn\` | PanelHost with visible fallback label; no hard-coded Panel PackedScene dependency |
| \`preview_candidate.gd\` | Dynamic scene resource read, safe loading error, disabled invalid controls, retry, guarded panel calls |
| \`placeholder_profiles.json\` | Adds a third *synthetic* long-text/mixed-language fixture without facts from the book |
| \`verify_character_accessibility_candidate.gd\` | Aligns existing 002 future checks with dynamic preview and three fixtures |
| \`verify_character_continue_candidate.gd\` | Adds future-only fault-handling, literal text, scroll, section and reload assertions |
| \`README.md\`, \`ACCEPTANCE.md\` | Living documentation and NOT_RUN future acceptance inventory |

Earlier \`verify_character_panel_candidate.gd\`, \`profile_contract_candidate.gd\`,
\`data_contract.schema.json\`, and \`project.godot\` are not changed in this
increment.

## Design decisions and reasons

### R1. Missing or invalid panel resource should not kill the preview scene

The 002 preview referenced \`character_profile_panel.tscn\` directly from a
\`[ext_resource]\` in the parent scene. If the scene resource was missing,
loading the **preview itself** could fail before any friendly UI appeared.
The new preview scene is an independent MarginContainer with a \`PanelHost\`
and a neutral \`Fallback\` label. At runtime it checks the *fixed* path
\`res://character_profile_panel.tscn\` with \`ResourceLoader.exists\`, then
\`ResourceLoader.load\` as a \`PackedScene\`, and validates the instantiated
root type and expected candidate methods before adding it to \`PanelHost\`.

On any rejected resource, the preview keeps its toolbar/status visible,
turns off the selection/clear controls, shows the fallback, and leaves
\`Reload\` available to try again. A failed panel cannot be mistaken for a
successful profile. No caller-controlled resource path, network URL,
private asset or user-supplied executable is accepted.

**Limit:** malformed Godot scripts or scene parse errors may still create
engine console errors. This catches a rejected resource, not a crash of
the engine or a failure inside engine internals. The panel scene itself
remains a separately embeddable candidate; hosts that directly preload
it remain responsible for their own failure handling.

### R2. Fixture errors must not partially populate the UI

The fixture is restricted to **one fixed** \`res://placeholder_profiles.json\`.
The parser retains the 002 atomic checks (schema, identity and count).
The new reader first checks existence and open success, enforces 64 KiB
**before** reading, checks actual byte count and FileAccess error,
rejects non-roundtrippable UTF-8 and BOM, and only then parses a JSON array.

A failed load returns a generic, bounded visible message. Picker entries
are constructed only from an entirely validated batch; all old selections
are cleared at the start of reload. Empty, truncated, malformed, invalid
encoding, duplicate ID and out-of-bounds cases cannot leave a partial
picker. A bad direct \`set_profile\` still preserves the last valid panel
value and emits a rejection, independent of fixture import.

**Reason:** separate the UI component's stable in-memory injection
semantics from the preview's explicit all-or-nothing reload policy.
A stale test fixture should never silently survive a failed reload.

### R3. Long text should remain complete, readable and navigable

The data schema retains a maximum 1200-character summary and 600-character
item text. With up to 8 sections of 12 items, total content is still
substantial. The **same single vertical ScrollContainer** holds the
name, summary, tags and every field. No truncation/ellipsis is enabled.

\`profile_text_layout_candidate.gd\` normalizes CRLF and isolated CR to LF
and tabs to four spaces **for display only**. \`profile_copy()\` remains a
deep copy of the exact injected source. If a text span has 40 or more
consecutive non-whitespace characters, the Label switches to arbitrary
character wrapping; normal prose uses smart-word wrapping. This avoids
horizontal overflow from long IDs without breaking normal paragraphs
unnecessarily.

The panel also gains a visible \`SectionNav\` row whenever sections exist.
Its \`OptionButton\` and \`Jump\` button let keyboard users reach a selected
section via \`ScrollContainer.ensure_control_visible\`. Navigation is
based only on validated section IDs/headings from the injected data,
and it does not mutate content, save state, change focus automatically
or trigger gameplay actions. The row is absent on empty input.

**Limit:** exact word break behavior and text contrast require real Godot
desktop review, especially for mixed CJK/Latin, 320-pixel windows and large
system font scales. No screen-reader output is assumed.

### R4. Keyboard accessibility without hijacking game input

The 002 scroll handler ignored key releases, echoes, unrelated keys and
Ctrl/Alt/Meta. The 003 handler adds Shift to its modifier guards and moves
the decision into an independently checkable static method. It only
accepts input when the ScrollContainer itself owns focus.

ArrowUp/Down scroll by 64 px; PageUp/PageDown by 80% of the visible
height (minimum 64); Home/End jump to bounds. If a key would not change
the scroll position, it is **not consumed**, avoiding traps at the
top/bottom. Preview native controls remain Tab/Shift+Tab reachable;
section navigation uses native OptionButton and Button controls.
Text help stays visible while the panel is populated. Native accessibility
metadata is applied only where the Godot runtime exposes that property.

**Reason:** no global shortcut registration is appropriate before
the game-wide navigation and input layers have been approved.

## Failure paths and expected UI behavior

| Condition | Candidate behavior | Future verification |
| --- | --- | --- |
| Panel scene missing | No panel; fallback + status; reload enabled | isolated copy with scene renamed |
| Scene resource is not PackedScene | Factory rejection; no attachment | inject Resource/null in future harness |
| Scene root fails candidate shape | Reject/free temporary node | isolated fake PackedScene |
| Fixture file missing/unreadable | Empty disabled selector; readable error | isolated fixture removal/permissions |
| Fixture zero-length/oversize/truncated | Empty disabled selector; error | bytes and isolated file fixture |
| Invalid UTF-8/BOM/JSON/root type | No partial records | pure byte parser cases |
| Duplicate ID/invalid late record | Reject all options atomically | pure parser cases |
| Long summary/fields/unbroken tokens | Wrapping with all characters retained | panel text and real GUI review |
| More than one section | Jump selector and button visible | headless + real keyboard review |
| Scroll boundary/unfocused input | No consumption; no world input | pure navigation cases |
| Resource or data repaired then Reload | Recreate/repopulate on explicit retry | isolated GUI fault injection |

## Future-only test evidence / NOT_RUN

Three scripts are included as source and **were not executed**:

1. \`verify_character_panel_candidate.gd\` — original 001 assertions.
2. \`verify_character_accessibility_candidate.gd\` — 002 assertions adapted
   for the three placeholder records and 003 PanelHost.
3. \`verify_character_continue_candidate.gd\` — 003 byte/scene/long-text/
   keyboard/section/retry checks.

A future verifier may run these with an installed Godot 4 engine, explicitly
recording exact executable version, OS, commit, command, process exit status,
stdout/stderr, case IDs, observed/expected, and real screenshot/assistive
evidence. Do **not** convert authored test code or printed expected banners
into a PASS claim. A parser crash or missing engine is BLOCKED/FAIL, not PASS.

Manual verification must be distinct: 320x240, 480x320, 960x680 and
high-DPI/font scaling; long unbroken ASCII, multi-paragraph Chinese/Latin,
Tab/Shift+Tab, section jump, scroll boundaries, and simulated missing/malformed
scene/fixture. Actual native screen-reader accessibility, contrast ratio,
focus outline and performance remain unverified.

## Unresolved product integration boundaries

- Exact supported Godot 4 minor/platform and assistive-technology stack.
- Final game-wide theme/typography/focus policy.
- Real data adapters, dynamic assets/portrait pipeline or external resources.
- Shared API/official story semantics/canon review. None were decided.
- No private manuscripts, internal notes or real character details are
  required for this candidate or included in this public PR.

**Execution status for this delivery: NOT_RUN. No Godot, GDScript, test
scripts, CI, GUI, build or benchmark execution by this authoring window.**
