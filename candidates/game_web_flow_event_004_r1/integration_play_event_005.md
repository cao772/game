# GAME-WEB-PLAY-EVENT-005 r1 — independent synthetic preview overlay

**Status: NOT_RUN (development-only).** Nothing in this task was executed:
no Python imports, CLI commands, tests, lint, compile, Godot, CI invocations,
game scenes or live data access. This document specifies proposed behavior,
not a successful verification record.

## Input provenance

- Source repository: cao772/game, Draft PR #18.
- PR #18 HEAD read before development:
  819395fff9b694ac2b11e3b58485b24696f8128b.
- Stacked baseline: PR #9 branch codex/game-web-module-event-001-r1,
  public placeholder-only checker; no approved runtime contract.
- Updated branch only: codex/game-web-flow-event-004-r1.
- Original: event_flow_preview_candidate.py remains an independent static
  branch viewer; its original preview() semantics are not changed.
- This task adds requirements_for() as a read-only method of the *same
  preview candidate*, and the independent conditional play overlay. It
  never imports or modifies the formal Python EVENT002/Godot EVENT003
  execution candidates, shared bus, saves, scenes or authored story.

The PR #18 source defines only trigger.signal and trigger.conditions
(a list of IDs), and static actions[].next_event_id/optional
on_ignore_event_id. It **does not define per-action conditions, mutable
game state, token dedup, or accepted story effects**. This overlay does
not make them up.

## New/updated files (only within this PR's own candidate directory)

- event_play_preview_candidate.py: complete in-memory condition-gated
  navigation and detached snapshot CLI. No file writes, network or runtime
  event dispatch.
- test_event_play_preview_candidate.py: future synthetic unittest cases,
  not executed.
- event_flow_preview_candidate.py: one read-only requirements_for() access
  method; original preview()/options_for() preserved.
- integration_play_event_005.md: compatibility seam, CLI, risks,
  design choices and future validation instructions.
- acceptance_play_event_005.md: planned tests and evidence gate.
- README.md: task index, scope and link to docs.
- Existing synthetic fixture files remain byte-for-byte unmodified.

## Condition model: injected observations, not game conditions

A condition gate is computed per currently selected event:
- **required signal**: event.trigger.signal from a checker-approved,
  synthetic JSON event.
- **required conditions**: event.trigger.conditions from the same file.
- **observed signal**: externally supplied uppercase synthetic ID.
- **observed conditions**: externally supplied distinct list of uppercase
  synthetic IDs (0–16).

Gate is ready iff the observed signal matches the authored signal exactly
and all authored conditions are present in the observed set. Extra valid
observations are tolerated, but never treated as mutations or authored
triggers. An absent observation is **blocked**, not assumed true.
No automatic detection of real game state or scene objects occurs.

A blocked gate shows its authored configured_choices for read-only
inspection but available_choices is empty and choose is rejected with
CONDITIONS_NOT_MET plus required/missing data. It is only a preview
eligibility check. For linked targets, each new event must have a separately
injected observation. No target is automatically activated by visiting it.

## Navigation state: strictly ephemeral

- choose: select exactly an authored action ID or configured @ignore. The
  overlay checks the current gate; terminal/out-of-range and unknown choices
  are rejected without state mutation. No real event effect is executed.
- back: move the cursor backward by 1–24 recorded steps.
- forward: move through already recorded steps by 1–24 (not replaying
  runtime effects, only repositioning the in-memory view).
- jump: move to a recorded prefix cursor 0..history_length.
- choose after back/jump: truncate redo suffix and create a new purely
  synthetic branch trace. At most 24 selected steps in a path.
- observe: set an explicit synthetic event observation.
- clear_observation: remove an existing observation.

Observation updates invalidate old eligibility assumptions. If an
observation changes for an event in the *already selected prefix*, all
history resets conservatively to the start. Otherwise redo history is
dropped and the selected prefix is retained. An identical observation is
a no-op; errors are fully non-mutating.

No global singletons, runtime tokens, engine state, clocks, persistence,
disk snapshots, or side effects. The state is a temporary in-process
preview-session bookkeeping structure only.

## Snapshot and trace evidence (not a save game)

Each snapshot includes:
- preview_status = blocked / offered / terminal
- start_event_id/current_event_id, cursor, history_length, can_back,
  can_forward, recorded navigation history and selected prefix
- synthetic observations supplied by caller
- condition_gate with required/observed signals, missing conditions,
  requirement source JSON pointers and match result
- configured_choices (shown even when blocked) versus available_choices
  (only selectable when gate is ready)
- exact static trace from PR #18 preview(), its existing SHA256 and
  source snapshot SHA256
- state_snapshot_sha256 of deterministic detached snapshot fields
- no_runtime_effects, no_source_writes, no_persistence = true

These hashes are for reproducibility, **not cryptographic attestation or
proof of actual in-game execution**. Caller modifications to returned
snapshots cannot change internal candidate history/observations.

## Structured error echo

apply(command) always returns one of:
- APPLIED / UNCHANGED with a detached post-command snapshot, or
- REJECTED with structured code/message/details plus the **unchanged**
  prior snapshot. No exceptions for ordinary invalid user commands.

