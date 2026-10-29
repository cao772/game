extends RefCounted
## GAME-WEB-CONTINUE-SHELL-003 r1
## Standalone, in-memory assembly state. No upstream PR code is loaded.
## Only explicit synthetic adapters can execute via this registry.
## Pending candidate references are metadata, never executable modules.

const Placeholder = preload("res://placeholder_adapter_candidate.gd")
const SLOTS := ["round", "prompt", "profile", "bindings"]
const LABELS := {
    "round": "回合候选",
    "prompt": "交互提示",
    "profile": "资料面板",
    "bindings": "输入配置"
}
const SOURCE_PRS := {"round": 6, "prompt": 10, "profile": 14, "bindings": 15}
const REQUIRES := {"round": [], "prompt": [], "profile": [], "bindings": ["round"]}
const FALLBACK_TITLE := "独立降级视图"
const MAX_TEXT := 1800

var _entries: Dictionary = {}
var _generation: int = 0


func _init() -> void:
    for slot in SLOTS:
        _entries[slot] = {
            "mode": "missing",
            "adapter": null,
            "health": "unavailable",
            "reason": "未装配本地占位模块",
            "preview": {}
        }


func _known(slot: String) -> bool:
    return SLOTS.has(slot)


func generation() -> int:
    return _generation


func _set_entry(slot: String, entry: Dictionary) -> void:
    _entries[slot] = entry
    _generation += 1


# No dynamic script loading: callers may pass only explicitly trusted,
# shell-local mock objects. Method presence is NOT a sandbox.
func mount_mock(slot: String, adapter: RefCounted) -> bool:
    if not _known(slot) or adapter == null or not is_instance_valid(adapter):
        return false
    if not adapter.has_method("preview") or not adapter.has_method("preview_action"):
        return false
    _set_entry(slot, {
        "mode": "mock",
        "adapter": adapter,
        "health": "unchecked",
        "reason": "本地模拟适配器，非上游功能",
        "preview": {}
    })
    refresh(slot)
    return true


func restore_mock(slot: String) -> bool:
    if not _known(slot):
        return false
    return mount_mock(slot, Placeholder.new(slot))


func restore_all_mocks() -> void:
    for slot in SLOTS:
        restore_mock(slot)


func remove(slot: String) -> bool:
    if not _known(slot):
        return false
    _set_entry(slot, {
        "mode": "missing",
        "adapter": null,
        "health": "unavailable",
        "reason": "模块缺失；未加载任何上游组件",
        "preview": {}
    })
    return true


func disable(slot: String) -> bool:
    if not _known(slot):
        return false
    _set_entry(slot, {
        "mode": "disabled",
        "adapter": null,
        "health": "unavailable",
        "reason": "模块已禁用；仍可打开此页面查看说明",
        "preview": {}
    })
    return true


# Stage a reference for review ONLY. In particular, bindings/PR15
# needs a proposed round/PR6 predecessor but neither is executed.
func stage_candidate(slot: String) -> bool:
    if not _known(slot):
        return false
    _set_entry(slot, {
        "mode": "pending",
        "adapter": null,
        "health": "unavailable",
        "reason": "仅登记 Draft PR #%d，未批准、未集成、NOT_RUN" % SOURCE_PRS[slot],
        "preview": {}
    })
    return true


func _effective_status(slot: String) -> String:
    if not _known(slot):
        return "unknown"
    var entry: Dictionary = _entries[slot]
    match entry["mode"]:
        "missing":
            return "missing"
        "disabled":
            return "disabled"
        "pending":
            for requirement in REQUIRES[slot]:
                var parent: Dictionary = _entries[requirement]
                if parent["mode"] != "pending":
                    return "blocked_dependency"
            return "pending_review"
        "mock":
            if entry["health"] == "valid":
                return "synthetic_ready"
            return "degraded"
    return "degraded"


func status(slot: String) -> Dictionary:
    if not _known(slot):
        return {"ok": false, "status": "unknown", "reason": "未知模块"}
    var entry: Dictionary = _entries[slot]
    var state: String = _effective_status(slot)
    var reason: String = str(entry["reason"])
    if state == "blocked_dependency":
        reason = "依赖 Draft PR #6 的候选先登记；当前仅显示阻塞说明"
    if state == "degraded":
        reason = "占位适配器响应无效；已停用此页模拟请求：" + reason
    return {
        "ok": true,
        "slot": slot,
        "label": LABELS[slot],
        "source_pr": SOURCE_PRS[slot],
        "requires": (REQUIRES[slot] as Array).duplicate(),
        "mode": str(entry["mode"]),
        "status": state,
        "reason": reason,
        "action_enabled": state == "synthetic_ready",
        "generation": _generation
    }


