# GAME-WEB-MODULE-EVENT-002 r1 — future diagnostics acceptance

**Status: NOT_RUN. No script, import, test, CLI, lint, Python compile or
CI execution was performed for this development task.** All cases below
are expected behavior to be independently checked by Codex.

## Input and change boundary

- Input: the exact PR #9 branch source and README of the public, placeholder-
  only checker GAME-WEB-MODULE-EVENT-001 r1.
- Branch: codex/game-web-module-event-001-r1; PR #9 stays Draft.
- Scope: additive static JSON format diagnostics, cross-reference quality,
  structured source positions, synthetic future acceptance.
- No change to source JSON contract, existing fixtures, private EVENT001
  schema, game runtime, other draft PRs, main, canon or shared bus.
- No actual private, unpublished, or story data is included.
- All new and prior tests remain unexecuted under this task.

## Structured issue contract (candidate, not public shared API)

Fields on each issue:
- code: stable machine-readable issue category
- file: file path (do not publish private absolute paths in evidence)
- pointer: RFC 6901-style JSON Pointer, empty for root/file-level error
- detail: human-readable diagnostic without copying source excerpts
- severity: "error"
- location: null or {line, column, precision, column_unit}.
  Both line and column are 1-based and measure Unicode characters.
  Precision = "exact" for key/array token or JSON decoder position;
  "parent" when a missing field has no token of its own.
- related: optional array of {file,pointer,location} for duplicate source
  member / duplicate identifier / multiple candidate definitions / invalid
  target definition.
- target_id: optional identifier on reference diagnostics.

Top-level additions:
enhancement_task_id, enhancement_version, diagnostic_format,
references_checked, issue_counts_by_code. Existing status/issue_count/
unique_event_ids/files_selected remain unchanged.

## Planned automated cases (test_event_source_diagnostics_candidate.py)

| Case | Future expected result, NOT measured |
| --- | --- |
| json_trailing_comma_line_column | INVALID_JSON at true line 4, col 1 |
| invalid_nested_action_identifier_exact_pointer | INVALID_ID at /actions/0/action_id, exact source key |
| missing_field_anchors_parent_not_fake_exact | MISSING_FIELD /trigger/signal with parent precision |
| nested_duplicate_json_member_exact_second_key | DUPLICATE_JSON_KEY at repeated nested key, first key linked |
| multiple_duplicate_members_all_reported | every repeat reported; invalid file excluded |
| reference_pointer_and_target_id | UNKNOWN_EVENT_REFERENCE with exact pointer and target_id |
| ambiguous_reference_has_both_definitions | AMBIGUOUS_EVENT_REFERENCE linked to both competing definitions |
| duplicate_event_id_links_other_definition | DUPLICATE_EVENT_ID includes related first definition |
| reference_to_structurally_bad_definition | INVALID_EVENT_REFERENCE_TARGET for unique malformed target |
| reference_to_bad_field_definition_with_same_id | ignore reference also checks target validity |
| forward_and_backward_references_both_resolve | PASS for two syntactic targets regardless of direction |
| self_reference_is_static_valid_not_loop_semantics | syntactically valid; no runtime loop inference |
| ignore_and_action_references_both_counted | two valid non-null references counted |
| format_rejects_invalid_root_with_structured_location | OBJECT_REQUIRED location (1,1) for root array |
| null_and_nonstring_references_do_not_generate_target | null ignored, invalid type INVALID_ID only |
| escaped_json_pointer_token_for_unknown_field | slash/tilde escaped as ~1/~0 |
| unicode_character_column_not_byte_column | unicode character offset matches source |
| unknown_symlink_location_explicitly_unavailable | absent file-level input has location=null |
| machine_report_diagnostic_metadata | enhancement ID/version, code tally, severity |
| text_cli_prints_line_and_column | human output includes source coordinates |
| json_cli_round_trip_diagnostics | parseable structured JSON and exit 1 |
| source_files_are_not_modified | input bytes unchanged |
| report_order_independent_of_input_order | deterministically identical output |

## Original acceptance suite remains required

Run the unchanged EVENT-001 test_event_data_check_candidate.py in addition
to this extension; ensure duplicate JSON member handling still rejects
last-key-wins, original diagnostic codes/pointers still exist, directory
and symlink rules remain, and --json exit code behavior is unchanged.

## Future manual review (do not execute yet)

1. Byte-accurate UTF-8 invalid-content handling: unavailable source
   coordinates are explicit null; no fabricated Unicode columns.
2. Large and adversarial JSON under the 1MiB input cap; >128 nesting
   returns SOURCE_INDEX_ERROR rather than a false PASS.
3. Cross-reference target absent, duplicated and structurally malformed.
   Verify mutually relevant issues and related locations, sorted.
4. Parallel or changing filesystem input: the checker is *not* a
   transactional snapshot and does not protect against TOCTOU attacks.
5. Self-reference/cycles are static graph edges only; the checker must
   not execute event actions or infer any narrative/time-loop meaning.
6. Compare only the six previously submitted public candidate files and
   the three incremental files/docs; verify no other PR/main path changed.
7. No network, no game engine, no story texts and no automatic event bus
   integration. If imports write Python bytecode cache by default, use -B.

## Future commands, contingent on owner/Codex permission

    python -B candidates/game_web_module_event_001_r1/event_data_check_candidate.py --json candidates/game_web_module_event_001_r1/fixtures
    python -B -m unittest discover -s candidates/game_web_module_event_001_r1 -p "test_event*_candidate.py" -v

The discovery glob may need an explicit alternative if the on-disk filenames
change. Preserve complete stdout/stderr, exact exit statuses, Python version,
platform and Git HEAD for every executed command; list failures/skips rather
than reporting an unverified pass.

## Review/decision gate

Status: **NOT_RUN**. Files written and fetched through GitHub only, not run.
Author must approve identifier policy, static reference set semantics,
ambiguity behavior and location format before a shared interface is even
considered. Codex independent execution and author review are still pending.
No merge to main, no original source overwrite, no canonical story approval.