Prospective codes: INVALID_COMMAND, UNKNOWN_OPERATION, COMMAND_FIELDS,
UNKNOWN_EVENT, INVALID_SIGNAL, INVALID_CONDITIONS, INVALID_CHOICE,
CONDITIONS_NOT_MET, UNKNOWN_CHOICE, TERMINAL_LOCKED, STEP_LIMIT,
INVALID_STEPS, INVALID_CURSOR, CURSOR_OUT_OF_RANGE.

The CLI catches loader PreviewFailure from PR #9/18, echoes
STRUCTURE_CHECK_FAILED and its diagnostic report in JSON mode, and exits
nonzero without exposing unvalidated branch options. Malformed --command
JSON is returned as INVALID_COMMAND_JSON, not a traceback.

## Preview-only CLI contract (for future Codex validation; do NOT run yet)

From repository root on the stacked PR #18 checkout:

    python -B candidates/game_web_flow_event_004_r1/event_play_preview_candidate.py --event-id EVENT_START --format json candidates/game_web_flow_event_004_r1/fixtures

Without observations: the event remains blocked and only *configured*
choices are listed; this is a successful read-only inspection (exit 0).

Inject synthetic flags and choose a two-stage route:

    python -B candidates/game_web_flow_event_004_r1/event_play_preview_candidate.py --event-id EVENT_START --format json --command '{"op":"observe","event_id":"EVENT_START","signal":"SIGNAL_START","conditions":["FLAG_READY"]}' --command '{"op":"observe","event_id":"EVENT_NEXT","signal":"SIGNAL_NEXT","conditions":["FLAG_READY"]}' --command '{"op":"choose","choice":"ACTION_TO_NEXT"}' --command '{"op":"choose","choice":"ACTION_FINISH"}' candidates/game_web_flow_event_004_r1/fixtures

Other commands:
- {"op":"choose","choice":"ACTION_END"}
- {"op":"choose","choice":"@ignore"} only if configured
- {"op":"back","steps":1}
- {"op":"forward","steps":1}
- {"op":"jump","cursor":0}
- {"op":"clear_observation","event_id":"EVENT_START"}

Repeat --command in order. Shell quoting differs across Windows shell,
PowerShell and Unix. Commands are JSON *strings* sent in arguments; no
input command-file loader, auto-action policy, or game integration exists.
Maximum 64 commands per CLI call. Strict exact-key validation avoids
silently ignoring an unexpected command property.

The CLI always emits only a report on stdout. In JSON mode it contains
a final snapshot and per-command results; the first rejected command
stops subsequent execution. Exit 0 means accepted preview request
only; exit 1 means rejected preview command/input; argparse exits 2 on
invalid CLI options. Test results are **NOT_RUN**, not PASS.

## Design decisions, rationale, and tradeoffs

| Choice | Reason | Explicit tradeoff |
| --- | --- | --- |
| Condition model is signal equality plus required flags | Exact semantics supported by PR #9 JSON | No arbitrary expressions, predicates, action-specific gating or simulated live sensors |
| No observation means blocked | Avoid guessing success | CLI without observations lists configured but disabled branches |
| One read-only requirements_for() accessor | Avoid reaching into PR #18 private _events | Keeps base preview()/options_for() intact but adds unapproved candidate-only method |
| Session overlay instead of editing runtime | Protect all other windows and avoid shared interface approval | Not a real playable game or Godot UI |
| Recorded cursor + redo suffix | Back/forward/jump and branch fork are deterministic | Preview-only navigation, not runtime rollback |
| Reset on past observation change | Prevent stale successful trace from misleading a reviewer | Loses old synthetic route, intentionally conservative |
| All commands return error + unchanged snapshot | Helpful diagnostic feedback, non-mutating errors | Error messages do not infer intended action |
| Source trace reused from PR #18 | Exact reference/pointer provenance without duplicate event execution logic | Needs PR #18 and stacked PR #9 checker sources |
| No save files or emitted game events | No pollution of the actual game | Only an in-memory technical prototype |
| Synthetic fixture-only public evidence | Protect story/privacy boundaries | Cannot claim private schema compatibility |

## Restrictions and future integration seam

**No official shared interface is approved.** The only dependency chain is:

    PR #9 checked public placeholder JSON
       → PR #18 static CheckedEventPreview
       → event_play_preview_candidate.py (in-memory synthetic session)

For any future engine integration, an author-approved separate adapter must
define mapping of actual signal and conditions into this candidate model,
ownership of state, real event actions, dedup, failure handling, timestamps,
persistence and private schema protection. None of those mappings can be
inferred from these files, nor should this module be imported directly into
the game save/runtime.

The tool only displays ID tokens, file paths and hashes from selected
inputs. Even if a user were to supply private files, CLI reports may expose
their paths or identifiers. **Do not use private files in public PR
evidence.** Existing PR #9 checker input size/symlink/race limitations
still apply, and the source previewer remains best-effort against
concurrent file mutation (not a security boundary).

## Future acceptance

See acceptance_play_event_005.md. Codex must independently execute
synthetic tests after authorization, capture exact HEAD/version/exit code,
and distinguish structural checker status from true game verification.
All tests and runtime behaviors remain **NOT_RUN** for this development task.
