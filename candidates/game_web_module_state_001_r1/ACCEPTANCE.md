# Future acceptance matrix — NOT RUN

`GAME-WEB-MODULE-STATE-001 r1`, standalone Godot 4.7.2 candidate.
Source baseline: Draft PR #6; tester: Codex **after** this authoring task.

## Procedure (for future Codex execution only)

1. Record Godot binary/version, OS, filesystem, exact Git commit and
   branch. Confirm only this isolated project is used.
2. Run `godot --headless --path candidates/game_web_module_state_001_r1 --script res://verify_snapshot_inspector.gd`.
3. Capture full stdout/stderr and process exit status, without including
   any real/private game save content in reports.
4. Review the temporary `user://w_module_state_*` directory handling;
   tests must clean only the exact files and directories they created.
5. If any parser/runtime error or assertion fails, record failure; do not
   reclassify as accepted or infer success from source inspection.
6. Independent follow-up: inspect a read-only copy of permitted example
   saves, only after the owner provides explicit authorization. Not part
   of this PR's acceptance.

## Tests represented in the SceneTree source

| Case | Input | Expected |
|---|---|---|
| A01 | Valid story v1 | `valid` with deep-copied data |
| A02 | Valid free v1 | `valid`; content independent from story |
| A03 | Story path with expected free | `invalid_request` |
| A04 | Free path with expected story | `invalid_request` |
| A05 | Valid v1 without target | `no_migration_needed`; no writes |
| A06 | Valid v1 with explicit modified target | Two-field in-memory diff, `same_version_proposal`, cannot apply |
| A07 | Mutation of returned data | Later inspection unchanged |
| A08 | Synthetic numeric v0 | `unsupported_version`, `mapping_required` |
| A09 | Synthetic v0 plus explicit valid target | `manual_unverified_preview`; no apply |
| A10 | Bad target phase | `invalid_target` |
| A11 | Wrong-mode target | `invalid_target` |
| A12 | Truncated JSON | `malformed_json`; no source data exposed |
| A13 | Root array | `invalid_schema` |
| A14 | Numeric version 2 | `unsupported_version` |
| A15 | Missing or extra field | `invalid_schema` |
| A16 | Boolean clock | `invalid_schema` |
| A17 | Negative clock | `invalid_schema` |
| A18 | Valid-shaped file containing other mode | `mode_mismatch` |
| A19 | Nonfinite exponent | Invalid/blocked (parser or schema) |
| A20 | File exceeding candidate size guard | `too_large` |
| A21 | Missing file | `missing` |
| A22 | Traversal / res:// path | `invalid_request` |
| A23 | Raw story/free bytes before and after | Exactly equal |
| A24 | Snapshot `.tmp` files | None created by inspector |
| A25 | Fixture cleanup | Only test-registered files/directories removed; failures yield nonzero |

## Additional manual tests proposed (not automated here)

- B01: `version: 1.0` is accepted as numeric 1, not as a new version.
- B02: Reject boolean version, nonstring round_id, whitespace-only
  round_id, invalid phase, nonboolean door_open, string clock, NaN clock.
- B03: Source with unsupported version AND opposite valid mode must never
  be treated as a migration preview for the expected mode.
- B04: Inaccessible file, file replaced during inspection, and symlink
  traversal under `user://`: document platform-specific behavior.
- B05: JSON duplicate keys and other parser extensions: assess strict
  syntax acceptance separately; do not claim current inspector is a
  strict RFC parser.
- B06: Confirm no private fixture, runtime values, or user directories are
  included in PR/CI logs or external archives.

## Evidence record template

```json
{
  "task_id": "GAME-WEB-MODULE-STATE-001",
  "version": "r1",
  "scope": "W-STATE",
  "canon": "N/A",
  "implementation": "isolated candidate",
  "repository": "cao772/game",
  "branch": "codex/game-web-module-state-001-r1",
  "commit": "TO_BE_RECORDED_BY_CODEX",
  "godot_version": "NOT_RUN",
  "platform": "NOT_RUN",
  "command": "NOT_RUN",
  "exit_code": null,
  "passed": null,
  "failed": null,
  "stdout_stderr_evidence": "NOT_RUN",
  "github_archival": "Draft PR only; not merged",
  "notion_archival": "NOT_DONE",
  "drive_archival": "NOT_DONE",
  "reviewer_decisions": [
    "Legacy schema mapping not provided",
    "Read-only API not approved as shared contract"
  ],
  "status": "NOT_RUN"
}
```

**Do not replace NOT_RUN with PASS based on code review.**
