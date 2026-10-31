# Future-only acceptance — GAME-WEB-PLAY-CHAR-005 r1

**All proposed checks: NOT_RUN. No test execution in this development task.**
Use this document together with prior \`ACCEPTANCE.md\` and
\`verify_profile_flow_candidate.gd\`; the new future-only script is
\`verify_profile_play_candidate.gd\`.

## Headless/source acceptance to be performed later

| ID | Scenario | Expected evidence | Status |
|---|---|---|---|
| P01 | 24 valid unique synthetic profiles | Atomic load succeeds; list count 24 | NOT_RUN |
| P02 | 25th entry | Rejected; previous 24 retained | NOT_RUN |
| P03 | Summary included in summary-copy data | Full value available for local preview | NOT_RUN |
| P04 | Search by tag, name, status | Only matching stable-ID rows visible | NOT_RUN |
| P05 | Unknown or filtered-out ID | Cannot open, route unchanged | NOT_RUN |
| P06 | Detail selected, query changes | Return to list; selection discarded | NOT_RUN |
| P07 | Malformed batch/duplicate ID | Rejected with prior valid collection intact | NOT_RUN |
| P08 | Fixed three synthetic fixture records | Accepted without real character data | NOT_RUN |
| P09 | Invalid UTF-8 and wrong scene type | Pure helper rejects | NOT_RUN |
| P10 | Flow scene and wrapped header | Header is flow container; no parser errors | NOT_RUN |
| P11 | ReloadSamplesButton exists | Native keyboard-focusable control | NOT_RUN |
| P12 | Breadcrumb starts in list | Explicit route text visible | NOT_RUN |
| P13 | Three record cards | Name, subtitle, tags and bounded excerpt | NOT_RUN |
| P14 | Long synthetic profile opens | Exact profile ID, full summary retrievable | NOT_RUN |
| P15 | Detail panel mounted | Candidate panel exists and content shown | NOT_RUN |
| P16 | Detail resource invalid | Fallback/retry visible, no false loaded status | NOT_RUN |
| P17 | Retry after repair | Old instance discarded; fresh instance accepted | NOT_RUN |
| P18 | Back from detail | List route, origin row present and focusable | NOT_RUN |
| P19 | Back twice | Second returns false, no extra route push | NOT_RUN |
| P20 | Search filter | List regenerated with matching rows | NOT_RUN |
| P21 | Failed source replacement | List/count unchanged, rejection signal | NOT_RUN |
| P22 | Successful fixture reload | Filter cleared, list restored | NOT_RUN |
| P23 | Narrow layout | Only selected pane shown; search hidden in detail | NOT_RUN |
| P24 | Narrow Back | List/search visible again | NOT_RUN |
| P25 | Wide layout | List and detail both visible | NOT_RUN |
| P26 | Retry invoked outside detail | Harmless no-op | NOT_RUN |
| P27 | Exit button | Signal once; no scene closure/game action | NOT_RUN |
| P28 | Prior 004 future test source | No regressions with added row wrappers | NOT_RUN |

## GUI / keyboard / failure / usability checks to be performed later

| ID | Manual test | Acceptance criteria | Status |
|---|---|---|---|
| G01 | 320x240, 400x300, 700x500, 1060x720 | Header wraps, no clipped list/detail controls | NOT_RUN |
| G02 | Tab and Shift+Tab from top through rows | Visible focus, no keyboard trap | NOT_RUN |
| G03 | Enter/Space on a selected list button | Opens its matching detail | NOT_RUN |
| G04 | Back from deeply scrolled list | Previously clicked row refocused and scroll retained | NOT_RUN |
| G05 | Long CJK, unbroken ASCII, CRLF, markup literals | Full detail preserved; list excerpt clearly marked | NOT_RUN |
| G06 | Detail section chooser and scroll arrow/page keys | Keyboard reading works when focused only | NOT_RUN |
| G07 | External host focus / Escape | No global shortcuts or shell history mutation | NOT_RUN |
| G08 | Hide panel scene in disposable copy | Visible fallback, retry enabled, list/back usable | NOT_RUN |
| G09 | Restore panel scene and Retry | Detail appears without stale instance | NOT_RUN |
| G10 | Corrupt/remove fixture in disposable copy | Failure message mentions prior list retained | NOT_RUN |
| G11 | Restore fixture and Reload | Fresh three-record collection, no duplicates | NOT_RUN |
| G12 | IME, large fonts, high DPI | Search typing and controls visually coherent | NOT_RUN |
| G13 | OS screen reader and focus semantics | Spoken labels/announcements actually observed | NOT_RUN |
| G14 | Screen capture and resource diagnostics | No unintended resource errors, legible focus/contrast | NOT_RUN |
| G15 | Shell #17 mock-only handoff | Preview shape accepted; no live scene mounted | NOT_RUN |
| G16 | Host Control mount + Exit signal | Host owns routing and teardown | NOT_RUN |
| G17 | Static diff inspection | Only PR #21's own directory changed | NOT_RUN |
| G18 | Privacy/content review | Synthetic-only, no source manuscript/chat evidence | NOT_RUN |
| G19 | Performance/memory/scroll budget | Measured on a specified system, never fabricated | NOT_RUN |

## Later verification commands (not executed)

From repo root, with an authorized Godot binary:

    godot --headless --path candidates/game_web_flow_char_004_r1 --script res://verify_profile_flow_candidate.gd
    godot --headless --path candidates/game_web_flow_char_004_r1 --script res://verify_profile_play_candidate.gd

The printed \`PASS\` banner in test source is just an expected output. A
future reviewer must capture exact commit, Godot version, OS, UTC date,
stdout/stderr, exit code, observed values and case-specific screenshots.
A parser failure, test crash or missing resource is not PASS. Manual/native
accessibility tests and real shell integration require separate evidence.

Unresolved author gate: exact Godot 4.x minor, supported platform,
approved UI theme, accessibility criteria, shell Control host/focus
ownership, official data source and validated interface. No requests
for those ordinary design preferences were needed to submit this
isolated technical candidate.

**STATUS: NOT_RUN.**


## Demo resource loading future cases

| ID | Scenario | Expected observation | Status |
|---|---|---|---|
| P29 | Standalone demo starts | Flow exists under Host via fixed PackedScene loader | NOT_RUN |
| P30 | Demo reloads | Previous Flow freed and one new Flow mounted | NOT_RUN |
| P31 | Demo Flow scene missing | Static fallback plus Retry survives | NOT_RUN |
| P32 | Demo scene wrong class/missing methods | No invalid Control attached | NOT_RUN |
| P33 | Demo Exit signal | Exit notice shown, no SceneTree exit | NOT_RUN |
| G20 | Narrow demo toolbar | Header controls and fallback visible at small width | NOT_RUN |

Resource fault cases require a disposable copy, not edits to the PR branch.
