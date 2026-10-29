# GAME-WEB-MODULE-STATE-002 r1 · future acceptance plan

**STATUS: NOT_RUN / NOT_VERIFIED.** This document is authored test
expectations, not execution evidence. No code or tests were executed during
this task. The original W-STATE-001 future test file remains present with
adjusted redacted-diff assertions.

## Source and scope

- Draft PR #13, branch `codex/game-web-module-state-001-r1`, only
  `candidates/game_web_module_state_001_r1/`.
- Snapshot v1 contract from Draft PR #6 remains the only known format.
- No approved v0/v2 schemas or runtime/example saves; synthetic version
  labels in tests are purely rejection fixtures.
- The inspector is the only subject. Tests are permitted later to
  write disposable *synthetic* files inside their own fresh `user://`
  directory; they must not touch production saves or private material.

## Future execution by Codex ONLY (not now)

From repository root, capture command, tool version, stdout/stderr, exit
code **for each command** and exact candidate commit:

```sh
godot --headless --path candidates/game_web_module_state_001_r1 --script res://verify_snapshot_inspector.gd
echo "suite_001_exit=$?"
godot --headless --path candidates/game_web_module_state_001_r1 --script res://verify_report_boundaries.gd
echo "suite_002_exit=$?"
```

Future success criterion: both scripts complete with exit code 0, no
parser errors, all case checks PASS, no fixture cleanup failures. A
script's printed expectation is **not a test result until observed**.
Godot version is requested 4.7.2 but **not verified locally**.

### Original suite: cases A01–A25 (unchanged scope, future only)

Valid story/free; wrong expected mode; v1 no-op/same-version preview;
independent deep-copied data; unsupported synthetic version; explicit
manual target; invalid target; JSON damage; missing/extra fields;
boolean/negative/nonfinite clock; foreign content; oversized input;
missing/unsafe path; before/after byte identity; no temp files; cleanup.

Diff assertions now verify **no before/after values in output**.
Original suite remains isolated; it must not operate on a real game save.

### Additional future report/boundary suite: R01–R48

| Group | IDs | Expected outcome |
|---|---|---|
| Redacted report | R01–R08 | Valid v1 and expected mode; correct compatibility; safe metadata, no data/path/ID/hash; no migration needed |
| Structural preview | R09–R14 | Same-version proposal, only known field/kind changes, no apply, deep-copy independence, no private value |
| Unsupported source | R15–R21 | Unknown numeric version classified unsupported; absent mapping blocked; caller-supplied target is unverified only; extra unknown keys counted, not disclosed |
| Cross-mode | R22–R23 | Foreign mode wins over unknown version; no preview |
| Missing source mode | R24–R26 | Invalid source, cannot claim compatibility or preview |
| Invalid v1 schema | R27–R29 | Structured missing-field code; valid target cannot repair invalid source |
| Damaged JSON | R30–R31 | Malformed file; preview blocked |
| Boolean version | R32–R33 | Invalid type distinct from unsupported numeric version |
| Invalid target | R34–R35 | Invalid clock type or foreign target rejected |
| Pair reports | R36–R37 | Independent mode results; explicitly non-atomic |
| Unsafe paths | R38–R39 | Traversal and non-user URI refused |
| Oversize | R40–R41 | Inspection-size guard; preview refused |
| No writes | R42–R43 | Original bytes identical; no temporary snapshot created |
| Numeric normalization | R44–R47 | JSON version 1 versus 1.0 treated as identical v1; no phantom diff |
| Invalid source recovery guard | R48 | Unexpected field in v1 source cannot be rescued by a valid target |

**Additional manual review required after authorized testing:**
- `version:1.0` accepted; `version:2` unsupported only if mode valid.
- No dependency on a permissive JSON parser's unspecified behavior with
  duplicate keys, invalid UTF-8, exponent overflow or non-standard syntax.
- No symlink escape guarantee; platform-specific read errors and
  concurrent file changes require separate investigation.
