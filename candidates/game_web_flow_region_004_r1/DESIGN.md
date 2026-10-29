# Design decision record — GAME-WEB-FLOW-REGION-004 r1

**Proposed; NOT_RUN.** All new functionality is experimental and isolated.

## Functional modules and why

| Layer | Implementation | Responsibility | Rationale |
| --- | --- | --- | --- |
| Data | `synthetic_targets.json` | Three fake XZ points A/B/C; versioned schema | Inspectable public-only example, no manuscript exposure |
| Model | `flow_model_candidate.gd` (`RefCounted`) | Target validation, sorted proximity, enter/exit, selection, confirmation, suppression, snapshot | Deterministic logic independent of graphics and OS focus |
| Prompt | pinned `interaction_prompt_candidate.*` | UI display, focus, multi-target navigation and action emission | Reuse exactly the current PR #10 candidate without changing it |
| Coordinator | `flow_demo.gd` | Binds model to prompt; draws procedural floor/markers; provides local buttons | Keeps flow isolated and enables future automated scene checks |
| Evidence | two `verify_*.gd`, `ACCEPTANCE.md` | Future pure-model and scene/UI acceptance; no execution yet | Prevents code submission being misreported as verified gameplay |

## Target entry and validation

`synthetic_targets.json` has `schema_version: synthetic-targets-v1`
and `targets` array. Each record requires unique `placeholder_*` ID
(<=64 chars), nonblank `label` <=64 chars, optional nonblank
`action_caption` <=40 chars, finite XZ coordinates within the
independent ±5 m X, ±4.2 m Z trial plane (with marker margin).
1–16 target records maximum. The entire catalog is rejected on any
invalid record, with **no partial exposure**. No real scene nodes,
characters, identifiers, names, dialogue, time, combat, inventory
or event payload fields are supported.

The JSON contains 3 synthetic points at x = -1.2 / 0 / +1.2, z = 0.
This deliberately allows a *small overlap* of A and B proximity near
(-0.6, 0), useful to validate multi-choice UI, without claiming this
geometry exists in the real game.

## Proximity and transition semantics

1. Scene hands a world-planar Vector2(X,Z) to `move_player`.
2. Clamps position to the synthetic floor.
3. Each target not previously eligible enters at distance <=1.55 m.
4. Each target previously eligible remains until distance >1.85 m.
5. Eligible targets sort nearest-first; ties within 0.0001 m use ID
   lexicographic order. Membership order changes can update the
   prompt without creating a confirmation.
6. Existing selected ID is preserved if still eligible; when it
   disappears, nearest eligible target is chosen, or none if empty.
7. Explicit `mark_selected(id)` accepts only eligible IDs.
8. Confirmation requires ID == current selected AND membership AND
   a fresh distance check <=exit radius. It returns a purely local
   feedback record and increments only a local integer.
9. Manual dismiss suppresses auto-prompt while *any* target remains
   nearby. Suppression resets on leaving **all** targets, not on every
   target switch. A separate re-open control explicitly clears it.

**Why two radii?** Avoid rapid show/hide jitter near a sharp threshold.
**Why ID-preserved selection?** Prevent stale index confirming a
different target as the list reorders. **Why no auto-confirm?**
The user must explicitly activate the prompt. **Why suppression?**
Hiding Escape should not be undone by the next movement frame.

Distances, positions, input keys, color, move speed and hysteresis
are proposals; the author has not approved them.

## State ownership and UI synchronization

`FlowModel` owns eligibility, current ID, dismissal and local feedback.
PR #10 prompt owns visible widget focus and selected Button action.
The scene coordinator is the only crossing point:

- On eligibility changes: show prompt, sync its list using stable
  selected ID, or hide programmatically.
- When prompt emits `placeholder_changed`: model validates and
  records the selected eligible ID, then updates marker highlighting.
- When prompt emits `interaction_requested`: model separately
  checks selected ID and current eligible range before giving feedback.
