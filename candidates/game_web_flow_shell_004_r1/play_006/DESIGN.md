# GAME-WEB-SHELL-006 r1 — isolation design and rationale

All interface names are **private candidate seams**; none is an approved
game-level shared contract. Source authoring only, execution **NOT_RUN**.

## Exact original source reviewed

The current PR #24 head before change was
`e7a567d578156113d315282eac0e8dadc96e8590`
on `codex/game-web-flow-shell-004-r1`, targeting `main` as a Draft.
Its actual `play_005/play_shell.gd`, `event_preview_model.gd`,
`play_entry.tscn`, current acceptance and integration documents, real
PR #23 copied target catalogue/model and PR #18 copied event JSON fixtures
were fetched from GitHub at that commit before editing.

PR #23 pinned upstream reference
`5ecac707f40bacaaaab10e574b97724ccebaabb6`: public
`placeholder_a`, `placeholder_b`, `placeholder_c` and
`flow_snapshot()` with `loaded`, `confirm_count`,
`last_confirmed`. PR #18 pinned upstream reference
`819395fff9b694ac2b11e3b58485b24696f8128b`: three public JSON
fixtures `EVENT_START`, `EVENT_NEXT`, `EVENT_END`.
Neither PR defines a target/event relation. The three associations in
this delivery are **new explicitly labelled synthetic proposals**.

## Architecture

```text
PlayShell005 (existing PR #24 wrapper)
  ├─ menu / region  ── fixed PR #23 synthetic Node3D
  │     └─ explicit button → flow_snapshot() (read-only)
  │           └─ target_event_bridge_candidate.gd (SHELL-006)
  │               ├─ fixed region target JSON catalogue
  │               ├─ fixed synthetic_target_event_map.json
  │               └─ event_preview_model.has_event(...) 
  │                   └─ event_preview_model.start_at(mapped_id)
  │                        → event preview UI (no event bus)
  ├─ event → saves → return_previous() → same in-memory preview
  ├─ event → return_previous() → NEW synthetic region instance
  └─ any module → return_menu() → original menu and cleared route
```

## Private function semantics

- `target_event_bridge_candidate.prepare(event_model)`: explicitly read
  two **fixed** public res:// JSON resources; reject bad UTF-8/size/JSON,
  missing or extra mapping fields, duplicate target IDs, unknown target
  IDs or event IDs, missing approval flags, invalid schema versions and
  empty/too-long reasons. Any failure clears the stored lookup.
- `target_event_bridge_candidate.validate_document(...)`: pure
  negative-test seam, no registry mutation or real event dispatch.
- `resolve(snapshot)`: require actual bool `loaded=true`, an int
  `confirm_count >= 1`, and a String/StringName `last_confirmed`
  present in the validated mapping. A missing mapping is a hard block.
- `event_preview_model.has_event(event_id)`: only asks if a fixed
  public JSON event is present in its own loaded catalogue.
- `event_preview_model.start_at(event_id)`: atomic entry selection;
  rejects unknown values without altering the current event or trace.
- `_follow_region(blocked_override=null)`: actual UI pathway requires
  unpaused tree and native window focus, and uses an actual mounted
  PR #23 synthetic region snapshot. The optional focus override is
  a **future test seam only**, never an authorization or security gate.
- `_open_module(id, remember, restore_preview)`: one active screen,
  at most 16 previous module IDs, no history entries for same page.
  Explicit navigation resets the event model; navigating back to event
  from saves restores the same in-memory trace. Region return rebuilds
  the scene and clears old target provenance.
- `return_previous()`: pops history; empty history returns to the main
  menu (returns false for caller). `return_menu()` resets navigation,
  mapping metadata, last confirmed target and transient event preview.
- `_reset_event()`: restarts from the mapped event if one is recorded;
  otherwise from the fixed public EVENT_START. An invalid mapped ID is
  **BLOCKED**, never silently substituted.
- `navigation_snapshot()`: read-only copy of candidate UI navigation
  state, including its clear `NOT_APPROVED` marker.

## Design choices and rejected alternatives

| Decision | Reason | Alternative avoided |
|---|---|---|
| JSON explicitly `candidate_only=true`, `NOT_APPROVED`, `PROPOSAL_NOT_CANON` | Nobody has approved actual event triggering semantics | Adding lore or claiming canonical target relationships |
| Map A/B/C to START/NEXT/END | Covers start, middle and final nodes with only public synthetic inputs | Deriving story events from room objects or characters |
| Strictly check map against *both* existing public fixture sets | Stops typo/unknown ID from silently becoming default event | Mapping unverified strings or auto-discovering files |
| Button-confirmed transition | Native focus/pause and user action remain explicit | Automatic event dispatch from a prompt signal |
| Reject unknown with no fallback to EVENT_START | Keeps missing dependency visible | Hiding gaps behind a misleading successful transition |
| Add only two methods to local event preview model | Minimal change to existing PR #24, no shared event API | Editing PR #18/23 or copying Python checker |
| Bounded previous-module navigation | Avoids stale/reentrant history; keeps menu return deterministic | Global state-stack/serialization design |
| Reconstruct graybox on return | Its scene persistence contract was never approved | Pretending to restore a saved player position |
| Preserve local event trace when returning from read-only saves | Prevents losing what user was previewing without persisting it | Writing event history into snapshot files |
| Keep full PR #18 Python checker NOT_RUN | It needs the PR #9 Python dependency; Godot bridge cannot claim parity | Duplicating a partial validator and calling it approved |
| Never write or load private resources | Strict separation from manuscript, characters, real saves | Publishing source text or inventing extra game facts |

## Failure matrix

| Fault | Expected UI | Effects |
|---|---|---|
| No region instance, absent `flow_snapshot` | BLOCKED on region | No event, no signal |
| Region snapshot wrong type/unloaded/zero confirmations | BLOCKED on region | No change of active module |
| Godot window unfocused or tree paused | BLOCKED on region | No event entry |
| Event JSON missing/malformed | BLOCKED on region | No default event substitution |
| Mapping JSON absent/malformed/duplicate/unknown entry | BLOCKED on region | Bridge clears candidate lookup |
| Mapped event ID missing | BLOCKED on region | Event trace not changed by `start_at` |
| Event navigation rejected | Remain on region, BLOCKED | No synthetic confirmation signal |
| Region return after mapped event | New graybox | Old mapping context cleared |
| Save-browser return | Event preview restored from memory | No snapshot write, no auto path discovery |
| Main-menu return | Menu restored | History/context/last ID reset |
| Missing other module scene/method | BLOCKED with return-menu available | No silent game fallback |

## Known gaps and limitations

This is a **source-level integration proposal**, not evidence that Godot
parses, UI renders, signals fire, or native 3D focus works. The PR #23
SubViewport is unchanged, PR #20 is still only a manual read-only file
browser, and PR #18's Python checker has not been implemented in Godot.
There is no approved mapping ownership, event bus, game clock/snapshot
writer, keyboard priority, runtime persistence contract, or canon.
Security cannot be established by method-presence or JSON validation alone.

No code execution, tests, Godot, CI, screenshots or benchmarks performed.
**ALL NOT_RUN**, pending author's final acceptance.
