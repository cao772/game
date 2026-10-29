# Source audit — exact pinned public Draft inputs

All following GitHub PRs were read via their actual source and file lists
before assembly; a PR title was never treated as an API specification.
All were **open Drafts**, not approved release interfaces.

| PR | HEAD reviewed | Source used | Boundary |
|---|---|---|---|
| [#24](https://github.com/cao772/game/pull/24) | `9b35bf957d5c544e833dd2d68c818c81f6a224e9` | existing `flow_entry.tscn`, `flow_root.gd`, shell menu; project.godot | new overlay on same PR branch; no original shell script edits |
| [#18](https://github.com/cao772/game/pull/18) | `819395fff9b694ac2b11e3b58485b24696f8128b` | `event_flow_preview_candidate.py` source reviewed; exact `placeholder_start/next/end.json` copied | Python checker depends on stacked PR #9 and is not callable from Godot; local traversal is a distinct unapproved adapter |
| [#19](https://github.com/cao772/game/pull/19) | `6fbb184989889d738f108a76dc9de85c3262ac4d` | `input_settings_ui_backend_004.gd`, V1 bindings, V2 migration, settings/controller and workflow from its stacked base | original input UI has disk actions; memory-only backend methods mounted instead; no game router |
| [#20](https://github.com/cao772/game/pull/20) | `ca0344b500b6a26e4a13eb6be22b2f86524f993f` | `snapshot_browser.tscn`, browser controller/model and pinned inspector | read-only, explicit user:// folder, no automatic list of saves |
| [#21](https://github.com/cao772/game/pull/21) | `6d57b441251564878575af121a224e6727d92e25` | profile flow scene/controller/model, validator, panel, fixture loader, public sample profiles and helpers | synthetic list/detail/back, not actual character data |
| [#23](https://github.com/cao772/game/pull/23) | `5ecac707f40bacaaaab10e574b97724ccebaabb6` | Node3D `main.tscn`, flow, model, prompt scene/script, synthetic targets | synthetic graybox only; no real world or confirmed event trigger |

## Resource relocation

Each public candidate source is copied **only** into the new
`play_005/vendor/<module>/` directory, preserving logic but rewriting
relative `res://` references to the matching fixed isolated prefix.
No source PR branch is mutated or merged. JSON sample fixtures remain
byte-identical to reviewed originals.

All copied source methods are candidate-local and unapproved:
- #23 `flow_snapshot()`: `loaded`, `confirm_count`, `last_confirmed`.
- #20 `_inspect_pressed` existing UI method; hosted as read-only scene.
- #21 `load_placeholder_profiles()`, `exit_requested`, list/detail.
- #19 `profile()`, `preview()`, `rebind_memory()`,
  `restore_defaults_memory()`, `key_label()`.
- #18 JSON `event_id/actions/next_event_id/on_ignore_event_id`;
  Python `CheckedEventPreview` **not ported**.

## Missing contracts and risks

1. No approved mapping from region target ID to event ID; the user
   explicitly clicks a separate preview screen; no game event fires.
2. No approved event schema/validator callable in Godot. PR #18's Python
   checker from PR #9 is deliberately not bypassed under a claim of
   parity; result says NOT_RUN.
3. No approved save writer or runtime save integration. Browser can
   inspect only manually supplied compatible local `user://` locations.
4. No approved full input ownership, global focus priority or keyboard
   router; #19 disk UI intentionally excluded and #6 absent.
5. Godot minor version/native performance, SubViewport input/focus,
   scene mount lifecycle, split layout and CI are unknown; NOT_RUN.
6. Vendor script source may contain unexecuted or compile-sensitive
   assumptions: full runtime review needed before any release.

All new logic is restricted to this PR branch and public candidate
folder. No source manuscript, private evidence, main changes or canon.