- When the prompt is dismissed by its own controls, coordinator
  records manual suppression. Programmatic hide on leaving all uses
  a scoped guard to avoid creating a false manual-dismiss flag.
- A publicly readable `flow_snapshot()` test seam exposes only
  local trial data, not a game state/save contract.

The model never reads or writes user:// or files. The scene reads one
static JSON fixture at startup and never writes files or networking.
There is no persistence or approved cross-candidate protocol.

## Visual and navigation proposal

A fixed overhead trial camera, a single floor and box primitives are
generated in code with built-in Godot materials. A blue player marker
moves on XZ; eligible cubes turn green; currently selected one turns
amber. UI includes the current X/Z, nearby IDs, selected ID, prompt
visible flag, local confirmation count and text feedback. There are
no textures, characters, NPCs, novel cues, or imported real regions.

**Reason:** satisfies spatial approach/leave and observable feedback
without copying unfinished bedroom scenes or using paid assets.

## Limitations and failure behavior

- **No real 3D physics:** no collision/navmesh, perspective character
  controls, occlusion, raycast target detection or animation.
- **No true "player":** a 3D marker + Vector2 plane motion only.
- **No runtime basis:** Godot import, GDScript parsing, focus, GUI
  clipping, GPU viewport and future tests are explicitly NOT_RUN.
- **No real scene source available on main:** use an isolated synthetic
  trial rather than silently invent a canonical bedroom or target.
- **No approved dependency contract:** pinned PR #10 source might
  change. This draft intentionally duplicates two exact files to
  stay runnable independently of unmerged PRs; future upgrade
  requires author/Codex provenance review.
- **No InputMap/event/save integration:** PR #6/#15/#17 are separate
  Drafts. Reusing them or asserting shared compatibility would
  exceed this task. In particular Escape priority is unresolved.
- **Invalid catalog:** fail closed with an explicit BLOCKED status.
  No fallback story content or hidden fake target is generated.
- Multiple prompts, multiplayer, accessibility, localization, IME,
  native loss/restore focus and controller layouts are not accepted
  or tested by this candidate.

## Decisions left to final author acceptance

Approve/discard the candidate; later optionally decide how to adapt
synthetic motion to real scene target discovery, real input arbitration,
UI visual style, approach distance and actual interaction semantics.
None of those decisions is implied by this code submission.

---

## GAME-WEB-PLAY-REGION-005 r1 — design addendum (NOT_RUN)

Actual PR #23 code was read before editing, and improvements were
selected without changing original scene/model semantics.

1. **Click selects rather than confirms.** A ray from the fixed trial
   camera is intersected with a synthetic cube-center plane and sent to
   a pure nearest-ID picker. Confirmation remains an explicit second
   step through the pinned prompt. This prevents accidental clicks from
   mutating the local confirmation count.
2. **Out-of-range clicks reject visibly.** The picker identifies even an
   ineligible displayed cube, but the coordinator refuses selection,
   confirmation or focus transfer until actual model proximity permits.
3. **Prompt focus has priority over movement.** Background WASD is
   suspended while the prompt owns keyboard focus; explicit host controls
   can return focus to the synthetic world and move selection backward
   or forward. Existing focus/Escape logic in the pinned PR #10 prompt
   remains unmodified.
4. **Feedback is local and bounded.** A 12-entry in-memory journal
   records only coarse synthetic outcomes and the optional placeholder
   ID. It is neither a shared event API, timestamped game history,
   save format nor private telemetry.
5. **All geometry is still synthetic.** The 0.52m click radius, viewport,
   marker material colors and UI history size are trial proposals. No
   canonical bedroom/object placement is implied.

See `PLAY_EXTENSION.md` and `INTEGRATION.md` for detailed routing,
limitations, missing real-scene inputs and the final owner review gate.
This is **NOT_RUN**, not functional/visual acceptance.
