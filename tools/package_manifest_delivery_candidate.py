#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""GAME-WEB-CONTINUE-PACK-003 r1: offline evidence delivery candidate.

Reads the PR #11 manifest checker, writes one deterministic audit ZIP
containing a machine-readable report and a human-readable diagnostic summary.
Does NOT include, extract, execute, overwrite or upload original game files.
Python 3.12+ standard library only. Development status: NOT_RUN.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import stat
import sys
import tempfile
import zipfile
from collections import Counter
from pathlib import Path
from typing import Any

try:
    from tools.package_manifest_check_candidate import (
        BLOCK_SIZE, FIXED_DATE, FORMAT, MAX_TOTAL_BYTES, Issue, Result,
        _safe_archive_path, check_archive,
    )
except ModuleNotFoundError:
    # Direct invocation from tools/, without installing a package.
    from package_manifest_check_candidate import (
        BLOCK_SIZE, FIXED_DATE, FORMAT, MAX_TOTAL_BYTES, Issue, Result,
        _safe_archive_path, check_archive,
    )


REPORT_SCHEMA = "GAME-WEB-CONTINUE-PACK-003-report-v1"
REPORT_FILES = (
    "manifest-review.json",
    "diagnostics.txt",
    "README.txt",
)
MAX_ARCHIVE_BYTES = MAX_TOTAL_BYTES + 128 * 1024 * 1024
TEMP_PREFIX = ".game-manifest-review-"

CATEGORY: dict[str, str] = {
    "ARCHIVE_ERROR": "archive",
    "MANIFEST_COUNT": "manifest",
    "MANIFEST_SCHEMA": "manifest",
    "INVALID_MANIFEST": "manifest",
    "FORMAT_MISMATCH": "manifest",
    "MANIFEST_RECORD": "manifest",
    "INVALID_SIZE": "manifest",
    "INVALID_SHA256": "manifest",
    "UNSAFE_PATH": "path_safety",
    "UNSAFE_MANIFEST_PATH": "path_safety",
    "DUPLICATE_ZIP_MEMBER": "duplicates",
    "DUPLICATE_MANIFEST_PATH": "duplicates",
    "MEMBER_MISSING": "membership",
    "MEMBER_UNLISTED": "membership",
    "MISSING_ENTRY": "membership",
    "HASH_MISMATCH": "integrity",
    "SIZE_MISMATCH": "integrity",
    "MEMBER_READ_ERROR": "integrity",
    "MEMBER_METADATA": "archive_structure",
    "MEMBER_ORDER": "archive_structure",
    "MANIFEST_ORDER": "archive_structure",
    "TOO_MANY_MEMBERS": "limits",
    "TOTAL_SIZE_LIMIT": "limits",
    "MANIFEST_TOO_LARGE": "limits",
    "TOO_MANY_RECORDS": "limits",
    "SIZE_LIMIT": "limits",
    "ARCHIVE_FINGERPRINT_ERROR": "integrity",
    "ARCHIVE_CHANGED": "integrity",
}

REMEDIATION: dict[str, str] = {
    "ARCHIVE_ERROR": "Inspect the local input path and ZIP integrity without extracting it.",
    "MANIFEST_COUNT": "Provide exactly one root manifest.json.",
    "INVALID_MANIFEST": "Regenerate valid UTF-8 JSON without duplicate object keys.",
    "MANIFEST_SCHEMA": "Use the documented strict manifest object structure.",
    "FORMAT_MISMATCH": "Use an archive made by the matching PR #4 r2 candidate.",
    "MANIFEST_RECORD": "Use exactly path, size and sha256 in each record.",
    "INVALID_SIZE": "Provide a nonnegative integer byte size (not bool).",
    "INVALID_SHA256": "Provide a lowercase, 64-character SHA256 hex digest.",
    "UNSAFE_PATH": "Remove unsafe ZIP member; rebuild from a trusted source root.",
    "UNSAFE_MANIFEST_PATH": "Remove unsafe manifest path; rebuild with the source packager.",
    "DUPLICATE_ZIP_MEMBER": "Remove case/Unicode-colliding ZIP entries and regenerate the manifest.",
    "DUPLICATE_MANIFEST_PATH": "Ensure each normalized manifest member appears exactly once.",
    "MEMBER_MISSING": "Restore the missing member or regenerate the manifest.",
    "MEMBER_UNLISTED": "Remove unexpected member or rebuild a complete manifest.",
    "MISSING_ENTRY": "Include root project.godot and at least one .gd or .tscn.",
    "HASH_MISMATCH": "Rebuild from verified source; do not silently rewrite the digest.",
    "SIZE_MISMATCH": "Rebuild; ensure recorded byte size matches member contents.",
    "MEMBER_READ_ERROR": "Treat the archive as corrupt; recreate it from safe input.",
    "MEMBER_METADATA": "Reject symlink/special, compressed or non-deterministic entries.",
    "MEMBER_ORDER": "Sort source ZIP members and append manifest.json last.",
    "MANIFEST_ORDER": "Sort manifest rows by source-relative POSIX path.",
    "ARCHIVE_FINGERPRINT_ERROR": "Use a stable readable local ZIP as input.",
    "ARCHIVE_CHANGED": "Stop concurrent modification and retry from a stable copy.",
}


