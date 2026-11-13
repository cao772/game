# Technical baseline audit — runtime foundation v1

Date: 2026-11-03. Review mode: source reading only, using pinned Git objects. No Godot import, script execution, tests, CI, deployment or benchmark was performed. Prior PR descriptions and historical test counts are not evidence that this new foundation runs.

## Source versions actually inspected

| PR | Pinned commit | Files read (full file or relevant portions) |
| --- | --- | --- |
| #2 | `cb0026ec668b96832efed5bf452a90548bc31c20` | `prototypes/save_candidate.py` |
| #6 | `f5143fb72db6083cab6364b8caa5daf7d6995dc2` | `candidates/game_web_integrate_001_r1/integration_candidate.gd` |
| #8 | `5a0bce07e5eafcd4081acaf446d67e3caf35934c` | `prototypes/recovery_flow_candidate.py` |
| #9 | `cfd28c5cd30a3c4c163abfde7a3eb9ebcd23eb50` | `candidates/game_web_module_event_001_r1/event_data_check_candidate.py` |
| #18 | `31bee7fa4a130186c6b889b918712fafa2de84c8` | `candidates/game_web_flow_event_004_r1/event_flow_preview_candidate.py`, `event_play_preview_candidate.py` |
| #33 | `8394140bccd34918a98c43762fe184f8f0517d55` | `candidates/game_web_region_025_r1/menu_flow_owner.gd`, `keyboard_grid.gd` |
| #34 | `ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a` | `candidates/game_web_region_026_r1/menu_flow_owner.gd`, `project.godot` |
| #36 | `19872d27e2a90c334ac2e3fa1d7bd502a220f008` | `candidates/game_web_region_028_r1/event_preview_model_candidate.gd`, `event_preview_screen.gd` |

Line references below are to these exact versions, not to the new runtime files. The current `main` baseline inspected is `533b11f50c0d359cd0a5424d5216b0145727699a`; its tracked tree contains only `README.md`.

## Integration decisions

### Reuse invariants, keep old serialization separate

- PR #2 `prototypes/save_candidate.py:16-46` accepts a strict clock-based schema with `mode = free | history`; `:55-90` handles chapter clocks and free-clock isolation. The new quest snapshot uses `mode = free | chapter` and has no world clocks. These are different formats: never rename fields and call the old save migrated. Retain PR #2 as a reference and keep existing saves untouched.
- PR #2 `prototypes/save_candidate.py:99-118` writes a temporary file, flushes it and replaces the destination; the new store uses immutable generations. Carry over staged validation and preservation of valid state, not the file-replacement contract. The old Python fsync behavior is not a durability guarantee for a new Godot implementation.
- PR #6 `integration_candidate.gd:124-191` provides a useful ownership rule: a single mutation path and copy-on-read, with in-memory publication only after its specific storage call succeeds. Its action mapping at `:149-170` is fixed to phase/door flags, and it requires a live SceneTree (`:131-134`). It is not a generic quest runner and is not imported into this headless-independent domain layer.
- PR #8 `recovery_flow_candidate.py:18-19,74-132` explicitly depends on the earlier Python save schema and classifies errors without claiming a successful restore. Keep this as an offline recovery reference. Do not silently direct it at new generation files or assume its `free_clock` checks apply to quests.

### Keep preview and authoring tools out of gameplay state