func snapshot() -> Array[Dictionary]:
    var items: Array[Dictionary] = []
    for slot in SLOTS:
        items.append(status(slot))
    return items


func is_mounted(slot: String) -> bool:
    return _effective_status(slot) == "synthetic_ready"


func _preview_valid(data: Variant) -> bool:
    if typeof(data) != TYPE_DICTIONARY:
        return false
    if not data.has("ok") or typeof(data["ok"]) != TYPE_BOOL or not data["ok"]:
        return false
    if not data.has("title") or not data.has("body"):
        return false
    if typeof(data["title"]) != TYPE_STRING or typeof(data["body"]) != TYPE_STRING:
        return false
    return not str(data["title"]).strip_edges().is_empty() \
        and str(data["title"]).length() <= 100 \
        and str(data["body"]).length() <= MAX_TEXT


# Refresh is explicit; no background polling or auto-discovery.
func refresh(slot: String) -> Dictionary:
    if not _known(slot):
        return status(slot)
    var entry: Dictionary = _entries[slot]
    if entry["mode"] != "mock":
        return status(slot)
    var adapter: RefCounted = entry["adapter"]
    if adapter == null or not is_instance_valid(adapter) \
            or not adapter.has_method("preview") \
            or not adapter.has_method("preview_action"):
        entry["health"] = "invalid"
        entry["reason"] = "适配器不存在或缺少方法"
        entry["preview"] = {}
    else:
        var data: Variant = adapter.call("preview")
        if _preview_valid(data):
            entry["health"] = "valid"
            entry["reason"] = "仅本地模拟，未连接上游 Draft PR"
            entry["preview"] = (data as Dictionary).duplicate(true)
        else:
            entry["health"] = "invalid"
            entry["reason"] = "preview() 格式无效或内容超限"
            entry["preview"] = {}
    _set_entry(slot, entry)
    return status(slot)


func view(slot: String) -> Dictionary:
    var info: Dictionary = status(slot)
    if not info.get("ok", false):
        return {"ok": false, "title": FALLBACK_TITLE, "body": "未知槽位", "status": "unknown"}
    var entry: Dictionary = _entries[slot]
    if info["action_enabled"]:
        var sample: Dictionary = entry["preview"]
        return {
            "ok": true,
            "title": sample["title"],
            "body": sample["body"],
            "status": info["status"]
        }
    return {
        "ok": false,
        "title": FALLBACK_TITLE + " · " + info["label"],
        "body": info["reason"] + "\n\n不会自动导入 Draft PR 或触发任何游戏操作。",
        "status": info["status"]
    }


# The only permitted request string is a clearly labelled local demonstration.
# No actual gameplay action is defined here.
func invoke_mock(slot: String, request_id: String) -> Dictionary:
    if request_id != "sample_request" or not _known(slot):
        return {"ok": false, "message": "未知的模拟请求"}
    if _effective_status(slot) != "synthetic_ready":
        return {"ok": false, "message": "模块尚未可用于本地模拟"}
    var entry: Dictionary = _entries[slot]
    var adapter: RefCounted = entry["adapter"]
    if adapter == null or not is_instance_valid(adapter):
        refresh(slot)
        return {"ok": false, "message": "模块实例失效"}
    var result: Variant = adapter.call("preview_action", request_id)
    if typeof(result) != TYPE_DICTIONARY:
        entry["health"] = "invalid"
        entry["reason"] = "模拟请求返回值不是 Dictionary"
        _set_entry(slot, entry)
        return {"ok": false, "message": "模拟请求结果无效"}
    if typeof(result.get("ok")) != TYPE_BOOL \
            or typeof(result.get("simulated")) != TYPE_BOOL \
            or result.get("simulated") != true \
            or typeof(result.get("message")) != TYPE_STRING \
            or str(result.get("message")).length() > 300:
        entry["health"] = "invalid"
        entry["reason"] = "请求结果缺少模拟标记或文本不合法"
        _set_entry(slot, entry)
        return {"ok": false, "message": "模拟请求结果无效"}
    if not result["ok"]:
        return {"ok": false, "message": str(result["message"])}
    return {"ok": true, "message": str(result["message"]), "simulated": true}
