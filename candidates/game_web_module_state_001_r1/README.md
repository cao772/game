# W-STATE independent read-only inspection · GAME-WEB-MODULE-STATE-002 r1

**Draft candidate / Canon N/A / NOT_RUN / NOT_VERIFIED.**
This continues GAME-WEB-MODULE-STATE-001 r1 **within the same Draft PR #13**
and in the same isolated directory. No change to main, other candidates,
source novel, or any approved shared interface.

## Verified source baseline (read-only GitHub inspection)

- [Draft PR #13](https://github.com/cao772/game/pull/13), source branch:
  \`codex/game-web-module-state-001-r1\`.
- Underlying snapshot proposal: [Draft PR #6](https://github.com/cao772/game/pull/6),
  \`candidates/game_web_integrate_001_r1/round_snapshot_candidate.gd\`,
  original observed blob \`6734407f432bb8912d5c769e76200448489dc646\`.
- Snapshot v1 is the **only supplied schema**: exact JSON object
  \`version\` = numeric 1 (bool rejected), \`mode\` = story/free,
  \`round_id\` = nonblank string, \`phase\` = ready/observing/resolved/deferred,
  \`door_open\` = boolean, and finite nonnegative numeric \`clock_seconds\`.
- No evidence of an approved v0/v2 format, legacy transformation table, clock
  adjustments, repair strategy, runtime persistence contract, or real user
  save examples. None is assumed.

## Files

| Path | Purpose |
|---|---|
| \`snapshot_inspector_candidate.gd\` | RefCounted core; read-only inspect, safe report, v1 compatibility classification, structural preview |
| \`verify_snapshot_inspector.gd\` | Existing future acceptance suite adjusted for redacted previews; **NOT_RUN** |
| \`verify_report_boundaries.gd\` | Additional future SceneTree error/report test cases; **NOT_RUN** |
| \`project.godot\` | Standalone Godot project, no scene/autoload |
| \`REPORT_FORMAT.md\` | Safe report fields, error code taxonomy, compatibility table |
| \`MIGRATION_POLICY.md\` | Block/preview matrix, required approvals and missing mappings |
| \`ACCEPTANCE.md\` | Future commands, evidence format, new coverage |

No private payload or runtime save is included in this public branch.

## Proposed in-memory API

\`\`\`gdscript
const Inspector = preload("res://snapshot_inspector_candidate.gd")
var inspector = Inspector.new()

# Safe metadata report; suitable for deliberate public sharing only after
# operational review. No source JSON, identifiers, user path, hash or values.
var report = inspector.report_snapshot(
    "user://candidate/story.round_snapshot.json", "story"
)

var compatibility = inspector.compatibility_snapshot(
    "user://candidate/story.round_snapshot.json", "story"
)
var pair = inspector.report_pair("user://candidate")

# Legacy rich API: a valid v1 snapshot is returned as a deep copy.
# Do NOT serialize / publish its data or hashes to public PR/CI logs.
var detailed = inspector.inspect_snapshot(
    "user://candidate/story.round_snapshot.json", "story"
)

# Proposal only. No save, apply, conversion or runtime side effect.
var preview = inspector.preview_migration(
    "user://candidate/story.round_snapshot.json", "story"
)
\`\`\`

- \`report_snapshot\`: sanitized diagnostic metadata without raw input/round ID,
  path, source JSON, text checksum, or any snapshot values; structured
  \`error_code\` and known \`error_field\`, version compatibility classification.
- \`compatibility_snapshot\`: isolated compatibility subset from the same
  inspection logic. It performs a new read when called separately.
- \`report_pair\`: separate story/free safe reports. **Not an atomic pair**.
- \`inspect_snapshot\` and \`inspect_pair\`: retained original detailed
  APIs for local inspection, including validated payload and decoded-text
  SHA-256. They are **not public-safe reporting methods**. Payload is
  deep-copied only when strict v1 validation succeeds.
- \`preview_migration\`: legacy method name retained; returns metadata-only
  changed field/kind tuples. There are no \`before\` or \`after\` values,
  and unknown field names are suppressed; see MIGRATION_POLICY.
  SHA-256 in this **detailed preview API** should not be published.
  This is only an in-memory planning artifact.

The module never writes, renames, deletes or creates files; never
executes OS commands. Synthetic fixtures are written by future test
scripts only, under uniquely named \`user://\` directories.

## Statuses and migration guardrails

See [REPORT_FORMAT.md](REPORT_FORMAT.md) for the compatibility truth table
and structured diagnostics. Summary:

- \`valid\` + matching mode -> \`compatible_v1\` (format only, not gameplay).
- Finite numeric version !=1 + verified same mode -> \`unsupported\`;
  explicit mapping absent. Default preview: \`mapping_required\`.
- Other valid mode -> \`incompatible_mode\`, even if version is unsupported.
- No trustworthy version, invalid/missing mode, malformed JSON, bad v1 schema,
  missing/unreadable/oversize file -> no positive compatibility claim.
- Explicit complete valid v1 target: for verified v1 source, only a
  \`same_version_proposal\`; for unsupported numeric version and matching
  mode, only \`manual_unverified_preview\`. No target can override a
  damaged/invalid schema, unsafe path or foreign mode.
- \`ok: true\` in a preview means **a comparison description was produced**;
  it never means a migration is supported, approved, applied or safe.
- Always \`can_apply=false\`, \`mapping_approved=false\`,
  \`writes=false\`, \`requires_review=true\`.

\`MAX_BYTES = 1048576\` is a **new inspection-only safety cap**,
not a production save limit or writer capability.

## Known limitations (do not overclaim)

- Upstream PR #6 remains Draft and its duplicated six-field contract is
  **not automatically synchronized**. Re-review if upstream changes.
- Godot's JSON parser is not treated as proof of strict RFC 8259 acceptance;
  duplicate keys/parser extensions/invalid UTF-8 require separate review.
- \`user://\` path-string filtering is not a symlink or filesystem
  sandbox. Symlink escape prevention is **not proven**.
- No interprocess lock, single-snapshot stability under concurrent
  modification, transactional pair consistency, power-loss guarantee or
  automatic backup/rollback.
- \`text_sha256\` (in detailed APIs only) hashes decoded text, not a
  cryptographically asserted immutable file version.
- Valid v1 data is syntactically valid, not approved game semantics or
  proof of clock invariants.
- The safe report may reveal enum mode, file size and version classification.
  If metadata itself is sensitive, keep reports private as well.

## Future Codex execution — **NOT PERFORMED BY THIS TASK**

From repository root, after explicit authorization to test:

\`\`\`sh
godot --headless --path candidates/game_web_module_state_001_r1 --script res://verify_snapshot_inspector.gd
godot --headless --path candidates/game_web_module_state_001_r1 --script res://verify_report_boundaries.gd
\`\`\`

Run separately and record **each** exit code, Godot binary/version, commit,
platform, full output and failures without real saves/private data.
An expected PASS message in a test script is **not evidence of an actual PASS**.
See [ACCEPTANCE.md](ACCEPTANCE.md).

**Project status: SOURCE_WRITTEN / NOT_RUN / NOT_VERIFIED.**
Do not merge or mark Ready based on source submission.
