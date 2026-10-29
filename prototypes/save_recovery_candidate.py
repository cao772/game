"""Isolated opt-in save backup/recovery candidate; no automatic actions.

Single-writer filesystem use only. Not an approved shared game interface.
"""
from __future__ import annotations
import hashlib
import json
import os
import shutil
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from prototypes import save_candidate as baseline

MAX_SAVE_BYTES = 2 * 1024 * 1024
BACKUP_FORMAT = 1

class RecoveryError(ValueError):
    """Backup integrity or recovery-policy error."""

def _stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")

def _sha(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()

def _read_limited(path: Path) -> bytes:
    if path.is_symlink():
        raise RecoveryError("symbolic links are not supported")
    with path.open("rb") as stream:
        data = stream.read(MAX_SAVE_BYTES + 1)
    if len(data) > MAX_SAVE_BYTES:
        raise RecoveryError("file exceeds configured byte limit")
    return data

def _unique_pairs(items: list[tuple[str, Any]]) -> dict:
    result = {}
    for key, value in items:
        if key in result:
            raise RecoveryError("duplicate JSON object key")
        result[key] = value
    return result

def _bad_constant(value: str) -> None:
    raise RecoveryError("non-standard JSON constant: " + value)

def _strict_json(payload: bytes) -> Any:
    try:
        return json.loads(payload.decode("utf-8"),
                          object_pairs_hook=_unique_pairs,
                          parse_constant=_bad_constant)
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise RecoveryError("invalid UTF-8 or JSON document") from exc

def _valid_state(payload: bytes) -> dict:
    try:
        return baseline.validate(_strict_json(payload))
    except (baseline.SaveError, TypeError, KeyError) as exc:
        raise RecoveryError("save schema validation failed") from exc

def _checked_save(path: Path) -> tuple[bytes, dict]:
    payload = _read_limited(path)
    return payload, _valid_state(payload)

def _write_new(path: Path, payload: bytes) -> None:
    with path.open("xb") as stream:
        stream.write(payload)
        stream.flush()
        os.fsync(stream.fileno())

def _atomic_replace(path: Path, payload: bytes) -> None:
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="wb", dir=path.parent,
                                         prefix=".recovery-pending-",
                                         delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)

def _backup_root(save_path: Path, backup_dir: str | Path | None) -> Path:
    if backup_dir is not None:
        return Path(backup_dir)
    return Path(str(save_path) + ".backups")

def inspect_save(save_path: str | Path) -> dict:
    """Read only: valid, missing or corrupt; no game data disclosure."""
    try:
        payload, state = _checked_save(Path(save_path))
    except FileNotFoundError:
        return {"status": "missing"}
    except (OSError, RecoveryError) as exc:
        return {"status": "corrupt", "reason": str(exc)}
    return {"status": "valid", "sha256": _sha(payload),
            "bytes": len(payload), "free_clock": state["free_clock"],
            "mode": state["mode"], "version": state["version"]}

def create_backup(save_path: str | Path,
                  backup_dir: str | Path | None = None) -> dict:
    """Publish a validated byte-exact snapshot as a new directory."""
    source = Path(save_path)
    try:
        payload, state = _checked_save(source)
    except (OSError, RecoveryError) as exc:
        raise RecoveryError("cannot back up an invalid or unreadable save") from exc
    root = _backup_root(source, backup_dir)
    if root.is_symlink():
        raise RecoveryError("backup root cannot be a symlink")
    root.mkdir(parents=True, exist_ok=True)
    backup_id = "backup-" + _stamp() + "-" + uuid.uuid4().hex
    manifest = {
        "backup_format": BACKUP_FORMAT,
        "backup_id": backup_id,
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "payload_file": "save.json",
        "payload_sha256": _sha(payload),
        "payload_bytes": len(payload),
        "save_version": state["version"],
        "free_clock": state["free_clock"],
        "mode": state["mode"],
    }
    pending = Path(tempfile.mkdtemp(prefix=".pending-", dir=root))
    destination = root / backup_id
    try:
        _write_new(pending / "save.json", payload)
        manifest_bytes = (json.dumps(manifest, ensure_ascii=False,
                                     sort_keys=True, indent=2) + "\n").encode("utf-8")
        _write_new(pending / "manifest.json", manifest_bytes)
        os.rename(pending, destination)
    finally:
        if pending.exists():
            shutil.rmtree(pending)
    return {"status": "created", "path": str(destination), **manifest}

