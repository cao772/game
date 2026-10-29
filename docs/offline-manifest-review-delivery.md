# GAME-WEB-CONTINUE-PACK-003 r1 | Offline manifest audit bundle

**Status: NOT_RUN.** The author requested development only. No project Python, CLI, tests, CI jobs, or example archives were executed in this round. No passing result is claimed.

## Scope and provenance

This is a continuation on [Draft PR #11](https://github.com/cao772/game/pull/11), stacked on [Draft PR #4](https://github.com/cao772/game/pull/4). The original packager code and the game runtime, shared APIs, Canon and manuscript are outside this task and unmodified.

| File | Purpose |
|---|---|
| tools/package_manifest_check_candidate.py | Existing independent read-only verifier; extended structured Issue diagnostics (rule, related_path, index) without removing the existing code/path/detail fields |
| tools/package_manifest_delivery_candidate.py | Independent offline verification, report generation, deterministic ZIP bundling, atomic no-overwrite publication |
| schemas/package-manifest-review-report.schema.json | Draft 2020-12 JSON Schema reference for the audit report |
| tests/test_package_manifest_check_candidate.py | Original acceptance cases retained |
| tests/test_package_manifest_delivery_candidate.py | Additional future acceptance cases; never run in this task |

## Future commands (NOT executed)

    python tools/package_manifest_check_candidate.py --archive ./artifacts/source.zip
    python tools/package_manifest_check_candidate.py --archive ./artifacts/source.zip --json
    python tools/package_manifest_delivery_candidate.py --archive ./artifacts/source.zip --deliver ./reports/manifest-review.zip

    python -m unittest discover -s tests -p test_package_manifest_check_candidate.py -v
    python -m unittest discover -s tests -p test_package_manifest_delivery_candidate.py -v

The destination parent must exist. The destination .zip must NOT already exist and the parent directory chain must contain no symlinks/reparse points. The delivery ZIP is NOT a playable Godot package and contains NO original source members.

## Versioned report format

The single offline review ZIP contains exactly three files in fixed order:

1. manifest-review.json — UTF-8, final newline, sorted JSON keys, 2-space indentation; schema_version GAME-WEB-CONTINUE-PACK-003-report-v1.
2. diagnostics.txt — UTF-8 human-readable summary; untrusted diagnostic paths/details JSON-escaped.
3. README.txt — UTF-8 limitations and instructions.

ZIP metadata is deterministic: ZIP_STORED, fixed 1980-01-01 timestamp and regular-file permissions. Neither runtime clock nor a random report identifier is embedded.

The report schema requires:

- validation_status PASS/FAIL (run-time artifact status; not project development state)
- release_approved always false; evidence_scope offline_zip_internal_consistency_only
- source archive basename, archive byte length and SHA256 (or null when not safely available)
- expected manifest marker GAME-WEB-PACK-001-r2 and GitHub PR linkage
- checked_files, manifest_files, total_diagnostics, counts by category
- diagnostics with ordinal ID, severity, category, code, path, optional index, stable rule, related_path, detail and suggested remediation
- explicit limitations separating integrity from provenance, security, privacy and license approval.

This schema is a documentation contract, not a runtime JSON Schema validation dependency. Standard-library-only implementation is preserved.

## Design tradeoffs and rationale

**Single ZIP versus multiple reports.** A single audit ZIP can be transported offline without needing multiple output files to appear atomically. It contains both a machine-readable report and a human-readable interpretation but no game content. The report file format intentionally distinguishes the manifest checker from the original packager.

**Atomic no-overwrite strategy.** Validate a new output path before reading the archive. Write a temporary ZIP in the output parent directory, flush and fsync, then publish via os.link(temp, destination). The hard-link operation fails if the target exists and creates the final name only when the ZIP is complete. A finally block cleans up the temporary pathname on both success and failure. There is NO os.replace, overwrite, direct-copy or hard-link fallback. If the target filesystem cannot create hard links, delivery fails (CLI exit 2) rather than weakening the no-overwrite guarantee. An existing target, even a broken symlink, is never replaced.

**Evidence after failed verification.** A malformed or inconsistent source ZIP still gets a complete FAIL audit bundle if the output path is valid. This preserves diagnostic evidence; CLI exit code 1 denotes failed validation with successful report delivery. Exit 0 denotes candidate validation PASS and successful delivery. Exit 2 denotes a destination or publication failure and never claims delivery.

**Reproducibility and source mutation.** The source ZIP is fingerprinted with streaming SHA256 before and after calling the existing checker, retaining a stable digest and byte length only if both reads match. This catches ordinary concurrent modifications; it is not a guarantee against a malicious filesystem adversary. Three passes can be costly, but no performance measurements have been conducted. Two deliveries from the same report object should be byte-identical; compatibility across Python versions is pending.

**Structured duplicate/path diagnostics.** Existing code/path/detail remain intact, preserving the former checker API. Optional rule, related_path and zero-based index enrich duplicate ZIP and duplicate manifest diagnostics. Exact duplicate and Unicode NFC/casefold collision are distinguished. Unsafe paths carry reason rules (parent/empty component, Windows device name, backslash or absolute path, excluded directory, sensitive filename, non-whitelisted extension, control characters). Remediation text and category are stable report-layer mappings, not Canon semantics.

**Privacy.** The output report intentionally includes the source archive filename and relative ZIP member paths to support review; those names may be sensitive. No source payload is included, and local filesystem error strings are suppressed from portable ARCHIVE_ERROR diagnostics. NEVER commit actual audit reports from private source projects to this public PR without a separate privacy review.

**Limited trust.** The ZIP is compared only against its own manifest. Changes to both the source data and matching SHA256 cannot be detected as unauthorized; original source directory omissions, digital signatures, licenses, hidden secrets in permitted text, Godot runtime behavior, performance and release approval are out of scope.

## Future acceptance cases (all NOT_RUN)

| ID | Input/condition | Expected |
|---|---|---|
| A01 | Synthetic valid source ZIP, Chinese scene path | Report PASS, correct source SHA256 and counts |
| A02 | Repeated delivery of one report to two fresh filenames | Byte-identical ZIPs |
| A03 | Open audit ZIP | Exactly three audit files, fixed timestamps, no source members |
| A04 | Existing output filename | Reject; original bytes unchanged; no temp residue |
| A05 | Existing output symlink, if OS permits creation | Reject without following; otherwise explicit SKIP |
| A06 | Output parent symlink, if OS permits | Reject; otherwise explicit SKIP |
| A07 | Missing parent / .. / wrong extension | Reject before publishing |
| A08 | Simulated os.link failure | No output and temporary file removed |
| A09 | ZIP casefold collision | DUPLICATE_ZIP_MEMBER, related path and index |
| A10 | Duplicate manifest row | DUPLICATE_MANIFEST_PATH, exact duplicate rule and index |
| A11 | ZIP parent traversal member | UNSAFE_PATH, explicit traversal rule; no extraction |
| A12 | Missing entry plus incorrect SHA256 | Preserve and count both findings |
| A13 | Input ZIP missing | FAIL report with null SHA256; no local absolute-path error text |
| A14 | Simulated changed digest across fingerprint passes | ARCHIVE_CHANGED and FAIL |
| A15 | Repeat CLI delivery to same destination | Initial 0, second 2, destination unchanged |
| A16 | Source integrity check fails but publication succeeds | Exit 1 with FAIL audit ZIP |
| A17 | Existing PR #11 JSON issue fields | code, path, detail maintained |
| A18 | Real integration with PR #4 ZIP | Codex future verification; NOT_RUN |
| A19 | Python 3.12/3.14 Windows 8.3 aliases, junctions | Codex future verification; NOT_RUN |
| A20 | CRC tamper, hostile concurrent changes, network filesystem | Expanded security review; NOT_RUN |
| A21 | Draft 2020-12 schema validation with an independent validator | Future optional QA; NOT_RUN |

The existing PR #11 tests remain in place. All added acceptance cases are source only, not results.

## Documented limitations

- This is not a security sandbox, signature/provenance system, privacy or license audit, or Godot executable build.
- Source SHA256 is evidence of bytes seen at validation time, not an authenticated identity.
- True adversarial TOCTOU races are not fully prevented by ordinary before/after checks.
- Output publication requires a filesystem that supports hard links; Windows junction, UNC, non-NTFS and Python-version behavior remain unverified.
- Invalid archive paths or the very archive/member names may disclose sensitive names in reports; generated reports must remain offline/private unless reviewed.
- The current **development and test status remains NOT_RUN**; no CI result or successful execution is claimed.

No main changes, no edits to PR #4 packager files, shared game interfaces, manuscripts, Canon, or private assets.
