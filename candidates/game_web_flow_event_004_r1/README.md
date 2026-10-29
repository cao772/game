# GAME-WEB-FLOW-EVENT-004 r1 — independent checked event-flow preview candidate

**Status: NOT_RUN.** Draft technical proposal only. No Python, Godot, CLI,
lint, type-check, tests or CI was run by this development task.

## Scope and original sources reviewed

This new candidate builds on GitHub
[Draft PR #9](https://github.com/cao772/game/pull/9), read at HEAD
<cfd28c5cd30a3c4c163abfde7a3eb9ebcd23eb50>, including its current:
- event_data_check_candidate.py (bounded input file selection, strict JSON
  structure, duplicate IDs and reference checks),
- event_source_diagnostics_candidate.py (line/column and JSON pointer source
  lookup),
- event_repair_advice_candidate.py (review-only suggestions),
- README and existing placeholder fixtures, plus EVENT-003 acceptance design.

PR #9 contains a **public, experimental synthetic JSON contract**, not the
private EVENT001 schema and not the approved game runtime. The previewer
refuses nonconforming inputs instead of inventing a schema adapter. Only
placeholder event IDs and flags have been committed. There is no narrative
text, character data, private evidence, or user manuscript in this candidate.

## Repository and dependency choice

This is a **stacked, independent codex/ branch** based on the exact
unmodified PR #9 head. The new Draft PR targets
codex/game-web-module-event-001-r1, NOT main. This deliberately avoids
copying/checking in another revision of the checker or modifying PR #9;
the new PR diff contains only files inside:

    candidates/game_web_flow_event_004_r1/

The previewer imports the public checker and source-location indexer
from the *sibling PR #9 directory*. It is **isolated from all real game
runtime/event bus/save/scene code**, but its prospective use depends on
the pinned public checker contract. If PR #9 is changed, merged, or
removed, its checker compatibility must be separately re-verified.
Without the sibling public checker directory the module fails explicitly
rather than bypassing the validation gate.

## New files

- event_flow_preview_candidate.py — complete read-only Python 3.12+
  standard-library CLI and in-memory flow preview model.
- test_event_flow_preview_candidate.py — future synthetic unittest cases
  only (NOT_RUN).
- fixtures/placeholder_start.json, placeholder_next.json,
  placeholder_end.json — synthetic 3-event graph with two actions, an
  explicitly configured ignore branch and terminal/null targets.
- README.md — format, design, usage and limitations.
- acceptance.md — detailed future acceptance cases and decision record.

## Preview behavior (NOT a runtime implementation)

1. Accept an explicit directory or list of JSON files; resolve only files
   selected under the PR #9 checker rules (max 1,024 files, 1 MiB each,
   reject symlinks). A file set with missing target definitions fails.
2. Call the unchanged PR #9 check_event_data() gate. **Only if report
   status is PASS** may an event be listed or its branch choices shown.
   Invalid structure, duplicate IDs, bad references and ambiguous targets
   produce REJECTED with checker diagnostics, no partial preview.
3. Build an in-memory collection of event definitions and source pointers
   using bounded reads. Re-read and compare bytes and selected file paths
   around validation; reject detected concurrent changes. This is a
   best-effort consistency check, not transactional/TOCTOU protection.
4. Start at an explicit event ID. Present configured actions **in source
   order**, plus @ignore only if on_ignore_event_id explicitly exists.
   A null reference means the preview has reached a terminal link;
   this does not assert any gameplay/combat/story outcome.
5. With no --choice arguments, show available branches. Repeat --choice
   to walk a sequence of **explicit** user-selected references. Never
   auto-follow or auto-activate a target event. After each selected link,
   show what other options are available at the resulting event ID.
6. Reject unknown selection, invalid start, extra choice after terminal,
   bad input or >24 selected steps as a failed request. Same-ID self
   references/cycles are allowed syntactically and require an explicit
   choice for every step. No recursion, replay, dedup, state-machine
   semantics or time-loop explanation is inferred.
7. Produce a deterministic trace with step, from_event_id, selection,
   to_event_id, terminal/linked label, source file SHA256, JSON pointers
   and line/column source information for source, target reference and
   linked target definition. Include selected-file snapshot SHA256 and
   trace SHA256 for local reproducibility. These hashes are NOT signatures
   or proof that an event really executed.
8. stdout-only text or JSON report. No file writes, story output, event
   effect execution, save calls, shared interface, scene imports,
   network, image UI or any real game mutation. Preview results are
   freshly calculated for every call.

## Prospective CLI (do not run during the current development stage)

From repo root, after Codex is authorized to execute:

    python -B candidates/game_web_flow_event_004_r1/event_flow_preview_candidate.py \
      --event-id EVENT_START \
      candidates/game_web_flow_event_004_r1/fixtures

To preview a deliberate two-link selection:

    python -B candidates/game_web_flow_event_004_r1/event_flow_preview_candidate.py \
      --event-id EVENT_START \
      --choice ACTION_TO_NEXT --choice ACTION_FINISH \
      --format json \
      candidates/game_web_flow_event_004_r1/fixtures

To preview the explicit ignore branch:

    python -B candidates/game_web_flow_event_004_r1/event_flow_preview_candidate.py \
      --event-id EVENT_START --choice @ignore \
      candidates/game_web_flow_event_004_r1/fixtures

