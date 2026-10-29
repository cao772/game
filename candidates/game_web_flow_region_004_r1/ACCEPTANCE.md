# Future acceptance plan — GAME-WEB-FLOW-REGION-004 r1

**ALL CASES: NOT_RUN. NO AUTHORIZATION TO EXECUTE IN THIS TASK.**

## Scope and evidence rules

The next Codex/owner execution must record the exact GitHub HEAD,
Godot executable/version, OS, renderer/GPU, invocation, stdout/stderr,
exit codes, and native GUI screenshots. `PASS` is allowed only for
individually executed and evidenced checks. A headless return code does
not establish native keyboard focus, GUI rendering, accessibility,
input latency or performance. Missing evidence is `INCOMPLETE`, not
`PASS`.

## Planned model contract checks (future)

Command for future use only, from the repository root:

```sh
godot --headless --path candidates/game_web_flow_region_004_r1 \
  --script res://verify_flow_model_candidate.gd
```

Expected console marker *only if it eventually passes*:
`PASS GAME-WEB-FLOW-REGION-004 r1 (future model checks)`.

| Case | Reproduction | Expected result |
| --- | --- | --- |
| F001 | Construct fresh model | Loaded false; no nearby targets |
| F002 | Pass empty/invalid target list | Entire input rejected, no partial target |
| F003 | Pass duplicate ID or non-placeholder ID | Rejected; previously valid model unchanged |
| F004 | Load 3-record public `synthetic_targets.json` | Exactly A/B/C records recognized |
| F005 | Position (0,3) | No eligible target, no prompt entry |
| F006 | Position (-1.2,1.5) | Enters A only at proposed 1.55 threshold |
| F007 | From F006 move (-1.2,1.7) | A remains eligible by 1.85 exit hysteresis |
| F008 | Move (-1.2,1.9) | A leaves, selected ID clears |
| F009 | Move (-0.6,0) | A and B both eligible; deterministic distance+ID tie order |
| F010 | Choose B then attempt choose C | B accepted, C rejected while out of range |
| F011 | Attempt confirm A while B selected | Rejected; local counter unchanged |
| F012 | Confirm selected B once | One success with B ID and count +1 |
| F013 | Dismiss prompt then confirm B | Rejected while dismissed |
| F014 | Explicitly re-open without leaving | Dismissal cleared; selection preserved |
| F015 | Leave all targets | Eligibility empty; manual suppression reset |
| F016 | Ten approach/confirm/leave cycles | Ten additional confirmations, no stale ID |
| F017 | Malformed NaN/Inf or out-of-bounds coordinates | Catalog or position rejected, no scene side effects |
| F018 | Catalog has >16 items or invalid types | Atomic fail-closed validation |

## Planned SceneTree integration checks (future)

```sh
godot --headless --path candidates/game_web_flow_region_004_r1 \
  --script res://verify_flow_scene_candidate.gd
```

Expected if eventually successful:
`PASS GAME-WEB-FLOW-REGION-004 r1 (future scene contract)`.

| Case | Operation | Expected evidence |
| --- | --- | --- |
| F019 | Instantiate only independent `main.tscn` | Procedural demo, all three synthetic markers and prompt component available |
| F020 | Approach A/B overlap | Prompt appears with 2 options, selected ID synchronized |
| F021 | Change prompt selection | Model selected ID updated, no confirmation yet |
| F022 | Invoke prompt request through isolated test seam | One signal and one model confirmation |
| F023 | Leave target range | Prompt hidden; eligible list cleared |
| F024 | Re-enter, manually hide, remain nearby | Auto-prompt remains suppressed |
| F025 | Press explicit re-open control | Prompt returns without resetting confirmation count |
| F026 | Reset local flow | Counter resets, marker far, no prompt; catalog remains public A/B/C |

## Future desktop/visual/manual checks (all NOT_RUN)

| Case | Operator action | Visual/behavior criterion |
| --- | --- | --- |
| G001 | Launch independent scene; inspect fixed viewport | One empty graybox floor, player marker, three labeled cubes and status UI; no story assets |
| G002 | Move WASD toward A | Marker moves, A becomes highlighted, prompt appears on entry |
| G003 | Move just outside enter radius but inside exit radius from an eligible A | Prompt remains; hysteresis avoids flicker |
| G004 | Move beyond exit radius | Prompt hides, A loses highlight, state says no eligible target |
| G005 | Click A/B overlap button | Two selectable IDs visible; amber highlight tracks selected target |
| G006 | Use Tab/Shift+Tab within prompt | Keyboard focus ring follows live controls; no invisible button selected |
| G007 | Press next/previous, PgUp/PgDn | Selection changes without model confirmation or duplicate feedback |
| G008 | Press Enter/Space while focused on prompt action | One visible confirmation, selected ID and count accurate |
| G009 | Hide prompt with Escape | Suppression persists while standing nearby; no automatic redisplay next frame |
| G010 | Move completely away and approach again | Suppression clears on leave; prompt reappears on new entry |
| G011 | Use host re-open button after dismissal | Prompt reopens without any new confirmation |
| G012 | Try host confirmation while prompt hidden | No confirmation; display explicit refusal |
| G013 | Switch off native window focus / Alt+Tab | Movement and native prompt actions do not dispatch while unfocused |
| G014 | Activate a text input as future host fixture | WASD should not move while LineEdit/TextEdit owns focus |
| G015 | Pause SceneTree in controlled future QA | Movement and confirmation stop while paused |
| G016 | Select target then walk out of its range while others remain | Model reselects nearest eligible, preventing stale target confirmation |
| G017 | Repeat 10 complete cycles with native mouse + keyboard | No stuck prompt, duplicate signals, stale target IDs or counter drift |
| G018 | Resize window from 1280×720 to smaller/HiDPI | Record clipping, unreadable controls or label collisions explicitly |
| G019 | Compare independent copy of prompt source to exact PR #10 blob | Contents identical to pinned blobs; any upstream drift separately reviewed |
| G020 | Inspect GitHub PR diff and run after authorization | Only new candidate folder added; no scene/main/manuscript mutation |

## Evidence JSON template for future use

A future operator may capture results in this shape; **no result
file is created or populated by this development task**:

```json
{
  "task_id": "GAME-WEB-FLOW-REGION-004",
  "version": "r1",
  "source_head": "FILL_AT_EXECUTION",
  "engine": "FILL_AT_EXECUTION",
  "os": "FILL_AT_EXECUTION",
  "status": "NOT_RUN",
  "case_results": [
    {
      "case_id": "F001",
      "status": "NOT_RUN",
      "expected": "loaded=false",
      "observed": null,
      "evidence_path": null
    }
  ],
  "reviewed_by": null,
  "shared_interface_approved": false,
  "canon_approved": false,
  "main_merged": false
}
```

## Known unverified dependencies / conservative decisions

- PR #10 is unmerged Draft. The two copied source files are pinned,
  not promoted to a production contract.
- No actual game region, player controller or interactable scene
  was supplied on main. Use a public-only synthetic floor and markers,
  rather than inventing canon or importing unpublished content.
- No evidence yet for accessibility, native window focus, FPS,
  GUI text legibility or platform-specific parse behavior.
- Any eventual integration with separate PR #6, #15 or #17 requires
  independent explicit author approval. No automatic merge.
