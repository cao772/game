# GAME-WEB-CHAR-006 r1 — future acceptance inventory

**All tests and checks below: NOT_RUN.** This is a source-only delivery.

The new future-only script is \`verify_profile_paging_candidate.gd\`.
Run it only when the author authorizes a separate verification task.
Previous \`verify_profile_flow_candidate.gd\` and
\`verify_profile_play_candidate.gd\` must also be reviewed and executed
then; written expected PASS text is never evidence of execution.

| Case | Scenario | Acceptance condition | Status |
| --- | --- | --- | --- |
| P001 | Empty model | One empty page, no rows, no Next/Previous | NOT_RUN |
| P002 | Inject 14 synthetic records | Three pages: six, six, two | NOT_RUN |
| P003 | First/last page bounds | Out-of-range changes rejected without mutation | NOT_RUN |
| P004 | Page metadata | Index, 1-based number, counts and flags coherent | NOT_RUN |
| P005 | Select off-page stable ID | Model moves to item's correct page and opens detail | NOT_RUN |
| P006 | Back after off-page detail | Returns to originating page, preserves filter | NOT_RUN |
| P007 | Search changes on page 3 | Resets to page 1, discards selected detail | NOT_RUN |
| P008 | Zero search matches | Page 1/1, zero rows and visible no-results message | NOT_RUN |
| P009 | Duplicate ID, late invalid record | Atomic rejection; old page/filter/list retained | NOT_RUN |
| P010 | Replace with 6 exact items | Exactly one page; old page index discarded | NOT_RUN |
| P011 | List rendering after Next | Exactly six new row cards; no stale old card | NOT_RUN |
| P012 | Last page rendering | Exactly two cards; Next disabled | NOT_RUN |
| P013 | Native button access | Previous/Next Tab-focusable, readable visible labels | NOT_RUN |
| P014 | Focus bookmark on each page | Last focused ID on revisited page restored | NOT_RUN |
| P015 | Back from detail | Previous row focus and scroll position restored | NOT_RUN |
| P016 | Removed/filter-hidden origin | Focus falls back to existing row/search; no stale node | NOT_RUN |
| P017 | Long-summary in list | Preview bounded; full underlying summary unchanged | NOT_RUN |
| P018 | Detail scene missing | Clear warning, full text in vertical scroll, Retry available | NOT_RUN |
| P019 | Invalid scene root/methods | Same degraded behavior, never false success | NOT_RUN |
| P020 | Normal detail returns after restore | Degraded view hidden; full pinned panel visible | NOT_RUN |
| P021 | Degraded long sections and item values | All headings and values present; no partial disclosure | NOT_RUN |
| P022 | Fixture missing with empty list | One explicit internal *synthetic* stub; method returns false | NOT_RUN |
| P023 | Fixture missing after prior valid load | Preserve previous list; emit rejection, not success | NOT_RUN |
| P024 | Repeated missing-file attempt on stub | Still flagged as synthetic degradation | NOT_RUN |
| P025 | Fixture restored | Genuine three records replace stub; flag resets | NOT_RUN |
| P026 | Invalid UTF-8/BOM/oversize JSON | Fail closed per unchanged pinned loader | NOT_RUN |
| P027 | Fixed resource path only | No arbitrary user path/network/private data | NOT_RUN |
| P028 | 14-record built-in demo generator | Validated synthetic records, 3-page UI | NOT_RUN |
| P029 | Ctrl/Alt/Meta/Shift in reading area | No new global shortcut or gameplay dispatch | NOT_RUN |
| P030 | Host exit request | Still only emits signal; no SceneTree or shell mutation | NOT_RUN |

## Native manual cases (distinct from headless)

| Case | Procedure | Required evidence | Status |
| --- | --- | --- | --- |
| M01 | 320x240 / 400x300 / 700x500 / 1060x720 | No critical overlap, page controls reachable | NOT_RUN |
| M02 | Tab/Shift+Tab through search, page controls and row cards | Native keyboard flow, visible focus, no trap | NOT_RUN |
| M03 | Page 1 → page 2 → detail → Back | Original page/row and scroll position restored | NOT_RUN |
| M04 | Page 2 → 3 → 2 with keyboard only | Previously focused row refocused | NOT_RUN |
| M05 | Search while browsing later page | Page and focus reset, no stale rows | NOT_RUN |
| M06 | Remove detail PackedScene in disposable copy | Full degraded text visible and scrollable | NOT_RUN |
| M07 | Restore scene and click Retry | Normal detail reappears, no stale panel instance | NOT_RUN |
| M08 | Delete/corrupt fixture in disposable copy | False return + clearly synthetic stub/retention notice | NOT_RUN |
| M09 | Restore fixture, Reload | Stub disappears, exact three fixture entries return | NOT_RUN |
| M10 | Screen reader on specified Godot/platform | Actual text/control names announced | NOT_RUN |
| M11 | Large font/IME and very long CJK/ASCII text | Readable, no silent truncation or horizontal trap | NOT_RUN |
| M12 | Native shell embedding | Only after separately approved Control host exists | NOT_RUN |
| M13 | Static privacy review / commit diff | All changes in own folder; no original story or private chat | NOT_RUN |
| M14 | Performance budget (RAM/frame time) | Real measurements; no invented success | NOT_RUN |

## Future execution command — never run in this task

From the GitHub repository root after choosing an approved Godot version:

    godot --headless --path candidates/game_web_flow_char_004_r1 --script res://verify_profile_paging_candidate.gd

Evidence must include exact commit SHA, Godot version, OS, UTC timestamp,
stdout/stderr, exit code, case ID, expected and observed outcome, reproduction
steps, and image/log location. For M06/M08, use an isolated disposable copy
rather than mutating the authoritative branch. A new test source is
**NOT_RUN** until it actually executes.

**Status for every entry above: NOT_RUN.**
