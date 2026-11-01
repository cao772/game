# GAME-WEB-REGION-020 r1｜合成 A/B/C 地图数据结构校验候选

**DRAFT · NOT_RUN · public synthetic data only · no shared API or canon approval**

This is an isolated Godot 4 **source-only** proposal focused on **structural data validation and actionable diagnostics**, not UI evidence cards. It was authored after read-only inspection of [cao772/game Draft PR #26](https://github.com/cao772/game/pull/26) at exact HEAD `cd15ec7bc04cceb388f5174b3d8e83e620a23205`. New branch `codex/game-web-region-020-r1` starts from `main` `533b11f50c0d359cd0a5424d5216b0145727699a` and changes nothing outside `candidates/game_web_region_020_r1/`.

## File guide

| File | Source / purpose |
| --- | --- |
| `region_validator.gd` | New standalone structural diagnostic engine: JSON syntax and field-level codes, severity, JSON-style path and fix action. No disk write. |
| `catalog_recovery.gd` | New *candidate* adapter to accept only validated catalogs, or fail over atomically to an embedded A/B/C synthetic catalog with explicit notice. |
| `synthetic_boundary_cases.gd` | New in-memory **example input factory**, not automated tests. |
| `diagnostics_demo.gd` | New standalone Godot Control UI; displays future diagnostic results with clickable synthetic cases and an optional fixed fixture. |
| `synthetic_regions.json` | **Exactly the public synthetic PR #26 blob**, SHA `2c336868a30f6c247a1a8f04c5d5a5fe5e31bed5`; it is *not* a new shared schema or real map. |
| `main.tscn`, `project.godot` | Independent Godot 4 compatibility-renderer entry, no autoload. |
| `INPUT_FORMAT.md` | Actual PR #26 input grammar, rules and deviations made solely by this candidate. |
| `DESIGN.md`, `BOUNDARY_CASES.md`, `SOURCE_REVIEW.md`, `ACCEPTANCE.md` | Architectural choices, expected edge-case diagnostics, source-provenance comparison and future-only acceptance cases. |

## Proposed interaction (NOT_RUN)

In the future, an authorized reviewer may open this folder as a separate Godot project. The user can choose a **purely synthetic** boundary case such as invalid schema version, ragged row, missing target, unknown glyph, duplicate A, or invalid JSON, then select **Check** to see a diagnostic list:
- stable code such as `RAGGED_ROW` or `MISSING_ID`;
- severity `ERROR`/`WARNING`;
- source path like `$.scenarios[0].grid[3]`;
- human-readable problem and actionable repair advice;
- explicit `SOURCE_ACCEPTED`, `FALLBACK_SYNTHETIC` or `BLOCKED` processing mode.

A separate button inspects **only** the included `res://synthetic_regions.json` file. No arbitrary path, private story, other PR, user files or network input is fetched. The validator accepts a raw Variant or a JSON text string but does not mutate either. Bad input cannot partially replace an accepted catalog.

## Important strict distinction

**Valid structure is NOT valid route, true visibility or correct claimed outcome.** PR #26 intentionally has A/B/C records with claims that may disagree with route simulation. This candidate checks types, shape, perimeter, glyphs and uniqueness. It **does not** reject a sealed-off target (scenario C), compare claims against BFS/visibility, run a physical raycast, or certify safe passage.

PR #26's original `_valid_catalog` returned a Boolean and silently selected an embedded fallback when JSON was invalid, with a generic message; this candidate provides independent named diagnostics and displays the recovery distinction. PR #26 remains unchanged and does not import this candidate.

## Recovery and resource limits

- Valid source → `SOURCE_ACCEPTED`, structurally verified data copied only in memory; nonfatal unknown fields reported as warnings.
- Missing/unreadable optional local fixture, JSON syntax/structure error → `FALLBACK_SYNTHETIC`, precise input issues retained, embedded A/B/C checked before use; **never pretend original was corrected**.
- If embedded fallback itself fails structural validation → `BLOCKED`, empty catalog, no silent launch.
- Missing `.gd` source, scene or compatible Godot runtime → **hard import blocker**, not recoverable inside the app.
- 16000-character input limit and 48-item diagnostic cap are **candidate safety bounds**, not measured performance specifications.

## Status and privacy

**NOT_RUN.** No Godot, parser, GDScript, tests, CI, screen reader, performance or runtime checks have been executed. GitHub source upload and PR readback verify only that files exist and are isolated, not that scripts compile or work. No real game scenes, characters, locations, drafts, chat evidence or private story are included. Keep Draft; do not merge or integrate without explicit authorization.
