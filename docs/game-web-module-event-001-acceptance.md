# GAME-WEB-MODULE-EVENT-001 r1 — prospective acceptance record

Task: GAME-WEB-MODULE-EVENT-001  
Version: r1  
Input basis: public GitHub PR #6 (input/state integration) and PR #2
(tooling conventions), both read-only; no public event JSON schema
or approved shared event definition was found in those sources.  
Scope: static structure, duplicate identifiers, within-input references.  
Deliverables: checker, unittest suite, synthetic fixtures, README.  
**Status: NOT_RUN.** All cases below are designed, none executed.

## Planned test cases

| Test | Synthetic input / operation | Expected result, NOT observed |
| --- | --- | --- |
| valid_two_file_forward_reference | EVENT_ALPHA targets EVENT_BETA | PASS; two unique IDs |
| valid_terminal_null_target_and_ignore | null target/ignore | PASS |
| missing_action_reference_fails | action targets absent EVENT_NOT_PRESENT | UNKNOWN_EVENT_REFERENCE; exit 1 |
| missing_ignore_reference_fails | ignore targets absent EVENT_UNKNOWN | UNKNOWN_EVENT_REFERENCE |
| duplicate_event_id_across_files | two files define EVENT_A | DUPLICATE_EVENT_ID |
| duplicate_action_id | two action IDs equal in one event | DUPLICATE_ACTION_ID |
| duplicate_condition_id | repeated trigger condition | DUPLICATE_CONDITION |
| missing_required_fields | missing trigger and actions | MISSING_FIELD twice |
| unknown_fields_rejected | synthetic unknown root/action keys | UNKNOWN_FIELD |
| invalid_identifier_types_and_values | lowercase, integer, empty, digit-leading | INVALID_ID |
| trigger_shape_and_conditions | string conditions / null trigger | ARRAY_REQUIRED / OBJECT_REQUIRED |
| action_shape_and_limits | zero actions / non-object action | ACTION_COUNT / OBJECT_REQUIRED |
| duplicate_json_member_rejected_before_overwrite | repeated event_id JSON key | DUPLICATE_JSON_KEY |
| invalid_json | truncated JSON document | INVALID_JSON |
| nonstandard_nan_rejected | NaN token | INVALID_JSON |
| invalid_utf8 | invalid byte sequence | INVALID_UTF8 |
| no_json_files | directory contains no .json | NO_JSON_FILES |
| missing_path | absent input path | INPUT_NOT_FOUND and NO_JSON_FILES |
| duplicate_input_path_does_not_duplicate_event | same path twice plus directory | One file selected, PASS |
| recursive_directory_json_only | nested JSON and unrelated TXT | One JSON selected, PASS |
| symlink_file_is_rejected_without_reading | explicitly passed symlink | SYMLINK_FORBIDDEN; skip if OS disallows symlink fixture |
| json_file_size_limit | >1MiB .json file | FILE_TOO_LARGE |
| checker_leaves_source_unchanged | snapshot bytes before/after check | Bytes equal |
| issue_order_is_deterministic | reversed CLI input order | Identical JSON report |
| cli_json_output_and_nonzero_on_invalid | --json with bad reference | Parseable report, exit 1 |
| cli_success_zero_for_valid | text output, valid input | PASS report, exit 0 |

Additional manual/negative acceptance tasks after author approval:
1. Verify 1,024-file cap and 1,025-file rejection on target OS.
2. Verify file replacement and symlink-race behavior; fail closed where
   feasible and record any unresolved TOCTOU weakness.
3. Confirm exact Python version and OS for each test run.
4. Confirm checker never invokes Godot, modifies game data, repairs JSON,
   downloads content, creates caches, or writes evidence files.
5. Review behavior for self-reference and cycles (currently syntactically
   accepted if the target ID exists), without inferring narrative semantics.
6. Review how CLI reports handle sensitive absolute paths; do not share
   private execution paths in public PR evidence.

## Acceptance gate and evidence format (for later, not claimed now)

Evidence item proposed fields:
- task_id/version and exact GitHub head SHA
- platform, Python executable version
- commands and exit codes (checker and unittest separately)
- test count, individual failures/skips and stdout/stderr
- input fixture hashes, non-secret paths and changed-file list
- explicit confirmation whether input files were modified
- reviewer decision: accept/reject/revise; no automatic merge

**Structural checker PASS is not scene PASS, engine PASS, schema
equivalence, shared interface approval, or canon acceptance.**

Archive future private evidence only to authorized Notion/Drive, not in
public fixture content. No main changes and no existing PR source edits.
