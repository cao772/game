# GAME-WEB-EVENT-006 r1 — prospective acceptance / evidence package

**Status: NOT_RUN**. Source-only development. These tests, previous suites,
CLI invocations, Python imports, compilation/lint, Godot and any runtime
work have NOT been executed by the authoring task.

## Record

- task_id: GAME-WEB-EVENT-006
- version: r1
- input_version: PR #18 HEAD 673e62e5ffe05c977b6acce85b8e3c80b4029ca0
- branch: codex/game-web-flow-event-004-r1; target Draft PR #18
- scope: synthetic condition explanation, safe-prefix path rollback,
  recorded navigation breadcrumbs, structured error presentation
- dependencies: PR #18 checked flow preview and public PR #9 checker
- deliverables: pure helper module, integrated Python overlay, this design,
  future synthetic test file and README
- scope exclusions: game execution, official story, private EVENT001 schema,
  main, other PRs, scenes, saves, shared event bus, new narrative rules
- status: NOT_RUN; no success/failure measurements claimed

## Future automated acceptance

File: test_event_preview_diagnostics_006_candidate.py
(all tests are planned and NOT_RUN)

| Case | Expected only |
| --- | --- |
| initial_diagnosis_missing_observation | missing observation code and source /trigger/signal; choices disabled |
| ready_diagnosis_has_no_reasons | matching synthetic observation has no blocking reasons |
| wrong_signal_has_precise_source | signal mismatch points to checked signal source |
| missing_conditions_has_precise_source | missing flags point to checked condition source |
| both_signal_and_flags_failed_in_order | stable pair of reason codes in documented order |
| extra_flags_informational_not_blocking | extra observed flag reported but no new restriction |
| terminal_diagnosis_explicit | terminal is explicit; no fabricated live condition |
| unknown_reason_fails_closed | upstream unknown blocked state remains blocked |
| breadcrumbs_present_without_executing_branches | initial root only, no redo |
| breadcrumbs_mark_redo_unselected | back marks later positions as unapplied |
| first_changed_step_is_earliest_applied_selection | earliest dependent step is detected |
| changing_second_event_retains_safe_first_step | preserve earlier safe step, discard dependent suffix |
| changing_start_event_rolls_back_to_zero | changed first-step gate resets recorded route |
| changing_only_redo_event_preserves_prefix | clear redo but keep selected prefix |
| change_unvisited_event_preserves_applied_prefix | irrelevant observation does not erase selected prefix |
| explicit_rollback_truncates_recorded_future | rollback retains prefix and drops redo |
| rollback_can_clear_redo_at_current_cursor | truncation at cursor removes future steps |
| rollback_same_position_without_redo_is_noop | idempotent rollback unchanged |
| rollback_forward_request_rejected_unchanged | forward rollback fails, state hash identical |
| rollback_invalid_cursor_rejected_unchanged | bool/None/fraction/negative rejected without state mutation |
| rollback_after_terminal_restores_prior_event | temporary terminal view can be discarded |
| back_forward_keep_redo_until_explicit_truncation | reversible navigation round-trips same snapshot |
| choose_after_back_truncates_old_redo | choice fork replaces suffix, reports discarded count |
| error_echo_includes_condition_sources_and_unmodified_hash | gate source and exact old snapshot hash |
| bad_choice_shows_safe_suggestion_and_stable_snapshot | wrong branch never mutates history |
| unknown_error_uses_generic_manual_review | unknown errors do not guess repair |
| gate_diagnostics_detached_from_internal_state | caller's mutated return objects do not affect session |
| cli_json_rejection_includes_error_view | JSON rejection has category/pointers/cursor |
| cli_json_loader_failure_without_fabricated_snapshot | failing checker returns error, no fake snapshot |
| cli_malformed_command_json_error_has_guidance | invalid command JSON gives readable structured error |
| cli_text_diagnostic_and_error_source_echo | human report shows source pointer, reasons, route |
| cli_text_rollback_shows_discarded_steps | human report includes truncate policy and discard count |
| no_event_sources_or_runtime_are_written | synthetic JSON input bytes unchanged |
| source_fingerprint_stays_constant_after_rollback | rollback does not affect selected source hashes |
| e006_does_not_change_static_flow_preview_semantics | original static preview() still follows links unchanged |

## Mandatory future regression and boundary checks

1. Run the original PR #18 test_event_flow_preview_candidate.py and
   test_event_play_preview_candidate.py in addition to the EVENT-006
   future tests, and consider PR #9 checker regression separately.
2. Confirm original static preview() and options_for() behavior, PR #9
   source, other branches and main are unmodified by the EVENT-006 diff.
3. Confirm existing EVENT-005 behavior for a changed observation used by
   the first selected step still resets the entire route; later changes
   now retain only prior safe steps.
4. Exercise all selection/condition errors against stable before/after
   snapshots: invalid signal, unknown choice, terminal, missing required
   flags, wrong types, cursor bounds and rollback-forward refusal.
5. Verify error_view reports sources only when actually available. A
   checker failure does not invent current event choices or snapshots.
6. Review line/column provenance and SHA256 of the public synthetic
   fixture files; do not use real manuscript data for public evidence.
7. Verify no real runtime events, clocks, game saves, scene state, network
   calls, source rewrites or automatic repair paths.
8. Stress explicit cycles with the existing 24-selection cap; rollback
   must not automatically replay or regenerate game events.
9. Review filesystem races and symlink limitations inherited from
   the checker; no claim of secure transactional snapshot.
10. Keep explicit distinction between static checker PASS on synthetic
    input and actual Godot/game tests, both currently NOT_RUN.

## Proposed later commands (DO NOT EXECUTE IN THIS TURN)

On a local checkout of PR #18 with stacked PR #9 code:

    python -B -m unittest discover -s candidates/game_web_flow_event_004_r1 -p "test_event_preview_diagnostics_006_candidate.py" -v

For regression, only after authorization:

    python -B -m unittest discover -s candidates/game_web_flow_event_004_r1 -p "test_*candidate.py" -v

And the original PR #9 tests in their sibling folder separately.

## Evidence required from future Codex execution

Exact GitHub branch/HEAD SHA; OS and interpreter version; full executed
commands, stdout/stderr and exit codes; each test's actual result and
pass/fail/error/skip counts; synthetic fixture content hashes;
read-only verification and changed-file list; explicit pending Godot,
runtime and schema-integration status; final author acceptance decision.

**No test has passed merely because its source code was submitted.**
All added mechanisms are tentative technical preview behavior and
cannot approve story canon or any shared API.
