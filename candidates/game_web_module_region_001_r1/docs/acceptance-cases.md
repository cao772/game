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

---
## GAME-WEB-MODULE-REGION-002 r1 — NEW future cases (NOT_RUN)

### Planned headless addition

```sh
godot --headless --path . --script res://verify_interaction_prompt_extension_candidate.gd
```

Expected text if verified later (not observed):
`PASS GAME-WEB-MODULE-REGION-002 r1 (future headless checks)`, exit 0.
Review the script and record the exact Godot version before execution.
Proposed checks: empty/duplicate/oversized targets, initial selection B,
multi-target navigation and wraparound, invalid selection no-op, selected
ID in emitted signal, atomic style rejection, high-contrast and default
preset switching, focus snapshot contract, pause/window gate, 10 cycles,
and original single-target entry point.

### Planned native GUI cases

| ID | Preparation | Action | Expected observable result |
| --- | --- | --- | --- |
| M13 | Open demo | Show three generic targets | Target counter 1/3; previous/next buttons visible; only placeholder labels |
| M14 | A selected | Use next button or PageDown with focus inside prompt | Active ID becomes B; no interaction request emitted |
| M15 | C selected | PageDown then PageUp | C → A → C wrapping; action focus retained when switching via keys |
| M16 | Prompt shown | Use Tab and Shift+Tab repeatedly | Focus visits exactly four prompt buttons with visible focus outline |
| M17 | Single-target prompt | Use Tab/Shift+Tab | Only action/dismiss are focusable; navigation hidden |
| M18 | Focus previous or next | Click another target in demo and reopen multi-target prompt | Focus returns to a valid prompt control; focus role matches active native control |
| M19 | Prompt showing B | Activate action Button | One request for selected ID B, not for stale A |
| M20 | Prompt visible | Hide with Escape when focused, then show again | Role becomes none when hidden, ID/count clear; re-show captures usable action focus |
| M21 | Prompt visible | Toggle high contrast/default via demo | Color/size/focus outline changes; active target and signal count stay unchanged |
| M22 | Prompt visible | Apply invalid style via API | Operation false; previous style visually unchanged (atomic) |
| M23 | Prompt visible | Apply style padding 4/36, font size 12/30 | No panel overlap/clipping at supported demo viewport; record any failures |
| M24 | Outside host control has focus | Press Escape, PageDown, 1, 2, 3, R | Prompt does not consume outside keys; no new global mapping |
| M25 | Prompt visible | Alt+Tab away and back; then pause/unpause | No off-focus/paused request; record focus after return |
| M26 | Any target list | Replace with invalid/duplicate IDs | Existing target/visibility remains stable; no partial update |
| M27 | Three targets | Repeat show → switch → request → hide 10 times | No duplicate request signals, stale IDs, or focus state leakage |
| M28 | Existing r1 tests | Run original test script separately when permitted | Original single-target behavior must remain compatible; no implied PASS now |

The native visual and keyboard-focus cases **must not** be presented as
passing merely because future headless checks return 0.
Save screenshots, event counts, Godot version, commit SHA and unexpected
focus transitions. Any failures should be preserved for review, not edited away.
