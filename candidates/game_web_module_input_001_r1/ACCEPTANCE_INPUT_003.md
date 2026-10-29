# GAME-WEB-CONTINUE-INPUT-003 r1 — deferred acceptance

**STATUS = NOT_RUN.** This document and `verify_input_migration_003.gd`
are future test specifications only. Author explicitly forbids running code or
tests during this development task. No PASS evidence exists.

## Automated future SceneTree cases

| ID | Future assertion |
| --- | --- |
| I301 | Strict V1 from PR #15 is recognized and migrated in memory to V2 |
| I302 | V2 document has exact schema_version, format and five bindings |
| I303 | V2 validation round-trips V1 values, preserving all actions and codes |
| I304 | V2 future/unsupported version fails without guessed migration |
| I305 | V2 extra fields and foreign format fail |
| I306 | Duplicate V1 keycode causes conflict with both action owners |
| I307 | Unknown historical V0/map shape rejected, not auto-converted |
| I308 | Duplicated V2 keycodes cannot bypass PR #15 validator |
| I309 | Conflict preview includes owners, explanation, corrective next steps |
| I310 | Preview is read-only for memory and disk, including invalid actions |
| I311 | Path traversal and wrong filename are rejected |
| I312 | Missing V1 file returns an explicit error |
| I313 | Migration preview does not create V2 or modify legacy bytes |
| I314 | Incorrect token refuses commit |
| I315 | Cancelled token cannot be replayed |
| I316 | V1 modified after preview triggers SOURCE_CHANGED, no V2 creation |
| I317 | Runtime binding modified after preview triggers MEMORY_CHANGED |
| I318 | Valid explicit migration creates isolated V2 document |
| I319 | Legacy V1 remains byte-for-byte identical after migration |
| I320 | Memory follows V2 only after persisted write verification |
| I321 | Migration confirmation token is one-shot |
| I322 | Existing V2 target blocks repeat migration and overwrite |
| I323 | A fresh settings instance explicitly loads V2 |
| I324 | Restore preview lists exact mapping deltas, no mutation |
| I325 | Wrong restore token refuses commit without altering files |
| I326 | Existing .tmp refuses reset, preserves original memory/disk/temp |
| I327 | Restore preview invalidated by intermediate memory rebind |
| I328 | Valid external V2 modification detected before reset commit |
| I329 | Explicit V2 reload accepts a valid externally changed profile |
| I330 | Confirmed full-default restore updates memory after disk success |
| I331 | Legacy file still unchanged after V2 defaults restoration |
| I332 | Repeated defaults restoration is no-op without rewrite |
| I333 | Previously loaded missing V2 triggers EXTERNAL_DELETE |
| I334 | Explicit new V2 defaults file creation requires preview + confirm |
| I335 | Malformed existing V2 is refused, not silently repaired |
| I336 | Signals only report explicit operations, not pure conflict previews |
| I337 | Fixture cleanup only affects uniquely created user:// test directory |
| I338 | Finite test run returns nonzero on assertion failure, zero on pass |

**Future-only command, not executed:**

```bash
godot --headless --path candidates/game_web_module_input_001_r1 \
  --script res://verify_input_migration_003.gd
echo $?
```

## Manual desktop and fault-injection acceptance — all NOT_RUN

- Verify keyboard remap, echo filtering, text focus and native OS focus
  continue to be handled by PR #15's adapter, not by a new global InputMap.
- Confirm UI receives and displays owner details for collisions, with no
  silent swap or unexpected gameplay action.
- Confirm controller and PR #15 adapter share **one** bindings instance
  when integrated in an isolated host.
- Validate actual UI confirmation/cancel flow and one-use tokens.
- Validate platform-specific file rename, disk full, access denied, read
  failure, temp-file collisions, symlinked paths, external writer races,
  unexpected process termination and power loss.
- Validate UTF-8 JSON, numeric decoding, parser behavior on Godot 4.7.2.
- Verify missing/corrupt V2 does not erase the original V1 file.
- Check Windows/macOS/Linux keyboard-layout-specific keycodes and IME.
- Measure performance only if a later authorized project asks for it.
- Re-run existing PR #15 test suites only after explicit user authorization.

## Review gates and unresolved external prerequisites

1. No approved product UX or real game scene has been provided. The candidate
   exposes data and signals, not a production settings screen.
2. The V2 JSON format is a proposal, **not** a shared or public API promise.
3. The only known source schema is PR #15 V1; older V0 formats cannot be
   inferred. Additional migration adapters need real source samples.
4. Restore and migration use explicit caller confirmation and avoid automatic
   file repair. These are conservative choices documented in
   `MODULE_INPUT_003.md`.
5. The same-directory fixed temporary filename, optimistic digest check and
   path-text validation are not cross-process locking or a security boundary.
6. PR #15 and parent PR #6 are drafts; no merge into `main` is authorized.

Record future evidence with: Godot version, OS, exact branch HEAD, command,
stdout/stderr, exit code, assertion totals, UI focus recordings if authorized,
and separately any filesystem failure injection outcomes. Do not mark PASS
until those actual records exist.
