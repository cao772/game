## 020 — 2026-11-09

A visitor unfolds a personal cup and saucer at the west counter, adjusts the pair and carries it home. The public basin remains available throughout. Both visitors use the same checked movement primitives. Source and static geometry review only.

## 019 — 2026-11-07

Adds a west rear-lane wash shelter and one public basin with continuous fill, one-time preparation and draining. Three station uses, three-way pickup exclusion, actor-aware placement and pause/success-only-reset semantics are integrated without expanding existing save schemas.31 scripts parsed offline; fixed geometry and resource checks only. Godot/gameplay/tests/builds NOT_RUN.

## 018 — 2026-11-07

Adds one finite reading visitor with tray-aware observation, a private notebook visual, window/quiet drawing spots and rear-lane return. Routes wait, retreat physically and replan around blocked edges. Existing player interactions and save schemas remain unchanged; success-only reset and modal/focus suspension are integrated. Offline grammar and source/geometry checks only; Godot/gameplay/builds NOT_RUN.

# Source development log

## GAME-WORLD-READING-TRAY-017 — 2026-11-07

Made the public booklet one movable tray with desk, bench-side and frontage
supports. Added mutually exclusive toolbox/tray carrying, page retention while
moving, held reading and seated surface reading at the correct eye height.
Queued secondary input clears on focus/modal/pause; occupied placements reject
before mutation. Existing world/quest/urban saves and resident routines remain.
Tray layout is visit-local with explicit save/restore/exit feedback. No new NPC
or third-party asset. Offline grammar, geometry and source self-review only;
Godot, gameplay, tests, save I/O and builds remain NOT_RUN.

## GAME-WORLD-READING-ROOM-016 — 2026-11-06

Opened the southwest ground floor as a public reading passage with two always-open
doorways, two shelf-side routes and the original outdoor loop. Added three-page
reading with physical heading/bookmark feedback, a local light and checked bench
sitting. Page/light changes last for the visit and reset only on scene entry or
successful layout restore. Existing saves, quest APIs, workshop behavior and the
resident routine are unchanged. No new external assets or characters.

Offline grammar, resource and fixed-geometry checks plus source review only.
Godot import, gameplay, tests, save I/O, rendering and builds are NOT_RUN.

## GAME-WORLD-YARD-WORK-015 — 2026-11-06

Raised the existing yard support into a workbench while retaining its save anchor.
The same resident can organize tools there independently of the indoor work light,
and toolbox placement influences the next destination when a dwell ends. Active
walks retain their destination. A pure work rule connects actor activity, the
hinged toolbox lid and optional work-specific conversation. Layout changes refresh
work in the same input turn without moving or advancing the resident. Legacy
dialogue forms, the five-field urban save and old world/quest content remain.
Resident probing and modern-street camera directions also use the Godot 4.1
`global_transform.basis` access path.

Source, offline grammar and static review only. Godot, gameplay, tests, save I/O,
animation/visual acceptance and Windows export remain NOT_RUN.

## GAME-WORLD-LIFE-014 — 2026-11-06

Extended the existing workshop resident's routine to a separate terrace lookout.
The actor uses the stair route, rests above the yard, and returns through the same
gate-aware graph. Waypoint arrival checks floor contact and height; player blocking
continues to pause progress. The player's bench and alternate ramp remain available.
Optional place-specific small talk distinguishes a current stop from a future
destination and accepts older three-destination copy. Five-field urban saves,
world/quest data, the terrace geometry and staging assets remain unchanged.

Source and offline review only. Godot import, gameplay, tests, animation, save I/O
and Windows export remain NOT_RUN.

## GAME-WORLD-TERRACE-013 — 2026-11-06

Added a public yard terrace at 3 m with a short stair route, a switchback ramp and
a seated observation point. The ground lane and resident graph remain intact.
Sitting and standing validate body clearance, supporting floor and the full path;
blocked exits preserve the seated pose. Both camera modes and carried-toolbox
presentation support sitting. Successful layout restoration clears the posture;
old world/quest data and the five-field urban save remain unchanged.

Source, offline grammar and static review only. No Godot import, game tests,
runtime traversal, animation/visual acceptance or Windows export was performed.

## GAME-WORLD-RESIDENT-012 — 2026-11-06

