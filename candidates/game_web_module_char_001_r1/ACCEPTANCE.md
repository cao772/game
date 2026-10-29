# Future acceptance and evidence plan — GAME-WEB-MODULE-CHAR-001 r1

All cases are **NOT_RUN** at submission. Listed outcomes are acceptance
criteria rather than test results. Do not label them PASS until executed.

## Planned headless validation

File: verify_character_panel_candidate.gd. Godot 4 SceneTree assertions
with explicit exit code 0 on all checks and nonzero on assertion failures.
Engine parse/startup errors must also be recorded, not counted as PASS.

| ID | Scenario | Expected result | Status |
| --- | --- | --- | --- |
| A01 | Instantiate empty component | Neutral empty view, zero section cards | NOT_RUN |
| A02 | Null/array/missing/extra fields | Rejected | NOT_RUN |
| A03 | Boolean, wrong or fractional schema version | Rejected | NOT_RUN |
| A04 | Unsafe profile id, blank display name | Rejected | NOT_RUN |
| A05 | Too-long summary or item value | Rejected | NOT_RUN |
| A06 | Excess tags or duplicate tags | Rejected | NOT_RUN |
| A07 | Malformed item/duplicate or unsafe section id | Rejected | NOT_RUN |
| A08 | Null character in text | Rejected | NOT_RUN |
| A09 | Valid synthetic Unicode input | Data displayed as text | NOT_RUN |
| A10 | Literal markup marker in value | Rendered literally, not interpreted | NOT_RUN |
| A11 | Mutate original input after set_profile | Component value unchanged | NOT_RUN |
| A12 | Mutate result of profile_copy | Internal nested values unchanged | NOT_RUN |
| A13 | Invalid replacement after valid profile | Prior data/UI retained; error exposed | NOT_RUN |
| A14 | Replace with profile having no sections | Old section removed, empty-section hint | NOT_RUN |
| A15 | Empty optional strings and tags | Corresponding elements hidden/cleared | NOT_RUN |
| A16 | Section with no items | Empty-item hint visible | NOT_RUN |
| A17 | clear_profile | No retained data/cards; empty view shown | NOT_RUN |
| A18 | Call set_profile before node ready | Deferred render completes when added | NOT_RUN |

## Planned native GUI / manual checks

| ID | Scenario | Expected outcome | Status |
| --- | --- | --- | --- |
| H01 | Open preview at 960x680 | Synthetic profile only, readable controls | NOT_RUN |
| H02 | Switch fixture A to B and back | No stale tags, cards or strings | NOT_RUN |
| H03 | Clear then reselect | Empty and reloaded states coherent | NOT_RUN |
| H04 | Resize parent to roughly 320x240 | No severe overlap; scroll remains usable | NOT_RUN |
| H05 | Larger resizable window | Content reflows and remains legible | NOT_RUN |
| H06 | Mouse wheel and keyboard focus | Normal scrolling, no unintended game actions | NOT_RUN |
| H07 | Mixed Chinese/Latin text | No corrupt glyphs; literal markers preserved | NOT_RUN |
| H08 | Godot error console and visual review | No parser/runtime errors; contrast checked | NOT_RUN |
| H09 | Inspect IO/network/persistence effects | No unintended writes or outbound requests | NOT_RUN |
| H10 | Target Godot 4.x engine/version | Record exact version and compatibility | NOT_RUN |

## Verifier's evidence requirements

For each case record task_id, r1, exact commit SHA, Godot version,
operating system, case ID, status (PASS/FAIL/BLOCKED/NOT_RUN), UTC timestamp,
expected result, observed result, reproduction steps, and evidence location.
Capture stderr/stdout and exit code for the headless suite. Capture real
screenshots and console output separately for manual GUI checks. Keep
private resources in authorized storage rather than public GitHub.

## Unresolved owner decisions

1. Target Godot 4.x minor and supported platforms.
2. Whether any external model should map to this candidate schema.
3. Approved theme, font fallback, localization, accessibility/contrast
   criteria and avatar/portrait pipeline.
4. Whether section/tag caps and navigation behavior fit real design.
5. Who reviews and authorizes eventual shared API/canon integration.

No code, test, build, CI job, rendering, benchmark or native GUI acceptance
was executed during this source-development task. No merge is authorized.


---

## Additional GAME-WEB-MODULE-CHAR-002 r1 acceptance cases

