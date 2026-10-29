# GAME-WEB-CONTINUE-REGION-003 r1 — focus, state and placeholder-data extension

**Code delivered for review only. NOT_RUN.** This document describes intended
behavior; none of the expected results below is an observed Godot result.

## Exact provenance and isolation

Source read from Draft PR #10 at commit
`7b65636bbf11580dd4cce284ea022b5c27e90181`:
the prompt script/scene, standalone demo, earlier QA scripts, README and
MODULE-002 guide. This extension changes only files under
`candidates/game_web_module_region_001_r1/` in that PR's existing
`codex/game-web-module-region-001-r1` branch.

No external assets, plugins, network traffic, novel/character data, real
gameplay targets, manuscript, shared event API or save implementation.
Everything introduced here is still an **unapproved local candidate**.

## Problems targeted and design decisions

### 1. Reordering a target list should not jump the selection

Prior `show_for_targets()` explicitly resets the selected target by supplied
index. This is appropriate when *opening* an entirely new prompt, but not
when refreshing an already visible list. A naive index-based refresh can
turn a selected B into C when the list order changes.

**Decision:** keep `show_for_targets()` unchanged for explicit opening, and
introduce `synchronize_targets(input_targets, preferred_id = &"")`
for explicit live updates. It validates the complete proposed list first,
then chooses in the following order:

1. If `preferred_id` exists in the new list, choose it.
2. Otherwise, preserve the previous selected target ID if it still exists.
3. If the selected ID was removed, clamp the old selected index to the
   nearest valid index (never search story meaning or assume a new target).
4. Reject empty/invalid input atomically (caller must use `hide_prompt()`
   to dismiss).

The list remains limited to 1–16 unique, public placeholder IDs. A valid
list refresh emits `target_list_changed` exactly once; only a real selected
ID change emits `placeholder_changed`. Selection/reorder never emits an
`interaction_requested` action.

**Reason:** ID continuity is more stable than index continuity. Explicit
fallback makes target removal predictable and avoids invisible event/state
side effects. Empty list is treated as invalid, rather than silently
hiding a user-visible prompt.

### 2. Focus needs both an observed role and a state notification

Earlier `focus_state()` was already a live viewport read, but host
demonstration also listened to multiple independent signals. Those signals
can be observed at different times (e.g. focus exits then enters during
a single Tab event, target list changes before a visual refresh). Relying
only on event order can render stale status text.

**Decision:** add `state_snapshot()`, combining currently observed
selection, IDs, request count, style and focus role. It returns an
independent dictionary with:

```text
shown, target_id, target_index, target_count, target_ids,
focus_role, request_count, style, revision
```

`prompt_state_changed(snapshot)` is a *deferred/coalesced* notification.
Multiple changes within one idle-frame coalesce into the latest state;
identical states do not emit duplicates. `revision` increases when a
distinct snapshot is published; reading `state_snapshot()` before the
flush reflects current values with the last published revision.

The earlier signals are retained:
`interaction_requested`, `placeholder_changed`,
`prompt_visibility_changed`, `target_list_changed`,
`focus_state_changed`, and `style_changed`.

**Reason:** expose an authoritative read model while preserving callers'
previous granular notifications. The UI demo always reads the latest
snapshot instead of stitching together potentially stale fragments.
Revisions are **local in-memory UI revisions**, not persistent gameplay
version IDs or a save/event interface.

### 3. External keyboard focus can be lost without target changes

`get_viewport().gui_get_focus_owner()` may retain a Control reference
while the OS window itself has lost focus. A cached role alone could then
mislead the user.

**Decision:** `_current_focus_role()` returns `none` if the native
window is not focused. The candidate listens to `Window.focus_entered`
and `focus_exited` and requests a deferred focus reconciliation. A live
target-list sync preserves focus if it is already on a visible prompt
control; if the focused navigation row becomes hidden, it requests focus
on the action Button.

**Reason:** avoid falsely reporting a usable focus outline when the
window is inactive, and repair stale nav focus after 3→1 targets.
This is a best-effort UI proposal, *not* proof of native keyboard behavior;
platform-specific focus edge cases need actual screenshots and input tests.

Focus remains scoped to the prompt: no changes to InputMap, no new
1/2/3/R key mapping. Escape/PageUp/PageDown remain prompt-focus-only
per MODULE-002, and shared arbitration with separate PR #6 is unresolved.

### 4. Demonstration data must be auditable and explicitly non-canonical

A standalone fixture `placeholder_targets.example.json` supplies four
sets of generic A/B/C/D/E IDs: initial, reordered, reduced and alternate.
`placeholder_catalog_candidate.gd` reads that bundled JSON only and
rejects absent/malformed schema before returning a deep-copied structure.
The prompt remains the final strict validator for IDs/labels/captions.

**Reason:** concrete, user-visible examples demonstrate update semantics
without importing real world content. Keeping examples in a single public
data file lets reviewers inspect exactly what can be shown; there is no
remote source, data discovery, or hidden dependency.

The demo provides buttons to show old single-target calls, load a
three-target list, reorder, reduce, replace with a preferred ID, explicitly
transfer focus to the host, switch styles, cycle, and hide. A state
inspector displays current ID, index, role, revision and request counter.
It never modifies gameplay/world state.

## Operation definitions and limitations

- `show_for_targets`: initial or explicit replacement by index, unchanged.
- `synchronize_targets`: refresh visible list with ID preservation and
  an optional preferred ID, not an interaction event.
- `select_target` / `cycle_target`: local selection, unchanged.
- `request_interaction`: emits one local action for the selected ID if
  existing gates allow. The special focus override remains test-only and
  does not authorize a production bypass.
- `hide_prompt`: explicit hide resets targets; prior focus restoration
  remains best-effort.
- `state_snapshot`: immediate read; `prompt_state_changed`: coalesced
  deferred notification; no persistence or integration contract.
- `apply_style`: existing local-only atomic theme updates, unchanged.

An external host that directly edits private node `visible` or target
Button properties is outside this candidate contract; hosts should call
the documented methods. Multiple simultaneous prompts, nested modal
stacks, OS/native focus return and screen reader behavior are not yet
specified or validated.

## Future verification steps — DO NOT EXECUTE IN THIS TASK

From the standalone candidate Godot project directory, after approval:

```sh
godot --headless --path . --script res://verify_interaction_prompt_candidate.gd
godot --headless --path . --script res://verify_interaction_prompt_extension_candidate.gd
godot --headless --path . --script res://verify_interaction_prompt_sync_candidate.gd
```

The new script is a prospective finite contract regression that includes:
fixture loading, B reordering without selection jump, invalid-list atomicity,
removed-target fallback, explicit preferred ID, request count and selected ID,
style/revision isolation, hidden-state clearing, and ten repeated rounds.
Headless focus role structure is checked; native keyboard focus is not.

See `docs/acceptance-cases.md` for dedicated future native manual cases
M29–M40. Capture Godot version, exact commit, exit codes, raw logs,
visible focus screenshots, focus-loss/restore evidence, plus failures.
Never turn an expected PASS string into a claim of execution.

## Open boundaries for owner review

- Final native focus behavior under desktop focus loss, IME and different OS.
- Escape arbitration if/when PR #6's independent input router is integrated.
- Final palette, localization, screen-reader support and high-DPI layout.
- Rules for real targets, discovery/distance and gameplay consequences
  (not within this candidate; no interface approved).
- Any official shared signals, store or eventual main merge.

**Status: NOT_RUN. No code, tests, game scenes or UI were executed.**
