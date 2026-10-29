# GAME-WEB-MODULE-STATE-001 r1 / W-STATE

**Independent technical candidate · Canon: N/A · NOT_RUN**

Read-only round-snapshot inspection and *preview-only* migration planning
for Godot 4.7.2. This is not an approved shared save interface.
No original prose, private materials, existing Python save, event runtime,
or other code under `main` is changed.

## Actual source and dependency boundary

Source reviewed: [PR #6, W-INPUT × W-STATE](https://github.com/cao772/game/pull/6),
file `candidates/game_web_integrate_001_r1/round_snapshot_candidate.gd`
on branch `codex/game-web-integrate-001-r1`, Git blob
`6734407f432bb8912d5c769e76200448489dc646`.

That file contains the unchanged GAME-WEB-STATE-001 r1 candidate.
Its protocol is a JSON root object with **exactly six fields**:
`version` (numeric 1, not boolean), `mode` (`story`/`free`),
`round_id` (nonblank string), `phase`
(`ready`/`observing`/`resolved`/`deferred`),
`door_open` (boolean), `clock_seconds`
(nonnegative finite numeric, not boolean).
The file naming rule is `user://.../story.round_snapshot.json`
or `user://.../free.round_snapshot.json`, matching expected mode.

This module has an **independent duplicate of the validation rules** as a
read-only implementation, not an imported or modified write codec. This
permits inspection when the source PR is still Draft and remains isolated
from the writer's API. Any future change to PR #6 must trigger a fresh
compatibility review, not an automatic assumption of compatibility.

## Contents

- `snapshot_inspector_candidate.gd`: RefCounted read-only inspector,
  version/corruption detection, two-mode scan, manual migration preview.
- `verify_snapshot_inspector.gd`: finite SceneTree test **source for future
  execution**; it deliberately writes only synthetic test fixtures.
- `project.godot`: standalone Godot project.
- `README.md`: usage, source evidence, API and safety limits.
- `MIGRATION_POLICY.md`: proposal semantics and approval boundaries.
- `ACCEPTANCE.md`: future test cases, exit criteria and evidence template.

## API proposal

In another GDScript in this standalone project:

```gdscript
const Inspector = preload("res://snapshot_inspector_candidate.gd")
var inspector = Inspector.new()
var report = inspector.inspect_snapshot(
    "user://isolated/story.round_snapshot.json", "story"
)
var pair = inspector.inspect_pair("user://isolated")
var preview = inspector.preview_migration(
    "user://isolated/story.round_snapshot.json", "story"
)
```

`inspect_snapshot(path, expected_mode)` returns a new dictionary:
`ok`, `status`, `error`, `version_label`, `source_mode`,
`expected_mode`, `text_sha256`, `byte_length`, `data`.

- `data` is a deep copy **only for fully valid v1 input**; otherwise `{}`.
- `version_label` is a diagnostic string, not a schema selector.
- `text_sha256` hashes the decoded text read by Godot, not an assertion
  of byte-for-byte provenance or interprocess consistency.
- `byte_length` is the file size seen before reading content.

`inspect_pair(folder)` returns separate `story` and `free` inspection
results. These are **two sequential reads, not an atomic pair**.

`preview_migration(path, expected_mode, proposed_target=null)` returns:
`ok`, `status`, `source_status`, `source_version`,
`target_version`, `expected_mode`, `text_sha256`, `changes`,
`requires_review=true`, `can_apply=false`, `writes=false`, `error`.

- Valid v1 and no target: `no_migration_needed`, empty changes.
- Unknown finite numeric version and no target: `mapping_required`;
  there is **no approved old schema to migrate**.
- With an explicitly supplied complete valid v1 target object of the
  expected mode, the inspector computes an in-memory field-by-field diff.
  For invalid-schema or unsupported-version source, this is
  `manual_unverified_preview`; it is **not a successful migration**.
- With a valid v1 source, a changed target is a
  `same_version_proposal`, also **not** a version migration.
- Corrupt/unreadable/oversize/missing source or cross-mode content:
  blocked, with no speculative reconstruction.
- An invalid proposed target is rejected. No method applies a preview.

Differences report `field`, `kind` (`add`/`remove`/`change`),
`before`, `after`. Treat diff values as potentially sensitive
**in memory**: do not post runtime reports containing private save data
to public GitHub, Notion, or Drive. This PR contains only public test
fixtures and static implementation.

## Inspection status contract (candidate)

| Status | Meaning |
|---|---|
| `valid` | Fully validated protocol v1, correct mode |
| `invalid_request` | Invalid expected mode/path/name/traversal |
| `missing` | Requested snapshot absent |
| `unreadable` | File cannot be opened, or path is a directory |
| `too_large` | >1 MiB candidate inspection guard |
| `malformed_json` | Godot JSON parser rejected the input |
| `invalid_schema` | Parsed JSON but root/fields/types/values invalid |
| `unsupported_version` | Parsed finite numeric version != 1 |
| `mode_mismatch` | Parsed source mode differs from expected mode |

The guard of 1 MiB is **a new inspection proposal**, not a size restriction
in the PR #6 writer. The Godot parser's permissive JSON handling (e.g.,
possible duplicate-key handling) remains a limitation; schema validation
does not prove strict RFC 8259 conformance.

## Safety and integration boundaries

- Inspector uses only `FileAccess.READ` and metadata reads. It has no
  save, rename, delete, process execution, or directory-creation API.
- The future **test script** writes temporary synthetic fixtures under
  its own fresh `user://` directory, then removes only its registered
  files/directories; this is separate from the read-only module.
- No automatic repair; no rename or replace; no cross-mode writes.
- No assumptions about story/free clock progression, chapter transition,
  character, plot, canon, or event semantics.
- A file may be changed concurrently while inspected; text hashes only
  identify the bytes as *decoded on that read*, not a lock or transaction.
- Unknown old-version layouts are not invented. Explicit caller-supplied
  v1 targets can be compared but never applied.
- Malformed input is not treated as a new save; no silent fallback.

## Future verification — do not execute during this development task

From repository root, **Codex later** may run:

```bash
godot --headless --path candidates/game_web_module_state_001_r1 \
  --script res://verify_snapshot_inspector.gd
echo $?
```

Expected only **if actually observed**: `PASS GAME-WEB-MODULE-STATE-001 r1`
and status 0. Failed assertions should return nonzero. A Godot parse
error can also exit nonzero. For the test matrix and reporting template,
see [ACCEPTANCE.md](./ACCEPTANCE.md).

**Actual state for this PR: SOURCE_WRITTEN; NOT_RUN; NOT_VERIFIED.**
No CI, Godot execution, Codex acceptance or cross-platform persistence
has been claimed. Do not mark the PR Ready or merge until verified.
