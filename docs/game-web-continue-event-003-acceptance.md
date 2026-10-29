# GAME-WEB-CONTINUE-EVENT-003 r1 — checker continuation and future acceptance

**Status: NOT_RUN.** This change is only source development on the existing
GitHub Draft PR #9. No Python command, test, import, lint, compilation,
Godot, CLI check or CI was intentionally executed in this task.

## Scope and provenance

- task_id: GAME-WEB-CONTINUE-EVENT-003
- version: r1
- input_version: current PR #9 / head read at the start of this turn
  (GAME-WEB-MODULE-EVENT-001 r1 + EVENT-002 diagnostic extension r1).
- scope: independent static placeholder event checker, detailed diagnostics,
  selected-file cross-references, human-reviewed repair advice and future tests.
- source base: read existing PR #9 checker, source indexer, README,
  existing synthetic test module and acceptance document.
- output branch: codex/game-web-module-event-001-r1.
- deliverables: two new pure modules, new synthetic future test suite, additions
  to the existing checker and README, this acceptance/design document.
- explicit exclusions: private EVENT001 JSON/Schema; story, scenes, runtime,
  state snapshots, main, other PR branches, event bus, auto-repair or canon.

The source files use Python 3.12+ standard library only.

## Design choices and rationale

| Choice | Reason | Deliberate limitation |
| --- | --- | --- |
| Keep previous static JSON placeholder format, existing --json and diagnostic_format = 2.0-candidate | Preserve earlier PR #9 callers and prospective test expectations | Not a published or approved schema/API |
| Add event_repair_advice_candidate.py as a pure step after source-index and reference validation | Keeps interpretation separate from parse, file access, symbol resolution | No edits or automatic fixes |
| Add event_report_candidate.py as a pure stdout text renderer | Human triage with grouped file, line:column, pointer, linked target sites and review steps | No output file, Godot console, GUI or cloud integration |
| Add continuation_task_id and advice_format instead of changing existing task_id/version | Makes incremental authorship auditable without breaking original issue fields | Diagnostic formats remain candidates |
| Suggestions are static, rule-based templates keyed by error code | Avoids unreliable generated patches or story assumptions | Reviewer may need to investigate underlying intent |
| For a missing target, use difflib.get_close_matches only among unique, structurally healthy, already selected IDs | A plausible spelling is useful while avoiding ambiguous or malformed candidate suggestions | Suggestion is explicitly unconfirmed; no automatic rewrite |
| Preserve source locations and related locations from EVENT-002 | Data owner sees exactly which files/JSON pointers are involved | Missing fields use parent position; file-level errors may lack a source position |
| No full graph reachability/loop analysis | Cycles/self-references are syntax-level references, not gameplay or time-loop rules | Behavioral validation requires a separately authorized runtime |

There are no source snippets or value excerpts copied into suggestions. Raw
issue.file paths and target identifiers can still be sensitive; never publish
diagnostic output from real private inputs to a public PR.

## Incremental code layout

1. candidates/game_web_module_event_001_r1/event_repair_advice_candidate.py
   - Error-specific actionable review steps for current checker codes.
   - No auto_apply support: all suggestions have auto_apply=false and
     requires_review=true.
   - For unresolved references: at most 3 unconfirmed spelling matches,
     filtered to unambiguous structurally healthy event definitions.
   - Sorted per-file issue counts, advice-code counts, no applied fixes.
   - Unrecognized future error codes receive safe generic review guidance.
2. candidates/game_web_module_event_001_r1/event_report_candidate.py
   - Deterministic full human report, per-file grouping with source location
     precision and JSON pointer, related reference definitions and suggested
     review steps. No file writes or source excerpts.
3. candidates/game_web_module_event_001_r1/event_data_check_candidate.py
   - Integrates advice after existing structural and reference checks.
   - Adds continuation metadata and review-only summary to JSON report.
   - Existing --json alias and --format {json,text} output modes to stdout.
   - Exit 0 for structurally valid selected files, 1 for checker issues,
     argparse exit 2 for conflicting CLI modes or invalid arguments.
4. candidates/game_web_module_event_001_r1/test_event_repair_advice_candidate.py
   - Synthetic future assertions, not executed.

## Proposed diagnostic contract (not approved interface)