def _verified_backup(snapshot_dir: str | Path) -> tuple[bytes, dict, dict]:
    folder = Path(snapshot_dir)
    if folder.is_symlink() or not folder.is_dir():
        raise RecoveryError("backup directory missing or symlinked")
    try:
        manifest = _strict_json(_read_limited(folder / "manifest.json"))
        if not isinstance(manifest, dict):
            raise RecoveryError("manifest must be an object")
        if type(manifest.get("backup_format")) is not int:
            raise RecoveryError("invalid backup format")
        if manifest["backup_format"] != BACKUP_FORMAT:
            raise RecoveryError("unsupported backup format")
        if manifest.get("backup_id") != folder.name:
            raise RecoveryError("backup identifier mismatch")
        if manifest.get("payload_file") != "save.json":
            raise RecoveryError("unsupported backup payload path")
        if type(manifest.get("payload_bytes")) is not int:
            raise RecoveryError("invalid manifest size")
        payload = _read_limited(folder / "save.json")
        if len(payload) != manifest["payload_bytes"]:
            raise RecoveryError("backup payload size mismatch")
        if _sha(payload) != manifest.get("payload_sha256"):
            raise RecoveryError("backup checksum mismatch")
        state = _valid_state(payload)
        for field, expected in (("save_version", state["version"]),
                                ("mode", state["mode"]),
                                ("free_clock", state["free_clock"])):
            if type(manifest.get(field)) is not type(expected):
                raise RecoveryError("invalid manifest field type: " + field)
            if manifest[field] != expected:
                raise RecoveryError("manifest and payload disagree: " + field)
        if not isinstance(manifest.get("created_utc"), str):
            raise RecoveryError("missing backup timestamp")
        return payload, manifest, state
    except (OSError, KeyError, TypeError, ValueError) as exc:
        raise RecoveryError("backup verification failed: " + str(exc)) from exc

def inspect_backup(snapshot_dir: str | Path) -> dict:
    """Read only: verify manifest, checksum and baseline save schema."""
    try:
        _, metadata, _ = _verified_backup(snapshot_dir)
    except RecoveryError as exc:
        return {"status": "corrupt", "reason": str(exc)}
    return {"status": "valid", **metadata}

def list_backups(save_path: str | Path,
                 backup_dir: str | Path | None = None) -> list[dict]:
    root = _backup_root(Path(save_path), backup_dir)
    if root.is_symlink():
        raise RecoveryError("backup root cannot be a symlink")
    if not root.exists():
        return []
    if not root.is_dir():
        raise RecoveryError("backup root is not a directory")
    return [{"path": str(entry), **inspect_backup(entry)}
            for entry in sorted(root.glob("backup-*"), reverse=True)]

def _quarantine(path: Path, existing_bytes: bytes) -> Path:
    """Preserve exact corrupt bytes before a primary-file replacement."""
    destination = path.with_name(
        "." + path.name + ".corrupt-" + _stamp() +
        "-" + uuid.uuid4().hex + ".bin")
    _write_new(destination, existing_bytes)
    return destination

def restore_backup(snapshot_dir: str | Path, save_path: str | Path, *,
                   replace_valid: bool = False, allow_rollback: bool = False,
                   backup_dir: str | Path | None = None) -> dict:
    """Explicit restore, never silently replace valid or newer progress."""
    payload, metadata, state = _verified_backup(snapshot_dir)
    target = Path(save_path)
    if target.is_symlink():
        raise RecoveryError("destination cannot be a symlink")
    if not target.parent.is_dir():
        raise RecoveryError("destination parent does not exist")
    current = inspect_save(target)
    if current["status"] == "valid":
        if current["sha256"] == metadata["payload_sha256"]:
            return {"status": "unchanged", "backup_id": metadata["backup_id"]}
        if not replace_valid:
            raise RecoveryError("valid destination requires replace_valid=True")
        if state["free_clock"] < current["free_clock"] and not allow_rollback:
            raise RecoveryError("rollback requires allow_rollback=True")
        prior = create_backup(target, backup_dir)
        protected = prior["path"]
        quarantine = None
    elif current["status"] == "corrupt":
        try:
            original = _read_limited(target)
        except OSError as exc:
            raise RecoveryError("cannot preserve corrupt destination") from exc
        quarantine = _quarantine(target, original)
        protected = None
    elif current["status"] == "missing":
        quarantine = None
        protected = None
    else:
        raise RecoveryError("unrecognized destination inspection status")
    _atomic_replace(target, payload)
    return {"status": "restored", "backup_id": metadata["backup_id"],
            "free_clock": state["free_clock"],
            "previous_backup_path": protected,
            "quarantine_path": str(quarantine) if quarantine else None}
