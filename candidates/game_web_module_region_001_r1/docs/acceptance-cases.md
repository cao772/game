# Future verification cases — NOT_RUN

Task: GAME-WEB-MODULE-REGION-001; version: r1.
These are **proposed** acceptance steps, not reported test results.

## Automated headless contract checks

Run, only when authorized, from this independent candidate project root:

```sh
godot --headless --path . --script res://verify_interaction_prompt_candidate.gd
```

Expected (unverified): `PASS GAME-WEB-MODULE-REGION-001 r1`
plus exit code 0; failures must exit nonzero.
The fixture loads the independent prompt scene and checks:
- Initial hidden state and rejection of invalid placeholder inputs.
- Visible state and selected StringName target after show.
- Button focusability plus explicit Tab/Shift+Tab paths.
- Blocked request emits no signal; allowed injected request emits once.
- Placeholder replacement while shown does not duplicate visibility.
- hide clears current target; repeated hide and hidden requests are no-ops.
- 10 show/request/hide cycles preserve deterministic counts.
- SceneTree pause blocks requests even with injected native-focus override.

Headless logic results do not prove actual native GUI focus or visual quality.

## Manual desktop/Godot 4.x cases (all NOT_RUN)

| ID | Preparation | Operation | Observable pass criterion |
| --- | --- | --- | --- |
| M01 | Open `demo.tscn` | Launch demo | Only two generic target buttons and one hide button visible; prompt initially absent |
| M02 | Demo running, click placeholder A | Observe shown prompt | Target A label and action/dismiss buttons visible; action button receives keyboard focus |
| M03 | Prompt visible | Press Tab then Shift+Tab | Focus moves between action/dismiss without jumping to external demo buttons |
| M04 | Action focused | Press Enter, then Space | Exactly one `interaction_requested(placeholder_a)` per discrete activation; status count advances |
| M05 | Prompt visible | Press Escape with focus inside prompt | Prompt hides; active target clears; outside control regains focus if still valid |
| M06 | Prompt hidden | Press Escape, Enter, Space | No prompt action signal emitted; no unexpected scene action |
| M07 | Show A, then choose B via host (call/API) | Inspect prompt | Target ID/label updates; no hide-show transition; action emits B, not A |
| M08 | Show A | Click dismiss button | Prompt hides; repeated external hide is safe |
| M09 | Prompt visible | Alt+Tab away; attempt actions, then return | Window-unfocused native action must not emit; focus behavior on return recorded |
| M10 | Prompt visible | Pause SceneTree in controlled test | Both native and injected action dispatch blocked |
| M11 | New instance | Repeat show/interact/hide ten rounds | Ten signals for ten real activations, no stale target or doubled connections |
| M12 | Other host controls focused | Press 1/2/3/R and Escape | No module mappings for 1/2/3/R; Escape does not consume if focus is outside the prompt |

## Evidence to retain on future execution

- Godot binary path and full version; OS/GPU/renderer.
- Exact candidate GitHub commit SHA and the case IDs exercised.
- Raw stdout/stderr and command exit status for headless test.
- Native screenshots showing hidden, visible, A/B replacement, action focus,
  dismiss focus and target status text.
- Manual record of focus-loss/return, native key repeat and pause behavior.
- Any deviations labeled FAIL / BLOCKED / INCOMPLETE, never promoted to PASS
  solely because a scripted process exits 0.

## Acceptance boundary

No change to published game scenes, novel manuscript, roles, worldbuilding,
shared interfaces, actual save model, or global InputMap is in scope.
The owner approves both integration and any eventual merge separately.
