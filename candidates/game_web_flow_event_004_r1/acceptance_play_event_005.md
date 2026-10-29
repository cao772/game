# GAME-WEB-PLAY-EVENT-005 r1 — future acceptance cases

**Status: NOT_RUN.** This file specifies verification requirements; no
Python execution, compilation, tests, CLI, Godot, lint, or CI have been
run or intentionally triggered in this development request.

## Handoff record

| Field | Value |
| --- | --- |
| task_id | GAME-WEB-PLAY-EVENT-005 |
| version | r1 |
| input_version | PR #18 pre-change HEAD 819395fff9b694ac2b11e3b58485b24696f8128b |
| input dependency | Public PR #9 synthetic checker, stacked PR #18 original preview |
| branch | codex/game-web-flow-event-004-r1 |
| scope | Synthetic conditions, explicit branch navigation, in-memory snapshots, structured error echo |
| deliverables | event_play_preview_candidate.py, test_event_play_preview_candidate.py, integration_play_event_005.md, this document, small read-only accessor in original PR #18 candidate, README addendum |
| execution status | NOT_RUN; all expected outcomes below are prospective |
| excluded | main, real event runtime, story/canon, save files, scenes, shared interfaces, real gameplay status |

## Prospective automated assertions (all NOT_RUN)

The file test_event_play_preview_candidate.py contains the following
future unittest cases, each using temporary synthetic placeholders:

| Test | Expected result (not observed) |
| --- | --- |
| initial_snapshot_blocked_without_observation | Missing observation blocks gate but displays disabled configured choices |
| correct_signal_and_all_conditions_unlock | Exact signal and required flag enable available choices |
| signal_mismatch_retains_block | Incorrect signal blocks; select fails with CONDITIONS_NOT_MET |
| missing_condition_retains_block | Missing flag reported; attempt does not change snapshot |
| extra_valid_conditions_do_not_block | Additional valid observed flag does not block required flags |
| step_to_beta_requires_separate_observation | Linked target initially blocked until its own observation arrives |
| explicit_ignore_branch_has_trace_and_gate | Configured @ignore records target and pointer |
| terminal_prevents_next_selection | Null target locks preview, no further mutation |
| unknown_action_error_echo_does_not_mutate | UNKNOWN_CHOICE includes available choices and prior snapshot |
| missing_gate_error_echo_contains_requirements | Requirements/missing flags in error and state unchanged |
| back_then_forward_preserves_trace | Cursor navigation reproduces deterministic prior snapshot/hash |
| jump_navigation_to_root_and_forward | Recorded cursor jump repositions without event execution |
| branch_from_history_truncates_future | New choose after back forks route and discards redo suffix |
| invalid_navigation_positions_do_not_mutate | Out-of-range/invalid number (including bool) rejects without state change |
| rejected_command_fields_do_not_mutate | Missing/extra fields, wrong container, unknown op reject atomically |
| invalid_observation_inputs_rejected_atomically | Unknown event, bad signal, duplicate/wrong-type flags reject |
| change_past_observation_resets_history | Editing observation used by selected prefix invalidates entire route |
| change_future_observation_discards_redo_only | Editing a redo-only event keeps selected prefix and removes redo |
| change_observation_of_unvisited_event_preserves_prefix | Unvisited synthetic source observation doesn't invalidate selected steps |
| clear_observation_blocks_current_event | Clearing current observation causes blocked state |
| clear_missing_observation_is_noop | Idempotent clear returns UNCHANGED |
| repeat_identical_observation_is_noop | Same signal and flag set preserves snapshot |
| snapshot_is_detached | Mutating returned fields doesn't affect internal session |
| snapshot_hash_changes_with_observation_and_choice | Hash changes on synthetic state navigation/change |
| source_snapshot_sha_stays_constant_across_preview | Source hash independent of runtime-like preview cursor |
| no_source_json_modified_by_session | Byte-for-byte original source fixtures remain |
| cli_json_multiple_commands_and_snapshots | JSON command list yields terminal trace, cursor 2, return 0 |
| cli_missing_conditions_error_echo | Error is JSON REJECTED with code and unchanged cursor, return 1 |
| cli_invalid_command_json_rejects_without_trace | Invalid command JSON rejected without traceback or trace |
| cli_checker_gate_fails_before_conditions | Failed checker blocks session construction and branch offering |
| cli_text_echo_and_branches | Human report shows condition-unlocked choices and no-effects notice |
| original_flow_candidate_still_unmodified_semantics | Original PR #18 preview() still directly walks a checked synthetic link |

The prior PR #18 32 acceptance cases and prior PR #9 static checker tests
remain relevant regression suites and have NOT been executed here.

## Additional future manual verification (NOT_RUN)

1. Confirm PR #18 is still Draft and diff is limited to its own candidate
   directory. Confirm no changes to PR #9, main, other windows' files,
   event runtime, save logic, or original story sources.
2. Run future tests using only synthetic fixture data and Python -B;
   verify CLI status and process exit code independently from the
   descriptive in-report status.
3. Verify condition gate is exactly signal equality + required flag subset,
   with missing observations blocked and extra flags tolerated.
4. Verify that no action-specific predicate/engine state was inferred
   from the PR #9/18 data format. Confirm explicit authored options only.
5. Verify trace source pointers/files/hashes match the PR #18 original.
   Check state snapshot hash changes with injected observations,
   while source fingerprint remains constant.
6. Verify back/forward/jump, branch fork, target terminal, 24-choice cap,
   and observation-update invalidation. No automatic recursion through
   synthetic graph cycles.
7. Check all invalid inputs, including malformed --command JSON, unknown
   operation, extra fields, negative/fractional/bool cursor values,
   unknown event, duplicate flags, wrong signal and unavailable links.
   Rejected operations must echo the previous state snapshot exactly.
8. Check the returned snapshot is deep-detached. The preview must not
   generate actual game events, clock changes, persistence or saves.
9. Check CLI source file input stability and PR #9 checker failure
   boundaries, including duplicate IDs/refs/malformed/symlink paths.
   Existing best-effort race checks are not security claims.
10. Test JSON and text reports with synthetic-only values; never publish
    real paths, unpublished character data or private chat evidence.
11. Confirm original CheckedEventPreview.preview() and options_for()
    behavior has not changed except new read-only requirements_for().
12. Review exact changed-file list and commit hashes before author acceptance.

## Future commands — DO NOT EXECUTE IN THIS DEVELOPMENT TASK

On a future local checkout of the PR #18 branch (which includes PR #9):

    python -B candidates/game_web_flow_event_004_r1/event_play_preview_candidate.py --event-id EVENT_START --format json candidates/game_web_flow_event_004_r1/fixtures

    python -B -m unittest discover -s candidates/game_web_flow_event_004_r1 -p "test_event_play_preview_candidate.py" -v

If approved for broader regression, execute the PR #18 original flow
preview tests and PR #9 checker tests separately, collecting independent
success/failure evidence; do not substitute old PASS reports for this HEAD.

## Evidence package for later Codex and owner review

- Exact branch, Draft PR number, full HEAD SHA, OS, Python version
- Executed commands and exit statuses (real, not predicted)
- Per-test passed/failed/skipped/error counts and stdout/stderr
- Fixture source hashes and byte immutability comparison
- Evidence of no game-source writes, no private data/public logs
- Changed-file manifest limited to this preview candidate
- Unverified claims explicitly marked NOT_RUN (including Godot/GUI)
- Final author review decision, separate from candidate submission

**Current result: ONLY CODE SUBMISSION. NOT_RUN.**
The design remains a technical experiment; no canon or shared API approved.
