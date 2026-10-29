# Candidate integration handoff — GAME-WEB-PLAY-CHAR-005 r1

**NOT_RUN / NOT APPROVED / PUBLIC SYNTHETIC SOURCE ONLY**

## A. Standalone Godot project (recommended first review target)

Open \`candidates/game_web_flow_char_004_r1/project.godot\` with a
Godot 4.x binary chosen later by the author. The project defines
\`flow_demo.tscn\` as its standalone entrypoint; this scene uses only
the pinned public synthetic \`placeholder_profiles.json\`.

The module's own scene is \`profile_flow_candidate.tscn\`, a Control-based
MarginContainer. Its root \`profile_flow_candidate.gd\` owns an in-memory
list/detail model and never writes to disk or network.

Local candidate calls:
- \`load_placeholder_profiles() -> bool\`: fixed local fixture only.
- \`set_profiles(Array) -> bool\`: atomically validates full #14-schema
  Dictionaries (up to 24; unique profile_id); a bad batch does not replace
  the previous good one.
- \`open_profile(id: String) -> bool\`: known and filter-visible only.
- \`go_back() -> bool\`: return detail to list.
- \`route_copy() -> Dictionary\`: read-only route, ID, filter, total.
- \`current_profile_copy() -> Dictionary\`, \`visible_rows_copy() -> Array\`:
  defensive read-only view data.

Candidate-only signals:
\`route_changed(route_name, profile_id)\`,
\`exit_requested\`, \`collection_replaced(record_count)\`,
\`collection_rejected(reason)\`.

No shell, input router, save/history clock, NPC, story or canon contract
is implied by these names.

## B. Embedding a UI in a separate reviewed Control host

1. **Choose explicit ownership**: the host owns mounting/unmounting,
   the host's Back/Escape policy and what to do on \`exit_requested\`.
2. Copy/rebase this project into a reviewed Godot workspace, respecting
   root-relative \`res://\` scripts and the pinned #14 source lock in
   \`UPSTREAM_LOCK.md\`; resolve collisions rather than overwriting files.
3. Instantiate \`profile_flow_candidate.tscn\` into a suitable Control
   container, not the existing PR #17 registry, and attach it as a child.
4. Supply only approved/carefully validated dictionaries or invoke the
   fixed synthetic fixture in an isolated demonstration. The module
   refuses invalid/duplicate entries atomically.
5. Listen to its informational \`exit_requested\` and route via **host
   controls**; do not infer that the module can call \`show_page()\`
   or cancel story actions.
6. On removal, the host must free its own instance. No save or
   persistent selected-profile state exists in this module.
7. Run the later-authorized test plan before considering acceptance.

These are integration instructions, **not executed integration evidence**.

## C. Shell Draft PR #17 is not a live UI host

Read from the prior FLOW-CHAR-004 public review: shell #17 at
\`5ed0602cfb7498900dee13936194bac69d7c9737\`.
Its \`profile\` slot uses a trusted-local RefCounted
\`preview()\`/\`preview_action("sample_request")\` mock and text-only
display; it does **not** expose an approved Control scene attachment.

The independent \`shell_profile_adapter_candidate.gd\` in this branch is
only such a synthetic mock. Even if an authorized reviewer later mounts
it in shell #17, it shows placeholder text, **not** this list/detail UI.
A future shell change would have to introduce a Control host, define
navigation/focus and disabled-state handling, and review a limited
dependency adapter. This PR deliberately does none of that.

## D. Error injection later (not run now)

Make a disposable *copy* of the candidate project when permission to test
is granted. Verify that temporarily hiding the panel resource yields
an error/fallback while list, Back and Exit remain available; restore it
and press Retry. Temporarily remove or corrupt only the synthetic
fixture, then press Reload and verify that the previous valid data is
explicitly retained; restore it to recover.

Don't edit or replace the authoritative public branch's fixtures while
testing; don't use actual characters, manuscripts, raw conversation
evidence or externally sourced assets.

## E. Unknowns and author acceptance gate

Unknown: Godot minor, platform target, shell Control mounting policy,
global key/focus arbitration, theme/font and screen-reader criteria.
Thus no integration, accessibility compliance, runtime compatibility
or performance claim is made.

**Current state: SOURCE_SUBMITTED / NOT_RUN.**


## F. Independent demo host resource fault path

The demonstration now loads `profile_flow_candidate.tscn` dynamically
from a **fixed** local path rather than via a hard scene dependency.
Its static toolbar and fallback remain even if the flow PackedScene is
missing, incompatible, or fails the minimum local candidate method/signal
checks. The **Reload Component** action unmounts any prior demo flow
instance before another attempt; this never touches game state.
Restoring the disposable file and retrying is a separate future manual
acceptance step. On a successful local mount, the host reads only the
synthetic fixture and listens to the informational exit signal.

This host is not a shell integration: PR #17 still has no approved
Control-scene mounting slot.
