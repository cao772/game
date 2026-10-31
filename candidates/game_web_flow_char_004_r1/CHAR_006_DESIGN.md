# GAME-WEB-CHAR-006 r1 — paged synthetic list, focus continuity, resource degradation

**Technical candidate · SOURCE_SUBMITTED · NOT_RUN · no canon/API approval.**

## Source provenance and change boundary

Read the actual current GitHub Draft PR #21 head
\`8f3471dd23f716d4bd96191e5a1f61a33e5837f8\` before editing:
\`profile_flow_candidate.gd/.tscn\`, \`profile_flow_model_candidate.gd\`,
\`flow_demo_candidate.gd/.tscn\`, \`placeholder_fixture_loader_candidate.gd\`,
pinned character detail scene/renderer, earlier future verification scripts,
README and PLAY_005 design/acceptance. The source of the pinned #14 renderer
remains untouched; this change adds/edits only
\`candidates/game_web_flow_char_004_r1/\` in PR #21's
\`codex/game-web-flow-char-004-r1\` branch.

The existing profile contract, root-relative resource paths, 24-entry
collection cap, 80-character search limit and strict all-or-nothing validation
are unchanged. The independent shell PR #17 has **no approved Control host**;
no live shell mount is implemented or claimed.

## Actual implementation

| File | Increment |
| --- | --- |
| \`profile_flow_model_candidate.gd\` | Page index, count/bounds, filtered counts, six-row page slices, page-local summary copies, and page-of-ID selection |
| \`profile_flow_candidate.gd\` | Native previous/next buttons, live page/count text, per-page focus bookmarks, restoration after detail Back, full-text degraded view and explicit fixture-fallback state |
| \`profile_flow_candidate.tscn\` | Page-control row; focusable vertical full-text degraded reader with no horizontal scroll |
| \`profile_degraded_candidate.gd\` | Fully synthetic schema-compliant fallback record and lossless plain-text detail formatting |
| \`synthetic_page_factory_candidate.gd\` | Generates 0–24 bounded synthetic records, default 14 for a three-page visual exercise |
| \`flow_demo_candidate.gd\`, \`flow_demo.tscn\` | Explicit 14-record button alongside the fixed-file demo/reload. No private input or gameplay request |
| \`verify_profile_paging_candidate.gd\` | Future-only GDScript checks; does NOT run when committed |
| \`CHAR_006_ACCEPTANCE.md\`, \`CHAR_006_DESIGN.md\` | Behavior, rationale, manual gate, static evidence plan |
| \`README.md\`, \`ACCEPTANCE.md\` | Latest-source navigation and review entries |

## Decision 1: deterministic, bounded pages rather than unbounded scrolling

There are at most 24 validated records. The candidate now displays
**6 list cards per page**, retaining the full existing filtered summary
collection for the previously exposed \`visible_rows_copy()\` method.
\`current_page_rows_copy()\` is a new **local proposal** for page-only data.
The UI displays *page number / page count* and *items on page / matching
items / total items*, with the previous and next Buttons disabled at
boundaries.

An empty collection or no search matches is shown as **page 1 of 1 with
zero rows**, not a page-zero ambiguity. Requesting a negative/out-of-range
page is refused without altering state. Successful source replacement or a
new query resets to page 1. An invalid batch leaves the previous list,
page/filter and current selection intact, consistent with the original
atomic loader contract.

Selecting a stable ID via \`open_profile(id)\` automatically relocates
the current page to the matching filtered row, so existing programmatic
calls still work even for an off-page record. Returning via Back retains
that page. Filtered-out/unknown IDs are rejected. No sorting of imported
records or world-state meaning is introduced.

## Decision 2: focus bookmarks by page; no global keyboard shortcuts

The 005 Back implementation remembered a row ID and list scroll position
but did not model pagination. Every dynamic list Button now records its ID
on \`focus_entered\`, indexed by page. Previous/Next are native focusable
Buttons; a page change reconstructs **only the visible six cards**, resets
scroll and defers focus to the most recently focused visible row for that
page, or its first row, or search if empty. The Back path retains the
origin row ID and scrollbar offset and defers restoration after rebuilding
that page, rather than focusing a node queued for deletion.

Search and successful collection replacement clear old page bookmarks,
preventing stale focus onto filtered-out/removed IDs. The application
host remains responsible for its own navigation and Escape behavior:
no InputMap, global accelerator, autoload, save or game action is added.
The pinned detail panel still supplies its own full-content scroll and
native section jump controls.

**Limits:** Godot focus/scroll and IME behavior depend on native window,
viewport and exact engine build; all remain manual **NOT_RUN** checks.

## Decision 3: failures are visible and truthfully labelled

### Detail scene missing or rejected

If the fixed \`res://character_profile_panel.tscn\` is missing, invalid,
wrong type or rejects the selected validated profile, the normal detail
host hides and **a separate full-text vertical ScrollContainer** displays
a plain-text rendition of **all** existing title, subtitle, status, tags,
summary, sections and item values. The text comes from the *already
validated and deep-copied* selected record. It is not BBCode, HTML, a
script or a re-created character. Lines are normalized for presentation
only. The UI shows a clear degradation warning and Retry remains
available; list, Back, pagination and Exit are not removed.

A successful retry uses the prior 005 explicit unmount/remount behavior
and hides the degraded reader. A malformed scene may still produce a
Godot parser diagnostic: this is not an engine crash sandbox.

### Fixed synthetic fixture unavailable

The loader continues to accept **only**
\`res://placeholder_profiles.json\`, with its fixed 64 KiB, 12-record,
UTF-8, duplicate-ID and atomic validation constraints.

A failed read with **previously accepted profiles** preserves them
without claiming they are newly loaded. A failed read when there
is **no valid collection** installs exactly one hard-coded,
schema-valid **synthetic degradation** entry, visibly labeled
\`资源降级 / 非原始数据\`. The method still returns **false** and
emits \`collection_rejected\`, because the requested source did not
load. Successful later reload removes the stub and restores the genuine
synthetic fixture. A repeated failure while the stub is active
explicitly says that the synthetic fallback remains (not that it is a
verified file).

No private novel, real character, external path, prior chat transcript,
image or uploaded asset is ever substituted. The diagnostic record is
in source only and has no story meaning.

\`apply_placeholder_result(Dictionary)\` is a **local future fault-injection
seam**, not a public IO adapter. It can accept a pre-parsed result for
deterministic future checks but it cannot choose or fetch a file path.

## Decision 4: a visible three-page standalone demo

The pinned file contains three synthetic records and cannot exercise more
than one six-row page. The standalone demo therefore adds an explicit
\`分页样本（14 条）\` Button which uses the new local
\`synthetic_page_factory_candidate.gd\` and calls the Flow's already
validated \`set_profiles()\`. Fourteen records provide pages of
6 + 6 + 2. This does not modify the pinned JSON fixture or PR #14.
A separate \`重载占位\` button still re-reads only the fixed JSON.

## Future review and evidence (not executed)

Review \`CHAR_006_ACCEPTANCE.md\`; the new finite script
\`verify_profile_paging_candidate.gd\` covers page arithmetic,
bounds, off-page selection, filtering, simulated bad fixture results,
full-text fallback and page navigation source. The earlier
\`verify_profile_flow_candidate.gd\` and
\`verify_profile_play_candidate.gd\` remain included for future
regression validation. Headless checks cannot certify native focus,
screen-reader announcements, small-device layout, contrast or
resource fault recovery. A future reviewer must use a **disposable
copy** to simulate physically missing Godot resources, record the
exact commit, Godot version/OS, exit code, logs and screenshots, and
distinguish PASS/FAIL/BLOCKED from NOT_RUN.

No code execution, Godot parsing/editor, tests, CI runs, GUI, screenshot,
accessibility session or performance measurements were performed here.

## Unresolved integration inputs

Precise Godot 4.x minor, supported platforms, approved typography,
screen-reader/test stack, shell Control host and focus arbitration,
real profile-data adapter and final owner acceptance remain **unknown**.
No guessed interface or story facts have been introduced. The user
retains final acceptance/merge control.
