# Source review and provenance — 2026-10-29

Status: Source review performed through connected GitHub only.
**No Godot/code/tests executed. NOT_RUN.**

## Checked original sources

- Repository: `cao772/game`, main commit
  `533b11f50c0d359cd0a5424d5216b0145727699a`.
  Only README in its public main tree; no official Godot game scene.
- Draft PR #10 `codex/game-web-module-region-001-r1`,
  HEAD `964876d33e7e5406648b6826e309dae974cc86eb`,
  **Draft, not merged**.
- Reviewed its current `interaction_prompt_candidate.gd` and
  `interaction_prompt_candidate.tscn` actual file bodies, plus
  `README.md`, `docs/module-003-focus-sync.md`,
  `docs/integration-boundaries.md`, example catalog/loader
  and PR diff filenames.
- PR #10 local contract offers `show_for_targets`,
  `synchronize_targets`, `cycle_target`,
  `interaction_requested`, `placeholder_changed`,
  `prompt_visibility_changed`, `request_interaction`
  and `active_target_id`. These are **not** approved shared interfaces.
- Exact source Git blobs copied **unchanged** into new standalone root:
  - `interaction_prompt_candidate.gd`:
    `89d78c42cb160c930ce1d589d70a58da2854bd7e`
  - `interaction_prompt_candidate.tscn`:
    `e7ac3524e5abc255699c8f1dd10902c6abaffbd0`

## Parallel draft candidates consulted

- [Draft PR #15](https://github.com/cao772/game/pull/15):
  separate input-bindings candidate, stacked on PR #6;
  no input map/router source copied or integrated.
- [Draft PR #17](https://github.com/cao772/game/pull/17):
  separate shell/assembly and navigation candidate;
  no shell source copied or integrated.
- [Draft PR #6](https://github.com/cao772/game/pull/6):
  independent INPUT-to-snapshot experiment; no save or
  gameplay state code used in this project.

Other PRs are independent. This independent flow PR introduces no
commit or file modification to any prior PR branch, no dependency
on their unapproved API, and no change to `main`.

## Source/feature boundary

This flow is a new stand-alone technical synthesis, not a
restoration of an existing game level. The user did not supply
real interactable scene nodes, a target discovery interface,
approved UI style, or final action semantics. Instead, the
flow uses an explicitly versioned, static synthetic JSON
fixture and fixed XZ coordinates; all numbers and behavior
are labeled proposals.

No user manuscript, canonical story, character, archive link,
personal note, ChatGPT transcript, raw screenshot or private
setting is included in any GitHub file.

## Handoff

Review PR diff and exact commit hash; then Codex may later
run the documented future tests and desktop screenshots **only
when user authorizes execution**. GitHub upload/readback verifies
source presence, not functional correctness or product approval.
