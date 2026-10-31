# GAME-WEB-PLAY-REGION-005 r1 — Independent interaction flow extension

**Status: NOT_RUN. Proposed technical candidate. Not canon or an approved shared interface.**

## Actual inputs read, provenance and constraint

On 2026-10-29, PR #23 `cao772/game` was an open **Draft**, HEAD
`5ecac707f40bacaaaab10e574b97724ccebaabb6`,
branch `codex/game-web-flow-region-004-r1`, base `main`.
Read its real `flow_demo.gd`, `flow_model_candidate.gd`, copied PR #10
`interaction_prompt_candidate.gd` / `.tscn`, synthetic JSON,
two future QA scripts and README/DESIGN/ACCEPTANCE before editing.
This continuation edits **only that same independent candidate directory**.
The copied original PR #10 prompt remains byte-identical and untouched.
No actual game level, real character data, approved target interfaces or
interactable asset pipeline is present in the referenced draft.
Therefore the flow continues using A/B/C public synthetic cubes and
conservative planar picking; no fabricated canon or real-game action.

## Delivered implementation

| File | Scope |
| --- | --- |
| `target_picker_candidate.gd` | New pure selection helper: choose closest finite XZ marker hit within 0.52m, deterministic ID tie-break; returns explicit eligible flag |
| `feedback_journal_candidate.gd` | New bounded RefCounted journal, 12 in-memory items; monotonic local sequence, typed outcomes and defensive copies |
| `flow_demo.gd` | Expanded: left-click 3D cube selection via orthographic camera ray-plane intersection; proximity rejection; host previous/next/focus/world buttons; visually visible confirmation/refusal, feedback history, read-only debug snapshot |
| `verify_play_selection_candidate.gd` | Future-only 30 checks for pure picker + feedback buffer; NOT_RUN |
| `verify_play_scene_candidate.gd` | Future-only scene-level selection, confirmation, rejection, suppress/reopen and reset checks; NOT_RUN |
| `PLAY_ACCEPTANCE.md` | Additional input/visual/native + contract acceptance and evidence gates |
| `README.md`, `DESIGN.md`, `ACCEPTANCE.md` | Append-only continuation records, exact source base and rationale |

`flow_model_candidate.gd`, `synthetic_targets.json`, `main.tscn`,
`project.godot`, original PR #10 copied prompt and earlier QA scripts
remain unchanged.

## Independent click-to-select path

1. Left-click unhandled 3D viewport space. The transparent root UI
   overlay ignores background mouse input, while its child buttons and
   panels still receive their normal GUI events.
2. Convert mouse pixel to `Camera3D.project_ray_origin/normal`.
   Intersect with the synthetic cube center plane `y = 0.38`.
3. The pure picker checks finite XZ and valid radius, then finds the
   nearest cube center within the proposed `0.52` radius. Ties
   use lexical stable placeholder IDs.
4. If no marker was hit, return false; an unrelated floor click does
   not consume input or modify selection.
5. If a marker is hit but not in the model's current eligible set,
   or the prompt has been manually hidden, record a visible refusal.
   **Do not reopen automatically, select it, or confirm it.**
6. If the marker is eligible and prompt shown, locate its ID in
   `prompt_entries()`, call `prompt.select_target(index)`, let the
   existing `placeholder_changed` callback update the pure model,
   then grant focus to the prompt's action button.
7. **A click only selects.** Confirmation still requires a separate
   action/button/Enter/Space request. Model.confirm checks selected ID,
   current nearby set and physical distance again.

The click surface is a deliberately **planar picker, not physics
collider/raycast occlusion**. It is adequate only for three trial cubes
on one flat synthetic floor. A real game needs explicit scene targets,
collision/occlusion/range policy and an approved API before integration.

## Keyboard focus and navigation decisions

- Prompt's own Tab, Shift+Tab, PageUp, PageDown, Enter, Space and Escape
  remain in the pinned original PR #10 code, **not rewritten**.
- This continuation adds explicit host controls for previous/next,
  'focus prompt action' and 'release UI focus to world'.
- WASD synthetic marker movement is now blocked while one of the prompt
  controls owns keyboard focus, preventing accidental motion while
  browsing or confirming a target. Pause and native-window-unfocused
  gates still apply; focused LineEdit/TextEdit is also respected.
- A world-click on an eligible cube focuses the action button, making
  selection -> confirmation deliberate. A non-eligible click does not
  steal keyboard focus.
- Focus state shown in the inspector is read live from
  `prompt.focus_state()`, not reconstructed from stale signal order.
- No new keyboard 1/2/3/R mappings and no global InputMap changes.
  The other Draft PRs' input modules are not wired in.

## Feedback and bounded state decisions

A local journal collects:
`info`, `enter`, `leave`, `selection`, `success`,
`rejected`, `dismiss`, `reset`.
Each record is `{sequence, kind, message, target_id}`.
A record cannot contain an arbitrary ID: only empty or `placeholder_*`.
Display shows the latest six lines; total in-memory capacity is twelve
and old entries are dropped. Exported copies cannot alter the journal.
This is **UI feedback**, not a game event, audit trail, analytics service,
save, world-state write or timestamped narrative record.

The demo continues using the original model's internal
`confirm_count`. It only increments when the selected synthetic ID is
currently reachable and the prompt is not suppressed. Rejected attempts
do not increment. Reset discards the journal and adds one `reset`
notice. `flow_snapshot()` additionally exposes a defensive
`feedback_history` list and the current prompt `focus_role`
for local future tests only.

## Why these choices?

- **Click selects; another action confirms:** avoids accidental
  interaction and cleanly distinguishes pointer discovery from action.
- **Focus only goes to prompt after valid selection:** out-of-range
  clicks cannot hijack keyboard focus.
- **Use deterministic pure picker:** easy to reason about and QA without
  needing physics or an unapproved target discovery API.
- **Local rolling journal instead of global event bus:** user can see
  the exact recent result and denied actions without introducing
  save/event semantics or private telemetry.
- **Preserve pinned PR #10 prompt:** protects other Draft work and makes
  provenance and upgrade decisions explicit.
- **Unchanged source branch and baseline tests:** new revision is
  reviewable as one additive commit against the existing Draft PR.

## Open/unverified limitations

No Godot executable, import, script, tests, native input, renderer,
screenshot, CI or performance check has been run during this task.
The scene relies on actual Godot mouse routing and viewport focus
behavior that **must be inspected on a real window later**. In
particular, the full-rect GUI background pass-through, 3D projected
ray point, focus capture, font/layout at 1280x720 and release-focus
control are proposed and unverified. Screen readers, IME,
controller support, clipping and touch remain out of acceptance.

Host scene target geometry, final author-approved interactions, occlusion
and authoritative shared save/event interfaces are **missing inputs**.
They are explicitly not inferred from unmerged drafts. If integrated
later, dependency pinning, input arbitration, event meaning and narrative
review require separate owner approval. This PR remains Draft; no main merge.
