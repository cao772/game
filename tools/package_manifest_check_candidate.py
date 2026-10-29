#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""GAME-WEB-MODULE-PACK-001 r1: read-only ZIP manifest checker.

Independent technical candidate for the format produced by
GAME-WEB-PACK-001 r2 (PR #4). Python 3.12+, standard library only.
No extraction, execution, networking, or changes to existing archives.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import sys
import unicodedata
import zipfile
from dataclasses import asdict, dataclass
from pathlib import Path, PurePosixPath

FORMAT = "GAME-WEB-PACK-001-r2"
FIXED_DATE = (1980, 1, 1, 0, 0, 0)
ALLOWED_SUFFIXES = frozenset({".gd", ".tscn", ".tres", ".md", ".json"})
BLOCKED_DIRS = frozenset({
    ".git", ".godot", ".env", ".venv", "venv", "env", "ops",
    "cookie", "cookies", "secrets", "credentials", "__pycache__",
    "node_modules", "dist", "build", "evidence", "screenshots",
    "raw_chat", "raw_chats", "chat_logs", "chat_exports",
    "transcripts", "原始聊天", "原始对话", "聊天记录", "聊天导出",
    "对话记录", "证据", "证据图片",
})
BLOCKED_FILES = frozenset({
    ".env", "env", "environment", "cookie", "cookies",
    "secrets", "credentials",
})
SENSITIVE_MARKERS = (
    "cookie", "credential", "secret", "raw_chat", "chat_export",
    "chat_log", "conversation_export", "transcript", "原始聊天",
    "原始对话", "聊天记录", "聊天导出", "对话记录", "会话导出",
)
MAX_MEMBERS = 10000
MAX_MANIFEST_BYTES = 4 * 1024 * 1024
MAX_MEMBER_BYTES = 512 * 1024 * 1024
MAX_TOTAL_BYTES = 2 * 1024 * 1024 * 1024
BLOCK_SIZE = 1024 * 1024
HEX_SHA256 = re.compile(r"^[0-9a-f]{64}$")


@dataclass(frozen=True)
class Issue:
    code: str
    path: str
    detail: str
    rule: str | None = None
    related_path: str | None = None
    index: int | None = None


@dataclass
class Result:
    archive: str
    checked_files: int
    manifest_files: int
    issues: list[Issue]

    @property
    def ok(self) -> bool:
        return not self.issues

    def as_dict(self) -> dict:
        return {
            "status": "PASS" if self.ok else "FAIL",
            "format_expected": FORMAT,
            "archive": self.archive,
            "checked_files": self.checked_files,
            "manifest_files": self.manifest_files,
            "issues": [asdict(issue) for issue in self.issues],
            "release_approved": False,
        }


def _issue(
    items: list[Issue], code: str, path: str, detail: str,
    *, rule: str | None = None, related_path: str | None = None,
    index: int | None = None,
) -> None:
    items.append(Issue(code, path, detail, rule, related_path, index))


def _reserved_component(name: str) -> bool:
    native = getattr(os.path, "isreserved", None)
    if native is not None and native(name):
        return True
    if name.endswith((" ", ".")):
        return True
    if any(c in '<>:"/\\|?*' or ord(c) < 32 for c in name):
        return True
    stem = name.split(".", 1)[0].rstrip(" ").casefold()
    if stem in {"con", "prn", "aux", "nul", "conin$", "conout$"}:
        return True
    return (
        len(stem) == 4
        and stem[:3] in {"com", "lpt"}
        and stem[3] in "123456789¹²³"
    )


def _excluded_basename(name: str) -> bool:
    lower = name.casefold()
    return (
        lower in BLOCKED_FILES
        or lower.startswith(".env")
        or lower.endswith((".env", ".env.json", ".local.json"))
        or any(token in lower for token in SENSITIVE_MARKERS)
    )


def _path_error(name: object, *, allow_manifest: bool = False) -> str | None:
    """Validate archive member names lexically, on every host platform."""
    if not isinstance(name, str) or not name:
        return "path must be a nonempty string"
    if name.startswith("/") or "\\" in name:
        return "absolute paths and backslashes are forbidden"
    parts = name.split("/")
    if any(part in ("", ".", "..") for part in parts):
        return "empty, dot or parent path component"
    if any(_reserved_component(part) for part in parts):
        return "Windows-reserved or unsafe path component"
    if any(ord(c) == 127 for c in name):
        return "control character in path"
    if PurePosixPath(name).as_posix() != name:
        return "path is not normalized POSIX"
    if any(part.casefold() in BLOCKED_DIRS for part in parts[:-1]):
        return "excluded directory"
    if allow_manifest and name == "manifest.json":
        return None
    if name == "manifest.json":
        return "manifest cannot list itself"
    if _excluded_basename(parts[-1]):
        return "excluded sensitive filename"
    if name == "project.godot":
        return None
    if PurePosixPath(name).suffix not in ALLOWED_SUFFIXES:
        return "non-whitelisted extension or non-root project.godot"
    return None


def _path_rule(problem: str) -> str:
    """Stable diagnostic reason identifier for unsafe member names."""
    if "parent path component" in problem:
        return "PATH_TRAVERSAL_OR_EMPTY_SEGMENT"
    if "absolute paths" in problem:
        return "PATH_ABSOLUTE_OR_BACKSLASH"
    if "reserved" in problem:
        return "PATH_WINDOWS_RESERVED"
    if "control" in problem:
        return "PATH_CONTROL_CHARACTER"
    if "excluded directory" in problem:
        return "PATH_EXCLUDED_DIRECTORY"
    if "sensitive filename" in problem:
        return "PATH_SENSITIVE_FILENAME"
    if "whitelisted" in problem:
        return "PATH_EXTENSION_NOT_ALLOWED"
    if "itself" in problem:
        return "PATH_MANIFEST_SELF_REFERENCE"
    if "normalized" in problem:
        return "PATH_NOT_NORMALIZED"
    return "PATH_INVALID"


def _collision_key(name: str) -> str:
    return unicodedata.normalize("NFC", name).casefold()


def _reject_duplicate_keys(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON property: {key}")
        result[key] = value
    return result


def _reject_constant(value: str) -> None:
    raise ValueError(f"non-JSON numeric constant: {value}")


def _safe_archive_path(raw: str | Path) -> Path:
    candidate = Path(raw).expanduser()
    if ".." in candidate.parts:
        raise ValueError("archive path contains '..'")
    candidate = candidate.absolute()
    for ancestor in (*reversed(candidate.parents), candidate):
        meta = os.lstat(ancestor)
        reparse_flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)
        if stat.S_ISLNK(meta.st_mode):
            raise ValueError(f"symbolic link in archive path: {ancestor}")
        if getattr(meta, "st_file_attributes", 0) & reparse_flag:
            raise ValueError(f"reparse point in archive path: {ancestor}")
    if not stat.S_ISREG(os.stat(candidate).st_mode):
        raise ValueError("archive must be a regular file")
    return candidate


def _member_metadata_error(info: zipfile.ZipInfo) -> str | None:
    if info.is_dir():
        return "directory members are not produced by PR #4"
    if info.flag_bits & 0x1:
        return "encrypted ZIP member"
    if info.compress_type != zipfile.ZIP_STORED:
        return "only ZIP_STORED is supported"
    if info.date_time != FIXED_DATE:
        return "timestamp differs from deterministic packager"
    if info.file_size > MAX_MEMBER_BYTES and info.filename != "manifest.json":
        return "member size exceeds verification bound"
    if info.create_system == 3:
        mode = info.external_attr >> 16
        kind = stat.S_IFMT(mode)
        if kind not in (0, stat.S_IFREG):
            return "symlink, directory or special-file ZIP metadata"
    return None


def _load_manifest(
    archive: zipfile.ZipFile, info: zipfile.ZipInfo, issues: list[Issue]
) -> dict | None:
    if info.file_size > MAX_MANIFEST_BYTES:
        _issue(issues, "MANIFEST_TOO_LARGE", "manifest.json", "manifest exceeds 4 MiB")
        return None
    try:
        with archive.open(info, "r") as handle:
            payload = handle.read(MAX_MANIFEST_BYTES + 1)
        if len(payload) > MAX_MANIFEST_BYTES:
            raise ValueError("manifest bytes exceed limit")
        decoded = payload.decode("utf-8", errors="strict")
        if decoded.startswith("\ufeff"):
            raise ValueError("UTF-8 BOM not allowed")
        value = json.loads(
            decoded,
            object_pairs_hook=_reject_duplicate_keys,
            parse_constant=_reject_constant,
        )
    except (ValueError, UnicodeError, RuntimeError, EOFError,
            OSError, zipfile.BadZipFile) as exc:
        _issue(issues, "INVALID_MANIFEST", "manifest.json", str(exc))
        return None
    if not isinstance(value, dict) or set(value) != {"format", "files"}:
        _issue(issues, "MANIFEST_SCHEMA", "manifest.json",
               "expected object with exactly 'format' and 'files'")
        return None
    if value["format"] != FORMAT:
        _issue(issues, "FORMAT_MISMATCH", "manifest.json",
               f"expected {FORMAT}")
    if not isinstance(value["files"], list):
        _issue(issues, "MANIFEST_SCHEMA", "manifest.json", "'files' must be an array")
        return None
    return value


def check_archive(raw_archive: str | Path) -> Result:
    """Read and validate a PR #4-format ZIP. Never extract or mutate it."""
    issues: list[Issue] = []
    result = Result(str(raw_archive), 0, 0, issues)

    try:
        archive_path = _safe_archive_path(raw_archive)
        result.archive = str(archive_path)
        with zipfile.ZipFile(archive_path, mode="r", allowZip64=True) as archive:
            infos = archive.infolist()
            if len(infos) > MAX_MEMBERS:
                _issue(issues, "TOO_MANY_MEMBERS", "", f"more than {MAX_MEMBERS} ZIP entries")
                return _finalize(result)

            total_size = sum(i.file_size for i in infos)
            if total_size > MAX_TOTAL_BYTES:
                _issue(issues, "TOTAL_SIZE_LIMIT", "", "declared uncompressed size exceeds 2 GiB")
                return _finalize(result)

            names = [info.filename for info in infos]
            first_by_name: dict[str, zipfile.ZipInfo] = {}
            seen_keys: dict[str, str] = {}

            for member_index, info in enumerate(infos):
                name = info.filename
                err = _path_error(name, allow_manifest=True)
                if err is not None:
                    _issue(issues, "UNSAFE_PATH", name, err,
                           rule=_path_rule(err), index=member_index)
                metadata_error = _member_metadata_error(info)
                if metadata_error:
                    _issue(issues, "MEMBER_METADATA", name, metadata_error)
                key = _collision_key(name)
                if key in seen_keys:
                    _issue(issues, "DUPLICATE_ZIP_MEMBER", name,
                           f"collides with {seen_keys[key]}",
                           rule=("EXACT_DUPLICATE" if name == seen_keys[key]
                                 else "UNICODE_CASEFOLD_NFC_COLLISION"),
                           related_path=seen_keys[key], index=member_index)
                else:
                    seen_keys[key] = name
                first_by_name.setdefault(name, info)

            if names != sorted(names[:-1]) + ["manifest.json"]:
                _issue(issues, "MEMBER_ORDER", "",
                       "ZIP must contain sorted source paths followed by manifest.json")

            manifest_entries = [i for i in infos if i.filename == "manifest.json"]
            if len(manifest_entries) != 1:
                _issue(issues, "MANIFEST_COUNT", "manifest.json",
                       f"expected exactly one manifest; found {len(manifest_entries)}")
                return _finalize(result)

            manifest_info = manifest_entries[0]
            if manifest_info.file_size > MAX_MANIFEST_BYTES:
                _issue(issues, "MANIFEST_TOO_LARGE", "manifest.json", "manifest exceeds 4 MiB")
                return _finalize(result)
            if _member_metadata_error(manifest_info) is not None:
                return _finalize(result)

            manifest = _load_manifest(archive, manifest_info, issues)
            if manifest is None:
                return _finalize(result)

            raw_records = manifest["files"]
            result.manifest_files = len(raw_records)
            if len(raw_records) > MAX_MEMBERS - 1:
                _issue(issues, "TOO_MANY_RECORDS", "manifest.json", "too many manifest rows")
                return _finalize(result)

            records: dict[str, dict] = {}
            record_keys: dict[str, str] = {}
            listed_order: list[str] = []

            for index, record in enumerate(raw_records):
                context = f"manifest.json#files[{index}]"
                if not isinstance(record, dict) or set(record) != {
                    "path", "size", "sha256"
                }:
                    _issue(issues, "MANIFEST_RECORD", context,
                           "record must have exactly path, size and sha256")
                    continue
                path = record["path"]
                path_error = _path_error(path)
                if path_error:
                    _issue(issues, "UNSAFE_MANIFEST_PATH", context, path_error,
                           rule=_path_rule(path_error), index=index)
                    continue
                listed_order.append(path)
                key = _collision_key(path)
                if key in record_keys:
                    _issue(issues, "DUPLICATE_MANIFEST_PATH", path,
                           f"collides with {record_keys[key]}",
                           rule=("EXACT_DUPLICATE" if path == record_keys[key]
                                 else "UNICODE_CASEFOLD_NFC_COLLISION"),
                           related_path=record_keys[key], index=index)
                else:
                    record_keys[key] = path
                if type(record["size"]) is not int or record["size"] < 0:
                    _issue(issues, "INVALID_SIZE", path, "size must be a nonnegative integer")
                    continue
                if record["size"] > MAX_MEMBER_BYTES:
                    _issue(issues, "SIZE_LIMIT", path, "declared size exceeds 512 MiB")
                    continue
                if not isinstance(record["sha256"], str) or not HEX_SHA256.fullmatch(
                    record["sha256"]
                ):
                    _issue(issues, "INVALID_SHA256", path,
                           "expected 64 lowercase hexadecimal characters")
                    continue
                records.setdefault(path, record)

            if listed_order != sorted(listed_order):
                _issue(issues, "MANIFEST_ORDER", "manifest.json",
                       "manifest file records must be sorted by POSIX path")

            if "project.godot" not in records:
                _issue(issues, "MISSING_ENTRY", "project.godot",
                       "root Godot project entry missing from manifest")
            if not any(PurePosixPath(p).suffix in (".gd", ".tscn") for p in records):
                _issue(issues, "MISSING_ENTRY", "",
                       "at least one .gd or .tscn manifest member required")

            actual = set(first_by_name) - {"manifest.json"}
            expected = set(records)

            for missing in sorted(expected - actual):
                _issue(issues, "MEMBER_MISSING", missing,
                       "listed in manifest but absent from ZIP")
            for extra in sorted(actual - expected):
                _issue(issues, "MEMBER_UNLISTED", extra,
                       "present in ZIP but absent from manifest")

            for path in sorted(expected & actual):
                info = first_by_name[path]
                if _path_error(path) is not None or _member_metadata_error(info):
                    continue
                record = records[path]
                digest = hashlib.sha256()
                count = 0
                try:
                    with archive.open(info, mode="r") as stream:
                        while True:
                            chunk = stream.read(BLOCK_SIZE)
                            if not chunk:
                                break
                            count += len(chunk)
                            if count > MAX_MEMBER_BYTES:
                                raise ValueError("read exceeded member size bound")
                            digest.update(chunk)
                except (ValueError, RuntimeError, EOFError, OSError,
                        zipfile.BadZipFile) as exc:
                    _issue(issues, "MEMBER_READ_ERROR", path, str(exc))
                    continue

                result.checked_files += 1
                if count != record["size"] or count != info.file_size:
                    _issue(issues, "SIZE_MISMATCH", path,
                           f"manifest={record['size']}, ZIP={info.file_size}, read={count}")
                if digest.hexdigest() != record["sha256"]:
                    _issue(issues, "HASH_MISMATCH", path, "SHA256 digest differs")

    except (ValueError, OSError, RuntimeError, EOFError, zipfile.BadZipFile,
            zipfile.LargeZipFile) as exc:
        _issue(issues, "ARCHIVE_ERROR", "", str(exc))

    return _finalize(result)


def _finalize(result: Result) -> Result:
    result.issues.sort(key=lambda item: (item.code, item.path, item.detail))
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Read-only integrity checker for PR #4 source ZIP manifests"
    )
    parser.add_argument("--archive", required=True, help="existing source ZIP")
    parser.add_argument("--json", action="store_true", help="emit JSON report to stdout")
    args = parser.parse_args(argv)
    result = check_archive(args.archive)
    if args.json:
        print(json.dumps(result.as_dict(), ensure_ascii=False, indent=2))
    else:
        print(
            f"{'PASS' if result.ok else 'FAIL'}: "
            f"{result.checked_files}/{result.manifest_files} checked; "
            f"{len(result.issues)} issue(s)"
        )
        for item in result.issues:
            print(f"  {item.code}: {item.path}: {item.detail}")
        print("Technical integrity only; not a release or license approval.")
    return 0 if result.ok else 1


if __name__ == "__main__":
    sys.exit(main())
