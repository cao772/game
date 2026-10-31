# GAME-WEB-EVENT-006 r1 — Independent preview diagnostics and rollback

**Status: NOT_RUN.** No Python application code, imports, tests, compilation,
Godot, checker CLI, or CI run was initiated by this development task.

## Source and scope

- task_id: GAME-WEB-EVENT-006; version: r1.
- input_version: Draft PR #18 HEAD 673e62e5ffe05c977b6acce85b8e3c80b4029ca0.
- branch: codex/game-web-flow-event-004-r1, original Draft PR #18.
- upstream: public PR #9 head cfd28c5cd30a3c4c163abfde7a3eb9ebcd23eb50.
- scope: synthetic trigger-condition diagnosis, explicit preview rollback,
  path breadcrumbs and structured human/machine error display.
- exclusions: other PRs, main, author manuscript, story, scene runtime,
  real event executor, save, shared event interface.
- Deliverables: event_preview_diagnostics_006_candidate.py,
  test_event_preview_diagnostics_006_candidate.py, modified
  event_play_preview_candidate.py, README addendum and this design plus
  acceptance_event_006.md.

The real code of PR #18 was read first, including CheckedEventPreview,
SyntheticPlaySession, prior synthetic tests and integration docs. PR #9's
placeholder contract supports a trigger.signal, required trigger.conditions,
actions with static next_event_id, and optional on_ignore_event_id.
No per-action conditions, game effects, persistence, actual event state or
true story mechanics are defined. This extension deliberately invents none.

## Condition diagnostics

The existing EVENT-005 gate remains the sole eligibility decision.
A new pure helper explains the result without replacing it:

- OBSERVATION_NOT_SUPPLIED: no synthetic observation; fail closed.
- SIGNAL_MISMATCH: observed signal differs from the source trigger signal.
- REQUIRED_CONDITIONS_MISSING: observed flag set lacks required IDs.
- GATE_UNAVAILABLE: unexpected blocked gate, fail closed.
- READY: no blocking reasons; only for an already-ready upstream gate.
- TERMINAL: no further event link.

Every reason has a stable code and may point to the checked source
JSON pointer, file hash and line/column. Missing flags are enumerated;
extra observed valid flags are informational, not blocking. A missing
observation is represented as one cause rather than misleadingly
claiming multiple individual flags were wrong. Reason order is stable.
No live sensors or scene data are accessed.

## Navigation and history

- back/forward/jump: navigate recorded positions, retain redo.
- choose after back: truncate redo and append a new explicit selection.
- NEW rollback command: {"op":"rollback","cursor":N}. N must be an integer
  excluding booleans, between 0 and the current cursor inclusive.
  It discards the entire suffix, including redo. Future rollback target
  is rejected, not interpreted as forward.
- When a synthetic observation changes for a previously selected event,
  the safe prefix preceding its FIRST selected step is retained.
  Affected steps and suffix are discarded, with cursor positioned at
  the preserved prefix. A changed first-step observation still resets
  history to root. Changing only redo/unvisited events drops redo and
  preserves the current active prefix.
- A repeated identical observation is a no-op. Rejected commands are
  nonmutating.
- Per-operation navigation_effect describes policy, old/new cursor,
  discarded count, and affected event ID. This effect is not put into
  persistent snapshot state so back-then-forward can roundtrip exactly.

Snapshots add condition_diagnostics, navigation breadcrumb positions
(root, each recorded step, selected_prefix vs redo, rollback range)
and diagnostic_extension metadata. Existing trace SHA256 and source
snapshot SHA256 remain. The state snapshot SHA256 includes this new
detached presentation metadata. Breadcrumbs and observation history are
ephemeral preview bookkeeping, NOT real game event state or save data.

## Error presentation

Each ordinary rejected command still returns its original error object
and unchanged previous snapshot. Added error_view gives:

- code, category, title, message, conservative next review step;
- related source pointer/location for a blocked condition when available;
- current cursor and unchanged state snapshot SHA256;
- source_state_changed=false, auto_repair=false,
  manual_review_only=true.

Human text output now includes gate reason codes, source JSON pointers
and source line/column, navigation positions (including redo), discarded
steps and a readable error explanation. JSON output keeps existing fields
and adds new ones. Loader/checker errors and invalid command JSON have
safe presentation even without a session snapshot.

## Design decisions and reasons

| Choice | Reason | Limit |
| --- | --- | --- |
| Separate pure diagnostics helper | Do not mix explanations with the original parser or gate | Works only with this candidate |
| Preserve upstream ready status | No extra fictional condition semantics | No true game-state evaluation |
| Safe-prefix invalidation | Keep earlier independent steps without retaining stale choices | No general causal/dependency graph |
| Explicit rollback vs back | Separate irreversible discard from redo navigation | Not a save/engine rollback |
| Error view only, no patch generation | Clear diagnostics while preserving sources | No automated repairs |
| Per-operation effects, not global snapshot effects | Preserve deterministic roundtrip snapshots | Effects only visible in command response |
| Reuse checked source pointers/hashes | Trace back to public synthetic files | Hash is not proof of execution or attestation |
| No extra JSON fixture in checker input directory | Checker treats all JSONs there as event definitions | Use existing public placeholders |

## Future CLI example (DO NOT EXECUTE HERE)

Future checkout of PR #18 with stacked PR #9 sources:

    python -B candidates/game_web_flow_event_004_r1/event_play_preview_candidate.py --event-id EVENT_START --format json --command '{"op":"observe","event_id":"EVENT_START","signal":"SIGNAL_START","conditions":["FLAG_READY"]}' --command '{"op":"choose","choice":"ACTION_TO_NEXT"}' --command '{"op":"rollback","cursor":0}' candidates/game_web_flow_event_004_r1/fixtures

Back keeps redo; rollback removes it. A linked event needs a separately
injected synthetic observation to offer its own choices.
No real game action, save, network event or Godot execution occurs.
Python -B prevents typical interpreter bytecode cache writes in a later
authorized test. Shell quoting can differ by OS.

## Restrictions and evidence gate

- This turn: source created/updated on GitHub only. **NOT_RUN**.
- No file in PR #9 or main was changed. Existing fixtures and other
  windows' candidates are unchanged.
- The checker only validates the public placeholder format; no private
  EVENT001 schema compatibility can be inferred.
- The checker reopens disk files; its best-effort consistency checks
  are not transactional or a security boundary. Source paths/IDs may
  reveal private information if later pointed at private files; do not
  publish private input or output in public PR evidence.
- No gameplay time/state/token dedup/replay, effect system or shared event
  interface is established by these preview operations.
- Codex later must run the planned synthetic acceptance and all earlier
  regression tests, record real commands, exit codes, platform, failures,
  skips, fixture hashes, and author approval. Source readback alone is
  NOT evidence of test success.