class DeliveryError(Exception):
    """Output path, atomic publication, or delivery contract failed."""


def _regular_and_unchanged(first: os.stat_result, second: os.stat_result) -> bool:
    return (
        stat.S_ISREG(first.st_mode)
        and stat.S_ISREG(second.st_mode)
        and first.st_dev == second.st_dev
        and first.st_ino == second.st_ino
        and first.st_size == second.st_size
        and first.st_mtime_ns == second.st_mtime_ns
    )


def _fingerprint(raw: str | Path) -> dict[str, Any]:
    """Read-only bounded SHA256 of input ZIP; no network or extraction.

    Rechecking both before and after check_archive detects ordinary source
    mutation, but is not a full malicious-TOCTOU security guarantee.
    """
    path = _safe_archive_path(raw)
    first = os.stat(path, follow_symlinks=False)
    if first.st_size > MAX_ARCHIVE_BYTES:
        raise ValueError("archive file exceeds candidate 2 GiB + 128 MiB cap")
    flags = os.O_RDONLY | getattr(os, "O_BINARY", 0)
    flags |= getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(path, flags)
    try:
        opened = os.fstat(fd)
        if not _regular_and_unchanged(first, opened):
            raise ValueError("archive changed before hashing")
        sha256 = hashlib.sha256()
        length = 0
        with os.fdopen(fd, "rb") as reader:
            fd = -1
            while True:
                chunk = reader.read(BLOCK_SIZE)
                if not chunk:
                    break
                length += len(chunk)
                if length > MAX_ARCHIVE_BYTES:
                    raise ValueError("archive exceeds candidate bound while reading")
                sha256.update(chunk)
            final_fd = os.fstat(reader.fileno())
            if not _regular_and_unchanged(opened, final_fd):
                raise ValueError("archive changed during hashing")
        final_path = os.stat(path, follow_symlinks=False)
        if not _regular_and_unchanged(first, final_path) or length != first.st_size:
            raise ValueError("archive changed after hashing")
        return {"name": path.name, "size_bytes": length, "sha256": sha256.hexdigest()}
    finally:
        if fd >= 0:
            os.close(fd)


def _fingerprint_optional(raw: str | Path) -> tuple[dict | None, str | None]:
    try:
        return _fingerprint(raw), None
    except (OSError, ValueError, RuntimeError) as exc:
        return None, f"{type(exc).__name__}: {exc}"


def _supplement(issues: list[Issue], code: str, detail: str) -> None:
    issues.append(Issue(code, "", detail, rule=code))


def _fingerprint_changed(left: dict | None, right: dict | None) -> bool:
    return left is not None and right is not None and (
        left["sha256"] != right["sha256"]
        or left["size_bytes"] != right["size_bytes"]
    )


