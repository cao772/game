# GAME-WEB-REGION-017 r1 — design and provenance (NOT_RUN)

## Source review and explicit isolation
The live Draft [PR #23](https://github.com/cao772/game/pull/23) was read at HEAD `553c9093a2b9cd54cb6fb4a1c8928472035141b0`. Its standalone Godot 4 project uses three synthetic cube targets, a proximity selection model, later click-to-pick, memory-only journal, trial straight-line navigation and native focus-loss recovery. The existing prompt copies come from a different unmerged Draft; it has neither a canonical gameplay scene nor a published shared API. In particular, proximity straight-line trial movement on a blank XZ floor does **not** establish occlusion, collision or a reachable route in a real world.

**New design choice:** build a clean Godot 4 Control/grid candidate from `main`, not another layer on PR #23. That avoids depending on unmerged prompt scripts and proves an independent *design shape*, while leaving all other branch heads unchanged. Costs: controls, assets and model are intentionally duplicated as candidates and will need deliberate reconciliation by the eventual engineering owner.

## Scope and public fixtures
The only regions are synthetic letters A, B and C. They are 2D grid test cases with characters `#` = solid occluder, `.` = open, `S` = start, `T` = target. Their geometry, sizes, reports, texts and visuals are synthetic examples. No geographic coordinate system, real-world place, story character, real NPC, time loop, private manuscript, or game mission is encoded.

- A: direct line of sight blocked, a four-neighbor detour exists; synthetic report says visibility=yes, reachability=yes. Correction changes *visible* to no.
- B: target reachable via a long perimeter route, synthetic report says reachability=no; correction changes *reachable* to yes.
- C: target T is isolated by walls; fixture report claims reachable=yes, but no target path exists. Recovery route to start S remains calculable because movement never crosses walls.

Route detection and visibility are deliberately **independent**: BFS via four cardinal neighbors (deterministic ordering), visible via finite grid sampling against # cells; neither implies the other. The visibility proxy does not assert accurate corner supercover or true ray tracing. Routing preview never teleports a character, presses a button or unlocks blocked cells.

## Record correction transaction, local only
1. Start with a reported pair `claimed.reachable`, `claimed.visible`, exactly supplied by synthetic fixture.
2. An explicit Inspect derives current local reachability and sampled sight line from current marker position. Moving one cell invalidates an old inspection; this avoids correcting from stale observations.
3. The record can be corrected only with a second explicit Correct action after Inspect. If reported fields already match observed fields, the action returns an informational no-op; otherwise both fields atomically update an in-memory copy.
4. Append bounded (maximum 12) human-readable notes, not timestamps or raw personal information. Selecting another scene or reset discards this local audit. There is no file write, network call, export, save, telemetric event or shared state.
5. **Limit:** claims become an observation *from the current marker position*, not global permanent truth. A future implementation would need origin/target provenance and approval before using this in any saved record; that contract is NOT approved here.

## Missing-resource behavior
External JSON loads only if version, exactly three distinct IDs A/B/C, title length, two boolean claims, rectangular dimensions and perimeter walls, valid glyphs, and exactly one S and T per grid pass validation. Invalid file falls back atomically to embedded A/B/C with an explicit status warning; no partial replacement. There are no custom media dependencies, so resource downgrade retains all facts through plain labels, route cells and state text.

A missing `region_model.gd`, `map_view.gd` or `region_demo.gd` is a **required source failure** (no magical fallback without a script), not a claim that the project will load. Missing runtime/existing Godot install is likewise not resolved by this PR.

## Input and native focus
- Controls outside the map use normal Godot GUI focus and Tab/Shift+Tab.
- Map click chooses a *route preview* only for passable cells; click and navigation **do not confirm** or correct any record.
- Map-focused W/A/S/D and arrows request exactly one tile per key press, no InputMap alteration, no continuous held motion or unapproved shortcut for actual game actions.
- Escape releases grid focus; visible host button explicitly restores it.
- Window focus loss gates movement; on return the gate remains active until all eight movement keys are released once. The host requests focus restoration only if the grid was previously focused and no other Control is currently focused; it never auto-runs Inspect/Correct or resumes movement.
- **Known unverified edges:** OS focus notifications, keyboard event propagation, click geometry after resize, arrow-key focus navigation and tab order, e.g. in IME or accessibility systems, require real native UI testing. No tests executed.

## Security/accessibility and boundaries
No parser loads arbitrary scene paths, URL, command, script, external image, or raw event from the fixture. Source review only inspects public repo paths. Normal controls remain focusable; critical information is always in text, not only tint, sound, or ray visibility. Grid key/focus behavior and contrast are future tests, not WCAG compliance claims.

## Chosen compromises / why
- Grid Control instead of an immersive 3D region: smallest reliable representation of walls, sight line and path semantics without a real-world location or non-approved 3D scene.
- BFS over real navmesh: exact on a small cardinal synthetic grid, explicit deterministic recovery route, no dependence on unapproved physics/navigation stack.
- One shared local model for A/B/C rather than three copied scene scripts: less drift in failure handling, while each fixture has independent walls and claims.
- Strong reset and explicit Inspect→Correct: no user mistake irreversibly changes a source; exposes evidence vs assertion.
- In-memory fallback instead of silent placeholder data: missing-resource behavior can be explained, not confused with production asset readiness.
- New branch from `main` rather than PR #23 head: avoids mutating or stacking on another Draft, so differences remain limited to the candidate directory.

## Unresolved dependencies / STOP conditions
- A real-game integration would require separately approved game scene, navigation/occlusion rules, actor state, focus arbitration, save/event API and product accessibility rules. **None supplied by PR #23.**
- UI layout, CSS equivalent/3D asset quality, performance, actual runtime import, focus restoration, line-of-sight corner cases and route animation have no observed evidence.
- Source compliance and GitHub commit presence do not equal Godot playability. Maintain Draft and NOT_RUN. Do not merge into main.
