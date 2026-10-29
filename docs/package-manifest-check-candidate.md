# GAME-WEB-MODULE-PACK-001 r1 — standalone manifest checker

Status: **implementation candidate only — NOT RUN, NOT TESTED, NOT APPROVED**. This work changes neither Canon nor any shared game interface.

## Baseline and provenance

Designed using cao772/game Draft PR #4 (https://github.com/cao772/game/pull/4), head 2f7a2c29c7fcfc2402b5d935349fec96dafa9988:

- tools/package_manifest_candidate.py: canonical-root r2 source packager, ZIP_STORED, sorted source entries, fixed timestamp, manifest.json last, SHA256 of each original byte stream.
- docs/package-manifest-validation.md: source-only candidate purpose and limits.

The checker expects manifest.json to be UTF-8 JSON containing exactly two top-level properties: format = GAME-WEB-PACK-001-r2, and files = an array of {path, size, sha256} objects. Each path is a source-relative POSIX member path; sizes are nonnegative integers and SHA256 values are 64 lowercase hex characters. Manifest itself is not listed.

This is a **stacked Draft PR** based on codex/package-manifest-r2 (PR #4), not main. It imports no symbols from the source packager and modifies no PR #4 files.

## Added files

- tools/package_manifest_check_candidate.py — Python 3.12+ standard-library, importable read-only check_archive(path) and command-line interface.
- tests/test_package_manifest_check_candidate.py — synthetic unittest acceptance cases for future execution (NOT EXECUTED).
- docs/package-manifest-check-candidate.md — this specification and test handoff.

## Future commands (NOT EXECUTED)

    python tools/package_manifest_check_candidate.py --archive ./artifacts/candidate.zip
    python tools/package_manifest_check_candidate.py --archive ./artifacts/candidate.zip --json
    python -m unittest discover -s tests -p test_package_manifest_check_candidate.py -v

Run from repository root. Exit status 0 means this checker found no configured integrity violation; 1 means a check failed. JSON output goes only to stdout; there is no upload, file mutation, extraction or execution of ZIP contents.

## Validation contract

1. Archive input must be an existing regular file. Reject input path traversal (..), symbolic-link or Windows reparse-point archive and ancestors.
2. Exactly one root manifest.json is required; reject invalid UTF-8, duplicate JSON object keys, invalid structure, incorrect format marker, and malformed records.
3. Archive member names and manifest paths must be relative POSIX strings. Reject absolute paths, backslashes, traversal components, Windows-reserved names, blocked/private directories and sensitive filenames. Only root project.godot and .gd/.tscn/.tres/.md/.json files are allowed.
4. Check both listed-but-missing and present-but-unlisted entries. Require project.godot and at least one .gd or .tscn.
5. Reject duplicate manifest records and ZIP members, including casefold/NFC-equivalent collisions.
6. Stream bytes and compare SHA256, manifest byte count and ZIP member declared length; CRC/read errors fail.
7. Check fixed timestamp, ZIP_STORED method, sorted source records, manifest.json last, and no ZIP symlink or special-file metadata.
8. Reject ZIPs exceeding 10,000 entries, manifest exceeding 4 MiB, individual member exceeding 512 MiB, or aggregate declared size exceeding 2 GiB. Limits are conservative candidate policy, not benchmark measurements.
9. Structured output contains status, expected format, archive, checked/manifest counts, issue codes and release_approved=false. Deterministic issue sorting.

Common issue codes: ARCHIVE_ERROR, MANIFEST_COUNT, INVALID_MANIFEST, MANIFEST_SCHEMA, FORMAT_MISMATCH, UNSAFE_PATH, UNSAFE_MANIFEST_PATH, DUPLICATE_ZIP_MEMBER, DUPLICATE_MANIFEST_PATH, MEMBER_MISSING, MEMBER_UNLISTED, MISSING_ENTRY, SIZE_MISMATCH, HASH_MISMATCH, MEMBER_READ_ERROR, MEMBER_METADATA, MEMBER_ORDER, MANIFEST_ORDER.

## Future acceptance cases (all PENDING)

| Case | Expected result |
|---|---|
| Synthetic valid ZIP with Chinese scene path | PASS, matched counts |
| Incorrect hash or byte count | HASH_MISMATCH / SIZE_MISMATCH |
| Missing ZIP entry or extra unlisted entry | MEMBER_MISSING / MEMBER_UNLISTED |
| Duplicate manifest path or duplicate ZIP entry | Duplicate violation |
| Parent traversal, Windows backslash or reserved device name | UNSAFE_PATH |
| No project.godot or no gd/tscn | MISSING_ENTRY |
| Duplicate JSON object key | INVALID_MANIFEST |
| Boolean size, uppercase/non-hex digest | INVALID_SIZE / INVALID_SHA256 |
| Wrong manifest version | FORMAT_MISMATCH |
| Unsorted member or manifest order | MEMBER_ORDER / MANIFEST_ORDER |
| Symlink ZIP metadata or compressed entry | MEMBER_METADATA |
| Archive inspected read-only | Bytes unchanged, no extracted paths |
| Archive link on supported OS | ARCHIVE_ERROR; explicit skip if unsupported |
| '..' in archive input argument | ARCHIVE_ERROR |
| Unicode-normalization member collision | DUPLICATE_ZIP_MEMBER |
| Real artifact from PR #4 | Pending independent integration verification |
| Windows Python 3.12 and 3.14, 8.3 aliases, junctions | Pending platform-specific verification |
| CRC corruption, hostile mutation, resource boundary fixtures | Future extended review coverage |

## Limits and decisions pending

- This checker validates the **ZIP and its own manifest**, not whether the original source tree contained additional eligible files omitted before packaging. There is deliberately no --source comparison in r1.
- A modified archive with consistently recomputed manifest digest can pass; no signature, chain-of-custody or trusted provenance is supplied.
- A passed checksum is not validation of Godot dependencies, file semantics, licenses, personal data, originality or release readiness. Source files may still conceal secrets in apparently allowed text. No private project artifacts should be committed.
- Source symlink/reparse safety belongs to the PR #4 builder; this verifier rejects marked ZIP symlinks and does not extract them.
- Real hostile concurrent filesystem mutation is outside current guarantees. This checker has not undergone any Windows, CI, Python 3.12, or real-archive verification in this task.
- If PR #4 changes version, member ordering or exclusion policy, compatibility must be reviewed explicitly. No Canon or shared interface is approved.

Codex handoff: execute future tests and real PR #4 integration independently, record actual PASS/FAIL/SKIP with environment and commit IDs. Publish only public technical evidence; do not upload private chats, manuscript, personal images, secrets or credentials.

## Continuation: GAME-WEB-CONTINUE-PACK-003 r1 (NOT_RUN)

This branch now also contains a self-contained offline audit delivery module, future
synthetic acceptance cases, and a strict reference JSON Schema. See
[offline-manifest-review-delivery.md](offline-manifest-review-delivery.md) for the
workflow, exit-code contract, security/privacy rationale and limitations.

- New delivery CLI: `python tools/package_manifest_delivery_candidate.py --archive ./source.zip --deliver ./reports/new-audit.zip`
- Atomic publication: temporary file in destination parent, fsync, hard-link
  into a **new** destination, cleanup; never overwrite a destination.
- Audit ZIP contents: `manifest-review.json`, `diagnostics.txt`, `README.txt`.
  The original game/source members are not included.
- Duplicate and unsafe-path issues retain their former keys and now optionally
  include reason rules, related conflicting paths and zero-based entry indexes.
- SHA256 of input ZIP, before/after verification, is recorded when stable;
  an ordinary changed or unreadable source is reported as a failure.
- JSON Schema: `schemas/package-manifest-review-report.schema.json`.
- Future cases: `tests/test_package_manifest_delivery_candidate.py`.

**Status NOT_RUN:** The continuation only adds and updates source/tests/docs.
No source code, tests, CLI, or actual archive was executed; previous PR #11
verification is not being represented as proof for these changes.