To select a different event from the same validated file set, change
--event-id. --choice is intentionally repeated in order; omitted --choice
only lists branches. All files in the selected set must pass PR #9 checks
before **any** preview result is generated.

### Output and exit convention

A successful preview returns status=offered or terminal and exit 0,
checker_status=PASS, available_choices and trace entries. That PASS is
the checker contract for synthetic files, not a scene test.
Rejected user selection or checker failure produces exit 1 and a
structured REJECTED error in JSON mode. CLI argument errors return 2
through argparse. Input paths and content hashes are included in trace;
do not post previews of private files in a public issue.

## Design decisions and rationale

| Choice | Rationale | Explicit limitation |
|---|---|---|
| Python CLI, no Godot UI | Existing checker is Python; fastest isolated non-runtime preview with full trace and no scene dependencies | No graphical widget, Godot runtime integration or in-engine event execution |
| Stacked PR based on #9, separate directory | Reuse checker unchanged without duplicating or overwriting it, keep review diff small | Requires the PR #9 candidate branch as base and sibling library |
| Gate on status PASS before listing any choices | Ensure the same public candidate contract is verified | No private EVENT001/real-world schema support |
| Require explicit event ID and explicit choices | Never guess gameplay defaults or implicitly traverse links | No autoplay or game loop |
| Only expose @ignore when the field exists | No new branch for unconfigured behavior | Null explicitly configured ignore is terminal |
| Source-order action options and stable JSON trace | Reviewer can check exactly which synthetic definition and pointer generated a result | Not a rendered game sequence |
| Snapshot/trace hashes from byte content | Reproducibility and provenance without exposing raw source | Not tamper-proof or transactional |
| 24 step cap, no recursion or effects | Avoid unbounded previews even with graph cycles | No detection of canonical loop semantics |
| Read-only, stdout-only | Protect source and other project work | Python import may create interpreter __pycache__ without -B |
| Structure failure aborts whole preview | Never show potentially misleading partial branches | Manual correction via PR #9 checker, not automatic repair |

## Pending review and limits

- PR #9 checker itself was NOT_RUN for this task. Compatibility is an
  implementation assumption anchored to the fetched GitHub source,
  not a claim of actual test success.
- File reads are not a security boundary; race conditions between validation
  and use can remain even with byte comparison. Never use as an input
  sandbox for malicious untrusted data.
- No private events are present, and no private event schema, shared
  event bus, runtime token, state, save, performance or story is approved.
- Python is a developer preview; Godot 4.7.2 functionality is not proven
  or asserted.
- A standalone package without the PR #9 library is outside scope.
- No branch of PR #9 or main was changed; no user manuscript was touched.

**Handoff:** Codex must later execute the checker and previewer with
synthetic cases, record exact HEAD SHA, Python version, exit codes,
stdout/stderr, changed file hashes, actual pass/fail counts and input
immutability. Until then: **NOT_RUN**.

See [acceptance.md](acceptance.md).


## GAME-WEB-PLAY-EVENT-005 r1 — conditional navigation overlay (NOT_RUN)

Adds a complete standalone Python overlay to this Draft PR's existing public
synthetic flow viewer. The original source checker, existing public fixture
JSON and original preview() semantics remain unchanged.

New files:
- event_play_preview_candidate.py — injected signal/conditions gate,
  explicit branch navigation (choose/back/forward/jump), temporary
  observation state, detached snapshots and structured error echoes.
- test_event_play_preview_candidate.py — future assertion suite, NOT_RUN.
- integration_play_event_005.md — dependency chain, documented decisions,
  condition limitations and future integration boundary.
- acceptance_play_event_005.md — planned verification matrix/evidence gate.

The existing event_flow_preview_candidate.py gets only a read-only
requirements_for(event_id) metadata accessor. It has no new event effects.

**Condition semantics are deliberately conservative:** The PR #9 public
format has trigger.signal and trigger.conditions but has NO authored
per-action predicates, effect state, replay token contract or shared bus.
This overlay requires explicit synthetic observed signal and flag IDs
from the caller. Without matching inputs, choices are displayed as
configured but are not selectable. It does not invent missing logic.

The state snapshot is ephemeral and strictly a preview cursor/history.
Recorded navigation can go backward or forward, fork from a prior step,
and recalculate the visible synthetic branch list. A changed observation
invalidates stale history as documented. No source write, real event
runtime, save file or time effect occurs.

Future local CLI sketch (NOT executed here):

    python -B candidates/game_web_flow_event_004_r1/event_play_preview_candidate.py --event-id EVENT_START --format json --command '{"op":"observe","event_id":"EVENT_START","signal":"SIGNAL_START","conditions":["FLAG_READY"]}' --command '{"op":"choose","choice":"ACTION_TO_NEXT"}' candidates/game_web_flow_event_004_r1/fixtures

Run later ONLY after Codex is authorized. It is normal for the linked
EVENT_NEXT preview to be blocked until a separate synthetic observation
for that event is provided. CLI returns structured JSON/text error
messages and an unchanged snapshot for invalid requests.

For detailed integration and acceptance, see
[integration_play_event_005.md](integration_play_event_005.md) and
[acceptance_play_event_005.md](acceptance_play_event_005.md).

**Status: NOT_RUN.** No application execution, tests, imports, Python compile,
CLI, Godot or CI were intentionally performed for EVENT-005. Readback of
GitHub sources confirms only submitted content, not successful behavior.
No main merge, private story publication or shared interface approval.
