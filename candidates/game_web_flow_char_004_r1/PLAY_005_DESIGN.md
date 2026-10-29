# GAME-WEB-PLAY-CHAR-005 r1 — list, details and input-fallback refinements

**DRAFT TECHNICAL CANDIDATE · SOURCE_SUBMITTED · NOT_RUN · NO CANON.**
Design record written during development only. It does not assert real Godot execution or accessibility conformance.

## Reviewed baseline and ownership

This continuation is pinned to the real contents of GitHub Draft PR #21,
\`codex/game-web-flow-char-004-r1\`, HEAD:
\`6d57b441251564878575af121a224e6727d92e25\`.
Read its \`profile_flow_candidate.gd/.tscn\`, \`profile_flow_model_candidate.gd\`,
standalone demo, fixed-source fixture/resource helpers, pinned #14 presentation
code, prior future-only verification script and its design/handoff documents.
PR #21 is based on \`main\` and remains a Draft. The entire delta here is
limited to \`candidates/game_web_flow_char_004_r1/\` and makes no changes to
main, other candidates or original novel files.

## Implemented differences from 004

1. **Scrollable list cards**. The source list used 44px buttons with names and
   statuses only; this revision renders native focusable buttons accompanied
   by subtitle, tags and a clearly marked summary excerpt. It does not put
   long prose in button tooltips. Detail view continues to use the exact
   full-length #14 panel and provides all validated summary/section data.
   \`visible_summaries()\` now includes a copied \`summary\` string solely for
   locally rendering an excerpt. There is no new canonical data schema.

2. **Full detail remains single-scroll, no hidden truncation**. The module
   reuses the pinned #14 snapshot \`character_profile_panel.tscn\` and its
   paragraph normalization, long-token wrap selection and section jump
   navigation. List-only excerpts are capped at 150 characters and explicitly
   direct users to the full detail. This bounds list rendering for up to 24
   records without pretending to truncate the source content. The full
   injected profile never changes because a preview is shortened.

3. **Back navigation restores context**. Earlier \`_refresh_ui()\` rebuilt
   every row when switching routes, which destroyed the clicked button and
   could lose keyboard focus and scroll position. This revision records
   the selected profile ID and list scrollbar position before opening.
   The Back action rebuilds the list, restores the scroll via a deferred
   property change and focuses the original row when it still exists,
   or the search input as a fallback. Search updates reset the origin to
   prevent jumping to a filtered-out row. There is no global Escape binding,
   so no claim of authority over the shell's history/focus arbitration.

4. **Responsive header and route cues**. The header changes from HBox to
   HFlowContainer to wrap Back, Reload and Exit controls at narrow widths.
   A readable breadcrumb tells the user whether they are in list or detail.
   At widths below 700 px, list/detail is mutually exclusive and search
   disappears while viewing a detail so all vertical space goes to reading.
   At wider widths both panes remain visible and independently scroll.
   Minimum row button height remains 44 px. No real typography/theme
   baseline was supplied, so final contrast and glyph QA remain pending.

5. **Panel resource fault handling with meaningful retry**. The resource
   still has a single fixed \`res://character_profile_panel.tscn\` locator
   and is checked via \`ResourceLoader.exists\`, \`ResourceLoader.load\`, and
   the pinned #14 PackedScene factory's root/method/child validation.
   On missing/invalid scene or rejected profile, the detail host is hidden,
   a visible message appears, the Retry button is available, and the
   list/Back/Exit controls remain responsive. Retry now **unmounts any
   previous panel instance** and loads a fresh one; the previous action
   merely re-rendered an already cached instance in some cases.
   Renderer errors can still create Godot diagnostics; this is not a
   security sandbox nor a full engine-crash recovery mechanism.

6. **Fixture reload and conservative failure behavior**. A new native
   \`ReloadSamplesButton\` calls only the fixed source loader in the #14
   public technical snapshot. The 64KiB / max-12 / UTF-8 / BOM / duplicate
   identity/atomic validation limits remain unchanged. A failed reload
   leaves the last valid injected in-memory list intact and **explicitly
   discloses** that fact in the visible error; no partial data and no
   fallback to private story text. A successful reload clears the filter
   and selection. The intentional distinction between retained on failure
   and cleared on successful replacement is recorded, not hidden.

7. **Keyboard scope and source of truth**. List cards are native Buttons,
   filter is native LineEdit, Back/Exit/Reload/Retry are native Buttons.
   Buttons optionally receive \`accessibility_name\` metadata only when
   that Godot property is actually available. Their tooltips are short
   descriptions, not the only path to essential information. The pinned
   panel already owns focus-local Up/Down, Page, Home and End navigation;
   this flow does not duplicate, consume, or register keyboard events
   globally. Its \`exit_requested\` is an informational signal.

## Explicit error and state matrix

| Cause | Model outcome | UI outcome | Recovery |
|---|---|---|---|
| Missing or malformed panel scene | Valid record still selected | Detail hidden, fallback + retry, list/back intact | Restore fixed local resource; Retry |
| Invalid panel PackedScene structure | No invalid node attached | Same fail-closed fallback | Replace scene with valid candidate; Retry |
| Detail panel set_profile rejects | No source mutation | Existing panel hidden, error + retry | Inspect candidate contract; Retry |
| Fixed synthetic fixture missing/corrupt | Old injected list preserved | Visible error saying it is retained | Restore fixture; Reload |
| Fixture duplicate ID / oversize / bad UTF-8 | Atomic failure from pinned loader | No partial batch accepted | Correct fixture; Reload |
| Unknown/filtered-out profile ID | Refused by in-memory model | Current route unchanged | Select visible row |
| Empty valid source list | Clears selection/filter | List empty message; detail empty | Load or inject valid set |
| Text query changed mid-detail | Detail closed by model | Return to filtered list; no stale selection | Open matching row |
| Back after row removed by replacement | Origin forgotten | Focus search instead of stale row | Search/select |
| Narrow window | Source unchanged | One pane visible, header wraps | Resize |
| Exit button | No local navigation or game state writes | Signal emitted for host only | Host decides |

## Integration with shell / no API promotion

PR #21 includes \`shell_profile_adapter_candidate.gd\`, a _synthetic-only_
\`RefCounted\` mock matching the previously read shell PR #17 private
\`preview()\` + \`preview_action("sample_request")\` shape. This task does
not modify or import shell PR #17, and does not assume that its
\`profile\` page can mount a Control. A separate, reviewed shell
container adapter is required for actual UI embedding. See
\`PLAY_005_INTEGRATION.md\` and \`SHELL_HANDOFF.md\`.
All public API and data keys remain candidates only.

## Future verification, not execution

- Added \`verify_profile_play_candidate.gd\` with later-only model/UI/long
  record/keyboard-control structure/state/back/search/reload cases.
- Retained the earlier \`verify_profile_flow_candidate.gd\`; both must be
  run in a later *authorized* local environment together with manual
  focus, narrow-layout, missing-resource and assistive-technology checks.
- Files and expected acceptance criteria are enumerated in
  \`PLAY_005_ACCEPTANCE.md\`.
- Target Godot 4.x minor, release platform, screen-reader stack, official
  design tokens and real shell mount policy were **not provided**; no
  speculative compatibility or PASS is asserted.

**This source-development change did not run Godot, GDScript, tests, builds,
CI jobs, browser/desktop UI, native accessibility checks or benchmarks.**


### 8. Demo-scene resource failure is also independently recoverable

The original 004 demonstration scene had a direct `ext_resource`
reference to `profile_flow_candidate.tscn`: missing that scene would
prevent the whole demo from opening. The 005 demonstration now uses a
fixed-path, dynamically loaded scene in a simple static host with a
visible fallback and a **Reload Component** button. The host verifies
PackedScene, Control root, the candidate methods and the informational
exit signal before mounting. It discards any old instance before retry
and does not read arbitrary paths.

This protects the *demo's own startup* if the independent flow scene is
missing. Corrupt scripts may still create engine logs; the engine and
its resource parser are not sandboxed. The user-facing flow itself still
handles missing detail panel and invalid synthetic fixture separately.
