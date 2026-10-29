# GAME-WEB-MODULE-STATE-002 r1 · migration preview policy

**Independent source proposal · Canon N/A · NOT_RUN.**
Continues 001 within [Draft PR #13](https://github.com/cao772/game/pull/13).
The only known protocol is snapshot v1 in [Draft PR #6](https://github.com/cao772/game/pull/6).
An old-version schema and author-approved migration rules are **NOT PROVIDED**.

## Ground truth and missing decisions

Known: six exact v1 fields and enum restrictions, story/free filename/content
isolation, read-only inspection. **Unknown**: actual earlier schema, field
mappings, renamed properties, backwards compatibility policy, clock rules,
event/round identity migration, fallback defaults, data retention, rollback
semantics, release process, and any live save samples.

Numeric 0 and 2 in synthetic future test fixtures are deliberately invented
**test inputs only**, not authentic historical or future save versions.

## Fail-closed decision rules

1. Require explicit `user://` path, safe lexical segments and filename
   `<expected_mode>.round_snapshot.json` where expected_mode is story/free.
   This is a lexical filter, **not symlink containment**.
2. Open read-only, reject >1 MiB candidate inspection input before parsing.
   Reject unreadable file, directory target, missing file and JSON parse error.
3. Require JSON object, a numeric finite source version, and a valid
   source mode equal to expected_mode. Reject otherwise. A foreign-mode
   file is never previewed even when its version is unsupported.
4. For version 1, require all six fields, no unknown fields, and all
   field types/ranges valid. Any malformed v1 content is blocked even
   if a proposed target looks valid. A valid target must **not repair**
   an invalid source by implication.
5. A finite numeric source version !=1 with verified matching mode can
   be labeled unsupported. Without a target: `mapping_required`.
   A caller may explicitly provide one **complete validated v1 target**;
   only a superficial field-structure comparison is produced, and the
   result is labeled `manual_unverified_preview`. This does not assert
   schema migration or content correctness.
6. With a valid v1 source and a complete v1 target, a differing target
   produces `same_version_proposal`, not a version migration;
   identical content yields `no_changes`. The target is never written.
7. Targets must pass full v1 validation and match expected_mode. A target
   with unexpected fields, invalid types, missing fields or another mode
   is `invalid_target`, without any change list.
8. Previews include **only six allowed field names and operation kinds**.
   Old-version extra key names and all before/after values are excluded.
   `unrecognized_source_field_count` is diagnostic only.
9. Every preview returns `requires_review=true`,
   `mapping_approved=false`, `can_apply=false`, `writes=false`.
   No apply, backup, repair, overwrite, rename, delete or save API exists.
10. `ok=true` indicates a **preview description** was formed. It does not
    mean source compatibility, a correct mapping, an accepted game rule,
    or a successful migration.

### Outcome table

| Source | Target | Result |
|---|---|---|
| Fully valid v1 | none | `no_migration_needed` (no changes) |
| Fully valid v1 | valid same v1 | `no_changes` |
| Fully valid v1 | valid different v1 | `same_version_proposal` |
| Verified same-mode unsupported version | none | `mapping_required`, no changes |
| Verified same-mode unsupported version | valid complete v1 | `manual_unverified_preview`, review only |
| Any source | invalid target | `invalid_target` only if source is otherwise inspectable |
| Any invalid path/source mode/schema/JSON/read/size | any | `blocked` |
| Incompatible source mode plus unsupported version | any | `blocked` (mode takes precedence) |

For exact classification/status/error codes consult
[REPORT_FORMAT.md](REPORT_FORMAT.md).

## What must be decided before a true migration can exist

- Source-version JSON schemas and real **authorized, sanitized** examples.
- The explicit target version and ownership of schema evolution.
- Per-field transformation and coercion rules, including clock handling.
- Whether unknown fields are retained/dropped; what to do on conflicts.
- Consistency, atomicity, backup/rollback, durability and writer arbitration.
- Security/privacy classification for runtime data and report retention.
- QA acceptance, platform-specific behavior and reviewer sign-off.

No defaults are silently selected in this task.

## Risks and limitations

- Even a redacted report may disclose metadata. Internal detailed inspection
  and preview APIs include local decoded-text hashes; do not post raw output.
- The Godot parser's treatment of duplicate keys, permissive JSON syntax,
  invalid UTF-8 and overflow is not a strict RFC guarantee.
- No locks; concurrent edits between independent reads can produce different
  results. Not a transactional pair inspection or a cross-process migration.
- Known v1 schema rules are copied from upstream PR #6, not an approved
  shared package; rereview on upstream change.
- Test scripts may create synthetic files **only when Codex later runs them**;
  this source-development phase has not executed tests.