- PR #9 `event_data_check_candidate.py:18-22,114-206` is an offline checker, including external source diagnostics and a contract built around `event_id`, `trigger`, `actions`, and optional ignore links. The new quest model has nodes, terminal flags, AND/OR prerequisites and granted facts. Reuse the bounded-ID and explicit-schema ideas, but the checker does not certify the new format.
- PR #9 `event_data_check_candidate.py:31-45` rejects duplicate JSON members and nonstandard numeric constants during parsing. A GDScript `Dictionary` API receives already-decoded objects and cannot recover duplicate keys discarded by a JSON decoder. No duplicate-key parity is claimed for the new quest API.
- PR #18 `event_flow_preview_candidate.py:19-32` imports PR #9 by a relative candidate-directory layout. It is not a standalone Godot module. `event_play_preview_candidate.py:44-50,105-146` states and implements detached, nonpersistent preview snapshots from caller-injected observations. Do not install a Python interpreter in the Windows game merely to run this editor aid.
- PR #36 `event_preview_model_candidate.gd:226-238` explicitly starts/resets a temporary preview. `:287-309` gates on manually supplied signal/condition matches; `:492-549` can retract history when observations change; `:611-625` limits preview choices to 24 and appends navigation breadcrumbs. These are useful authoring/debug semantics, but would permit unintended rollback if copied directly into a gameplay quest/reward system.
- PR #36 `event_preview_screen.gd:2-5,84-117` exposes a fixed-fixture observation-entry UI. It is a developer screen, not a player interaction surface. Keep it available on its existing branch; do not mistake clicking a synthetic branch for executing game objectives, grants, persistence or rewards.

### Defer scene wiring until the domain contract is stable

- PR #33 `menu_flow_owner.gd:1-5,91-92` and `keyboard_grid.gd:42-60` provide scene lifetime and keyboard-focus reference patterns. They operate a synthetic control/grid scene rather than a third-person gameplay controller.
- PR #34 `menu_flow_owner.gd:235-253` retains the same region instance while entering the event page, releasing region-subtree focus; `:273-290` restores the retained region on return. This is useful future navigation logic. It does not save world/quest state, and hidden processing/focus behavior still needs actual Windows verification.
- PR #34 `menu_flow_owner.gd:293-328` intentionally destroys temporary region/event instances when returning to the menu. A later gameplay scene must preserve its authoritative session outside that destroyed UI subtree, or it will lose unsaved quest progress. The new session coordinator is intended to be held by a future application owner, not allocated anew by each panel.
- PR #34 `project.godot:12-14` selects Compatibility rendering. This says nothing about RTX 5060 performance or suitability of the final game's renderer. Keep the Windows GPU target in delivery planning; defer rendering budgets until actual assets and measurement exist.

## Concrete risks for the new foundation

| Risk | Required handling | Status |
| --- | --- | --- |
| Same ID/version reused for different node graph | Definition identity must bind to immutable content or a fingerprint; reject incompatible snapshots before mutation | Sent to implementers for this batch |
| Structural graph reachability mistaken for solvable conditional routes | Label graph checks as structural; review AND/OR gates and fact acquisition separately | Documented; real content not validated |
| Chapter snapshot mistaken for a whole-world save | Keep mode slots separate; clearly state that chapter save does not bundle the paused free session | Required coordinator documentation |
| Entering/exiting chapter silently overwrites free progress | Retain distinct instances; reject nesting and mode mismatch; return failure without replacing old state | Required coordinator behavior |
| Old save format accidentally opened as new | New root and envelope version, no implicit migration | Required store behavior |
| Parsed JSON numbers are floats | Validate integral, finite, bounded numeric values and normalize before schema comparisons; reject booleans | Required static review |
| Multiple processes writing immutable generations | Single-writer assumption must remain explicit; process-local guard alone is not a filesystem lock | Limitation, not certified safe concurrency |
| Newest save has intact hash but invalid quest semantics | Coordinator must reject it without changing active state; physical corruption fallback does not prove semantic compatibility | Required failure behavior |
| Save count cap eventually reached | Return an explicit capacity error, retain existing files; no silent overwrite or automatic deletion | Capacity/retention work deferred |

## Baseline selected

Create a small `game/runtime/` domain layer on a fresh branch based on main, without vendoring all diagnostic candidates or changing their APIs. Implement bounded quest state, separate free/chapter sessions, and append-only persistence under a new format. This is additive source development, not approval of shared interfaces or a migration of historical data.

Keep the old source commits as review references. Future UI and scene work can selectively adapt their input/focus/lifecycle patterns after the application/session ownership boundary is decided. The final game still needs scene content, presentation, gameplay input, assets, executable export, and Windows acceptance.

All runtime claims for this batch remain `NOT_RUN`. This audit establishes source distinctions and integration choices only; it does not prove parser correctness, save durability, gameplay quality, renderer compatibility, or final-device performance.
