# GAME-WEB-CONTINUE-SHELL-003 r1 — Future acceptance plan

**Source delivered / all tests NOT_RUN.** No Godot launch, parser check,
execution, CI run, keyboard/UI trial, performance measurement or screenshot
was performed in this authoring request. All outcomes below are expectations
to be checked by a separately authorized reviewer.

## A. Proposed scripted cases — source in verify_shell_candidate.gd

The original categories S01–S12 were preserved in the future verifier.
Each category may include multiple assertions. None has run.

| Case | Input / operation | Expected state | Status |
|---|---|---|---|
| S01 | Instantiate shell | home | NOT_RUN |
| S02 | Select round | accepted, page changes | NOT_RUN |
| S03 | Select unknown page | rejected, current page retained | NOT_RUN |
| S04 | Navigate prompt/profile/bindings | each resolves | NOT_RUN |
| S05 | Inspect initial slot mocks | all locally registered | NOT_RUN |
| S06 | Navigate home | overview | NOT_RUN |
| S07 | Install unknown slot | rejected | NOT_RUN |
| S08 | Install adapter missing methods | rejected; old instance preserved | NOT_RUN |
| S09 | Unmount round | missing | NOT_RUN |
| S10 | Navigate to missing round | fallback, preview disabled | NOT_RUN |
| S11 | Remount synthetic round | ready, preview enabled | NOT_RUN |
| S12 | Go home | preview hidden | NOT_RUN |
| C01 | Inspect history after navigation | has entries | NOT_RUN |
| C02 | Navigate to same page twice | no duplicate history | NOT_RUN |
| C03 | Open module assembly page | modules selected | NOT_RUN |
| C04 | Go back | last previous page restored | NOT_RUN |
| C05 | Bad page ID | rejected, no redirect | NOT_RUN |
| C06 | Restore all; read snapshot | four stable synthetic statuses | NOT_RUN |
| C07 | Remove prompt | missing | NOT_RUN |
| C08 | View missing prompt | no action, visible fallback | NOT_RUN |
| C09 | Disable profile | disabled | NOT_RUN |
| C10 | Stage #15 without #6 | blocked_dependency | NOT_RUN |
| C11 | Stage #6 after #15 | pending_review, not actionable | NOT_RUN |
| C12 | Restore mock #6 with #15 staged | #15 returns to blocked_dependency | NOT_RUN |
| C13 | Inject malformed preview mock | degraded | NOT_RUN |
| C14 | Open degraded page | fallback and disabled button | NOT_RUN |
| C15 | Inject valid preview with bad action reply | preview ready until request | NOT_RUN |
| C16 | Send action reply missing `simulated: true` | degraded, no signal | NOT_RUN |
| C17 | Restore a degraded module | synthetic_ready | NOT_RUN |
| C18 | Inject blocked focus gate | action rejected, no signal | NOT_RUN |
| C19 | Accept valid local mock request | `simulated: true`, one signal | NOT_RUN |
| C20 | Mock returns explicit refusal | no signal, no real action | NOT_RUN |
| C21 | Mutate caller snapshot copy | internal state unaffected | NOT_RUN |
| C22 | Stage unknown slot | reject; explicit unknown | NOT_RUN |
| C23 | Attempt real-style action ID | rejected (only sample_request) | NOT_RUN |
| C24 | Pause SceneTree; request demo | reject even with focus override | NOT_RUN |
| C25 | Inspect UI slot/mode options | four each | NOT_RUN |
| C26 | Select missing scenario via UI | prompt missing | NOT_RUN |
| C27 | Select restore via UI | prompt synthetic_ready | NOT_RUN |
| C28 | Restore all after mixed states | all locally synthetic_ready | NOT_RUN |
| C29 | Restore all while on modules page | remain on modules page | NOT_RUN |

### Future command (not executed)

```sh
godot --headless --path candidates/game_web_module_shell_001_r1 --script res://verify_shell_candidate.gd
```

Expected (not observed): `PASS GAME-WEB-CONTINUE-SHELL-003 r1` and
exit 0 if every assertion succeeds; otherwise FAIL and nonzero exit.
This command must not be run without a subsequent author authorization.

## Legacy r1 inventory retained — manual/negative S13–S24

These IDs existed in the original PR #17 acceptance inventory. They are
not automated by the authored verifier and all remain **NOT_RUN**.

