# GAME-WEB-MODULE-INPUT-001 r1 — future acceptance plan

**Execution: NOT_RUN. No parser check, headless test, UI run, CI run, or
performance benchmark was performed while authoring this candidate.**

Parent technical source: [Draft PR #6](https://github.com/cao772/game/pull/6),
`f5143fb72db6083cab6364b8caa5daf7d6995dc2`. Scope: independent
input configuration only; no story, snapshot, game mode, or InputMap changes.

## Automatic headless cases (source prepared, not executed)

| ID | Case | Expected result |
| --- | --- | --- |
| M01 | Read all five defaults | 1/2/3/R/Escape map to the five PR #6 action IDs |
| M02 | Rebind action to available Z | New Z resolves; old 1 ceases to resolve |
| M03 | Rebind to another action's key | Rejected with conflict owner; original map intact |
| M04 | Unknown action, text keycode, modifier-only key | Rejected without changing state |
| M05 | Key echo and key release | Neither resolves to an action |
| M06 | Unknown key and pressed key with Ctrl | Neither resolves |
| M07 | Injected loss of focus / blocked flag | No action resolved |
| M08 | LineEdit, TextEdit and descendant focus | Key ignored; ordinary Control remains eligible |
| M09 | Reset one occupied default | Conflict rejected; no loss of another action |
| M10 | Full restore_defaults after remaps | Five defaults restored atomically |
| M11 | Full restore repeated | No-op; unchanged notification contract |
| M12 | Profile duplicate code, duplicate/unknown action | Invalid without partial apply |
| M13 | Profile extra keys, incomplete fields, invalid types | Invalid; unchanged map |
| M14 | Integral JSON floating numbers | Normalized if valid, fractional rejected |
| M15 | Save/load at allowed user:// basename | Valid profile roundtrip |
| M16 | Path traversal, wrong filename, missing directory | Rejected; no unintended filesystem writes |
| M17 | Existing corrupted JSON on disk | Save refuses replacement; load leaves memory unchanged |
| M18 | Adapter attaches to PR #6-shaped fake host | Prior child key handler deactivated only while attached |
| M19 | Second adapter same host | Rejected; no double keyboard processing |
| M20 | Adapter handles injected key and calls receiver | Exactly one canonical action when accepted |
| M21 | Echo, blocked focus, missing receiver | No receiver call |
| M22 | SceneTree.pause true despite false injected gate | No dispatch |
| M23 | Pause cleared, detached adapter, reattach | Forwarding resumes; original processing flag restored on detach/free |
| M24 | Test ends in bounded fashion with nonzero on assertion failure | PASS/FAIL and correct exit code; **not verified** |

**Command for later Codex execution (not run here):**

```bash
godot --headless --path candidates/game_web_module_input_001_r1 \
  --script res://verify_input_module_candidate.gd
echo $?
```

## Manual desktop checks — NOT_RUN

- D01 — Remap while focused text edit, type assigned letter, ensure no game
  action is emitted; check both LineEdit and TextEdit descendants.
- D02 — Alt+Tab, minimize, restore native focus; ensure no action while
  unfocused and subsequent legitimate press works.
- D03 — Focused button click uses action ID, without accidental extra key
  dispatch or focus loss.
- D04 — Verify key repeat produces only one action until a real next press
  after release.
- D05 — Attach/detach with PR #6's **actual** Integration/Router pair,
  confirm no duplicate action and no change to its snapshot writer.
- D06 — Keyboard layouts, physical vs logical keys, IME/compose and
  accessibility testing require an explicit subsequent requirement.
- D07 — Corrupt/foreign content, temp file races, backup policies,
  multi-process writers and platform rename semantics need separate review.
- D08 — Performance/memory/latency/large numbers of key presses:
  **NOT_RUN**, no benchmark claims.

## Review blockers

1. Parent PR #6 is a Draft. Its Godot 4.7.2 runtime and precise production
   GUI behaviors have **not** been established by this task. This module is
   only source-level aligned to its current Node name and public method.
2. Exact editor/runtime handling of keycodes and `user://` paths must be
   confirmed by Godot execution once expressly authorized.
3. Configuration storage has a fixed temporary filename and does not claim
   inter-process concurrency or power-loss durability. No autosave is
   performed; explicit save/load calls only.
4. Key remapping semantics, conflict policy, available key whitelist,
   resetting semantics, and disk format are **proposals**, not approved
   product interfaces. Canon is not applicable.
5. Without an authorized target game scene, UI or project specification,
   no real scene attachment or main-branch integration is attempted.
