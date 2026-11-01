# SOURCE_REVIEW｜read-only PR #26 at exact specified commit

**Target:** GitHub `cao772/game`, [Draft PR #26](https://github.com/cao772/game/pull/26), branch `codex/game-web-region-018-r1`, head **`cd15ec7bc04cceb388f5174b3d8e83e620a23205`**, base `main`. At review it was Draft/Open.

**Actual sources consulted:** `candidates/game_web_region_018_r1/region_model.gd` (full source; pinned blob `48ab256c9755525c3ebfdbf0614a5bef081c132a`), `synthetic_regions.json` (full source; pinned blob `2c336868a30f6c247a1a8f04c5d5a5fe5e31bed5`), `region_demo.gd` (source excerpt for UI boundaries), README, DESIGN and ACCEPTANCE. PR changed-file list was read in the current task.

**Observed source facts (static, not runtime):** PR #26 model has `load_catalog()` → optional fixed synthetic fixture → `_valid_catalog()` Boolean → built-in A/B/C fallback. `_valid_catalog` checks root version, three scenes and A/B/C IDs, title, claim Booleans, bounded rectangular strings, glyphs, boundary and S/T counts. It does not report field paths or repairs; it does not enforce connectivity, claimed truth or real-world safety. Original UI concerns focus, text and record correction; it is not a structural diagnostics interface.

**N20 distinction:** this new candidate only adds named validation diagnostics, a read-only synthetic fixture loader with explicit fallback, and synthetic failure examples. It does **not** modify PR #26 or use PR #27 evidence cards. It does not implement physical navigation, actor input, error telemetry, save schema or any private content.

**Branch isolation:** `codex/game-web-region-020-r1` created directly at main SHA `533b11f50c0d359cd0a5424d5216b0145727699a` (base tree `68cbdca4bf8824ca428a204e205945edfc48ae5d`), not stacked on PR #26. All new files will be under `candidates/game_web_region_020_r1/`. The original PR #26 blob is only copied unchanged to the new candidate folder.

**No execution:** no JSON/GDScript parser or Godot launched, no test runner, UI, CI or performance evidence. All acceptance cases are future plans, status **NOT_RUN**.
