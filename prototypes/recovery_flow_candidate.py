"""GAME-WEB-CONTINUE-ENGINE-003: independent preview + non-overwrite recovery.

NOT_RUN. Opt-in candidate only. No original save modification or automatic actions.
Requires the save and recovery candidates already present in Draft PR #8.
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
from prototypes import save_recovery_candidate as prior

RECOVERY_FORMAT = 1


class RecoveryFlowError(ValueError):
    """Refused preview, stale plan, damaged output, or failed recovery."""


class DuplicateKeyError(ValueError):
    pass


class NonFiniteNumberError(ValueError):
    pass


def _utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")


def _digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _absolute(path: str | Path) -> Path:
    # abspath normalizes relative paths, but does not follow symlinks.
    return Path(os.path.abspath(os.fspath(path)))


def _pairs(items: list[tuple[str, Any]]) -> dict:
    output = {}
    for key, value in items:
        if key in output:
            raise DuplicateKeyError("duplicate JSON key")
        output[key] = value
    return output


def _constant(value: str) -> None:
    raise NonFiniteNumberError("non-finite JSON number: " + value)


def _decode(payload: bytes) -> Any:
    return json.loads(payload.decode("utf-8"),
                      object_pairs_hook=_pairs, parse_constant=_constant)


def _fault(status: str, category: str, *, detail: str = "") -> dict:
    result = {"status": status, "category": category}
    if detail:
        result["detail"] = detail
    return result


def classify_save(save_path: str | Path) -> dict:
    """Read-only diagnostic; schema authority remains baseline.validate."""
    path = _absolute(save_path)
    if path.is_symlink():
        return _fault("unsafe", "symlink")
    try:
        raw = prior._read_limited(path)
    except FileNotFoundError:
        return _fault("missing", "not_found")
    except PermissionError:
        return _fault("inaccessible", "permission_denied")
    except IsADirectoryError:
        return _fault("unsafe", "not_regular_file")
    except prior.RecoveryError:
        return _fault("corrupt", "oversized_or_unsafe")
    except OSError:
        return _fault("inaccessible", "read_error")

    signature = {"sha256": _digest(raw), "bytes": len(raw)}
    try:
        data = _decode(raw)
    except UnicodeError:
        return {**_fault("corrupt", "invalid_utf8"), **signature}
    except DuplicateKeyError:
        return {**_fault("corrupt", "duplicate_json_key"), **signature}
    except NonFiniteNumberError:
        return {**_fault("corrupt", "nonfinite_json_number"), **signature}
    except json.JSONDecodeError:
        return {**_fault("corrupt", "invalid_json"), **signature}

    if not isinstance(data, dict):
        return {**_fault("corrupt", "schema_invalid"), **signature}
    version = data.get("version")
    if type(version) is not int:
        return {**_fault("corrupt", "version_type_invalid"), **signature}
    if version != baseline.VERSION:
        return {**_fault("corrupt", "unsupported_version"), **signature}
    mode = data.get("mode")
    if type(mode) is not str or mode not in ("free", "history"):
        return {**_fault("corrupt", "unknown_mode"), **signature}

    if not baseline.clock_ok(data.get("free_clock")):
        return {**_fault("corrupt", "invalid_clock"), **signature}
    history = data.get("history")
    if isinstance(history, dict):
        clocks = history.get("chapter_clocks")
        if isinstance(clocks, dict):
            if any(not baseline.clock_ok(tick) for tick in clocks.values()):
                return {**_fault("corrupt", "invalid_clock"), **signature}
        entry = history.get("entry_free_clock")
        if entry is not None and not baseline.clock_ok(entry):
            return {**_fault("corrupt", "invalid_clock"), **signature}
    try:
        baseline.validate(data)
    except (baseline.SaveError, KeyError, TypeError):
        return {**_fault("corrupt", "schema_invalid"), **signature}
    return {"status": "valid", "category": "none",
            **signature, "version": version, "mode": mode,
            "free_clock": data["free_clock"]}


def classify_backup(snapshot_dir: str | Path) -> dict:
    """Read-only best-effort damage classification; restore still revalidates."""
    folder = _absolute(snapshot_dir)
    if folder.is_symlink():
        return _fault("unsafe", "symlink")
    if not folder.is_dir():
        return _fault("missing", "snapshot_directory_missing")
    for filename, category in (("manifest.json", "manifest_missing"),
                               ("save.json", "payload_missing")):
        path = folder / filename
        if path.is_symlink():
            return _fault("unsafe", "symlink")
        if not path.is_file():
            return _fault("corrupt", category)
    try:
        _, metadata, _ = prior._verified_backup(folder)
        manifest_bytes = prior._read_limited(folder / "manifest.json")
    except PermissionError:
        return _fault("inaccessible", "permission_denied")
    except (prior.RecoveryError, OSError) as exc:
        message = str(exc)
        if "checksum mismatch" in message:
            category = "payload_checksum_mismatch"
        elif "size mismatch" in message:
            category = "payload_size_mismatch"
        elif "manifest" in message or "backup format" in message:
            category = "manifest_invalid"
        elif "schema" in message:
            category = "payload_schema_invalid"
        else:
            category = "backup_validation_failed"
        return _fault("corrupt", category)
    return {"status": "valid", "category": "none",
            "backup_id": metadata["backup_id"],
            "payload_sha256": metadata["payload_sha256"],
            "manifest_sha256": _digest(manifest_bytes),
            "free_clock": metadata["free_clock"],
            "save_version": metadata["save_version"],
            "mode": metadata["mode"]}


def _root_status(root: Path) -> dict:
    if root.is_symlink():
        return _fault("unsafe", "output_root_symlink")
    if not root.exists():
        return _fault("missing", "output_root_missing")
    if not root.is_dir():
        return _fault("unsafe", "output_root_not_directory")
    return _fault("ready", "none")


def _fingerprint(fields: dict) -> str:
    canonical = json.dumps(fields, sort_keys=True, ensure_ascii=False,
                           separators=(",", ":")).encode("utf-8")
    return _digest(canonical)


def preview_non_overwrite(snapshot_dir: str | Path, original_save: str | Path,
                          output_root: str | Path) -> dict:
    """Read-only preview. Does not create directories or change any files."""
    source = _absolute(snapshot_dir)
    original = _absolute(original_save)
    root = _absolute(output_root)
    backup = classify_backup(source)
    current = classify_save(original)
    destination = _root_status(root)
    permitted_current = current["status"] in ("valid", "corrupt", "missing")
    ready = (backup["status"] == "valid" and permitted_current
             and destination["status"] == "ready")
    messages = []
    if backup["status"] != "valid":
        messages.append("source_backup_not_valid")
    if not permitted_current:
        messages.append("original_not_safely_observable")
    if destination["status"] != "ready":
        messages.append("output_directory_not_ready")
    if (backup["status"] == "valid" and current["status"] == "valid"
            and backup["free_clock"] < current["free_clock"]):
        messages.append("candidate_older_than_original_no_original_write")
    identity = {
        "snapshot_dir": str(source),
        "original_save": str(original),
        "output_root": str(root),
        "backup": backup,
        "original": current,
        "root": destination,
        "ready": ready,
        "warnings": messages,
        "operation": "new_directory_only",
    }
    return {**identity, "preview_sha256": _fingerprint(identity)}


def _assert_fresh(preview: dict) -> dict:
    try:
        actual = preview_non_overwrite(preview["snapshot_dir"],
                                       preview["original_save"],
                                       preview["output_root"])
    except (KeyError, TypeError) as exc:
        raise RecoveryFlowError("malformed preview") from exc
    if actual != preview:
        raise RecoveryFlowError("stale or modified preview; regenerate")
    if not actual["ready"]:
        raise RecoveryFlowError("preview is not ready: " +
                                ",".join(actual["warnings"]))
    return actual


def _write_exclusive(path: Path, data: bytes) -> None:
    with path.open("xb") as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())


def recover_non_overwrite(preview: dict) -> dict:
    """Publish a distinct recovery directory; never replace the original save."""
    plan = _assert_fresh(preview)
    snapshot = Path(plan["snapshot_dir"])
    root = Path(plan["output_root"])
    try:
        payload, metadata, _ = prior._verified_backup(snapshot)
        if _digest(payload) != plan["backup"]["payload_sha256"]:
            raise RecoveryFlowError("backup changed after preview")
        manifest_raw = prior._read_limited(snapshot / "manifest.json")
        if _digest(manifest_raw) != plan["backup"]["manifest_sha256"]:
            raise RecoveryFlowError("manifest changed after preview")
    except (prior.RecoveryError, OSError) as exc:
        raise RecoveryFlowError("backup no longer readable/valid") from exc

    recovery_id = "recovery-" + _utc() + "-" + uuid.uuid4().hex
    published = root / recovery_id
    pending = None
    try:
        pending = Path(tempfile.mkdtemp(prefix=".recovering-", dir=root))
        receipt = {
            "recovery_format": RECOVERY_FORMAT,
            "recovery_id": recovery_id,
            "created_utc": datetime.now(timezone.utc).isoformat(),
            "backup_id": metadata["backup_id"],
            "payload_sha256": _digest(payload),
            "payload_bytes": len(payload),
            "preview_sha256": plan["preview_sha256"],
            "original_status": plan["original"]["status"],
            "original_sha256": plan["original"].get("sha256"),
            "original_clock": plan["original"].get("free_clock"),
            "restored_clock": metadata["free_clock"],
            "original_modified": False,
        }
        _write_exclusive(pending / "save.json", payload)
        data = (json.dumps(receipt, ensure_ascii=False, sort_keys=True,
                           indent=2) + "\n").encode("utf-8")
        _write_exclusive(pending / "receipt.json", data)
        # Catch ordinary changes to the original before publishing. Not a lock.
        _assert_fresh(preview)
        if published.exists() or published.is_symlink():
            raise RecoveryFlowError("recovery destination collision")
        os.rename(pending, published)
        pending = None
    except OSError as exc:
        raise RecoveryFlowError("recovery filesystem operation failed") from exc
    finally:
        if pending is not None and pending.exists():
            shutil.rmtree(pending)
    return {"status": "created", "recovery_dir": str(published),
            "recovery_id": recovery_id, "preview_sha256": plan["preview_sha256"],
            "payload_sha256": _digest(payload), "original_modified": False}


def inspect_recovery(recovery_dir: str | Path) -> dict:
    """Read-only result/receipt inspection, including rolled-back directories."""
    folder = _absolute(recovery_dir)
    rolled = folder.name.startswith("rolled-back-")
    if folder.is_symlink():
        return _fault("unsafe", "symlink")
    if not folder.is_dir():
        return _fault("missing", "recovery_directory_missing")
    try:
        receipt = _decode(prior._read_limited(folder / "receipt.json"))
        if not isinstance(receipt, dict):
            raise RecoveryFlowError("receipt must be an object")
        if type(receipt.get("recovery_format")) is not int:
            raise RecoveryFlowError("receipt version invalid")
        if receipt["recovery_format"] != RECOVERY_FORMAT:
            raise RecoveryFlowError("unsupported receipt version")
        recovery_id = receipt.get("recovery_id")
        if not isinstance(recovery_id, str) or not recovery_id.startswith("recovery-"):
            raise RecoveryFlowError("recovery identifier invalid")
        if not rolled and recovery_id != folder.name:
            raise RecoveryFlowError("recovery directory does not match receipt")
        if rolled and not folder.name.startswith("rolled-back-" + recovery_id + "-"):
            raise RecoveryFlowError("rollback directory does not match receipt")
        payload = prior._read_limited(folder / "save.json")
        if len(payload) != receipt.get("payload_bytes"):
            raise RecoveryFlowError("recovery size mismatch")
        if _digest(payload) != receipt.get("payload_sha256"):
            raise RecoveryFlowError("recovery checksum mismatch")
        prior._valid_state(payload)
    except (OSError, ValueError, KeyError, TypeError,
            prior.RecoveryError) as exc:
        return _fault("corrupt", "recovery_receipt_or_payload_invalid",
                      detail=str(exc))
    return {"status": "rolled_back" if rolled else "active",
            "category": "none", "recovery_id": recovery_id,
            "sha256": _digest(payload), "bytes": len(payload),
            "original_modified": False, "path": str(folder)}


def rollback_non_overwrite(recovery_dir: str | Path) -> dict:
    """Retract intact recovered output by rename; preserve it for audit.

    Never touches the original save or deletes recovered bytes.
    """
    folder = _absolute(recovery_dir)
    inspected = inspect_recovery(folder)
    if inspected["status"] != "active":
        raise RecoveryFlowError("only intact active recovery can be rolled back")
    parent = folder.parent
    if parent.is_symlink() or not parent.is_dir():
        raise RecoveryFlowError("unsafe recovery directory parent")
    destination = parent / (
        "rolled-back-" + inspected["recovery_id"] + "-" + uuid.uuid4().hex)
    if destination.exists() or destination.is_symlink():
        raise RecoveryFlowError("rollback destination collision")
    try:
        os.rename(folder, destination)
    except OSError as exc:
        raise RecoveryFlowError("rollback filesystem operation failed") from exc
    return {"status": "rolled_back", "recovery_id": inspected["recovery_id"],
            "retained_path": str(destination), "original_modified": False}
