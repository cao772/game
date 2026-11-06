# Source development log

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
