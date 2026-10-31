extends RefCounted
## GAME-WEB-SHELL-006 r1. Private, in-memory public-fixture bridge.
## No automatic event, real target relation, save, network or scene writes.
## This is a PROPOSED mapping, never canon, runtime unverified (NOT_RUN).

const MAP_PATH := "res://play_006/synthetic_target_event_map.json"
const TARGETS_PATH := "res://play_005/vendor/region/synthetic_targets.json"
const SCHEMA := "shell-synthetic-target-event-map-v1"
const MAX_BYTES := 16384
const MAX_TARGETS := 16
const MAX_REASON := 160
const ENTRY_FIELDS := ["target_id", "event_id", "reason"]

var _ready: bool = false
var _lookup: Dictionary = {}
var _error: String = "尚未读取占位映射"


func _fail(message: String) -> Dictionary:
    return {
        "ok": false, "reason": message,
        "candidate_only": true, "approval": "NOT_APPROVED",
        "checker_status": "NOT_RUN"
    }


func _unavailable(message: String) -> Dictionary:
    _ready = false
    _lookup.clear()
    _error = message
    return _fail(message)


func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return _fail("缺少固定公开候选文件：" + path.get_file())
    var content: PackedByteArray = FileAccess.get_file_as_bytes(path)
    if content.is_empty() or content.size() > MAX_BYTES:
        return _fail("候选数据为空或超过大小限制：" + path.get_file())
    var decoded: String = content.get_string_from_utf8()
    if decoded.to_utf8_buffer() != content:
        return _fail("候选数据编码不是合法 UTF-8")
    var parser := JSON.new()
    if parser.parse(decoded) != OK or typeof(parser.data) != TYPE_DICTIONARY:
        return _fail("候选 JSON 解析失败：" + path.get_file())
    return {"ok": true, "data": (parser.data as Dictionary).duplicate(true)}


func _id(value: Variant, prefix: String) -> bool:
    if typeof(value) != TYPE_STRING:
        return false
    var text_id: String = value
    if text_id.length() <= prefix.length() or text_id.length() > 64:
        return false
    if not text_id.begins_with(prefix):
        return false
    return text_id.is_valid_identifier()


# Pure validation: author may use this function in future negative tests,
# but it does not set a registry or attach to a live game component.
func validate_document(
    map_document: Variant, target_document: Variant, event_model: Object
) -> Dictionary:
    if event_model == null or not is_instance_valid(event_model) \
            or not event_model.has_method("has_event"):
        return _fail("事件预览模型缺少私有 has_event 校验入口")
    if typeof(map_document) != TYPE_DICTIONARY \
            or typeof(target_document) != TYPE_DICTIONARY:
        return _fail("映射或区域占位目录结构无效")
    var definition: Dictionary = map_document
    if definition.size() != 6 \
            or definition.get("schema_version") != SCHEMA \
            or typeof(definition.get("candidate_only")) != TYPE_BOOL \
            or definition["candidate_only"] != true \
            or definition.get("approval") != "NOT_APPROVED" \
            or definition.get("status") != "PROPOSAL_NOT_CANON" \
            or typeof(definition.get("description")) != TYPE_STRING \
            or typeof(definition.get("entries")) != TYPE_ARRAY:
        return _fail("不是明确标记未批准的占位映射版本")
    var catalog: Dictionary = target_document
    if catalog.get("schema_version") != "synthetic-targets-v1" \
            or typeof(catalog.get("targets")) != TYPE_ARRAY:
        return _fail("PR #23 公开目标目录版本或类型不匹配")
    var known: Dictionary = {}
    var targets: Array = catalog["targets"]
    if targets.is_empty() or targets.size() > MAX_TARGETS:
        return _fail("目标目录数量无效")
    for target in targets:
        if typeof(target) != TYPE_DICTIONARY:
            return _fail("公开目标结构无效")
        var candidate_id: Variant = target.get("id")
        if not _id(candidate_id, "placeholder_") or known.has(candidate_id):
            return _fail("公开目标 ID 无效或重复")
        known[candidate_id] = true

    var proposed: Dictionary = {}
    var entries: Array = definition["entries"]
    if entries.is_empty() or entries.size() > MAX_TARGETS:
        return _fail("映射条目为空或超出占位上限")
    for entry in entries:
        if typeof(entry) != TYPE_DICTIONARY:
            return _fail("映射条目不是对象")
        var item: Dictionary = entry
        if item.size() != ENTRY_FIELDS.size():
            return _fail("映射条目存在遗漏或额外字段")
        for field_name in ENTRY_FIELDS:
            if not item.has(field_name):
                return _fail("映射条目缺少 " + field_name)
        var target_id: Variant = item["target_id"]
        var event_id: Variant = item["event_id"]
        var reason: Variant = item["reason"]
        if not _id(target_id, "placeholder_") or not known.has(target_id):
            return _fail("映射包含区域目录之外的占位目标")
        if typeof(event_id) != TYPE_STRING \
                or not str(event_id).begins_with("EVENT_") \
                or not bool(event_model.call("has_event", event_id)):
            return _fail("映射引用不存在的公开占位事件")
        if typeof(reason) != TYPE_STRING \
                or reason.strip_edges().is_empty() \
                or reason.length() > MAX_REASON:
            return _fail("映射原因必须是有长度限制的说明")
        if proposed.has(target_id):
            return _fail("同一占位目标存在重复映射")
        proposed[target_id] = {
            "event_id": event_id,
            "reason": reason
        }
    return {"ok": true, "entries": proposed, "candidate_only": true}