**All cases below: NOT_RUN.** See
[MODULE_CHAR_002_DESIGN.md](MODULE_CHAR_002_DESIGN.md) for rationale and
the new \`verify_character_accessibility_candidate.gd\` future-only suite.

| ID | Input / procedure | Acceptance condition | Status |
| --- | --- | --- | --- |
| A19 | Empty/non-text/non-JSON fixture | Loader rejects without partial data | NOT_RUN |
| A20 | Root is JSON object/scalar or empty array | Loader rejects | NOT_RUN |
| A21 | Encoded fixture >64 KiB | Loader rejects with bounded error | NOT_RUN |
| A22 | More than 12 records | Rejects entire batch | NOT_RUN |
| A23 | Duplicate profile_id | Rejects entire batch | NOT_RUN |
| A24 | Invalid record after valid records | No partial result returned | NOT_RUN |
| A25 | Valid two-record synthetic fixture | Two records accepted and selectable | NOT_RUN |
| A26 | Long summary | Summary is under scroll Content | NOT_RUN |
| A27 | Reading area | Keyboard focus enabled; horizontal scroll disabled | NOT_RUN |
| A28 | Native accessibility properties available | Name/description set, status live hint guarded | NOT_RUN |
| A29 | Empty and populated panel | Help hint visibility follows data presence | NOT_RUN |
| A30 | Preview picker/clear/reload | All controls keyboard-focusable with tab order | NOT_RUN |
| A31 | Preview clear, invalid index, reload | No stale content; reload recovers fixture | NOT_RUN |
| A32 | Original r1 acceptance script after scene refactor | No stale node paths; r1 invariants preserved | NOT_RUN |

| ID | Manual / accessibility review | Acceptance condition | Status |
| --- | --- | --- | --- |
| H11 | 320x240, 480x320, 960x680 resizing | Entire header/body reachable without horizontal clipping | NOT_RUN |
| H12 | Keyboard Tab, Shift+Tab | Predictable navigation among preview controls and scroll | NOT_RUN |
| H13 | OptionButton arrows/Enter; Buttons Enter/Space | Native activation, no accidental game command | NOT_RUN |
| H14 | Focused scroll Up/Down/PageUp/PageDown/Home/End | Correct bounds and no keyboard trap | NOT_RUN |
| H15 | Repeated/modifier keys, focus in picker | No unintended profile reading scroll | NOT_RUN |
| H16 | Long CJK/Latin, high font scale | Words readable, no overlap or hidden content | NOT_RUN |
| H17 | Supported Godot and assistive technology | Verify actual spoken labels, status updates and focus | NOT_RUN |
| H18 | Unavailable, corrupt, oversized or duplicate fixture | Visible error, disabled invalid controls, no partial options | NOT_RUN |
| H19 | Contrast/focus-border screenshots | Author review needed; no WCAG compliance assumed | NOT_RUN |
| H20 | Diff scope and privacy audit | Only PR #14 module files, no lore or private material | NOT_RUN |

The requested authoring window performs no code/test execution. Expected
outputs are not evidence of a PASS. Exact engine minor and accessibility
toolchain are still owner inputs.


---

## GAME-WEB-CONTINUE-CHAR-003 r1 future acceptance extension

**All cases NOT_RUN**. See [CHAR_003_DESIGN.md](CHAR_003_DESIGN.md),
including the new future-only verify_character_continue_candidate.gd script.
The previous 001 and 002 future scripts are not a substitute for executing
and observing the new 003 tests.

| ID | Planned check | Required observation | Status |
| --- | --- | --- | --- |
| A33 | Null or wrong PackedScene class | Panel factory rejects without exposing a node | NOT_RUN |
| A34 | Panel scene missing or invalid | Preview fallback and reload remain visible | NOT_RUN |
| A35 | Repair resource and explicit reload | Usable synthetic component appears | NOT_RUN |
| A36 | Empty/unreadable/oversize fixture | Fail closed, disabled controls, bounded error | NOT_RUN |
| A37 | Invalid UTF-8, BOM, incomplete read | Reject before JSON/schema parsing | NOT_RUN |
| A38 | Bad JSON or wrong root | Atomic empty result | NOT_RUN |
| A39 | Duplicate ID or later bad record | No partial picker entries | NOT_RUN |
| A40 | Three valid synthetic records | Selectable and switchable, no duplicates | NOT_RUN |
| A41 | CRLF/CR/tab rendering | Display-only normalized; raw profile copy unchanged | NOT_RUN |
| A42 | Unbroken 40+ characters | Arbitrary-character wrapping, no truncation | NOT_RUN |
| A43 | Ordinary text and multiple paragraphs | Smart-word wrapping and preserved line boundaries | NOT_RUN |
| A44 | Large summary and section fields | All text accessible through one scroll region | NOT_RUN |
| A45 | Two or more sections | Section chooser/jump enabled and keyboard reachable | NOT_RUN |
| A46 | No section or stale selection | Jump disabled or no mutation | NOT_RUN |
| A47 | Keys with modifiers/echo/release/unfocused | Never consumed by local scroll handler | NOT_RUN |
| A48 | Arrow/Page/Home/End at boundaries | Bounded scroll; keys not trapped at limits | NOT_RUN |
| A49 | Older 001/002 acceptance scripts | No regression observed with updated preview structure | NOT_RUN |
| A50 | Public GitHub privacy and change-scope review | Only isolated directory, synthetic data, no canon | NOT_RUN |

| ID | Manual acceptance procedure | Required outcome | Status |
| --- | --- | --- | --- |
| H21 | Remove panel scene in disposable copy | Preview stays open with fallback and retry | NOT_RUN |
| H22 | Supply invalid scene in disposable copy | Clear error or recorded engine-level parse limitation | NOT_RUN |
| H23 | Restore scene, click Reload | Valid panel and three placeholders return | NOT_RUN |
| H24 | Bad/oversize/permission-denied fixture | Status visible; no stale selectable entries | NOT_RUN |
| H25 | Restore fixture and reload | No residual error/duplicate options | NOT_RUN |
| H26 | Long fixture on 320, 480, 960 px widths | No horizontal clip, every section reachable | NOT_RUN |
| H27 | Tab/Shift+Tab, section jump, scroll keyboard | Keyboard-only navigation usable without trap | NOT_RUN |
| H28 | Focus elsewhere / unrelated keys | No global gameplay action or unexpected scroll | NOT_RUN |
| H29 | Platform screen-reader and accessibility tree | Actual names/announcements independently verified | NOT_RUN |
| H30 | CJK glyphs, large font, focus contrast, frame cost | Screenshots/measurement recorded rather than inferred | NOT_RUN |

If a later verifier executes any of these, require exact commit, Godot
version, OS, command, UTC timestamp, stdout/stderr, exit code, per-case
observations, failure reproduction and evidence path. Never call written
checks PASS without execution. User expressly requested NOT_RUN here.
