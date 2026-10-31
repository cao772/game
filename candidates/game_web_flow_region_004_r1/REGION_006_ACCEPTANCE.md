# GAME-WEB-REGION-006 r1 — Future acceptance matrix

**EVERY CASE IS NOT_RUN. This file specifies expected behavior only.**

When the owner later permits execution, record the exact GitHub HEAD,
Godot binary/build, OS, renderer, command, stdout/stderr and exit code.
Desktop claims need actual screenshots/input observation. Never infer
`PASS` from a test's printed expected string.

## Future pure policy checks

```sh
godot --headless --path candidates/game_web_flow_region_004_r1 \
  --script res://verify_region_006_pure_candidate.gd
```

`N001–N026` planned: idle; unknown/invalid target rejection; A lookup;
start-to-A; time-step validation; 0.10s step cap; pause on focus loss;
no advance while paused; explicit user-authorized resume; bounded
straight-line arrival within 1.20m; no repeat movement after arrival;
cancel/reset; no resumed cancellation. Include exact count, stable ID,
finite coordinates and 90-step termination checks.

`K001–K014` planned: role/ID stored only for valid prompt focus;
a pending restoration claim cannot be consumed while inactive;
window-return key-release gate blocks held keys; release re-enables
manual keyboard motion; a claim succeeds exactly once with the
same target ID; changed ID and host focus refuse to restore; no prompt
role yields no claim; reset clears state.

Expected output **only if a future run actually passes**:
`PASS GAME-WEB-REGION-006 r1 future pure contracts`.

## Future scene-coordinator checks

```sh
godot --headless --path candidates/game_web_flow_region_004_r1 \
  --script res://verify_region_006_scene_candidate.gd
```

`S601–S624` planned: independent scene and modules present;
initial idle and hidden prompt; deterministic pure navigation seeded
through local candidate seam; simulated loss pauses; simulated window
return does not resume; explicit pure-model resume; arrival near A;
model/prompt IDs agree; no auto-confirm; leave hides; reset clears
navigation, focus gate, confirmation and journal.

**Important:** the scene script uses direct in-memory policy calls
rather than a native window to check logic wiring. It must not be
used to claim that real OS Alt+Tab or GUI pointer behavior passed.
If any native-focus-dependent scenario cannot be observed headlessly,
its desktop case remains `INCOMPLETE`.

Expected output **only on future success**:
`PASS GAME-WEB-REGION-006 r1 future scene contracts`.

## Proposed desktop/GUI cases — NOT_RUN

| ID | Operator procedure | Observable acceptance criterion |
| --- | --- | --- |
| M63 | Open only independent r004 candidate project | Scrollable host panel; no real characters, story or imported game levels |
| M64 | From far point press "navigate A" | Blue player marker begins moving along XZ, navigation mode moving |
| M65 | Observe arrival near A | Marker stops within approach range, prompt shows, A selected; no auto confirmation |
| M66 | Start navigation B, then change host position | Current path cancelled; no route continues in the background |
| M67 | Start navigation C, press Pause | Marker stops, mode paused; repeated Pause does not advance |
| M68 | Press Continue while paused, window focused, keys released | Route explicitly resumes; not a new confirmation event |
| M69 | Press Cancel while moving | Route stops, no further automatic movement |
| M70 | Start A navigation, Alt+Tab out of the Godot window | Route pauses immediately; no movement or confirmation while inactive |
| M71 | Alt+Tab back without pressing Continue | Route remains paused; no automatic resumption |
| M72 | Alt+Tab out while W is held, then return still holding W | Player does not move; input unblocks only after W/A/S/D are all released |
| M73 | Focus ActionButton for A, Alt+Tab away/return without other input | Same A ActionButton focus restored at most once; no confirm count change |
| M74 | Focus Next, Alt+Tab away, then return | Next focus restored only if still valid and visible |
| M75 | During loss, change visible prompt target to B | Stale A focus is not restored; no selection/confirmation is emitted |
| M76 | On window return, click a host button before deferred restoration | Host focus remains authoritative, prompt does not steal focus |
| M77 | Hide prompt during pending restoration | Pending claim clears; hidden prompt is not focused again |
| M78 | Reduce multi-target list so prior navigation button disappears | Focus falls back to visible ActionButton, not hidden navigation |
| M79 | While prompt owns keyboard focus, hold WASD | No unintended background marker movement |
| M80 | Use manual "release focus" control, then WASD | Movement resumes normally after safe release gate; model updates proximity |
| M81 | After reaching A, switch choice to B when both are nearby | Target focus/selected marker and model ID agree; no automatic confirmation |
| M82 | Explicitly confirm selected nearby target | One local confirmation and visible `success` feedback, exact selected ID |
| M83 | Attempt to confirm after leaving or manual hiding | Visible `rejected` feedback, confirmation count unchanged |
| M84 | Trigger navigation, focus, approach and rejection repeatedly | 12-record journal cap and six visible lines; statuses include `navigation` / `focus` |
| M85 | Reset synthetic flow while navigation or focus claim exists | Route/focus state idle, marker far, count zero, one reset feedback |
| M86 | Resize 1280×720 viewport and HiDPI | Side controls scroll, prompt remains usable; clipping documented if present |
| M87 | Compare PR #23 branch diff against prior HEAD | Every path inside same r004 candidate folder; prompt copies unchanged |
| M88 | Compare r004/r005 earlier regression scripts | All earlier suites retained and executable in a *future* authorized run |

## Evidence rules

Each case should record `status: NOT_RUN|PASS|FAIL|INCOMPLETE`,
actual observed input/output and evidence references. For M70–M78,
provide a native window focus transition description, frame/marker
before-after state, keyboard focus indicator and any unexpected
movement. For M86, include real screenshots. No test has been
performed in this authoring turn, so **no cases may be reported PASS**.

Trial values: movement 2.0 m/s, frame cap 0.10s, stop range
1.20m, existing entry/exit 1.55/1.85m, feedback journal 12.
They are **proposals, not approved game rules or performance metrics**.

All original r004 (F001–F026, G001–G020) and r005
(P001–P030, S001–S029, M41–M62) cases remain future requirements,
not assumed satisfied by these new tests.