def build_report(archive_path: str | Path) -> dict[str, Any]:
    """Produce a portable review report; never publish input paths by default.

    Three read-only passes (fingerprint/check/fingerprint) give the report
    an input-byte digest and flag ordinary modifications while checking.
    Report data remains untrusted unless its input provenance is verified.
    """
    first, first_error = _fingerprint_optional(archive_path)
    checked: Result = check_archive(archive_path)
    second, second_error = _fingerprint_optional(archive_path)

    issues = list(checked.issues)
    if first_error or second_error:
        _supplement(
            issues, "ARCHIVE_FINGERPRINT_ERROR",
            "input could not be fingerprinted consistently; no stable archive digest",
        )
    elif _fingerprint_changed(first, second):
        _supplement(
            issues, "ARCHIVE_CHANGED",
            "input SHA256 or size changed across validation passes",
        )

    issues.sort(key=lambda item: (
        item.code, item.path, item.detail, item.index if item.index is not None else -1,
    ))
    diagnostics: list[dict[str, Any]] = []
    for index, item in enumerate(issues, 1):
        category = CATEGORY.get(item.code, "other")
        diagnostics.append({
            "id": f"D{index:04d}",
            "severity": "ERROR",
            "category": category,
            "code": item.code,
            "path": item.path,
            "index": item.index,
            "rule": item.rule,
            "related_path": item.related_path,
            "detail": item.detail,
            "remediation": REMEDIATION.get(
                item.code,
                "Inspect this diagnostic and rebuild from trusted source.",
            ),
        })

    counts = Counter(d["category"] for d in diagnostics)
    stable_fingerprint = (
        first if first is not None and second is not None
        and not _fingerprint_changed(first, second) and not second_error else None
    )
    # A basename is included only for navigation; neither original game bytes
    # nor absolute local paths are packaged in a report.
    archive_name = Path(archive_path).name
    return {
        "schema_version": REPORT_SCHEMA,
        "validation_status": "PASS" if not diagnostics else "FAIL",
        "release_approved": False,
        "evidence_scope": "offline_zip_internal_consistency_only",
        "source": {
            "archive_filename": archive_name,
            "archive_size_bytes": (
                stable_fingerprint["size_bytes"] if stable_fingerprint else None
            ),
            "archive_sha256": (
                stable_fingerprint["sha256"] if stable_fingerprint else None
            ),
            "sha256_algorithm": "sha256",
        },
        "checker": {
            "source_pr": "cao772/game#11",
            "packager_pr": "cao772/game#4",
            "expected_manifest_format": FORMAT,
        },
        "counts": {
            "checked_files": checked.checked_files,
            "manifest_files": checked.manifest_files,
            "total_diagnostics": len(diagnostics),
            "by_category": dict(sorted(counts.items())),
        },
        "diagnostics": diagnostics,
        "limitations": [
            "Untrusted archive and manifest self-consistency only",
            "No omitted-source-file detection or origin signatures",
            "No privacy, license, Canon, Godot execution or release approval",
        ],
    }


def serialize_report(report: dict[str, Any]) -> bytes:
    return (
        json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2)
        + "\n"
    ).encode("utf-8")


def render_diagnostics(report: dict[str, Any]) -> bytes:
    """Escaped user-controlled values: no terminal escape injection."""
    lines = [
        f"GAME-WEB-CONTINUE-PACK-003 | {REPORT_SCHEMA}",
        f"Validation: {report['validation_status']}",
        "Release approved: NO",
        f"Archive: {json.dumps(report['source']['archive_filename'], ensure_ascii=True)}",
        f"Archive SHA256: {report['source']['archive_sha256'] or 'UNAVAILABLE'}",
        f"Files checked: {report['counts']['checked_files']}",
        f"Manifest rows: {report['counts']['manifest_files']}",
        f"Diagnostics: {report['counts']['total_diagnostics']}",
        "",
    ]
    for item in report["diagnostics"]:
        lines.extend([
            f"{item['id']} {item['severity']} {item['code']} [{item['category']}]",
            "  path: " + json.dumps(item["path"], ensure_ascii=True),
            "  related_path: " + json.dumps(item["related_path"], ensure_ascii=True),
            "  index: " + json.dumps(item["index"]),
            "  rule: " + json.dumps(item["rule"], ensure_ascii=True),
            "  detail: " + json.dumps(item["detail"], ensure_ascii=True),
            f"  action: {item['remediation']}",
        ])
    lines += [
        "",
        "This is NOT approval for release, privacy, licensing or Canon.",
        "The bundle contains no original ZIP member bytes.",
        "",
    ]
    return "\n".join(lines).encode("utf-8")


