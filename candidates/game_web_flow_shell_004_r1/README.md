# GAME-WEB-FLOW-SHELL-004 r1 — isolated candidate integration flow

**SOURCE_SUBMITTED candidate only; NOT_RUN; no shared-API/canon approval.**

This independent Godot 4 project assembles a pinned *copy* of the public
Draft PR #17 shell with local public Draft candidate copies from #10 (prompt),
#14 (profile panel), and #15 (input configuration). **It does not modify any
source PR**, does not cherry-pick their branches, and does not install a
gameplay/router/snapshot dependency. It uses only manufactured placeholder
targets and profiles. PR #6 is explicitly NOT included.

## Main entry / complete module

- `project.godot` — independent root, main scene `res://flow_entry.tscn`.
- `flow_entry.tscn` — root wrapper with pinned local PR #17 shell scene.
- `flow_root.gd` — actual candidate flow coordinator; stage switching,
  navigation, fallback, prompt signal feedback, readonly profile, binding UI.
- `shell_demo.tscn`, `shell_candidate.gd`,
  `module_registry_candidate.gd`, `placeholder_adapter_candidate.gd` —
  exact PR #17 implementation copies. No upstream shell branch modified.
- `adapters/prompt_isolated_adapter.gd` — validates and mounts local #10
  scene and handles its `interaction_requested(StringName)` notification.
- `adapters/profile_isolated_adapter.gd` — validates and mounts local #14
  scene and supplies a synthetic, schema-complete Dictionary to
  `set_profile`; never reads actual character data.
- `adapters/input_isolated_adapter.gd` — restricts #15 settings facade to
  `current_profile`, `key_display`, `preview_rebind`, `rebind`,
  `restore_defaults` (in-memory only). No file-profile I/O, keyboard
  dispatch or InputMap changes.
- `vendor/prompt/`, `vendor/profile/`, `vendor/input/` — **pinned
  public candidate copies**, with only resource path rewrites so resources
  resolve inside this independent root. These are unapproved source snapshots,
  not approved APIs.
- `verify_shell_candidate.gd` — copied original future-only shell suite.
- `verify_flow_candidate.gd` — new future-only integration suite, NOT_RUN.
- `DESIGN.md`, `SOURCE_MAP.md`, `ACCEPTANCE.md` — design rationale,
  exact provenance and future acceptance plan.

## Candidate navigation and flow

Open overview → **开始合成演示流程** → prompt (two synthetic target entries)
→ **继续下一步** → profile (synthetic record only)
→ **继续下一步** → input settings (preview conflicts, apply memory-only,
restore defaults) → **完成并返回概览**.

Every step is also accessible through the existing PR #17 shell menu. Back
navigation, module assembly scenarios and missing-module fallbacks remain
owned by its unmodified local shell copy. Leaving a step disposes its local
scene. The input config object lasts only for the current process; it never
writes `user://` or reads disk settings.

The prompt interaction emits **synthetic_prompt_requested** on this wrapper
and updates a status label; it never invokes PR #6, a round snapshot,
a plot event or an actual interaction handler. The profile panel is read-only.
The input configuration's key map is **not connected to keyboard routing**.

## Fail-closed and exact limits

The wrapper consults the shell's **in-memory** `module_status(slot)`.
It may mount a local copy only in `synthetic_ready` mode. In `missing`,
`disabled`, `degraded`, `blocked_dependency` or `pending_review`, it
renders shell's fallback and **does not mount** the vendor component.
The additional adapter refuses absent script/scene resources and missing
source methods. All origins remain Draft, even when a local copy mounts.

PR #15's optional `input_binding_router_candidate.gd` and PR #6
`integration_candidate.gd` are **intentionally absent**, because they
require unapproved action ownership, keyboard/focus arbitration and snapshot
persistence. PR #15 input **configuration** is locally demonstrable without
dispatch; this does not mean the end-to-end input system is integrated.

No manuscript, proprietary scene, real character, real target, private image,
unpublished note, connected data, network service, game state or actual world
time is included. No file writes or InputMap changes are intentionally called
by the new entrypoint. Upstream candidate source includes optional
file-writing methods, but the isolated adapter never exposes or invokes them.
Do not pass untrusted objects into the script bridge: method presence and
`ResourceLoader` are not security sandboxes.

## Future run (ONLY after separate author authorization)

```sh
godot --headless --path candidates/game_web_flow_shell_004_r1 --script res://verify_flow_candidate.gd
```

Native Godot editor preview, parser check, test execution, key/focus,
accessibility, performance, actual cross-PR compatibility and CI:
**NOT_RUN**. No PASS or working-screenshot claim is made.

## Record
`task_id=GAME-WEB-FLOW-SHELL-004`; `version=r1`;
`input=PR17 + PR10/14/15 pinned source`; `scope=isolated demonstration flow`;
`state=SOURCE_SUBMITTED/NOT_RUN`; `canon=not applicable`;
`author_review=PENDING`; `main_merged=NO`;
`other_PRs_edited=NO`; `Notion/Drive=NOT_WRITTEN`.
