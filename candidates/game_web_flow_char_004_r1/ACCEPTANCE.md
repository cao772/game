# Future acceptance plan — GAME-WEB-FLOW-CHAR-004 r1

**All cases NOT_RUN.** This is a development-only submission; the source
check script \`verify_profile_flow_candidate.gd\` is not an executed test.
Do not call any result PASS before independent Godot verification.

## Synthetic in-memory model and transition checks

| ID | Proposed case | Acceptance condition | State |
| --- | --- | --- | --- |
| F01 | Empty new model | list route, count 0, no selection | NOT_RUN |
| F02 | Non-array input | Reject, no existing record lost | NOT_RUN |
| F03 | Valid two-record array | Accept exact #14-format data | NOT_RUN |
| F04 | Caller mutates dictionary after set | Stored/visible copy unchanged | NOT_RUN |
| F05 | Invalid second record | Entire replacement rejected atomically | NOT_RUN |
| F06 | Duplicate profile_id | Reject atomically, no partial list | NOT_RUN |
| F07 | Unknown ID | Cannot enter detail | NOT_RUN |
| F08 | Known ID | Enter detail and expose stable ID | NOT_RUN |
| F09 | Caller mutates selected-profile copy | Internal record unaffected | NOT_RUN |
| F10 | Back from detail | list route, no record mutation | NOT_RUN |
| F11 | Second Back in list | No-op / returns false | NOT_RUN |
| F12 | Case-insensitive name/filter | Expected subset in original order | NOT_RUN |
| F13 | Filtered-out ID | Rejected while not visible in list | NOT_RUN |
| F14 | New search while detail active | Return to list; discard selection | NOT_RUN |
| F15 | Search beyond 80 characters | Reject, keep previous query | NOT_RUN |
| F16 | Valid empty collection | Empty list with no details | NOT_RUN |
| F17 | Bounded 24-entry collection | Accept at limit, reject 25 | NOT_RUN |

## Standalone UI and #14 renderer

| ID | Proposed case | Acceptance condition | State |
| --- | --- | --- | --- |
| F18 | Instantiate flow scene | No engine parser/runtime errors | NOT_RUN |
| F19 | Set synthetic profiles | List buttons created once per record | NOT_RUN |
| F20 | Click/focus profile row | Detail panel instantiated from pinned scene | NOT_RUN |
| F21 | Open a different record | No stale first profile, correct title/content | NOT_RUN |
| F22 | Detail Back button | Return to list, search remains usable | NOT_RUN |
| F23 | Unknown ID / stale row | No detail state mutation or crash | NOT_RUN |
| F24 | Text search / no match | Correct filtered rows and visible empty state | NOT_RUN |
| F25 | Bad replacement after valid list | Previous list remains, rejection signaled | NOT_RUN |
| F26 | Exit button | Exactly one exit_requested; no shell call | NOT_RUN |
| F27 | Missing panel PackedScene in disposable copy | List/back usable; visible error + retry | NOT_RUN |
| F28 | Restore panel and retry | Detail becomes visible without replacing list data | NOT_RUN |
| F29 | Malformed panel root / missing methods | Factory rejects without inserting bad node | NOT_RUN |
| F30 | Fixed fixture unavailable / malformed UTF8 | Fail closed; no story data substituted | NOT_RUN |
| F31 | Three pinned synthetic fixtures | List/detail switching without private data | NOT_RUN |
| F32 | Long multilingual summary with long ID | Complete text available through detail scroll | NOT_RUN |
| F33 | Repeated set_profiles + back + switch | No stale rows, duplicate signals or orphan nodes | NOT_RUN |

## Keyboard, responsive layout, shell and safety

| ID | Proposed case | Acceptance condition | State |
| --- | --- | --- | --- |
| H01 | Keyboard Tab/Shift+Tab through list | Reach search, list rows, Back and Exit | NOT_RUN |
| H02 | Native Enter/Space on list button | Opens correct detail without mouse | NOT_RUN |
| H03 | Back activation from detail | Focus returns to usable list/search control | NOT_RUN |
| H04 | Detail section selector/scroll keys | #14 native reading functions preserved | NOT_RUN |
| H05 | Escape/game key elsewhere | No global key interception or gameplay request | NOT_RUN |
| H06 | 320x240 narrow layout | List and detail each accessible one at a time | NOT_RUN |
| H07 | 700px breakpoint | Consistent switch to two-column master/detail | NOT_RUN |
| H08 | 1060x720 wide view | List and detail both readable; scroll available | NOT_RUN |
| H09 | Long CJK/Latin, large fonts, IME | No lost text, overlap or keyboard trap | NOT_RUN |
| H10 | Screen reader (OS/Godot specified) | Spoken labels/focus independently observed | NOT_RUN |
| H11 | Shell #17 trusted mock adapter | Registry accepts synthetic preview and request shape | NOT_RUN |
| H12 | Shell #17 disabled/pending/missing profile slot | No real UI loaded, graceful status | NOT_RUN |
| H13 | Host embeds Control with exit signal | Host decides route; module never calls shell | NOT_RUN |
| H14 | Source diff and SHA audit | Only own candidate directory; pinned copies unchanged | NOT_RUN |
| H15 | Privacy/canon audit | No manuscript, real character facts, private images or transcripts | NOT_RUN |
| H16 | Performance, memory and scrolling | Evidence measured; no invented benchmark | NOT_RUN |

## Evidence and execution boundaries

The future verification harness is a finite GDScript SceneTree source file:
\`verify_profile_flow_candidate.gd\`. A future independent verifier with
Godot 4 can try:

    godot --headless --path candidates/game_web_flow_char_004_r1 --script res://verify_profile_flow_candidate.gd

On success, the script intends to print \`PASS GAME-WEB-FLOW-CHAR-004 r1\`
with exit status zero. Nonzero/parser/engine failures must be recorded
as real outcomes. **These output expectations are not observed evidence.**

Manual cases require a native desktop/screen reader session; the headless
script cannot certify UI layout, focus visibility or integration with a
different Draft's shell. Future audit record per case: task/version, exact
commit SHA, Godot version, OS, command, UTC time, observed/expected, exit
code, stdout/stderr/screenshot, reproduction steps and evidence location.
No private source or raw chats should be added to public GitHub.

## Known blockers

- Exact target Godot 4.x minor and supported OS/IME/screen reader unknown.
- Shell PR #17 has no Control mounting area in its current public source;
  real UI integration requires its own future reviewed change.
- No public approved character data source, design tokens, font/contrast
  acceptance criteria or shared interface.
- Project is intentionally source-only and unverified until author review.

**Execution status: NOT_RUN. No code, tests, Godot editor, CI or benchmark
was run during this request.**


---

## GAME-WEB-PLAY-CHAR-005 r1 future acceptance

**All statuses NOT_RUN.** The new candidate source-level checks, native
manual keyboard/accessibility and missing-resource procedures are fully
listed in [PLAY_005_ACCEPTANCE.md](PLAY_005_ACCEPTANCE.md) with
`verify_profile_play_candidate.gd`. Existing
`verify_profile_flow_candidate.gd` also requires an independent
regression run after these changes. Writing those scripts is not running
them; do not record PASS without engine logs and real evidence.

Future-only invocation (not executed here):

    godot --headless --path candidates/game_web_flow_char_004_r1 --script res://verify_profile_play_candidate.gd

**GAME-WEB-PLAY-CHAR-005 r1: NOT_RUN.**


### 005 demo source additions

The new future-only `verify_profile_play_candidate.gd` also proposes
P29–P33 demo resource recovery assertions, while manual G20 reviews
small-screen fallback and the static retry control. No actual test
execution occurred; all remain NOT_RUN.


---

## GAME-WEB-CHAR-006 r1 future verification additions

See [CHAR_006_ACCEPTANCE.md](CHAR_006_ACCEPTANCE.md) and the new
\`verify_profile_paging_candidate.gd\`. All its documented pagination,
boundary, off-page ID, focus restore, synthetic resource fallback and
read-only degraded-detail cases are **NOT_RUN**.

Before any release or merge the independent reviewer must verify this
new suite *and* all prior 004/005 suites, then perform native keyboard,
long-text, missing PackedScene, malformed fixed synthetic fixture and
large-font/IME checks in a disposable copy. Require exact commit/engine
version, expected versus observed, logs, exit codes and screenshots.
Do not promote to PASS based on source inspection or expected output.

The user requested development only; **no tests were run**.