README = (
    "GAME-WEB-CONTINUE-PACK-003 r1: independent OFFLINE audit candidate\n"
    "manifest-review.json: schema-versioned JSON diagnostics, counts and source digest.\n"
    "diagnostics.txt: escaped human-readable copy of the findings.\n"
    "README.txt: this notice.\n"
    "NO source archive payload or extracted Godot files are included.\n"
    "No signatures or trusted provenance are supplied.\n"
    "PASS only means internal manifest/ZIP consistency under candidate rules.\n"
    "NOT a game-release, licensing, privacy, security or Canon approval.\n"
).encode("utf-8")


def _zip_info(name: str) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, FIXED_DATE)
    info.compress_type = zipfile.ZIP_STORED
    info.create_system = 3
    info.external_attr = 0o100600 << 16
    info.flag_bits |= 0x800
    return info


def _validate_target(raw_output: str | Path) -> Path:
    """Return a canonical-parent target without following links/reparse points."""
    supplied = Path(raw_output).expanduser()
    if ".." in supplied.parts:
        raise DeliveryError("output traversal segment '..' is forbidden")
    if supplied.name in ("", ".", ".."):
        raise DeliveryError("a new output filename is required")
    if supplied.suffix.casefold() != ".zip":
        raise DeliveryError("offline audit output must be a .zip file")

    candidate = supplied.absolute()
    parent = candidate.parent
    reparse = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)
    for item in (*reversed(parent.parents), parent):
        try:
            meta = os.lstat(item)
        except OSError as exc:
            raise DeliveryError("output parent must exist") from exc
        if stat.S_ISLNK(meta.st_mode) or getattr(
            meta, "st_file_attributes", 0
        ) & reparse:
            raise DeliveryError("output parent contains a link or reparse point")
        if not stat.S_ISDIR(meta.st_mode):
            raise DeliveryError("output parent must contain only directories")

    # Canonical parent prevents short/long Windows path alias mismatch.
    canonical_target = parent.resolve(strict=True) / candidate.name
    if os.path.lexists(canonical_target):
        raise DeliveryError("refusing to overwrite existing output path")
    return canonical_target


def deliver_offline(report: dict[str, Any], raw_output: str | Path) -> Path:
    """Publish ONE complete report ZIP, using same-directory hardlink creation.

    No unsafe rename/replace or copy fallback: hardlink-only publication
    makes the destination appear fully written or not at all and fails if
    the destination name exists. The temporary file is always removed.
    """
    destination = _validate_target(raw_output)
    temp_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w+b", dir=destination.parent, prefix=TEMP_PREFIX,
            suffix=".tmp", delete=False,
        ) as temporary:
            temp_path = Path(temporary.name)
            with zipfile.ZipFile(
                temporary, mode="w", compression=zipfile.ZIP_STORED,
                allowZip64=False,
            ) as archive:
                archive.writestr(_zip_info(REPORT_FILES[0]), serialize_report(report))
                archive.writestr(_zip_info(REPORT_FILES[1]), render_diagnostics(report))
                archive.writestr(_zip_info(REPORT_FILES[2]), README)
            temporary.flush()
            os.fsync(temporary.fileno())

        # Atomic no-clobber (hard links must be supported by the filesystem).
        os.link(temp_path, destination)
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        raise DeliveryError(f"offline report not published: {exc}") from exc
    finally:
        if temp_path is not None:
            temp_path.unlink(missing_ok=True)
    return destination


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Offline read-only manifest inspection and no-overwrite audit ZIP"
    )
    parser.add_argument("--archive", required=True, help="existing input ZIP")
    parser.add_argument("--deliver", required=True, help="NEW local audit ZIP path")
    args = parser.parse_args(argv)
    # Fail fast before scanning input when the delivery target is unsuitable.
    try:
        target = _validate_target(args.deliver)
    except (OSError, ValueError, DeliveryError) as exc:
        print(f"DELIVERY_REJECTED: {exc}", file=sys.stderr)
        return 2

    report = build_report(args.archive)
    try:
        published = deliver_offline(report, target)
    except (OSError, ValueError, DeliveryError) as exc:
        print(f"DELIVERY_FAILED: {exc}", file=sys.stderr)
        return 2

    print(
        f"{report['validation_status']}: {report['counts']['total_diagnostics']}"
        f" diagnostics; offline report: {published}"
    )
    print("Technical candidate only; no release, privacy or license approval.")
    return 0 if report["validation_status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