# Explicit preparation reads only TWO fixed public res:// files.
# Called when the user requests region→event, never on background polling.
func prepare(event_model: Object) -> Dictionary:
    _ready = false
    _lookup.clear()
    _error = "占位映射未验证"
    var map_read: Dictionary = _read_json(MAP_PATH)
    if not bool(map_read.get("ok", false)):
        return _unavailable(str(map_read.get("reason", "映射文件不可用")))
    var targets_read: Dictionary = _read_json(TARGETS_PATH)
    if not bool(targets_read.get("ok", false)):
        return _unavailable(str(targets_read.get("reason", "区域目录不可用")))
    var checked: Dictionary = validate_document(
        map_read["data"], targets_read["data"], event_model
    )
    if not bool(checked.get("ok", false)):
        return _unavailable(str(checked.get("reason", "占位映射校验失败")))
    _lookup = (checked["entries"] as Dictionary).duplicate(true)
    _ready = true
    _error = ""
    return {
        "ok": true, "count": _lookup.size(), "candidate_only": true,
        "approval": "NOT_APPROVED", "checker_status": "NOT_RUN"
    }


# A snapshot may only be received from the explicitly mounted PR #23
# synthetic scene. This structural check alone is not a trust boundary.
func resolve(snapshot: Variant) -> Dictionary:
    if not _ready:
        return _fail("映射尚未就绪：" + _error)
    if typeof(snapshot) != TYPE_DICTIONARY:
        return _fail("场景快照不是 Dictionary")
    var data: Dictionary = snapshot
    if typeof(data.get("loaded")) != TYPE_BOOL or data["loaded"] != true:
        return _fail("公开占位区域未载入")
    if typeof(data.get("confirm_count")) != TYPE_INT \
            or int(data["confirm_count"]) < 1:
        return _fail("尚未确认公开占位目标")
    var raw_id: Variant = data.get("last_confirmed", null)
    if typeof(raw_id) != TYPE_STRING and typeof(raw_id) != TYPE_STRING_NAME:
        return _fail("缺少有效的上次确认目标 ID")
    var target_id: String = str(raw_id)
    if not _lookup.has(target_id):
        return _fail("目标没有明确的占位映射，禁止默认跳转事件")
    var entry: Dictionary = _lookup[target_id]
    return {
        "ok": true, "target_id": target_id, "event_id": entry["event_id"],
        "mapping_reason": entry["reason"],
        "candidate_only": true, "approval": "NOT_APPROVED",
        "checker_status": "NOT_RUN", "no_runtime_effects": true
    }


func status() -> Dictionary:
    return {
        "ready": _ready, "count": _lookup.size(), "error": _error,
        "candidate_only": true, "approval": "NOT_APPROVED",
        "checker_status": "NOT_RUN"
    }


func clear() -> void:
    _ready = false
    _lookup.clear()
    _error = "已清除本次会话占位映射"
