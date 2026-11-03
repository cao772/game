# Source development log

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
