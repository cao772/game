# Future acceptance — GAME-WEB-PLAY-SHELL-005 r1

**EVERY CASE NOT_RUN.** Code and future test scripts have been authored
but not parsed, executed, run in Godot, tested in CI, or accepted.

## A. Future scripted cases (`verify_play_candidate.gd`)

| ID | Operation | Required expected observation | Current |
|---|---|---|---|
| P01 | Load exact three public PR #18 JSON fixtures | Model reports ok, checker_status NOT_RUN | NOT_RUN |
| P02 | Initial state | EVENT_START | NOT_RUN |
| P03 | Offer choices | Two fixture actions and configured @ignore | NOT_RUN |
| P04 | Select unoffered action | Rejected | NOT_RUN |
| P05 | Check state after rejection | EVENT_START unchanged | NOT_RUN |
| P06 | Select ACTION_TO_NEXT | Accepted in local trace | NOT_RUN |
| P07 | Inspect next event | EVENT_NEXT | NOT_RUN |
| P08 | Select ACTION_FINISH | Accepted | NOT_RUN |
| P09 | Next state | EVENT_END | NOT_RUN |
| P10 | Select ACTION_COMPLETE | Terminal link | NOT_RUN |
| P11 | Inspect terminal | True, no further actions | NOT_RUN |
| P12 | Select action after terminal | Rejected | NOT_RUN |
| P13 | Reset event preview | Start restored | NOT_RUN |
| P14 | Select @ignore from start | Accepted only due configured branch | NOT_RUN |
| P15 | Ignore destination | EVENT_END | NOT_RUN |
| P16 | Inspect checker status | NOT_RUN (no Python equivalence) | NOT_RUN |
| P17 | Instantiate play scene | Menu active | NOT_RUN |
| P18 | Unknown module ID | Rejected without navigation | NOT_RUN |
| P19 | Open event module | Accepted | NOT_RUN |
| P20 | Check current module | event | NOT_RUN |
| P21 | Check event view state | EVENT_START | NOT_RUN |
| P22 | Open save browser | Accepted navigation | NOT_RUN |
| P23 | Check current module | saves | NOT_RUN |
| P24 | Check overlay existence | Play005Screen attached | NOT_RUN |
| P25 | Return to menu | No active module | NOT_RUN |
| P26 | Open character list | Accepted navigation | NOT_RUN |
| P27 | Check current module | characters | NOT_RUN |
| P28 | Open input settings | Accepted navigation | NOT_RUN |
| P29 | Check current module | input_19 | NOT_RUN |
| P30 | Open region module | Accepted navigation | NOT_RUN |
| P31 | Check current module | region | NOT_RUN |
| P32 | Request region→event before target confirmation | Does not navigate | NOT_RUN |
| P33 | Return to main menu | No active module | NOT_RUN |

These are source-authored future assertions; even if later run and passed,
they would not establish the underlying Python event checker or actual
story/game save interoperability. A native GUI run is separately needed.

## B. Native/manual follow-up (never run)

| ID | Reviewer action | Expected evidence | Current |
|---|---|---|---|
| M01 | Launch root standalone project | Scene imports without errors, main menu displays | NOT_RUN |
| M02 | Inspect original PR #24 navigation after overlay addition | Original menu and flow preserved | NOT_RUN |
| M03 | Open PR #23 synthetic region | SubViewport renders real local Node3D boxes/UI | NOT_RUN |
| M04 | Move/approach/select/confirm a synthetic region target | Public `flow_snapshot` confirm_count increments | NOT_RUN |
| M05 | Try region→event with no confirmation | Explicit rejection, no event opened | NOT_RUN |
| M06 | Confirm region→event after one valid synthetic target | Opens unrelated public EVENT_START only by explicit click | NOT_RUN |
| M07 | Select EVENT_START → EVENT_NEXT → EVENT_END → terminal | Local trace coherent; no game state writes | NOT_RUN |
| M08 | Select ACTION_END to null and @ignore | Terminal/ignore behavior matches public fixtures | NOT_RUN |
| M09 | Remove/alter one event fixture in a throwaway copy | Visible BLOCKED, no invented graph fallback | NOT_RUN |
| M10 | Open save browser without entering a path | No automatic discovery/scan | NOT_RUN |
| M11 | Enter explicit valid/invalid user:// path and inspect | Read-only structured report, no writes | NOT_RUN |
| M12 | Compare two explicitly provided folders | Read-only comparison, no file mutations | NOT_RUN |
| M13 | Open PR #21 synthetic list and detail | Only public synthetic records, back/list/exit work | NOT_RUN |
| M14 | Break profile fixture path or validator in throwaway copy | Clear unavailable error, no real profile substituted | NOT_RUN |
| M15 | Open PR #19 input settings, preview conflicting key | Rejected before apply; original mapping retained | NOT_RUN |
| M16 | Apply a free key in memory, restore defaults | No InputMap edits, no disk writes | NOT_RUN |
| M17 | Relaunch after memory-only remap | Unpersisted mapping not silently restored | NOT_RUN |
| M18 | Remove PR #19 backend resource in throwaway copy | Clear BLOCKED, menu usable | NOT_RUN |
| M19 | Remove PR #20 scene in throwaway copy | Clear BLOCKED, menu usable | NOT_RUN |
| M20 | Remove PR #23 scene in throwaway copy | Clear BLOCKED, menu usable | NOT_RUN |
| M21 | Repeated open/close 30 times | No duplicate UI nodes, signals or stale child view | NOT_RUN |
| M22 | Focus loss and pause while region/prompt active | No unauthorized action or focus leakage | NOT_RUN |
| M23 | Resize 1024×640, 960×680, 1280×720, narrow DPI | Controls and return navigation remain accessible | NOT_RUN |
| M24 | Compare InputMap/user:// before/after | No global mapping or persisted file mutation from play shell | NOT_RUN |
| M25 | Inspect Git diff compared with previous PR #24 head | Only play_005/ plus project.godot changed | NOT_RUN |
| M26 | Check public source strings and fixture provenance | No manuscript/private facts/chat evidence | NOT_RUN |
| M27 | Compare pinned source SHAs and resource path rewrites | Local copied files traceable to each PR | NOT_RUN |
| M28 | Inspect exact Godot version, platform, renderer, native errors | Evidence recorded, no guessed compatibility | NOT_RUN |

## C. Unresolved or explicitly not testable yet

- No PR #9 Python checker or PR #18 Python CLI in Godot. The fixture model
  cannot establish checker validation, checksum parity, source pointers or
  replay equivalence. This is an intentional feature gap.
- No real region target→event rule, event→save writer, snapshot restoration,
  game clock semantics or canonical character information.
- PR #19 full input panel with disk migration/save and its routing to PR #6
  is deliberately absent; this tests only its in-memory backend.
- Native SubViewport input handling, keyboard focus, resizing, runtime scene
  compatibility and accessibility require separate execution approval.

## Future command (do not execute during this task)

```sh
godot --headless --path candidates/game_web_flow_shell_004_r1 --script res://play_005/verify_play_candidate.gd
```

**No run evidence exists.** Only after an authorized run record per-case
PASS/FAIL/BLOCKED with observed stdout, exit code, exact SHA, platform,
Godot version, operator and screenshots.

Proposed evidence object:
```json
{
  "task_id": "GAME-WEB-PLAY-SHELL-005",
  "version": "r1",
  "commit_sha": null,
  "case_id": "P01",
  "status": "NOT_RUN",
  "command": null,
  "exit_code": null,
  "godot_version": null,
  "evidence": [],
  "notes": "Await separate author approval for execution"
}
```
