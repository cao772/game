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
private EVENT001 schema. No existing file or branch source is modified.

Files:
- event_data_check_candidate.py — read-only checker, human and JSON CLI.
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
