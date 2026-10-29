# GAME-WEB-FLOW-REGION-004 r1 — independent synthetic graybox interaction flow

**STATUS: NOT_RUN. DRAFT ONLY. NOT CANON. NO APPROVED SHARED API.**

This is a new standalone Godot 4 project, intentionally isolated from
every real game scene, manuscript, story, saving, input/action bus, and
other candidate PR. The user requested development **without executing
any script, Godot import, test or performance measurement** in this turn.

## Source provenance and relationship to Draft PR #10

On 2026-10-29 the actual Draft PR #10 head was read:
`codex/game-web-module-region-001-r1` at
`964876d33e7e5406648b6826e309dae974cc86eb`.
Its actual source, independent design README, multi-target/focus contracts
and file list were examined before authoring. The standalone project
includes **exact pinned, unchanged file contents** from PR #10 for:

- `interaction_prompt_candidate.gd` (Git blob
  `89d78c42cb160c930ce1d589d70a58da2854bd7e`)
- `interaction_prompt_candidate.tscn` (Git blob
  `e7ac3524e5abc255699c8f1dd10902c6abaffbd0`)

This self-contained copy is necessary because `main` presently contains
only its README and no approved shared prompt component. We **do not**
import from PR #10 branch at runtime, edit that PR, or assume its API
is ratified. If PR #10 evolves, review and repin explicitly instead of
silently upgrading an unrelated draft.

Other parallel candidates (input PR #15 stacked on PR #6; shell PR #17)
were reviewed at their PR metadata / scope level. None is imported. The
flow does not add their action mappings, save integration, shell registry
or resource side effects.

## Files

```text
candidates/game_web_flow_region_004_r1/
  project.godot
  main.tscn
  flow_demo.gd                 # scene, procedural graybox and UI
  flow_model_candidate.gd      # pure in-memory proximity/state model
  synthetic_targets.json      # three public A/B/C placeholder records
  interaction_prompt_candidate.gd   # pinned exact copy from PR #10
  interaction_prompt_candidate.tscn  # pinned exact copy from PR #10
  verify_flow_model_candidate.gd     # FUTURE tests; NOT_RUN
  verify_flow_scene_candidate.gd     # FUTURE tests; NOT_RUN
  .gitignore
  README.md
  DESIGN.md
  SOURCE_REVIEW.md
  ACCEPTANCE.md
```

No other directories or existing scenes are modified.

## Candidate-only interactive flow

1. Load strictly versioned, **synthetic** JSON target records (A/B/C)
   containing an ID, label, confirmation caption and XZ coordinate.
2. Procedurally render a blank floor, a rectangular player marker,
   three distinguishable target cubes and a fixed trial camera. This is
   **not** the novel's bedroom or corridor and does not interpret canon.
3. Move a synthetic marker with WASD or the host's named demonstration
   buttons. Distances are computed in a flat XZ plane; no physics/NPC.
4. At ENTER radius 1.55 m, add reachable targets; retain current
   membership until EXIT radius 1.85 m (hysteresis).
5. Sort nearby items by increasing distance, tie-breaking by stable
   placeholder ID, then display the pinned PR #10 prompt. Multiple
   items use its native next/previous selection and focus controls.
6. Selection updates the local model only. Confirming the actual
   selected eligible ID emits one prompt signal and increments the
   model's **in-memory** counter with a visible text response. It does
   not interact with gameplay state or storage.
7. Leaving all targets hides and resets the local selection; manual
   dismiss suppresses prompting while nearby, until explicit re-open
   or a full leave-then-re-enter. Reset reloads the original in-memory
   public fixture and restores initial marker placement.

All coordinates, radii, speeds, lighting and input choices are trial
proposals, **not** author-approved level dimensions or product controls.

## Proposed local keyboard and buttons

- WASD moves the rectangular trial player marker while the native
  window is focused and the tree is not paused. No InputMap changes.
- The prompt's own action Button (click/keyboard Enter/Space) sends an
  ID signal. Tab and Shift+Tab move focus in that pinned component.
- PageUp/PageDown select previous/next targets **only when the prompt
  owns focus**, according to the pinned PR #10 candidate.
- Escape hides the prompt when focused. A separate host "re-open"
  button restores it, or leaving/re-entering resets suppression.
- Host buttons teleport to A, B, an A/B overlap, and a far location;
  other buttons request next, confirmation, re-open and reset.
- No keyboard 1/2/3/R mapping, no access to external input module.
  Arbitrating Escape with PR #6 remains a future integration decision.

## Future commands — DO NOT RUN in this authoring task

If Codex/owner later authorizes execution, open this directory as the
standalone Godot project and launch normally:

```sh
godot --path candidates/game_web_flow_region_004_r1 --editor
godot --path candidates/game_web_flow_region_004_r1
```

Future logic and standalone scene checks:

```sh
godot --headless --path candidates/game_web_flow_region_004_r1 \
  --script res://verify_flow_model_candidate.gd
godot --headless --path candidates/game_web_flow_region_004_r1 \
  --script res://verify_flow_scene_candidate.gd
```

The tests have **not** been run, and expected future PASS strings are
not observed results. See `ACCEPTANCE.md` for manual cases and
`DESIGN.md` for exact boundary/hysteresis/invalid-data behavior.

## Status / author handoff

- GitHub submission: Git objects and independent Draft PR only.
- Runtime / parser / import / headless test / GUI / screenshot / GPU
  measurement / CI: **NOT_RUN** by author instruction.
- Both copies from PR #10 remain unverified runtime dependencies,
  not shared product contracts.
- No main merge or modification. No private Notion/Drive uploads.
- No actual scene integration, authored canon, world state, public
  event bus or save writes. Owner reviews and approves separately.

---

## GAME-WEB-PLAY-REGION-005 r1 — clickable/keyboard-complete demonstration (NOT_RUN)

This is an incremental *candidate* on the same independent PR #23 branch.
The source read for this edit is the actual prior HEAD
`5ecac707f40bacaaaab10e574b97724ccebaabb6`.

Additional implementation, contained wholly in this directory:
- `target_picker_candidate.gd`: finite and deterministic ground-plane
  picking of public synthetic A/B/C cube locations (0.52m trial radius).
- `feedback_journal_candidate.gd`: 12-entry in-memory rolling
  selection/entry/exit/confirmed/rejected feedback record.
- Expanded `flow_demo.gd`: unhandled left-click -> cube ID selection
  -> highlight and action focus, with out-of-range refusal. Added previous,
  next, prompt-focus/world-focus controls, movement suppression while prompt
  owns focus, text history, and read-only focus/feedback data.
- Added future-only `verify_play_selection_candidate.gd` and
  `verify_play_scene_candidate.gd` tests.
- [Full implementation rationale](PLAY_EXTENSION.md),
  [integration boundaries](INTEGRATION.md),
  [future acceptance cases M41–M62](PLAY_ACCEPTANCE.md).

**NOT_RUN:** No Godot import, parser, GUI, code execution, tests, CI,
screenshot or actual native keyboard focus check occurred in this turn.
Existing PR #10 pinned prompt files, public fixture, base model and
r004 scripts are unchanged. No real game scene, manuscript,
canonical content or shared interface is approved or modified.
