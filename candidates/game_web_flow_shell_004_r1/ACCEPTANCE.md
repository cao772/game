# GAME-WEB-FLOW-SHELL-004 r1 — future acceptance suite

**All statuses: NOT_RUN.** No Godot process, editor, parser, static checker,
test script, CI, native UI or screenshot execution in this task. An authored
assertion is not a result. Reviewer must record version, commands, logs,
exit code and SHA before claiming PASS.

## Source-authored future checks (verify_flow_candidate.gd)

| ID | Candidate test | Expected | Status |
|---|---|---|---|
| F01 | Instantiate entry/main shell | Home shown | NOT_RUN |
| F02 | Begin synthetic demo flow | Prompt route accepted | NOT_RUN |
| F03 | Read active flow step | Prompt | NOT_RUN |
| F04 | Inspect mounted stage count | One widget | NOT_RUN |
| F05 | Probe prompt method | `show_for_targets` present | NOT_RUN |
| F06 | Inspect prompt display state | Shown | NOT_RUN |
| F07 | Cycle two sample targets | Selection works | NOT_RUN |
| F08 | Request prompt interaction with injected focus gate | Only demo signal | NOT_RUN |
| F09 | Count prompt signals | Exactly one | NOT_RUN |
| F10 | Advance to next step | Accepted | NOT_RUN |
| F11 | Active step | Profile | NOT_RUN |
| F12 | Profile mount | One panel | NOT_RUN |
| F13 | Validate panel API | `profile_copy` exists | NOT_RUN |
| F14 | Inspect copy | Synthetic `sample-record-a` only | NOT_RUN |
| F15 | Advance to input | Accepted | NOT_RUN |
| F16 | Active step | Bindings | NOT_RUN |
| F17 | Stage population | One input editor | NOT_RUN |
| F18 | Inspect action selector | Five source actions | NOT_RUN |
| F19 | Inspect key choices | At least 10 sample choices | NOT_RUN |
| F20 | Preview collision: action `observe`, KEY_2 | Conflict, no mutation | NOT_RUN |
| F21 | Apply conflicting key | No change signal | NOT_RUN |
| F22 | Apply free KEY_4 after explicit preview | One local memory change | NOT_RUN |
| F23 | Complete flow | Home | NOT_RUN |
| F24 | Confirm home | No active module | NOT_RUN |
| F25 | Remove prompt slot | Unmounted in shell | NOT_RUN |
| F26 | Navigate to removed prompt | Navigation remains possible | NOT_RUN |
| F27 | Inspect live stage on missing slot | No vendor widget | NOT_RUN |
| F28 | Inspect missing status | `missing` | NOT_RUN |
| F29 | Stage #15 while #6 not staged | Metadata-only candidate | NOT_RUN |
| F30 | Dependency evaluation | `blocked_dependency` | NOT_RUN |
| F31 | Open blocked input page | Navigation accepted | NOT_RUN |
| F32 | Stage content while blocked | No input editor | NOT_RUN |
| F33 | Stage #6 metadata | No source execution | NOT_RUN |
| F34 | Recheck #15 | `pending_review` (not connected) | NOT_RUN |
| F35 | Inspect stage after dependency status change | Still empty | NOT_RUN |
| F36 | Restore local mock prompt | Registration succeeds | NOT_RUN |
| F37 | Open prompt again | Source-copy adapter attempt | NOT_RUN |
| F38 | Inspect mounted prompt | One local widget | NOT_RUN |

These are only **intended source checks**. Native focus and layout are outside
this scripted suite.

## Native/manual and negative checks (future)

| ID | Scenario | Required outcome | Status |
|---|---|---|---|
| M01 | Open root Godot 4 scene, 1024×640 | No parser errors, legible menu and stage | NOT_RUN |
| M02 | Click the three-flow steps in order | Prompt → profile → bindings → home | NOT_RUN |
| M03 | Prompt enter/space, tab/shift-tab, two targets | Valid focus, no actual gameplay dispatch | NOT_RUN |
| M04 | Prompt Escape then menu back | Proper local dismissal/focus restoration | NOT_RUN |
| M05 | Profile scroll, section navigation, long text | No clipping, copy of synthetic data only | NOT_RUN |
| M06 | Input remap preview collision, invalid key, repeated apply | No silent overwrite, no disk changes | NOT_RUN |
| M07 | Quit/relaunch after local rebinding | No durable profile persisted | NOT_RUN |
| M08 | Remove/disable/stage each slot from assembly page | Existing menu and missing fallback work | NOT_RUN |
| M09 | Temporarily remove local prompt scene from isolated copy | Explicit degraded view, no mock action fallback | NOT_RUN |
| M10 | Temporarily remove profile helper/script | Import or mount failure recorded, no false readiness | NOT_RUN |
| M11 | Temporarily remove input settings script | Explicit degraded view, no input widget | NOT_RUN |
| M12 | Focus lost while prompt visible | Prompt must not emit user interaction | NOT_RUN |
| M13 | Pause scene; try input buttons and prompt | No unexpected write or game dispatch | NOT_RUN |
| M14 | Narrow/high-DPI screen | Main menu and child controls accessible | NOT_RUN |
| M15 | InputMap before/after | No global key mapping mutation | NOT_RUN |
| M16 | `user://` before/after | No snapshot or key-settings file writes | NOT_RUN |
| M17 | Git PR diff compared with main | Only new `game_web_flow_shell_004_r1` folder | NOT_RUN |
| M18 | Search public files/UI for private lore, real characters, chat evidence | Absent | NOT_RUN |
| M19 | Verify source-copy contract pinning | Exact SHAs/path rewrites documented | NOT_RUN |
| M20 | Native accessibility/IME, focus and keyboard priority | Record exact limitations, do not assume success | NOT_RUN |
| M21 | Godot exact minor, OS, renderer and runtime profile | Record actual results and unresolved incompatibilities | NOT_RUN |
| M22 | Attempt to use optional PR #15 disk API via shell UI | No such action exposed | NOT_RUN |
| M23 | Confirm PR #6 files absent | No input router/writer linkage | NOT_RUN |
| M24 | 30 repeated page/assembly cycles | No stale stage, duplicate signals or missing navigation | NOT_RUN |

## Future command — DO NOT EXECUTE NOW

```bash
godot --headless --path candidates/game_web_flow_shell_004_r1 --script res://verify_flow_candidate.gd
```

Anticipated output only if authorized test succeeds:
`PASS GAME-WEB-FLOW-SHELL-004 r1`, process exit 0.
Neither is observed or claimed at submission time.

## Proposed evidence format

```json
{
  "task_id": "GAME-WEB-FLOW-SHELL-004",
  "version": "r1",
  "commit_sha": "<fill after validation>",
  "godot_version": null,
  "platform": null,
  "case_id": "F20",
  "result": "NOT_RUN",
  "command": null,
  "exit_code": null,
  "logs": [],
  "screenshots": [],
  "reviewer": null
}
```

Do not merge or label accepted before author review. Even if future
headless assertions pass, they do not establish that the separate Draft
PRs can safely share real gameplay input, focus, save, canon or character
interfaces.
