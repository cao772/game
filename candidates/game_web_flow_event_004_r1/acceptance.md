# GAME-WEB-FLOW-EVENT-004 r1 — future acceptance & record package

**CURRENT STATUS: NOT_RUN.** Implementation source was committed to a separate
codex/ branch. No application execution, preview run, Python import,
unittest, compiler/lint invocation, automated test or Godot headless run
was performed by this task. Do NOT report PASS without Codex evidence.

| Field | Value |
| --- | --- |
| task_id | GAME-WEB-FLOW-EVENT-004 |
| version | r1 |
| input_version | Public GitHub Draft PR #9 head cfd28c5cd30a3c4c163abfde7a3eb9ebcd23eb50 |
| scope | Standalone checked synthetic event-flow preview, manual branch selection and provenance trace |
| deliverable | event_flow_preview_candidate.py, test_event_flow_preview_candidate.py, three synthetic JSON fixtures, README.md, acceptance.md |
| status | NOT_RUN; source readback is not code execution |
| author decisions | No ordinary design decisions deferred; future final acceptance and shared interface reserved to author |
| excluded | Canon/story/private evidence, main, existing runtime, existing checker edits, save/state/performance/scene scripts |

## Contract-oriented acceptance matrix (all future, none observed)

| Future test case | Expected behavior |
| --- | --- |
| initial_event_lists_configured_actions_and_ignore | No selections lists authored actions + explicit @ignore and empty trace |
| explicit_link_to_another_event | A → B, options for B offered |
| two_step_terminal | A → B → null, terminal, two trace entries |
| explicit_terminal_branch | Action to null ends preview |
| ignore_option_follows_explicit_reference | @ignore follows A → C, trace records ignore pointer |
| ignore_not_offered_if_field_is_absent | B without ignore field rejects @ignore |
| ignore_null_explicitly_ends_preview | Explicit null ignore ends preview |
| unknown_choice_error_has_explicit_available_list | Wrong choice error includes step and offered options |
| invalid_start_event_is_rejected | Missing/nonstring start rejected |
| invalid_selection_types_rejected | Invalid sequence types rejected |
| extra_step_after_terminal_fails | Extra choice after terminal rejected |
| cycle_requires_manual_steps_and_is_bounded | Repeated explicit loop choices allowed, >24 rejected |
| preview_repeat_is_deterministic | Repeat yields identical result and trace hash |
| separate_choices_do_not_share_mutable_runtime_state | A branch preview never affects another |
| returned_options_cannot_mutate_stored_events | Mutation of returned display data does not mutate source |
| trace_contains_source_pointer_and_content_sha | Source/ref/target pointer and hash present |
| selected_source_sha_matches_actual_bytes | Trace SHA256 equals source file bytes |
| selection_of_directory_and_duplicate_paths | Duplicate path inputs deduped |
| missing_dependency_input_rejects_before_preview | Unresolved selected-file reference blocks preview |
| duplicate_event_id_rejected_by_checker | Duplicate IDs fail checker gate |
| invalid_identifier_rejected_by_checker | Invalid IDs fail checker gate |
| missing_input_rejected | Empty or missing input fails |
| changed_bytes_during_check_fail_closed | Mocked mutation rejects INPUT_CHANGED |
| changed_file_selection_during_check_fail_closed | Mocked scan-set mutation rejects INPUT_CHANGED |
| no_input_files_are_written | Before/after synthetic source bytes equal |
| text_renderer_contains_only_id_path_and_trace | Text has trace/choices, no story |
| cli_text_lists_options | Text-mode offers choices, return 0 |
| cli_json_multistep_trace | JSON two-step terminal trace, return 0 |
| cli_json_bad_action_returns_structured_error | JSON REJECTED, return 1 |
| cli_checker_failure_does_not_offer_branches | Failed gate never offers choices |
| trace_hash_changes_with_selection | Different choices, different digest |
| snapshot_fingerprint_changes_with_valid_source_change | Changed valid JSON bytes change source fingerprint |

## Additional future manual review

1. Confirm candidate is stacked only on public PR #9, and all new changed
   paths are inside candidates/game_web_flow_event_004_r1/. No base PR
   checker or other game script is changed.
2. Confirm checker PASS is required before offering any branch; duplicates,
   missing target, malformed JSON, wrong type, symlink and scan limits fail.
3. Verify source pointer, line/column, source hash and linked target against
   actual synthetic JSON files.
4. Verify unavailable checker dependencies reject clearly, without bypass.
5. Verify no disk writes, event side effects, save attempts, scene imports,
   runtime clock changes or shared event-bus emissions. Python may write
   cache on import unless started with -B.
6. Verify CLI JSON/text exits and avoid publishing real/private absolute
   file paths or identifiers in public evidence.
7. Confirm self-references and cycles are manual static walks only,
   not time loops, gameplay transitions or canonical story facts.
8. File mutation detection is best effort, not TOCTOU-secure; check this
   limitation is explicit and not overstated.

## Proposed future commands (DO NOT EXECUTE YET)

Use Python -B from a local checkout of the stacked branch:

    python -B candidates/game_web_flow_event_004_r1/event_flow_preview_candidate.py --event-id EVENT_START --format json candidates/game_web_flow_event_004_r1/fixtures
    python -B candidates/game_web_flow_event_004_r1/event_flow_preview_candidate.py --event-id EVENT_START --choice ACTION_TO_NEXT --choice ACTION_FINISH --format json candidates/game_web_flow_event_004_r1/fixtures
    python -B -m unittest discover -s candidates/game_web_flow_event_004_r1 -p "test_event_flow_preview_candidate.py" -v

Separately, if full regression is authorized, run PR #9's original tests
against the unchanged checker in its original sibling folder.

## Future evidence required

- task/version, branch, Draft PR URL and exact HEAD SHA
- OS, Python version, exact commands and process exit codes
- observed unittest results including failures and skips, stdout/stderr
- synthetic input hashes and read-only verification
- Git changed path list (PR #9 and main should be untouched)
- NOT_RUN statements for Godot, game runtime, scenes and performance
- owner review / final acceptance separately recorded

All mechanisms remain experimental, no shared interface or canon approval.
