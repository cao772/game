# GAME-WEB-SHELL-006 r1 — synthetic target → event demo adapter

**DRAFT / SOURCE_SUBMITTED / NOT_RUN / NOT CANON / no approved shared API**

This continuation lives exclusively in the existing Draft
[PR #24](https://github.com/cao772/game/pull/24) branch
`codex/game-web-flow-shell-004-r1`. It extends the standalone candidate
without changing other PRs, shared interfaces, game history, original
manuscript, private story or any production save.

## Real deliverable

- `play_006/synthetic_target_event_map.json` — explicit, clearly labelled
  **PROPOSAL_NOT_CANON** fixture-only one-to-one mapping, not a story rule.
- `play_006/target_event_bridge_candidate.gd` — fixed-path read-only
  public-fixture validation, mapping resolution and fail-closed status.
- `play_005/event_preview_model.gd` — two **private** shell methods,
  `has_event(event_id)` and `start_at(event_id)`; nonexistent events never
  silently fall back to the default.
- `play_005/play_shell.gd` — actual region confirmation → validated event
  entry integration; bounded previous-module stack, clear return-to-menu,
  explicit status messages, repairable errors and mapped-event reset.
- `play_006/verify_shell_006_candidate.gd` — source-only future checks,
  never run.
- `play_006/DESIGN.md`, `play_006/ACCEPTANCE.md` — decisions, limits,
  test inventory and required future evidence.

All dependencies remain public synthetic candidate files from the preceding
PLAY-SHELL-005 revision. The working Godot entry remains
`project.godot` → `play_005/play_entry.tscn` (unchanged).

## Proposed mapping (demonstration only)

| PR #23 synthetic target ID | PR #18 public fixture event | Reason, not lore |
|---|---|---|
| `placeholder_a` | `EVENT_START` | Test starting event with multiple choices and optional ignore |
| `placeholder_b` | `EVENT_NEXT` | Test entering from an intermediate event |
| `placeholder_c` | `EVENT_END` | Test entering an end-node preview |

These relationships are **new technical proposals authored for this shell**;
the original PR #18/#23 sources contain no target→event map. The mapping is
not canon, not a world rule, not an implication that objects trigger these
events, and not a model for gameplay. Even successfully following the
mapping changes only in-memory UI state.

## End-to-end *candidate* behavior

1. Choose **合成灰盒 / 场景交互** from the existing main menu.
2. Move to, select and confirm a public PR #23 placeholder target in its
   isolated graybox. It must report `loaded=true`,
   `confirm_count>=1`, a valid `last_confirmed`.
3. Explicitly click the bridge button. The shell first loads the existing
   three fixed public PR #18 JSON fixtures, then reads the local mapping
   and target catalogue. It rejects malformed schemas, unknown targets,
   unknown events, duplicates, unapproved metadata, and absent resources.
4. Only after a valid match, `start_at(mapped_event_id)` selects an entry,
   clears the local event trace, and opens the existing event preview.
   Its status shows the **target ID, event ID, and proposal reason**.
5. The choices/ignore path remain governed by the existing
   `event_preview_model.gd`, with `checker_status=NOT_RUN`.
6. **返回上一模块** from event constructs a **fresh synthetic region**
   (does not restore a gameplay scene); from the read-only save browser it
   returns to the existing event preview with its current local trace.
7. **返回主菜单** is always available. It clears the module stack,
   approved-by-none mapping context, and last confirmed ID. Direct entry
   to the Event menu starts at `EVENT_START`, labelled *unmapped*.
8. **重新预览** restarts from the *mapped entry* when mapped, not blindly
   EVENT_START. This is local trace reset only.

Unknown or missing mappings stay in the region with a visible `BLOCKED`
message; they never route to a guessed event. Returning to the main menu
and then navigating again does not reuse an old target context.

## Explicit limits

- PR #18's Python checker still depends on PR #9 and **is not executed**.
  Local JSON checks are narrower than its source and must not be described
  as equivalent checker validation.
- PR #23 only exposes local confirmation counters and target ID; there
  is no approved event bus, narrative, ability, relationship or gameplay
  causal model.
- No event is written to a save. PR #20 remains an independent read-only
  browser requiring a manually supplied path; no automatic discovery.
- PR #19/15 input bindings do not dispatch an event. No InputMap, network,
  persistence, scene-asset export or global focus contract is added.
- Godot engine/platform version, SubViewport rendering/focus, source
  parser compatibility, CI, automated tests and native UI: **NOT_RUN**.
- No external contract approval or merge. The owner retains final review.

Do **not run** `verify_shell_006_candidate.gd` or launch Godot under
the current author's explicit no-execution instruction.

See [DESIGN.md](DESIGN.md) and [ACCEPTANCE.md](ACCEPTANCE.md).

`task_id=GAME-WEB-SHELL-006`; `version=r1`;
`input=PR24 HEAD e7a567d578156113d315282eac0e8dadc96e8590`;
`status=SOURCE_SUBMITTED/NOT_RUN/DRAFT`; `author_review=PENDING`;
`main=UNCHANGED`; `other_prs=UNCHANGED`; `Notion/Drive=NOT_WRITTEN`.