| Case | Original r1 expectation retained | Status |
|---|---|---|
| S13 | Each slot mock request stays local, with no game/snapshot changes | NOT_RUN |
| S14 | Tab/Shift+Tab, Space/Enter navigation has usable focus | NOT_RUN |
| S15 | Escape does not cause unapproved gameplay cancellation | NOT_RUN |
| S16 | Paused root blocks simulation requests | NOT_RUN |
| S17 | Native unfocused window blocks, regain focus safely | NOT_RUN |
| S18 | 1024x640, 960x680 and narrow sizes remain usable | NOT_RUN |
| S19 | Invalid mock preview falls back visibly, no write | NOT_RUN |
| S20 | Git diff restricted to the shell candidate path | NOT_RUN |
| S21 | No resource references to other Drafts or external assets | NOT_RUN |
| S22 | No automatic input-priority integration with #6/#10/#15 | NOT_RUN |
| S23 | No InputMap or user:// persistent mutation | NOT_RUN |
| S24 | No original manuscript or real character text in source/UI | NOT_RUN |

## B. Separate manual/native acceptance (not covered by headless source)

| Case | Reviewer action | Expected evidence | Status |
|---|---|---|---|
| M01 | Open full Godot scene; click six menu pages | screenshots, no blank/overlapped panels | NOT_RUN |
| M02 | Tab/Shift+Tab, Enter and Space through menu, selectors/buttons | focus visible, action routed once | NOT_RUN |
| M03 | Press Escape while menu and mock views shown | no unapproved #6/#10/#15 gameplay/cancel action | NOT_RUN |
| M04 | Test 1024x640, 960x680, 1280x720 and narrow viewport | labels, selectors and button accessible; note clipping if any | NOT_RUN |
| M05 | Remove a slot via assembly UI | text fallback visible, other three pages usable | NOT_RUN |
| M06 | Stage #15 with #6 missing, then stage #6 | blocked then pending, never ready | NOT_RUN |
| M07 | Minimize/unfocus window, then click request | request does not emit; resume behaves safely | NOT_RUN |
| M08 | Pause/unpause root SceneTree; attempt request | pause rejects; restart safely | NOT_RUN |
| M09 | Change assembly state repeatedly 30 times | no stale view, focus loss or crashes | NOT_RUN |
| M10 | With mock and pending status, inspect local `user://` | no profile/snapshot/config file created | NOT_RUN |
| M11 | Snapshot InputMap before/after navigation | unchanged | NOT_RUN |
| M12 | Inspect Git diff/file paths against main | only shell candidate folder changed | NOT_RUN |
| M13 | Search shipped source/UI and inspect public diff | no original story, private character or real-world evidence | NOT_RUN |
| M14 | Verify exact Godot minor/renderer/OS matrix | record compatibility and any errors | NOT_RUN |
| M15 | Review external RefCounted injection attack surface | no untrusted adapter automatically loaded | NOT_RUN |
| M16 | Confirm #6/#10/#14/#15 actual source independent | no implicit cross-imports or assumed approval | NOT_RUN |

## C. Negative/nonfunctional cases still needed after approval

- Automated test of a mock that emits many signals, returns oversized text,
  throws a GDScript error, or frees itself mid-call: **NOT_RUN**. The current
  future verifier covers malformed shapes, but not every hostile object.
- UI responsiveness, mobile adaptation and accessibility (screen reader,
  IME, DPI, contrast) require real native checks: **NOT_RUN**.
- Integration of actual #6 writer, #10 focus, #14 profile scene or #15
  router is **out of scope**. Do **not** report such interop as PASS from
  this mock-only suite.
- Concurrent custom instances, event storm and OS suspend/resume are
  **not guaranteed** by this source candidate.

## D. Future evidence format

```json
{
  "task_id": "GAME-WEB-CONTINUE-SHELL-003",
  "version": "r1",
  "commit_sha": "<actual reviewed commit after execution>",
  "godot_version": "<observed>",
  "platform": "<observed>",
  "case_id": "C10",
  "result": "NOT_RUN",
  "command": null,
  "exit_code": null,
  "evidence": [],
  "notes": "Await authorized execution"
}
```

Never replace `NOT_RUN` with PASS based on code review or GitHub file
presence. Record the exact runtime environment, stdout/stderr, exit code,
individual failure IDs, screenshots, dates and operator before acceptance.

## E. Handoff boundaries

- Parent PR #17 remains Draft on its own `codex/` branch, no main merge.
- Source references #6/#10/#14/#15 remain unapproved candidates.
- Current deliverable is executable-intended source, **NOT_RUN**; a pending
  external bridge is not a missing implementation promised in this task.
- No original manuscript, real identity, plot or private evidence uploaded.
- No change to upstream sources, Notion or Drive; final author acceptance
  is still required before any production integration.
