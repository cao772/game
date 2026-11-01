# GAME-WEB-REGION-017 r1 | standalone synthetic scene-interaction candidate

**DRAFT | NOT_RUN | ALL CONTENT PUBLIC SYNTHETIC | NO CANON / SHARED API APPROVAL**

## Read-only source review
Read actual [Draft PR #23](https://github.com/cao772/game/pull/23), branch `codex/game-web-flow-region-004-r1`, HEAD `553c9093a2b9cd54cb6fb4a1c8928472035141b0`, including current README, region-006 design/integration/acceptance, the scene script, proximity model, navigation model, focus policy, local feedback and JSON. It is a separate, unmerged standalone Godot 4 trial. Its original prompt is an unapproved pin of another Draft PR. No approved real scene, interaction/event/save interface, physical pathfinding, or canonical assets were found in that source. This project **does not import or copy PR #23's script, prompt or scene**.

This new module branches from the independently verified `main` SHA `533b11f50c0d359cd0a5424d5216b0145727699a` and creates only a fresh directory. Neither PR #23 nor any other PR, existing file, `main`, input mapping or shared interface is edited.

## Contents
- `project.godot` + `main.tscn`: independent Godot 4 compatibility-renderer project; no autoload or global plugin.
- `synthetic_regions.json`: three strictly synthetic A/B/C grid fixtures; intentionally incorrect trial claims for explicit correction.
- `region_model.gd`: fixture validation, deterministic four-neighbor reachability, approximate grid line-of-sight, one-cell movement, route preview, reset, in-memory audit and explicit record correction.
- `map_view.gd`: geometry drawn with rectangles and letters, no texture/font downloads; click to preview any open tile; W/A/S/D or arrows when focused.
- `region_demo.gd`: programmatically constructed scene switcher, text/route/feedback, explicit focus transfer, conservative window focus/key-release gate.
- `DESIGN.md`: trade-offs, read-only source constraints, local contracts and fail-closed handling.
- `ACCEPTANCE.md`: future-only manual and structural acceptance procedures; nothing run.

## Trial flow
1. Select **A / B / C**. Selection clears only that scene's local synthetic observation/correction history.
2. Focus the grid (click it or use the explicit focus button). Use WASD/arrows to move **one discrete tile per press**, subject to solid tiles.
3. Press **Show target route** to render a four-neighbor path. **A**: target is reachable via a detour although line of sight is blocked; **B**: target is reachable with a distinct path although the report says no; **C**: target is unreachable and the UI offers a route back to the start.
4. Click a floor tile to preview a route to that tile. Routes never move the marker automatically and do not authorize gameplay actions.
5. Press **Inspect** to derive an observation with two separate fields: reachable and visible. The fixture's reported fields remain unchanged until the separate **Correct local record** button is pressed. Correcting never changes the original JSON, saves, events or another scene.
6. **Reset** returns the active synthetic scene to its original claims and start position. Reopening/reselecting scenes has no persistence.

**Missing resource downgrade:** missing, unreadable, malformed or schema-invalid `synthetic_regions.json` loads only an embedded identical A/B/C synthetic fallback with a visible warning; it never searches for another game's files or private content. Missing required GDScript/project source cannot be recovered at runtime: import would fail, and remains NOT_RUN. There are no required textures, voice files or custom fonts.

**Keyboard/focus:** Tab/Shift+Tab belongs to normal UI focus traversal. Grid receives world movement only when it owns focus; Escape releases it; buttons and selector do not trigger movement. On native window focus loss, held movement keys must all be released on return before input can resume. Focus recovery requests are conservative and do not auto-interact or seize a focused UI control. These policies are **untested proposals**, not approved product keybindings.

## NOT_RUN / limits
No Godot/editor run, GDScript parser or import, tests, screenshots, browser/playback, CI verification, physics/collision, accessibility testing or performance measurement was initiated. Git commit/PR presence verifies only authored source was uploaded. Grid line-of-sight is a sampled explanatory proxy, not physical ray-casting; BFS is cell navigation, not a navmesh or walking AI. UI handles only this standalone module and synthetic fixtures. No real locations, character data, original story, canonical scene, private notes, real coordinates or unpublished plot is included.

See `DESIGN.md` for detailed choices and `ACCEPTANCE.md` for future tests to run only after authorization.