Added one workshop resident with workbench, shelving and yard activities, physical
walking and gate-aware route selection. A closed rear gate can cause a detour via
the front door and south lane; no available exit means waiting. Nearby optional
conversation reads the actual lamp/toolbox/route state without quest or inventory
mutations. Door-close protection now includes the resident; conversation and modal
UI pause both movement and the local routine. The five-field urban layout schema,
old world data and quest interfaces are unchanged. Resident progress resets on
scene entry and successful layout restoration; it is not persisted.

This uses the existing CC0 animated staging model. Source/grammar/geometry review
does not establish Godot imports, UI layout, physics, animation or save I/O at
runtime. Game, tests and Windows export remain NOT_RUN.

## GAME-WORLD-WORKSHOP-011 — 2026-11-06

Opened one modern block's ground floor into a front-to-yard workshop. Added nearby
visible E interactions for two shutters, a lamp and one toolbox on three supports.
The new urban_free save slot restores only the five-field layout and held item;
the player re-enters from the street. Save-before-return, confirmed restore and
explicit no-save exit preserve changes and old records on failure. Input shares
the walking controller's focus/pause gate; wall occlusion and occupied door/placement
checks guard interaction. Previous world/quest data and APIs are unchanged.

Source/grammar/resource/geometry and independent review only. Engine, gameplay,
tests, save I/O, visual acceptance and Windows export remain NOT_RUN.

## GAME-WORLD-MODERN-010 — 2026-11-06

Added a separate modern residential street with first-person and close shoulder
camera controls, six-storey blocks, street/alley/rear-path loops and bundled CC0
plaster, asphalt and paving maps. The explorer saves before entry and the street
returns through an exported path. Existing atlas, state/save contracts, quest data
and the earlier world controller remain unchanged. Modern street position is temporary.

This is an authored scale/material source study: shop interiors, traffic and urban
resident simulation are not implemented. Offline grammar/resource/asset checks and
cross-author source review do not establish rendered appearance, camera collision,
performance or gameplay acceptance. Godot, game, tests and Windows build are NOT_RUN.

## GAME-WORLD-RESIDENTS-009 — 2026-11-06

Residents now follow authored, clock-derived routes through the three regions.
Added moving models, optional conversations, live directions, manual companion
markers and explicit waiting until departure. Routine prop refreshes retain actors;
chat, map and restore dialogs pause movement/time. Routes and dialogue are separate
from the unchanged 008 atlas and world snapshot format. Added two CC0 walking model
variants with original geometry, skin and clips verified statically. Independent
source review and offline checks completed; engine/game/tests/build remain NOT_RUN.

## GAME-WORLD-008 — 2026-11-06

Added an optional-quest-independent exploration entry with three connected regions,
camera-relative movement, six crossings, two movable crates, persistent landmarks,
daily resident positions and a dedicated world save slot. The earlier desk scene
remains available through an opt-in save/restore wrapper. Adopted the official
MIT platformer's movement-direction conversion and a reduced CC0 Knight model.
Independent source review corrected arrival headings, held-prop placement during
pause and solid-crate overlap with the player. Source grammar/resources/data were
checked; engine import, game/tests and Windows acceptance remain NOT_RUN.

## GAME-RUNTIME-MARKET-006 — 2026-11-05

Added an optional stall errand with a quick replacement and a three-stop recovery route. The merchant, tool, signs and available return visit reflect the active side-quest state. Session schema 2 saves both quests in one generation and restores earlier delivery-only records. The original configure signatures remain available.

## GAME-RUNTIME-RECORDS-005 — 2026-11-05

An accessible records room now shows a physical slip in the tray assigned to the active terminal node. The archivist points the player toward the record and offers a different line after its inspection. Door travel, tray inspection and conversation reuse the current quest without issuing progress commands. Successful load and mode changes return to the yard. Static review covered doorway positions, sightlines, asset dependencies, outcome mapping and isolation between visits. Engine import, gameplay and Windows export await verification.

## GAME-RUNTIME-COUNTER-004 — 2026-11-05

Replaced the delivery marker with a lit desk, a clerk, and a parcel that travels from player to desk. Delivery, repeat visits and restores now have distinct presentation. The receipt holds a closer camera until dismissed. The scene can load a different delivery definition and use terminal-specific receipts and desk labels without adding save fields. See [counter source review and pending walkthrough](counter-review-v4.md).

## GAME-RUNTIME-SCENE-003 — 2026-11-04

