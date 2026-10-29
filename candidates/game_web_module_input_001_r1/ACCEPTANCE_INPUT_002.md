# GAME-WEB-MODULE-INPUT-002 r1 — future acceptance matrix

**All cases NOT_RUN.** This file defines intended validation only.
No code was executed, no tests were invoked, no parse/CI or performance
claims are made. No main-branch or shared-interface approval.

Related: [PR #15](https://github.com/cao772/game/pull/15) and
\`MODULE_INPUT_002.md\`.

## Deferred automated test cases

The new \`verify_input_settings_002.gd\` provides future SceneTree assertions.

| ID | Expected check | Pass criterion |
| --- | --- | --- |
| I201 | Initial map | Five PR #15 defaults, no mutation |
| I202 | Human-readable key labels | Letters and special-key display are stable |
| I203 | Conflict preview (1→2) | CONFLICT, two owner labels, cannot apply |
| I204 | Alternative suggestion | A currently unused supported key is offered |
| I205 | Side-effect-free preview | No signals, profile changes or disk IO |
| I206 | Unknown action / invalid typed key | Explicit errors without mutation |
| I207 | Same-key preview | Can apply; changed=false |
| I208 | Single/all-default preview | Correct proposal, no mutation |
| I209 | Valid in-memory rebind | One change event; no implicit save |
| I210 | Rebind same key again | No change event |
| I211 | Blocked single-default reset | Conflict, other action unaffected |
| I212 | Whole-default reset | Simultaneously restores all five mappings |
| I213 | Whole-default reset repeated | Idempotent; no extra change event |
| I214 | user:// path traversal | INVALID_PATH; no write |
| I215 | Wrong basename | INVALID_PATH; no write |
| I216 | Missing parent folder | MISSING_DIRECTORY; no write |
| I217 | First explicit save | New valid JSON at isolated fixture path |
| I218 | Save unchanged map twice | ALREADY_PERSISTED, bytes unchanged |
| I219 | Persisted remap | Memory changes only after disk commit |
| I220 | Second instance attempts blind overwrite | LOAD_REQUIRED |
| I221 | Second instance loads same profile | Exact bindings restored |
| I222 | Single-default reset to occupied key | Conflict; memory and disk unchanged |
| I223 | Existing .tmp blocks reset-and-save | TEMP_OCCUPIED; no disk or memory mutation |
| I224 | Full persisted restore after temp removal | Defaults committed and applied once |
| I225 | Full persisted restore repeated | No-op, no extra file overwrite |
| I226 | External valid file edit | EXTERNAL_CHANGE prevents lost update |
| I227 | Explicit reload after external edit | New file is accepted, normalized into memory |
| I228 | File invalid JSON | Load/save refuse, file untouched, memory unchanged |
| I229 | Deleted previously loaded file | EXTERNAL_DELETE; no silent recreation |
| I230 | Returned profile copy | Client mutation does not affect internal bindings |
| I231 | Success/error operation signals | One report per requested operation |
| I232 | Finite execution | Zero on full pass; nonzero on assertion failure |

These checks are *not* an execution report. Before marking any case PASS,
Codex must run the exact committed sources and retain stdout/stderr and
the final commit SHA.

## Future command (not executed)

From repository root using a compatible Godot 4 binary:

\`\`\`bash
godot --headless --path candidates/game_web_module_input_001_r1 \
  --script res://verify_input_settings_002.gd
echo $?
\`\`\`

Then re-run existing PR #15 suites under explicit future authorization:

\`\`\`bash
godot --headless --path candidates/game_web_module_input_001_r1 \
  --script res://verify_input_module_candidate.gd
echo $?
\`\`\`

The prior suite is not edited by this increment.

## Additional future manual tests — NOT_RUN

- Desktop keyboard with OS blur and focus restore; ensure remap doesn't
  activate unfocused game, still works on legal new keypress.
- TextEdit/LineEdit and descendant Controls: typing a remapped key does not
  dispatch through the PR #15 adapter.
- Actual GUI conflict popover and restoration confirmation: present exact
  action names, existing owners and suggested free keys, no silent swaps.
- Keyboard layout, IME, keypad and alternate OS combinations; mapping remains
  **logical keycode only** unless a new requirement is approved.
- UI button and PR #6 integration compatibility: verify no doubled action,
  no unexpected snapshot writes; check candidate adapter detach behavior.
- File lock/rename/symlink/race/security behavior on supported operating
  systems, multiple writers, interrupted saves and power loss.
- Disk permissions and capacity failures, real signal counts on failed saves.
- Latency, CPU usage and memory use are **NOT_RUN**. No guessed benchmarks.

## Decision points pending author/product approval

1. Whether to implement silent auto-load on launch (current candidate: no).
2. Whether physical keyboard layout, rebinding modifiers or gamepads matter.
3. Whether collisions should be swapped or require manual resolution
   (current candidate: reject; explicit feedback only).
4. Whether reset defaults should also save automatically
   (current candidate: separate command, default is memory-only).
5. Desired recovery policy for corrupt files, backups and concurrent writes
   (current candidate: refuse overwrite, ask for explicit external decision).

No decision here changes Canon, existing InputMap, main branch or approved
shared interfaces.
