"""Local planning and send reservation. Never controls a browser or sends a message."""
import argparse
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import os
import tempfile
from urllib.parse import urlparse

SHANGHAI = timezone(timedelta(hours=8))
BUSY = {"dispatch_pending", "running"}
WAITING = {"waiting_input", "waiting_decision"}


def read_json(path, default=None):
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except FileNotFoundError:
        if default is not None:
            return default
        raise


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(value, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def instant(value):
    dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if dt.tzinfo is None:
        raise ValueError("timezone required")
    return dt


def fresh(value, now, seconds=300):
    try:
        return 0 <= (now - instant(value)).total_seconds() <= seconds
    except (TypeError, ValueError, AttributeError):
        return False


def conversation(url):
    parsed = urlparse(url or "")
    match = re.search(r"/c/([0-9a-f-]{36})/?$", parsed.path, re.I)
    if parsed.scheme != "https" or parsed.hostname != "chatgpt.com" or not match:
        return None
    return match[1].lower()


def send_key(task):
    return hashlib.sha256(json.dumps(
        [task["id"], task["version"], task["input_sha256"]],
        separators=(",", ":")).encode()).hexdigest()


def numeric(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def resource_gate(resource, now):
    if not fresh(resource.get("utc"), now):
        return "resource_stale"
    values = [resource.get(k) for k in ("cpuAverage", "freeMemoryMinGiB", "diskFreeGiB")]
    if not all(numeric(v) and v >= 0 for v in values):
        return "resource_unknown"
    cpu, ram, disk = values
    if cpu > 100:
        return "resource_unknown"
    if ram < 4 or disk < 10:
        return "resource_stop"
    if ram < 8 or disk < 20 or cpu >= 70:
        return "resource_hold"
    return None


def paths(task):
    values = task.get("write_paths", [])
    if not isinstance(values, list) or not values:
        return None
    output = []
    for item in values:
        if not isinstance(item, str) or not item.strip():
            return None
        path = PurePosixPath(item.replace("\\", "/").lower())
        if path.is_absolute() or ".." in path.parts or ":" in item or str(path) == ".":
            return None
        output.append(path)
    return output


def overlaps(left, right):
    return any(a == b or a in b.parents or b in a.parents for a in left for b in right)


def plan(ledger, resource, browser, now):
    if now.tzinfo is None:
        raise ValueError("timezone required")
    tasks = ledger["tasks"]
    identifiers = [t["id"] for t in tasks]
    if len(identifiers) != len(set(identifiers)):
        raise ValueError("duplicate task IDs: reconcile ledger before dispatch")
    target = ledger["target_active"]
    ceiling = ledger["trial_ceiling"]
    if type(target) is not int or type(ceiling) is not int or not 1 <= target <= ceiling:
        raise ValueError("invalid capacity")
    current = {}
    by_id = {t["id"]: t for t in tasks}
    for task in tasks:  # Append order is task chronology, not a timestamp guess.
        key = conversation(task.get("url"))
        if key:
            current[key] = task
    blockers = []
    if now.astimezone(SHANGHAI).weekday() < 5:
        blockers.append("outside_weekend")
    gate = resource_gate(resource, now)
    if gate:
        blockers.append(gate)
    if browser.get("available") is not True or not fresh(browser.get("checked_at"), now):
        blockers.append("browser_unavailable_or_stale")
    if browser.get("quota_ok") is not True:
        blockers.append("quota_unverified")
    backlog = [t for t in current.values() if t.get("status") in {"review", "recovery_pending"}
               and t.get("technical_status") != "passed"]
    if len(backlog) >= ledger.get("max_review_backlog", 3):
        blockers.append("review_backlog")
    busy = [t for t in tasks if t.get("status") in BUSY]
    slots_left = max(0, target - len(busy))
    reserved_paths, reserved_chats = [], set()
    ready, blocked = [], []
    observations = browser.get("chats", {})
    for task in tasks:
        if task.get("status") != "queued":
            continue
        reasons = list(blockers)
        if task.get("owner_gate"):
            reasons.append("owner_decision_required")
        key = conversation(task.get("url"))
        obs = observations.get(key, {})
        if not key:
            reasons.append("durable_url_required")
        if not fresh(obs.get("observed_at"), now, 120):
            reasons.append("chat_observation_stale")
        if (obs.get("state") != "idle" or obs.get("project_verified") is not True
                or obs.get("model_high_verified") is not True):
            reasons.append("chat_not_ready")
        if obs.get("draft") != "" or any(t.get("draft") for t in tasks
                                          if key and conversation(t.get("url")) == key):
            reasons.append("draft_protected")
        if task.get("inputs_ready") is not True or not re.fullmatch(
                r"[0-9a-f]{64}", task.get("input_sha256", "")) or not task.get("version"):
            reasons.append("inputs_unverified")
        for dep in task.get("depends_on", []):
            if by_id.get(dep, {}).get("technical_status") != "passed":
                reasons.append("dependency_not_passed:" + dep)
        related = [t for t in tasks if t["id"] != task["id"] and key
                   and conversation(t.get("url")) == key]
        if (key in reserved_chats or any(t.get("status") in BUSY or
                t.get("owner_gate", t.get("status") in WAITING) or
                (t.get("status") in {"review", "recovery_pending"} and t.get("technical_status") != "passed")
                for t in related)):
            reasons.append("chat_busy_or_owner_gate")
        if task.get("sent_verified") or task.get("dispatch_key"):
            reasons.append("send_already_recorded")
        writable = paths(task)
        if not writable:
            reasons.append("explicit_write_paths_required")
        elif any(paths(t) is None or overlaps(writable, paths(t)) for t in busy):
            reasons.append("write_conflict_or_unknown")
        elif overlaps(writable, reserved_paths):
            reasons.append("queued_write_conflict")
        if slots_left == 0:
            reasons.append("capacity_full")
        if reasons:
            blocked.append({"id": task["id"], "reasons": sorted(set(reasons))})
        else:
            ready.append(task["id"])
            reserved_paths.extend(writable)
            reserved_chats.add(key)
            slots_left -= 1
    return {
        "generated_at": now.isoformat(), "time_gate": "work" if now.astimezone(SHANGHAI).weekday() >= 5 else "rest",
        "target_chats": target, "registered_chats": len(current), "historical_task_count": len(tasks),
        "currently_generating": (sum(o.get("state") == "generating" for o in observations.values())
            if browser.get("available") is True and len(observations) == len(current)
            and set(observations) == set(current) and fresh(browser.get("checked_at"), now)
            and all(fresh(o.get("observed_at"), now, 120) for o in observations.values()) else None),
        "global_blockers": blockers, "review_backlog": [t["id"] for t in backlog],
        "ready": ready, "blocked": blocked,
        "slots": [{"conversation_id": k, "id": t["id"], "role": t.get("role", ""),
                   "status": t["status"], "technical_status": t.get("technical_status", "unknown"),
                   "archive_state": t.get("archive_state", "unknown"),
                   "next_action": t.get("next_action", "inspect_existing_reply"),
                   "validation": t.get("validation", t.get("result", ""))} for k, t in current.items()],
        "note": "Planning only. Recheck time, page, draft and messages immediately before sending."
    }


@contextmanager
def ledger_lock(path):
    """Nonblocking OS lock for local ledger mutations; released even after a crash."""
    with path.open("a+b") as stream:
        stream.seek(0, 2)
        if stream.tell() == 0:
            stream.write(b"0")
            stream.flush()
        stream.seek(0)
        if os.name == "nt":
            import msvcrt
            msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        try:
            yield
        finally:
            if os.name == "nt":
                stream.seek(0)
                msvcrt.locking(stream.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                fcntl.flock(stream, fcntl.LOCK_UN)


def reserve(root, task_id):
    with ledger_lock(root / "dispatch.lock"):
        ledger = read_json(root / "tasks.json")
        report = plan(ledger, read_json(root / "logs/latest-resource.json", {}),
                      read_json(root / "browser-state.json", {}), datetime.now(timezone.utc))
        if task_id not in report["ready"]:
            raise ValueError("task not ready; run planner and inspect blockers")
        task = next(t for t in ledger["tasks"] if t["id"] == task_id)
        task.update(status="dispatch_pending", dispatch_key=send_key(task),
                    reserved_at=datetime.now(timezone.utc).isoformat())
        atomic_json(root / "tasks.json", ledger)
        return {"reserved": task_id, "dispatch_key": task["dispatch_key"], "sent": False}


def write_status(root, report):
    unknown = report["currently_generating"]
    lines = ["# 游戏调度状态（由 control.py 生成）", "",
             "更新时间：" + report["generated_at"],
             f"目标 {report['target_chats']}；登记聊天 {report['registered_chats']}；历史任务 {report['historical_task_count']}。",
             "当前生成数：" + ("未知，需网页重新核验。" if unknown is None else str(unknown)),
             "派发阻塞：" + ", ".join(report["global_blockers"]), "",
             "| 当前任务 | 流程状态 | 技术验收 | 归档 | 下一步 |", "| --- | --- | --- | --- | --- |"]
    for s in report["slots"]:
        lines.append("| " + " | ".join(str(s[k]).replace("|", "/").replace("\n", " ")
                     for k in ("id", "status", "technical_status", "archive_state", "next_action")) + " |")
    lines.extend(["", "本页不代表10项同时生成或性能全部通过。任务与证据以 tasks.json 和 sync-state.json 为准。",
                  "真实网页负责研发；本地工具只做计划、去重与记录。未发送草稿不自动发送。", ""])
    (root / "STATUS.md").write_text("\n".join(lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--reserve", metavar="TASK_ID")
    args = parser.parse_args()
    if args.reserve:
        print(json.dumps(reserve(args.root, args.reserve), ensure_ascii=False))
        return
    report = plan(read_json(args.root / "tasks.json"), read_json(args.root / "logs/latest-resource.json", {}),
                  read_json(args.root / "browser-state.json", {}), datetime.now(timezone.utc))
    if args.write:
        atomic_json(args.root / "logs/latest-plan.json", report)
        write_status(args.root, report)
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
