# GAME-WEB-FLOW-INPUT-004 r1 — future acceptance plan

**Every item below: NOT_RUN.** This is a specification, not observed test
evidence. Neither Godot nor any code/test runner was invoked in this
development task.

Parent dependency: [Draft PR #15](https://github.com/cao772/game/pull/15)
at starting SHA `a510986faf3c3ee0557196194d5f74f16e02de89`.
This new independent branch must add only `flow_input_004/` files.

## Future headless SceneTree acceptance

File: `verify_input_settings_flow_004.gd`. It should terminate with
`PASS GAME-WEB-FLOW-INPUT-004 r1` and exit 0 if all expectations hold,
or `FAIL` and nonzero on any assertion. Neither is an actual result.

| ID | Intended check | Acceptance criterion |
| --- | --- | --- |
| F401 | Scene instantiation | New scene and Control script load from existing isolated PR #15 project |
| F402 | Initial view | Five action rows, five default logical keys |
| F403 | No automatic persistence | Instantiating panel creates no V2 file |
| F404 | Dynamic controls | Every action has rebind and reset-one button |
| F405 | Rebind capture starts | UI shows target and waits for single key |
| F406 | Conflict preview | Existing key owner shown; confirmation disabled |
| F407 | Invalid action/key | No live mapping or file update |
| F408 | Preview is read-only | No disk/memory mutation before confirm |
| F409 | Explicit cancel | Clears pending operation, preserves live map/disk |
| F410 | Available key preview | Proposed key shown, both apply paths enabled |
| F411 | Memory-only confirmation | One binding changes, no V2 write |
| F412 | Return to default | Single reset works if original key unoccupied |
| F413 | Occupied default | Single reset blocked, other action unaffected |
| F414 | Preview full reset | Exact changed keys shown without mutation |
| F415 | Cancel full reset | Changes are not applied |
| F416 | Confirm full reset in memory | All defaults restored without intermediate conflicts |
| F417 | Rebind and persist | V2 written before live bindings change |
| F418 | Persisted schema | V2 file accepted by PR #15 migrator |
| F419 | Repeat save | Identical document is not rewritten |
| F420 | Second settings instance | No implicit load; existing file requires explicit load |
| F421 | Explicit load | Existing V2 map restored |
| F422 | Existing .tmp | Save/refund? **Reject**; preserve memory, disk and temp |
| F423 | Persisted restore | Successful save then live full-default reset |
| F424 | External edit | Digest mismatch rejected; external bytes preserved |
| F425 | Reload after external edit | Explicit user load accepts validated external file |
| F426 | V1 migration preview | Old V1 retained, no premature V2 creation |
| F427 | Migration cancel | No V2 file created |
| F428 | Migration confirmation | V2 created only after token confirmation |
| F429 | Migration preservation | V1 remains byte-for-byte identical |
| F430 | Optional game adapter suppression | Host-supplied Node unhandled key disabled while panel open |
| F431 | Panel close | Adapter flag restored and panel hidden |
| F432 | Test fixture isolation | Only test-owned unique `user://` files removed |
| F433 | Bounded test exit | 0 only for full pass; nonzero on test failure |

The source is future-only. **No runtime assertion was executed.**

## Additional manual desktop acceptance — NOT_RUN

- F4D01: View the scene at supported desktop resolutions, test resizing,
  font scaling, keyboard navigation and color contrast.
- F4D02: Click all five rebind buttons, physically press keys and verify
  preview output and no gameplay signal on key capture.
- F4D03: Press and hold remapped keys. Echo/key release must not create
  duplicate action requests; legal subsequent keydown remains eligible.
- F4D04: Focus LineEdit/TextEdit on a host scene. When panel is open, the
  supplied host adapter must be suspended; closing must restore its original
  processing state. No globally registered action should change.
- F4D05: Desktop Alt+Tab and minimize/restore; actual window-focus behavior
  remains pending the host integration test.
- F4D06: Escape capture and click-to-cancel both work. Escape is a candidate
  remappable key, not a hard-coded capture cancellation.
- F4D07: Conflict descriptions show action owners, free-key alternatives,
  and do not silently swap key assignments.
- F4D08: Return to defaults from a temporarily remapped profile, both
  in memory and through explicit V2 persisted save.
- F4D09: Simulate V2 disk denial, corruption, stopped process, stale writer
  and existing temporary file; failed operations leave live map unchanged,
  except cases explicitly marked as already committed.
- F4D10: Explicit V1 migration retains legacy bytes and never silently
  overwrites existing V2 destination.
- F4D11: Host adapter attached/detached while panel is open must not cause
  duplicate action routing or early input capture.
- F4D12: Confirm no keyboard events leave the panel for the original host
  during capture; non-capture events require explicit host adapter suspension.
- F4D13: Check IME, US/Chinese keyboard layouts, keypad and modifiers;
  physical-key mapping and gamepad are out of scope unless approved.
- F4D14: Check focus traversal for buttons, large text, screen reader
  semantics if required by later UI spec.
- F4D15: CPU/GPU/RAM and latency metrics: **NOT_RUN**; no benchmark claim.

## Future command (NOT RUN in this task)

```bash
godot --headless --path candidates/game_web_module_input_001_r1 \
  --script res://flow_input_004/verify_input_settings_flow_004.gd
echo $?
```

For later manual scene checks:

```bash
godot --path candidates/game_web_module_input_001_r1 \
  res://flow_input_004/input_settings_panel_004.tscn
```

## Explicit limitations / approval boundary

There is no authorized full game scene or approved visual design contract,
so this is a standalone Godot module. It is not production-wired into
PR #6's world or snapshot system. Its default file path is generic
`user://`; callers who want a new subdirectory must provide/create
one explicitly. Single-writer assumptions and optimistic V2 hashes are not
cross-process locks or crash-proof persistence. UI copy, V2 schema, conflict
handling and two-step confirmation remain proposals.

Record future evidence as: test command, OS, Godot precise version, branch
HEAD, stdout, stderr, exit status, fixture paths, GUI screenshots only if
author permits, and unresolved failures. Keep all cases NOT_RUN until
authorized execution occurs. Never pretend expected output is achieved.
