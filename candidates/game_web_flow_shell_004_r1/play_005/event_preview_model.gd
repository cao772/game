extends RefCounted
## GAME-WEB-PLAY-SHELL-005 r1, isolated Godot interpretation of public PR #18
## JSON fixtures ONLY. This does not execute PR #18's Python 3.12 checker
## (which depends on stacked PR #9), cannot claim checker equivalence.
const SOURCES := [
    "res://play_005/fixtures/placeholder_start.json",
    "res://play_005/fixtures/placeholder_next.json",
    "res://play_005/fixtures/placeholder_end.json"
]
const START := "EVENT_START"
const IGNORE := "@ignore"
const MAX_STEPS := 20
var _catalog: Dictionary = {}
var _at: String = ""
var _trace: Array[Dictionary] = []
var _last_error: String = ""

func _failure(reason: String) -> Dictionary:
    _last_error = reason
    return {"ok": false, "reason": reason, "candidate_only": true}

func _valid_id(value: Variant) -> bool:
    return typeof(value) == TYPE_STRING and str(value).length() > 0 \
        and str(value).length() <= 64 and str(value).is_valid_identifier()

func load_fixtures() -> Dictionary:
    var staged: Dictionary = {}
    for path in SOURCES:
        if not FileAccess.file_exists(path):
            return _failure("缺少固定公开占位数据：" + path.get_file())
        var text_value := FileAccess.get_file_as_string(path)
        if text_value.to_utf8_buffer().size() > 8192:
            return _failure("占位数据超过候选大小限制")
        var raw: Variant = JSON.parse_string(text_value)
        if typeof(raw) != TYPE_DICTIONARY:
            return _failure("事件文件不是 JSON 对象")
        var event: Dictionary = raw
        if not _valid_id(event.get("event_id")):
            return _failure("事件标识无效")
        var id: String = event["event_id"]
        if staged.has(id):
            return _failure("存在重复事件标识")
        var trigger: Variant = event.get("trigger")
        if typeof(trigger) != TYPE_DICTIONARY \
                or not _valid_id(trigger.get("signal")) \
                or typeof(trigger.get("conditions")) != TYPE_ARRAY:
            return _failure("事件触发结构无效")
        for condition in trigger["conditions"]:
            if not _valid_id(condition):
                return _failure("条件标识无效")
        if typeof(event.get("actions")) != TYPE_ARRAY:
            return _failure("事件缺少动作数组")
        var seen: Dictionary = {}
        for action in event["actions"]:
            if typeof(action) != TYPE_DICTIONARY \
                    or not _valid_id(action.get("action_id")) \
                    or not action.has("next_event_id"):
                return _failure("动作结构无效")
            if action["next_event_id"] != null and not _valid_id(action["next_event_id"]):
                return _failure("事件目标标识无效")
            if seen.has(action["action_id"]):
                return _failure("同一事件的动作 ID 重复")
            seen[action["action_id"]] = true
        if event.has("on_ignore_event_id") \
                and event["on_ignore_event_id"] != null \
                and not _valid_id(event["on_ignore_event_id"]):
            return _failure("忽略目标无效")
        staged[id] = event.duplicate(true)
    if not staged.has(START):
        return _failure("缺少事件起点")
    for id in staged:
        var event: Dictionary = staged[id]
        for action in event["actions"]:
            var destination: Variant = action["next_event_id"]
            if destination != null and not staged.has(destination):
                return _failure("目标事件不存在")
        var ignored: Variant = event.get("on_ignore_event_id")
        if ignored != null and not staged.has(ignored):
            return _failure("忽略后继事件不存在")
    _catalog = staged
    _at = START
    _trace.clear()
    _last_error = ""
    return {"ok": true, "candidate_only": true, "checker_status": "NOT_RUN"}

## GAME-WEB-SHELL-006 r1 private seam. A fixed public fixture ID only.
## No event bus, scene effect, persistence or approved shared contract.
func has_event(event_id: String) -> bool:
    return not event_id.is_empty() and _catalog.has(event_id)


func start_at(event_id: String) -> bool:
    # Validate before changing current event/trace; never default unknown IDs
    # to EVENT_START.
    if not has_event(event_id):
        return false
    _at = event_id
    _trace.clear()
    _last_error = ""
    return true


func reset() -> bool:
    if not _catalog.has(START):
        return false
    _at = START
    _trace.clear()
    _last_error = ""
    return true

func state() -> Dictionary:
    var choices: Array[Dictionary] = []
    if _catalog.has(_at):
        var current: Dictionary = _catalog[_at]
        for action in current["actions"]:
            choices.append({
                "id": str(action["action_id"]),
                "next": action["next_event_id"]
            })
        if current.get("on_ignore_event_id") != null:
            choices.append({"id": IGNORE, "next": current["on_ignore_event_id"]})
    return {
        "ok": not _catalog.is_empty(),
        "event_id": _at,
        "terminal": _at.is_empty(),
        "choices": choices,
        "trace": _trace.duplicate(true),
        "error": _last_error,
        "candidate_only": true,
        "checker_status": "NOT_RUN",
        "no_runtime_effects": true
    }

func choose(action_id: String) -> Dictionary:
    if _at.is_empty() or not _catalog.has(_at):
        return _failure("事件流程已经终止或尚未加载")
    if _trace.size() >= MAX_STEPS:
        return _failure("流程步骤超过本地预览上限")
    var offered: Array = state()["choices"]
    var match_count := 0
    var selected: Dictionary = {}
    for action in offered:
        if action["id"] == action_id:
            selected = action
            match_count += 1
    if match_count != 1:
        return _failure("动作不在当前候选清单中")
    var next_id: Variant = selected["next"]
    var before := _at
    _at = "" if next_id == null else str(next_id)
    _trace.append({
        "from": before,
        "choice": action_id,
        "to": _at,
        "ignored": action_id == IGNORE
    })
    _last_error = ""
    return {"ok": true, "event_id": _at, "candidate_only": true,
        "no_runtime_effects": true, "checker_status": "NOT_RUN"}
