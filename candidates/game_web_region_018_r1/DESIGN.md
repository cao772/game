# Design choices & security boundary | GAME-WEB-REGION-018 r1

**Revision candidate / all tests NOT_RUN.** Prior source is [PR #25](https://github.com/cao772/game/pull/25) at exact HEAD `8372c1fe5f6471ec6af788b65b68fa54fe7db65a`; new independent branch starts from clean main, not from PR #25. Its original 10-file A/B/C grid prototype uses BFS four-neighbor reachability, sampled straight-line visibility, in-memory record claims, separate Inspect/Correct, route preview, custom drawn Control, native window focus policy, and a JSON fallback. It explicitly does not prove real 3D navigation or an approved input/event interface.

## Decisions and trade-offs

| Decision | This candidate | Reason / limitation |
| --- | --- | --- |
| Keep synthetic A/B/C fixture unchanged | Reuse PR #25's public SHA blob and embedded fallback records | Enables comparison without inventing real-world scenes or modifying approved schema. Old `017` version string intentionally remains local and is **not** an API promise |
| Never rely on color | Draw each cell with `# . : S T P`; also publish numbered text rows, Boolean facts expressed as **是/否**, action and focus labels in plain text | Works conceptually without color perception or decorative textures; exact character alignment, contrast and screen-reader reading must be tested |
| Complete keyboard path | Native Tab/Shift+Tab + visible arrow buttons + explicit Inspect/Correct/Undo + OptionButtons | A user can finish without map focus and without mouse; traditional map WASD/arrows remains optional |
| Strong focus feedback | Thick white focus style on interactive controls, focused-map outline, and an independent **current focus** text line | Focus must not be conveyed by border color alone; native Tab order and OS-window behaviors are not tested |
| Explicit rollback | New 16-entry, memory-only undo snapshots for successful moves and corrections; clear-preview separately | Prevents failed input from requiring a full scene reset; old audit remains transparent, and undo invalidates stale inspection |
| Motion preference | Off by default, slow pulse or normal pulse available; pulse decorates current cell only | No movement or core fact changes depend on animation; optional motion may affect performance until validated |
| Text scaling | 100/125/150% via local font-size overrides and grid text-size scaling | Avoids fetching system fonts/assets. Layout and 150% clipping must be tested; not a WCAG compliance claim |
| Resource downgrade | Atomic versioned JSON validation then embedded A/B/C on failure; UI explicitly displays source | Never silently loads story, a different folder or private fixtures; required source import failure remains a hard block |

## Record provenance and undo semantics
The user-facing *reported* fields come from public fixture `claimed.reachable/visible`. *Inspected* fields describe only current grid position; moving, switching or undoing requires reinspection. An Inspect does **not** mutate the report. A separate Correct action compares two fields, pushes a pre-correction snapshot, and updates **only in-memory** report state. Successful movement pushes a pre-move snapshot. Undo restores the previous player position/report (not the original file), clears route preview and invalidates any past inspection, then appends a transparent rollback note. Undo does not travel between A/B/C scenes or restore a full event/time history. The rolling audit is limited to 12 entries; the undo stack to 16 entries. These numbers are **provisional design limits, not measured capacities**.

The base model's sampled line-of-sight may over/underestimate diagonal corner blocking; it is an instructional approximation, not physical occlusion. Path preview uses cardinal BFS over finite synthetic grids, not a navmesh, collision physics or NPC planning. A/B/C field claims are intentionally wrong in some cases so the user can observe correction.

## Input ownership and non-stealing
Normal GUI widgets have focus and should accept native Tab/Space/Enter. Only the map's own `_gui_input` consumes WASD/arrows while it has focus. Click on a tile only previews; it does not move, inspect or correct. Four visible direction Buttons provide the same one-cell semantic action even when focus never enters the map. Native window blur arms a key-release gate, and return does not auto-move, auto-correct or seize an already-focused control. If map had focus before blur and return leaves no GUI owner, an optional one-shot map-focus restore may occur; actual OS timing is **unverified**.

## Information downgrade/accessibility limit
No sounds, textures, external fonts or video are required. Grid characters remain visible at all motion settings, and a complete row-by-row text alternative is kept in ordinary Labels. State, mistakes and next actions are spelled out. A Label is **not proof** of screen-reader announcement; formal assistive-technology support, Chinese fallback glyphs, focus order, high magnification/reflow, switch input, IME and contrast are explicitly **future acceptance tasks**. The new white focus border is a supplement; the focus text label is primary fallback.

## Missing dependencies
`synthetic_regions.json` is optional at runtime because a validated embedded synthetic set is already present in the model and the data source/warning is visible. The following are **required**, not magically degradable: `region_model.gd`, `map_view.gd`, `region_demo.gd`, `main.tscn`, a compatible Godot 4 executable. Missing source must be reported as a future import failure, never counted PASS. There are no private connector, actor, real-location or shared gameplay dependencies.

## Not authorized
No changes to PR #25, PR #23, main, shared input schema, event/save APIs, canonical story or existing assets. No runtime, parser, tests, screenshots, CI or benchmarking in this task. A later authorized integration must deliberately reconcile these candidate-only copies instead of silently treating them as shared product components.