- Check `report_snapshot` itself contains no payload, user path,
  content digest or arbitrary source key (even in error messages).
- Check `preview_migration` contains **no before/after field values**,
  but note its existing `text_sha256` is local-only, not public-safe.
- Validate story/free independence; no clock rule, round progression or
  gameplay claim is made.
- Reconcile upstream PR #6 changes, if any, before approving changes.

## Gate / outcome tracking

| Gate | Current |
|---|---|
| Source read from current Draft PR #13 | Completed via GitHub connector |
| Incremental source/docs submitted | Source-written; commit to be recorded |
| Code executed in Godot | **NOT_RUN** |
| SceneTree assertions | **NOT_RUN** |
| CI | **NOT_VERIFIED** |
| Runtime privacy / symlink / concurrency review | **NOT_VERIFIED** |
| Approved legacy mapping | **NOT_PROVIDED** |
| Canon/shared interface approval | **NOT_APPLICABLE / NOT_APPROVED** |
| main merge | **NOT_DONE** |
| Notion / Drive | **NOT_DONE** |

## Future evidence record (template, not execution)

```json
{
  "task_id": "GAME-WEB-MODULE-STATE-002",
  "version": "r1",
  "scope": "W-STATE",
  "canon": "N/A",
  "repository": "cao772/game",
  "pr": 13,
  "branch": "codex/game-web-module-state-001-r1",
  "commit": "RECORD_LATER",
  "godot_version": "NOT_RUN",
  "platform": "NOT_RUN",
  "suite_001": {"command": "NOT_RUN", "exit_code": null, "results": "NOT_RUN"},
  "suite_002": {"command": "NOT_RUN", "exit_code": null, "results": "NOT_RUN"},
  "privacy_review": "NOT_VERIFIED",
  "legacy_mapping": "NOT_PROVIDED",
  "notion": "NOT_DONE",
  "drive": "NOT_DONE",
  "status": "NOT_RUN"
}
```

Do not promote this Draft or mark PASS based on source inspection alone.

---

## CONTINUE-STATE-003 r1 — additional future test suite (NOT_RUN)

New future SceneTree script: `verify_version_diff_003.gd`. It must
**not be run during this authoring phase**. Later Codex may run:

```sh
godot --headless --path candidates/game_web_module_state_001_r1 --script res://verify_version_diff_003.gd
echo "suite_003_exit=$?"
```

Planned `V001–V042` acceptance cases:

| Coverage | IDs | Expected outcome (not observed) |
|---|---|---|
| Version baseline | V001–V007 | Known numeric v1 reference only; bool/2 rejected; path isolation; no migration claims |
| v1-v1 comparison | V008–V014 | Only known field names/kinds and counts; no payload, hash or path; numeric version relation; non-atomic pair |
| Unsupported versions | V015–V022 | Numeric 0/2 are synthetic only; order visible; no unknown-schema field diff or mapping; redacted summaries |
| Corrupt file | V023–V024 | Pair comparison and safe preview blocked, empty changes |
| Safe preview | V025–V030 | v1 default/noop, phase-only review, no apply/approval/write, redacted reports |
| Protected identity/time | V031–V034 | Clock/round ID changes block approval, no private values |
| Invalid target/source | V035–V040 | Cross-mode, bool clock, extra target, invalid source and foreign mode blocked |
| Read-only integrity | V041–V042 | Bytes before/after equal; no temporary file created |

Additional future reviewer checks: privacy of report metadata itself,
strict JSON parser behavior, symlink path escape, concurrent snapshot
modification, Godot 4.7.2 parse/typing, test fixture cleanup, and
upstream PR #6 schema drift. These are **NOT_VERIFIED**.

**Actual status**: all old and new scripts are source-only, no Godot
execution or test result. Future evidence must include Git commit,
Godot binary/version, OS, full command, exit code, redacted output and
cleanup results. No production/private save is an allowed fixture.

No source-version mapping was provided. Codex must not mark a migration
as supported, or mark this PR ready/merge, on source-only evidence.
