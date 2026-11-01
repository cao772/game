# PR #25 read-only provenance | GAME-WEB-REGION-018 r1

Reviewed in GitHub before editing:
- Repository `cao772/game`, public, default branch `main` HEAD `533b11f50c0d359cd0a5424d5216b0145727699a`.
- Existing open **Draft PR #25**, head branch `codex/game-web-region-017-r1`, exact HEAD `8372c1fe5f6471ec6af788b65b68fa54fe7db65a`, base `main`. All ten changed files enumerated.
- Read the real complete contents of `region_model.gd`, `map_view.gd`, `region_demo.gd`, `synthetic_regions.json`, `main.tscn`, `project.godot`; read README, DESIGN, ACCEPTANCE and SOURCE_REVIEW scope/limitations. New branch copies the **public synthetic-only** fixture unchanged and extends local code only. No import of PR #25 branch at runtime.

**Original candidate baseline:** a stand-alone grid with A/B/C, wall glyph `#`, start `S`, target `T`, user `P`, cardinal route preview, approximate visibility, separate Inspect/Correct and memory-only journal; JSON fallback and partial native keyboard/focus behavior. Those are **source-described candidate capabilities**, not observed tested behavior.

**N18 additions:** full keyboard-operable directional Buttons, textual map rows, unambiguous fact/focus/recovery labels, in-memory undo (move and correction), clear preview, 100/125/150% text scale, Off/Slow/Normal purely decorative motion, explicit future acceptance plans.

**Isolation:** branch `codex/game-web-region-018-r1` starts from clean `main`, writes exclusively `candidates/game_web_region_018_r1/`; no modifications to PR #25 or other PRs, main, shared interfaces or real narrative. Review the PR diff before approval.

**NOT_RUN:** no Godot, parser, tests, UI, CI, screen reader, screenshots or performance measurement. File creation/readback proves source exists, not that it imports, runs or passes accessibility checks.
