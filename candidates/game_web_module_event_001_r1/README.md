# GAME-WEB-MODULE-EVENT-001 r1 — independent event-data checker

**Status: NOT_RUN / author-review candidate.** This is a public, synthetic,
standalone Python 3.12+ standard-library-only technical artifact. It is not
canon, does not import private event data, and does not approve a shared
gameplay event interface.

## Source review and boundary

Prepared after reading GitHub draft [PR #6](https://github.com/cao772/game/pull/6)
(input-to-snapshot coordinator, state helper and isolated project README) and
[PR #2](https://github.com/cao772/game/pull/2) (isolated tooling and
validation conventions). Neither makes a public event-definition JSON
contract available on main. Accordingly this directory declares a **new,
independent public candidate contract**, rather than assuming or copying the
private EVENT001 schema. No sources outside this PR's own candidate module are modified.

Files:
- event_data_check_candidate.py — read-only checker, human and JSON CLI.
- event_source_diagnostics_candidate.py — source locations, duplicate-member offsets and reference target diagnostics.
- test_event_source_diagnostics_candidate.py — new synthetic prospective acceptance (NOT_RUN).
- test_event_data_check_candidate.py — synthetic future unittest acceptance.
- fixtures/placeholder_alpha.json and placeholder_beta.json — no story text.
- docs/game-web-module-event-001-acceptance.md — independent acceptance matrix.

## Candidate JSON contract (NOT a replacement for EVENT001 schema)

Exactly one JSON object per .json file, no array bundles:

| Field | Requirement |
| --- | --- |
| event_id | Required unique uppercase identifier matching ^[A-Z][A-Z0-9_]{0,63}$ |
| trigger | Required object with signal and conditions |
| trigger.signal | Required identifier using the same format |
| trigger.conditions | Required array of 1–16 unique identifiers |
| actions | Required array of 1–16 action objects |
| actions[].action_id | Required identifier, unique within its event |
| actions[].next_event_id | Required null or ID of another event in the selected file set (self-reference permitted; no behavioral inference) |
| on_ignore_event_id | Optional null or reference to event in the same selected file set |

Each action object has precisely action_id and next_event_id. Each trigger
object has precisely signal and conditions. Unknown properties are rejected
to prevent silently accepting accidental extra content. Identifier matching
is case-sensitive. The checker validates *static targets only*, not game
transitions, loops, trigger semantics, action execution, or runtime timing.
Null means no outgoing event reference; it does not imply an engine action.
Cycles are not a validation error and are not evidence of story time loops.
The optional ignore reference is simply another syntactic cross-reference.

Across all files passed in one call, duplicate event_id values are rejected.
The same file passed multiple times is counted once by canonical path.
References are resolved within that explicitly selected file set, **not**
against undeclared external repositories, private sources, or other PRs.

## Inputs and outputs

- Arguments: one or more existing .json files or directories. Directory
  inputs recursively select .json files only; other extensions are ignored.
- Uses strict UTF-8 and JSON. Duplicate JSON member names, NaN/Infinity,
  malformed documents, unknown fields, wrong types, bad IDs, duplicate
  event/action/condition IDs, and dangling references fail closed.
- Input symlinks are rejected; symlinked directories are not traversed.
  Limit: at most 1,024 distinct files and 1 MiB per file. This is a
  bounded development checker, not a hardened adversarial file scanner.
- Report issues include code, path, JSON pointer and detail, sorted for
  stable review. JSON pointers are RFC 6901-style.
- Exit code 0 = report status PASS for the *candidate structural contract*;
  1 = at least one issue; 2 = argument parsing error. This never certifies
  scene runtime, private schema compliance, or canon.
- Files are read only. No write/repair mode, network, import of game sources,
  background service, Godot process, or shared event bus.

## Future execution commands (NOT executed in this task)

From repository root, after author/Codex permits execution:

    python candidates/game_web_module_event_001_r1/event_data_check_candidate.py --json candidates/game_web_module_event_001_r1/fixtures
    python -m unittest discover -s candidates/game_web_module_event_001_r1 -p "test_event_data_check_candidate.py" -v

Or pass selected .json files explicitly. Keep synthetic fixture test evidence
separate from a game/engine certification. Capture exact interpreter version,
commit SHA, command, stdout/stderr, process exit code and test result before
claiming a local PASS. Do not add unapproved CI runs.

## Explicit limits and pending owner choices

1. New public contract is intentionally *different in purpose* from
   EVENT001 private schema. Decide later whether any adapter should exist.
2. No relationship to the input, snapshot, or runtime contracts in PR #6;
   no linking or import was created.
3. References resolve only within the selected input set; absent external
   events are errors, not assumed valid.
4. Concurrent file mutation between stat and read, filesystem race conditions,
   Windows path aliases and hostile symlink replacement are not fully
   protected. There is no transactional scan snapshot.
5. This checker has no execution semantics, no save interfaces, no real
   event wiring, no engine testing, no cache or persistence.
6. Author must decide how to interpret self-references, allowed graph cycles,
   naming conventions, maximum limits, and future tool integration.

**Review gate:** NOT_RUN until Codex independently executes the prospective
cases and provides evidence. Do not merge to main, publish as shared interface,
or treat this as approval of any narrative or event behavior.


## EVENT-002 r1 enhancement — structured diagnostics (NOT_RUN)

The existing CLI and one-event-per-file placeholder JSON contract remain
unchanged. This **extends** PR #9's candidate, not EVENT001 or any other
schema/module. The same public placeholders are used.

### Diagnostic fields (machine-readable JSON)

Each issue preserves the original keys "code", "file", "pointer", "detail" and
adds:
- "severity": always "error" in this strict candidate.
- "location": null if no trustworthy source coordinate exists, or object
  with 1-based "line", "column", "precision" ("exact" or "parent") and
  "column_unit": "unicode_character".
- "related": optional list of file/pointer/location for known duplicate
  definitions, ambiguous targets, and original JSON member occurrence.
- "target_id": optional placeholder reference identifier for unresolved,
  ambiguous, or invalid target references.

The top-level report adds:
- "enhancement_task_id": "GAME-WEB-MODULE-EVENT-002"
- "enhancement_version": "r1"
- "diagnostic_format": "2.0-candidate"
- "references_checked": number of syntactically valid non-null reference sites
  examined by the enhancer (not a count of successful runtime transitions).
- "issue_counts_by_code": sorted mapping code to occurrence count.

Location precision: exact points to the syntactic key or array element;
parent anchors a missing field to an existing ancestor rather than
inventing a position. A malformed JSON syntax error uses Python's
JSONDecodeError line/column when supplied. UTF-8 errors and input/OS errors
may have no line/column, and never invent them. Nonstandard numeric
constants such as NaN remain invalid, but Python's parse_constant failure
does not guarantee a source coordinate. No raw source excerpts are copied
into diagnostics.

### Cross-reference behavior

- Known single valid target: accepted.
- Missing ID in the selected files: UNKNOWN_EVENT_REFERENCE with target_id.
- More than one definition: DUPLICATE_EVENT_ID on the later file and
  AMBIGUOUS_EVENT_REFERENCE at every reference site, with related source
  locations for competing definitions; **not silently resolved to first**.
- Single target with structural errors: INVALID_EVENT_REFERENCE_TARGET at
  its referring site with a linked definition coordinate.
- Invalid syntactic reference ID: INVALID_ID; no further resolution attempt.
- A duplicate JSON member is rejected before validating a last-key-wins
  object, and reports each repeated key's coordinate plus first occurrence.
- Self references and static graph cycles remain permitted, do not imply
  runtime iteration, story semantics, or authorization of any event loop.
- Scope remains a single selected file set; no remote imports, implicit
  namespaces, or private cross-project knowledge.

The source-location indexer accepts up to 128 levels of nesting after
normal JSON parsing and fails closed with SOURCE_INDEX_ERROR above that
limit. The previous per-file 1MiB and 1,024-file scan caps remain. No claim
of transactional filesystem snapshot or protection against concurrent file
replacement/symlink TOCTOU races.

The Python interpreter can itself generate __pycache__ on import; run
future verification with python -B or PYTHONDONTWRITEBYTECODE=1 if
zero interpreter cache writes are required. The checker never writes or
rewrites the event input JSON, generates reports on stdout only, and does
not launch Godot. No source/runtime tests have been run for EVENT-002.

Future acceptance matrix:
[EVENT-002 diagnostics](../../docs/game-web-module-event-002-acceptance.md).
The original EVENT-001 acceptance set remains present and unmodified.

**Gate:** Source submitted only. NOT_RUN. Codex must independently run both
test suites and capture exit codes, platform, precise HEAD SHA, errors,
skips, and read-only verification before anyone calls the change tested.
No main merge, story approval, or shared interface approval.


## EVENT-003 r1 — readable error reports and manual repair advice (NOT_RUN)

This increment continues the same PR #9; nothing from private EVENT001 or
other project branches was imported. No user content was changed.

Additional files:
- event_repair_advice_candidate.py: pure, rule-based review suggestions.
- event_report_candidate.py: full grouped human error report on stdout.
- test_event_repair_advice_candidate.py: synthetic future assertions.
- docs/game-web-continue-event-003-acceptance.md: design tradeoffs,
  diagnostics contract, and planned acceptance evidence.

The existing checker now attaches a repair_advice object to each issue:
- suggestion_id, category, title, non-destructive review steps.
- auto_apply=false, requires_review=true for EVERY error.
- For missing event references only: up to three possible spelling matches
  from unique and structurally healthy event IDs in the selected files;
  these are NEVER confirmed matches or automatic rewrites.
- Duplicate/ambiguous/structurally invalid target diagnostics preserve
  related definitions and source line/column anchors from EVENT-002.

JSON reports include repair_review_summary (file counts, advice rule counts,
manual-review policy, zero applied fixes), continuation_task_id and
advice_format=3.0-candidate. The previous diagnostic_format and code/pointer
fields are retained. The text renderer groups issues per file with
filename:line:column, location precision, pointer, code, related sites and
steps. It does not echo JSON source values. File paths and identifier values
may still be sensitive; use only placeholder evidence in public reports.

Output to stdout only, no file creation/repair:

    python -B candidates/game_web_module_event_001_r1/event_data_check_candidate.py --format text candidates/game_web_module_event_001_r1/fixtures
    python -B candidates/game_web_module_event_001_r1/event_data_check_candidate.py --format json candidates/game_web_module_event_001_r1/fixtures

Legacy --json is retained; --json combined with --format text is rejected.
Exit 0 means only static candidate checks found no issues, not scene or
engine certification. Exit 1 means one or more diagnostics; argparse
conflicts return exit 2.

No code execution, tests, import checks or CI were performed in this
development request. **NOT_RUN**. Future Codex tests must exercise all
three synthetic test files, with explicit real exit codes and version
evidence. Do not merge, replace sources, or approve shared interfaces or
story content based on this candidate.

See [EVENT-003 future acceptance and design decisions](
../../docs/game-web-continue-event-003-acceptance.md).
