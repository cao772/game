extends RefCounted
## GAME-WEB-FLOW-REGION-004 r1: isolated synthetic proximity flow model.
## Pure in-memory model: no scene tree, IO, event bus, save, story or real targets.
## All coordinates/radii are trial parameters, NOT approved gameplay.
const ENTER_RADIUS: float = 1.55
const EXIT_RADIUS: float = 1.85
const AREA_X: float = 5.0
const AREA_Z: float = 4.2
const MAX_TARGETS: int = 16

var _targets: Array[Dictionary] = []
var _nearby: Array[StringName] = []
var _player: Vector2 = Vector2(0.0, 3.0)
var _selected: StringName = &""
var _dismissed: bool = false
var _confirm_count: int = 0
var _feedback: String = "请选择一个模拟目标并接近。"
var _last_confirmed: StringName = &""
var _loaded: bool = false


func load_targets(raw_records: Array) -> bool:
    # Fail closed on absent, malformed, duplicated or out-of-bounds records.
    if raw_records.is_empty() or raw_records.size() > MAX_TARGETS:
        return false
    var checked: Array[Dictionary] = []
    var used: Dictionary = {}
    for record in raw_records:
        if not record is Dictionary:
            return false
        var item: Dictionary = record
        if not (item.get("id") is String or item.get("id") is StringName):
            return false
        var id := StringName(str(item["id"]))
        if not str(id).begins_with("placeholder_"):
            return false
        if str(id).length() > 64 or used.has(id):
            return false
        if not (item.get("label") is String):
            return false
        if not (item.get("action_caption", "交互") is String):
            return false
        var label: String = item["label"]
        var caption: String = item.get("action_caption", "交互")
        if label.strip_edges().is_empty() or label.length() > 64:
            return false
        if caption.strip_edges().is_empty() or caption.length() > 40:
            return false
        if not item.has("x") or not item.has("z"):
            return false
        if not (typeof(item["x"]) in [TYPE_INT, TYPE_FLOAT]):
            return false
        if not (typeof(item["z"]) in [TYPE_INT, TYPE_FLOAT]):
            return false
        var x: float = float(item["x"])
        var z: float = float(item["z"])
        if not Vector2(x, z).is_finite():
            return false
        if absf(x) > AREA_X - 0.35 or absf(z) > AREA_Z - 0.35:
            return false
        used[id] = true
        checked.append({
            "id": id, "label": label, "action_caption": caption,
            "position": Vector2(x, z)
        })

    # Atomic commit only after every record has passed validation.
    _targets = checked
    _nearby.clear()
    _selected = &""
    _dismissed = false
    _confirm_count = 0
    _last_confirmed = &""
    _feedback = "合成目录已加载；靠近目标查看提示。"
    _loaded = true
    return true


func is_loaded() -> bool:
    return _loaded


func all_targets() -> Array[Dictionary]:
    return _targets.duplicate(true)


func player_position() -> Vector2:
    return _player


func nearby_ids() -> Array[StringName]:
    return _nearby.duplicate()


func selected_id() -> StringName:
    return _selected


func is_dismissed() -> bool:
    return _dismissed


func _entry_by_id(id: StringName) -> Dictionary:
    for target in _targets:
        if target["id"] == id:
            return target
    return {}


func move_player(next_position: Vector2) -> Dictionary:
    if not _loaded:
        return {"ok": false, "error": "Catalog unavailable"}
    if not next_position.is_finite():
        return {"ok": false, "error": "Invalid coordinate"}
    _player = Vector2(
        clampf(next_position.x, -AREA_X, AREA_X),
        clampf(next_position.y, -AREA_Z, AREA_Z)
    )

    var former: Array[StringName] = _nearby.duplicate()
    var eligible: Array[Dictionary] = []
    for target in _targets:
        var id: StringName = target["id"]
        var distance: float = _player.distance_to(target["position"])
        var radius: float = EXIT_RADIUS if former.has(id) else ENTER_RADIUS
        if distance <= radius:
            eligible.append({"id": id, "distance": distance})

    # Sorted proximity: nearest first; stable lexical ID resolves exact ties.
    eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        if absf(float(a["distance"]) - float(b["distance"])) < 0.0001:
            return str(a["id"]) < str(b["id"])
        return float(a["distance"]) < float(b["distance"])
    )

    var updated: Array[StringName] = []
    for entry in eligible:
        updated.append(entry["id"])

    var entering: Array[StringName] = []
    var leaving: Array[StringName] = []
    for id in updated:
        if not former.has(id):
            entering.append(id)
    for id in former:
        if not updated.has(id):
            leaving.append(id)

    var changed: bool = former != updated
    _nearby = updated
    if _nearby.is_empty():
        _selected = &""
        _dismissed = false
        if not former.is_empty():
            _feedback = "已离开所有合成目标；提示隐藏。"
    elif not _nearby.has(_selected):
        _selected = _nearby[0]
        if changed:
            _feedback = "进入模拟交互范围，等待确认。"
    elif changed:
        _feedback = "附近合成目标列表已更新。"

    return {
        "ok": true, "changed": changed, "entered": entering,
        "left": leaving, "nearby": updated.duplicate(),
        "selected": _selected
    }


func prompt_entries() -> Array[Dictionary]:
    var entries: Array[Dictionary] = []
    for id in _nearby:
        var target: Dictionary = _entry_by_id(id)
        if not target.is_empty():
            entries.append({
                "id": id, "label": target["label"],
                "action_caption": target["action_caption"]
            })
    return entries


func mark_selected(id: StringName) -> bool:
    if not _loaded or not _nearby.has(id):
        return false
    _selected = id
    return true


func dismiss_prompt() -> bool:
    if not _loaded or _nearby.is_empty() or _dismissed:
        return false
    _dismissed = true
    _feedback = "已手动隐藏提示；可点击重新显示，或离开再接近。"
    return true


func reopen_prompt() -> bool:
    if not _loaded or _nearby.is_empty():
        return false
    _dismissed = false
    _feedback = "已重新显示附近的合成目标。"
    return true


func confirm(id: StringName) -> Dictionary:
    if not _loaded:
        return {"ok": false, "reason": "目录未载入"}
    if _dismissed:
        return {"ok": false, "reason": "提示已隐藏"}
    if id == &"" or not _nearby.has(id) or id != _selected:
        return {"ok": false, "reason": "目标不在当前可交互列表或选择已失效"}
    # Recheck actual distance, not only a stale proximity ID.
    var target: Dictionary = _entry_by_id(id)
    if target.is_empty():
        return {"ok": false, "reason": "占位目标已不存在"}
    var distance: float = _player.distance_to(target["position"])
    if distance > EXIT_RADIUS:
        return {"ok": false, "reason": "目标已经超出退出阈值"}
    _confirm_count += 1
    _last_confirmed = id
    _feedback = "确认成功：%s（第 %d 次；仅本地反馈）" % [
        target["label"], _confirm_count
    ]
    return {
        "ok": true, "target_id": id, "feedback": _feedback,
        "confirm_count": _confirm_count
    }


func snapshot() -> Dictionary:
    return {
        "loaded": _loaded,
        "player": _player,
        "nearby_ids": _nearby.duplicate(),
        "selected_id": _selected,
        "dismissed": _dismissed,
        "confirm_count": _confirm_count,
        "last_confirmed": _last_confirmed,
        "feedback": _feedback
    }