Each existing issue retains code/file/pointer/detail/location/related/target_id
and gains:

    "repair_advice": {
      "suggestion_id": "REVIEW_UNKNOWN_EVENT_REFERENCE",
      "category": "cross_reference",
      "title": "Review unresolved target identifier",
      "steps": ["...", "...", "..."],
      "auto_apply": false,
      "requires_review": true,
      "possible_spelling_matches": ["EVENT_BETA"],
      "match_note": "Spelling candidates only; none is a confirmed target."
    }

The possible_spelling_matches and match_note keys are optional and appear
only when there are useful unique, structurally healthy identifiers in the
currently selected inputs. "review_related_locations" is optional.

Report additions:

    "continuation_task_id": "GAME-WEB-CONTINUE-EVENT-003",
    "continuation_version": "r1",
    "advice_format": "3.0-candidate",
    "repair_review_summary": {
      "policy": "manual_review_only",
      "auto_fixes_applied": 0,
      "files_with_diagnostics": 1,
      "diagnostics_by_file": [
        {"file": "placeholder.json", "issue_count": 1}
      ],
      "advice_counts_by_rule": {"REVIEW_UNKNOWN_EVENT_REFERENCE": 1},
      "reference_spelling_hints": 1
    }

These are illustrative placeholder shapes and NOT actual output from an
executed tool. Old diagnostic_format remains 2.0-candidate to avoid a
breaking change. Counts describe the candidate report, NOT how many files
were actually repaired.

## Future acceptance (unexecuted)

Planned assertions in test_event_repair_advice_candidate.py:

1. unresolved reference receives review-only advice and unconfirmed close ID
2. unrelated target has no fabricated spelling suggestion
3. structurally invalid definitions excluded from spelling candidates
4. duplicate definitions excluded from spelling candidates
5. ambiguous references never auto-select one definition
6. target structural errors link to the target file/pointer
7. duplicate event ID guidance requires reference review
8. duplicate JSON member links first occurrence and blocks auto fixes
9. missing field parent location never claims to be exact
10. unknown-field advice does not prescribe silent deletion
11. synthetic input VALUES never appear in report advice or text
12. invalid identifier repair guidance is general and manual
13. malformed JSON includes exact syntax position when available
14. absent file has null location, no fake line number
15. continuation identifiers, version and summary counters present
16. human report includes file and line:column, code, pointer and suggestions
17. ambiguous references show both related definition files
18. valid report is concise and shows PASS without fabricated suggestions
19. legacy --json output remains parseable, exit code 1 for invalid input
20. explicit --format json output remains parseable
21. explicit --format text produces full human guidance
22. mutually conflicting --json and --format text reject with argparse 2
23. fixture input bytes remain unchanged after validation
24. reordering selected files gives deterministic equivalent report
25. unknown error code receives generic manual-review fallback
26. all known error codes have nonempty review steps, no auto fixes

Additional later checks, NOT executed:
- Run **all three** unittest modules and compare to earlier planned
  behavior (26 original structural, 23 EVENT-002 source diagnostics, 26 new).
- Exercise both JSON and text modes with synthetic fixtures; record exit codes
  and ensure no cache writes if running with python -B.
- Inspect report for no source-value excerpts and no unconfirmed edits.
- Confirm missing reference, duplicate ID, ambiguous reference, structurally
  invalid target and wrong-type link remain separate issues.
- Confirm file paths/identifiers do not leak private information into public
  comments; use synthetic evidence only.
- Confirm known disk race/TOCTOU and hard filesystem security limits
  are NOT presented as solved.
- Confirm only this PR branch changed; no main merge or game code integration.

Future commands, after the author authorizes tests:

    python -B candidates/game_web_module_event_001_r1/event_data_check_candidate.py --format text candidates/game_web_module_event_001_r1/fixtures
    python -B candidates/game_web_module_event_001_r1/event_data_check_candidate.py --format json candidates/game_web_module_event_001_r1/fixtures
    python -B -m unittest discover -s candidates/game_web_module_event_001_r1 -p "test_event*_candidate.py" -v

Do not execute these commands during development-only turns.

## Acceptance evidence requirements

Future Codex evidence: exact PR HEAD, platform and Python version; executed
commands; exit codes; per-case pass/fail/skip counts; full stdout/stderr of
synthetic tests; input fixture hashes; file read-only confirmation; and
author review outcome. A test marked planned is not a passed test.

Status: **NOT_RUN** / Draft / private storyline excluded / candidate only /
no shared interface approved / no main merge.