Added a configured main scene with one persistent application owner, collision-bounded location, WASD player, elevated fixed camera and explicit nearest-overlap interactions. The synthetic quest now connects collection, observation, route choice, physical delivery and a visible return-visit result. Added Chinese synthetic presentation, scrolling journal/dialogue, explicit save/archive/restore controls and confirmations for destructive in-memory restoration. Failed mode saves preserve the active mode; successful load/switch resets position by declared policy. Shared application APIs and save schemas remain unchanged.

Source review corrected a raw archive-receipt dump into a generation-only display, retained partial/warning feedback, and added scrolling to keep recovery and dialogue controls reachable. Reviewed normal, alternate-prerequisite, WAIT/RETRY, completion, failed restore and mode-isolation paths on paper. No independent reviewer or runtime execution in this batch. Resource and JSON inspection are not engine compilation or gameplay tests. Import, tests, CI, export and Windows acceptance remain NOT_RUN. See scene-review-v3.md for the exact limits.

## GAME-RUNTIME-FOUNDATION-002 — 2026-11-03

Continued the same implementation branch and Draft PR. Added application/world/dialogue adapters, bounded route history, and explicit nondeleting save archival. No main merge or runtime execution.

Implemented and statically reviewed:
- Loop-erased route history keeps at most 63 edges without imposing a lifetime action budget; final monotonic facts survive removed loops. Old histories up to 256 steps are fully validated before normalization.
- Explicit archive/recovery retains at least two valid active records, preserves corrupt/highest-generation records, avoids overwriting existing archive targets and reports non-atomic partial outcomes.
- Application presentation validates all text and observation bindings; revision-checked commands reject stale options after progress/load/mode changes. Scene world bindings cannot grant action-only facts.
- Save-before-mode-switch at the application boundary; failed saves leave the current mode intact. Active and archived restore share staged semantic validation.
- An explicit overlapping-body observation area and reusable plain-text dialogue panel with binding-epoch protection.
- Synthetic presentation data, current API contracts and future scene integration obligations. Corrected the project feature declaration to 4.1 for static variables; exact release version remains unpinned.

Independent review found and prompted a fix for an archive-capacity dead end: creating the first archive directory at a full active root, followed by a failed first move, previously prevented retry. The scan now allows exactly one verified archive control directory separately from the 1024 active/unknown entries, under a 1025 total bound. No file deletion or unbounded scan was introduced.

Validation is source review, paper state traces, JSON/reference consistency and artifact readback only. Import/compiler, game code, tests, CI, build/export and performance acceptance are **NOT_RUN**. The first-batch review documents below remain historical; current contracts and the v2 reviews supersede their history-capacity and no-retention limitations.

Next source milestone: a persistent scene owner, one bounded playable location with movement/targeting, quest progress/consequences and recovery controls. This batch supplies adapters, not a complete playable quest, Windows executable, full-world save or multi-process lock.

## GAME-RUNTIME-FOUNDATION-001 — 2026-11-03

Outcome: added a single runtime foundation under `game/`, based on main `533b11f50c0d359cd0a5424d5216b0145727699a`. Previous candidate PRs remain unchanged. Main is not merged.

Implemented:
- Exact-field quest definitions, explicit progress, AND/OR requirements, granted facts and terminal handling.
- Definition-content fingerprints and staged history restoration, including unknown action/node and missing-grant rejection.
- Distinct free/chapter runtime instances with fixed save-slot routing and staged load.
- Immutable JSON save generations, bounded validation, digest/readback, older-record recovery and diagnostics.
- One synthetic definition illustrating an alternative-route gate, a help route and a retry loop.

Reviewed: pinned legacy source distinctions, three new runtime modules, cross-module API shape and ownership. Separate implementation and independent review documents record their scopes. No engine/compiler or game code was executed. **Static review is not runtime acceptance.**

Decisions:
- Legacy authoring previews are not used as gameplay state machines.
- Old clock-based saves are not silently migrated into this new schema/root.
- Keep private story assets outside the public implementation.
- Preserve prior records; failed reads do not silently create a new game.
- Use one persistent application owner for the coordinator in future scene work.

Release blockers still open:
- Build scene interaction/dialogue/presentation and the complete first quest.
- Resolve quest history exhaustion and append-only save retention before extended play.
- Add explicit save-before-mode-switch UX and launcher single-instance behavior (or OS-level writer exclusion).
- Add whole-world state ownership, asset/content packaging and migration policy.
- Perform permitted later engine import/runtime verification and Windows export/playtest. None has happened in this batch.

No demo was deployed, no browser work chat was opened, no automation was resumed, and no Windows performance result is claimed.
