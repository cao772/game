extends RefCounted
## GAME-WEB-REGION-028 r1: explicit-input, provenance-aware synthetic event preview model.
## Independent repair candidate derived from PR #34 and the PR #35 static audit.
## Synthetic fixtures only. Not the PR #18 Python implementation or PR #9 checker. NOT_RUN.

const FIXTURE_PATHS := [
    "res://fixtures/placeholder_start.json",
    "res://fixtures/placeholder_next.json",
    "res://fixtures/placeholder_end.json"
]
const MAX_FILE_BYTES := 16384
const MAX_EVENTS := 16
const MAX_ACTIONS := 16
const MAX_CONDITIONS := 16
const MAX_CHOICES := 24
const IGNORE_CHOICE := "@ignore"

var _loaded: bool = false
var _started: bool = false
var _stale: bool = false
var _stale_reason: String = ""
var _load_error: String = "尚未读取固定合成事件夹具。"
var _events: Dictionary = {}
var _sources: Dictionary = {}
var _observations: Dictionary = {}
var _history: Array = []
var _cursor: int = 0
var _start_event_id: String = ""
var _source_snapshot_sha256: String = ""


func _sha_bytes(data: PackedByteArray) -> String:
    var context := HashingContext.new()
    if context.start(HashingContext.HASH_SHA256) != OK:
        return ""
    if context.update(data) != OK:
        return ""
    return context.finish().hex_encode()


func _canonical_sha(value: Variant) -> String:
    var encoded: String = JSON.stringify(value, "", true)
    return _sha_bytes(encoded.to_utf8_buffer())


func _valid_id(value: Variant) -> bool:
    if typeof(value) != TYPE_STRING:
        return false
    var identifier: String = value
    if identifier.is_empty() or identifier.length() > 64:
        return false
    for index in range(identifier.length()):
        var code: int = identifier.unicode_at(index)
        var upper: bool = code >= 65 and code <= 90
        var digit: bool = code >= 48 and code <= 57
        if index == 0 and not upper:
            return false
        if not upper and not digit and code != 95:
            return false
    return true


func _exact_fields(value: Dictionary, required: Array, optional: Array) -> bool:
    for field_name in required:
        if not value.has(field_name):
            return false
    for field_name in value.keys():
        if not required.has(field_name) and not optional.has(field_name):
            return false
    return true


func _prefix(source: Array, count: int) -> Array:
    var result: Array = []
    for index in range(mini(count, source.size())):
        result.append(source[index].duplicate(true))
    return result


func _fail(message: String) -> Dictionary:
    _load_error = message
    if _loaded:
        _stale = true
        _stale_reason = message
        return {"ok": false, "status": "STALE_BLOCKED", "reason": message, "previous_snapshot_preserved": true, "read_only": true, "candidate_only": true, "no_runtime_effects": true}
    _stale = false
    _stale_reason = ""
    return {"ok": false, "status": "BLOCKED", "reason": message, "previous_snapshot_preserved": false, "candidate_only": true, "no_runtime_effects": true}


func _validate_event(document: Dictionary) -> String:
    if not _exact_fields(document, ["event_id", "trigger", "actions"], ["on_ignore_event_id"]):
        return "事件对象字段与固定占位契约不符。"
    if not _valid_id(document.get("event_id")):
        return "event_id 必须是大写合成标识符。"

    var trigger_value: Variant = document.get("trigger")
    if typeof(trigger_value) != TYPE_DICTIONARY:
        return "trigger 必须是对象。"
    var trigger: Dictionary = trigger_value
    if not _exact_fields(trigger, ["signal", "conditions"], []):
        return "trigger 字段不完整或包含未定义字段。"
    if not _valid_id(trigger.get("signal")):
        return "trigger.signal 必须是大写合成标识符。"
    var conditions_value: Variant = trigger.get("conditions")
    if typeof(conditions_value) != TYPE_ARRAY:
        return "trigger.conditions 必须是数组。"
    var conditions: Array = conditions_value
    if conditions.is_empty() or conditions.size() > MAX_CONDITIONS:
        return "trigger.conditions 必须包含 1..16 个合成标识符。"
    var seen_conditions: Array = []
    for condition in conditions:
        if not _valid_id(condition) or seen_conditions.has(condition):
            return "trigger.conditions 存在无效或重复标识符。"
        seen_conditions.append(condition)

    var actions_value: Variant = document.get("actions")
    if typeof(actions_value) != TYPE_ARRAY:
        return "actions 必须是数组。"
    var actions: Array = actions_value
    if actions.is_empty() or actions.size() > MAX_ACTIONS:
        return "actions 必须包含 1..16 个分支。"
    var seen_actions: Array = []
    for action_value in actions:
        if typeof(action_value) != TYPE_DICTIONARY:
            return "action 字段与固定占位契约不符。"
        var action: Dictionary = action_value
        if not _exact_fields(action, ["action_id", "next_event_id"], []):
            return "action 字段与固定占位契约不符。"
        var action_id: Variant = action.get("action_id")
        if not _valid_id(action_id) or seen_actions.has(action_id):
            return "action_id 无效或在同一事件内重复。"
        seen_actions.append(action_id)
        var target: Variant = action.get("next_event_id")
        if target != null and not _valid_id(target):
            return "next_event_id 必须是已定义格式的 ID 或 null。"

    if document.has("on_ignore_event_id"):
        var ignored: Variant = document.get("on_ignore_event_id")
        if ignored != null and not _valid_id(ignored):
            return "on_ignore_event_id 必须是 ID 或 null。"
    return ""


func load_fixed_fixtures() -> Dictionary:
    # Stage all fixture files and references before replacing committed state.
    var staged_events: Dictionary = {}
    var staged_sources: Dictionary = {}
    for path in FIXTURE_PATHS:
        if not FileAccess.file_exists(path):
            return _fail("缺少固定公开合成事件文件：" + path.get_file())
        var file := FileAccess.open(path, FileAccess.READ)
        if file == null:
            return _fail("无法读取固定合成事件文件：" + path.get_file())
        var bytes: PackedByteArray = file.get_buffer(MAX_FILE_BYTES + 1)
        file.close()
        if bytes.is_empty() or bytes.size() > MAX_FILE_BYTES:
            return _fail("固定合成事件文件为空或超过 16 KiB：" + path.get_file())
        var decoded: String = bytes.get_string_from_utf8()
        if decoded.to_utf8_buffer() != bytes:
            return _fail("固定合成事件文件不是严格 UTF-8：" + path.get_file())
        var parser := JSON.new()
        if parser.parse(decoded) != OK or typeof(parser.data) != TYPE_DICTIONARY:
            return _fail("固定合成事件 JSON 无法解析为对象：" + path.get_file())
        var document: Dictionary = parser.data
        var issue: String = _validate_event(document)
        if not issue.is_empty():
            return _fail(path.get_file() + "：" + issue)
        var event_id: String = str(document["event_id"])
        if staged_events.has(event_id):
            return _fail("固定夹具内 event_id 重复：" + event_id)
        staged_events[event_id] = document.duplicate(true)
        staged_sources[event_id] = {"event_id": event_id, "file": path.get_file(), "sha256": _sha_bytes(bytes)}

    if staged_events.is_empty() or staged_events.size() > MAX_EVENTS:
        return _fail("固定合成事件数量为空或超过上限。")
    for event_id in staged_events.keys():
        var document: Dictionary = staged_events[event_id]
        var references: Array = []
        for action in document["actions"]:
            if action["next_event_id"] != null:
                references.append(action["next_event_id"])
        if document.has("on_ignore_event_id") and document["on_ignore_event_id"] != null:
            references.append(document["on_ignore_event_id"])
        for target_id in references:
            if not staged_events.has(target_id):
                return _fail("事件 " + str(event_id) + " 引用了未提供的固定目标 " + str(target_id) + "。")

    var source_rows: Array = []
    var ids: Array = staged_events.keys()
    ids.sort()
    for event_id in ids:
        source_rows.append({"event_id": event_id, "sha256": staged_sources[event_id]["sha256"]})
    var staged_snapshot_sha256 := _canonical_sha(source_rows)

    # Atomic commit point: old state is untouched until all validation succeeds.
    _events = staged_events
    _sources = staged_sources
    _observations.clear()
    _history.clear()
    _cursor = 0
    _start_event_id = ""
    _started = false
    _source_snapshot_sha256 = staged_snapshot_sha256
    _loaded = true
    _stale = false
    _stale_reason = ""
    _load_error = ""
    return {
        "ok": true,
        "status": "FIXTURE_READY_AWAITING_START",
        "events": ids,
        "session_reset_after_success": true,
        "validator": "N28_LOCAL_FIXED_FIXTURE_GUARD",
        "not_pr9_checker": true,
        "candidate_only": true
    }


func event_ids() -> Array:
    var result: Array = _events.keys()
    result.sort()
    return result


func begin(start_event_id: String) -> Dictionary:
    if not _loaded:
        return {"ok": false, "status": "BLOCKED", "reason": _load_error}
    if _stale:
        return {"ok": false, "status": "STALE_BLOCKED", "reason": _stale_reason, "read_only": true}
    if not _events.has(start_event_id):
        return {"ok": false, "status": "REJECTED", "reason": "所选起始事件不在固定夹具目录。"}
    _start_event_id = start_event_id
    _started = true
    _observations.clear()
    _history.clear()
    _cursor = 0
    return {"ok": true, "status": "PREVIEW_RESET", "snapshot": snapshot()}


func current_event_id() -> String:
    if not _started:
        return ""
    if _cursor == 0:
        return _start_event_id
    var target: Variant = _history[_cursor - 1].get("to_event_id")
    return "" if target == null else str(target)


func source_for_event(event_id: String) -> Dictionary:
    return _source_at(event_id, "/event_id")


func _source_at(event_id: String, pointer: String) -> Dictionary:
    if not _sources.has(event_id):
        return {}
    return {"event_id": event_id, "file": _sources[event_id]["file"], "sha256": _sources[event_id]["sha256"], "pointer": pointer}


func _options_for(event_id: String) -> Array:
    if not _started or event_id.is_empty() or not _events.has(event_id):
        return []
    var document: Dictionary = _events[event_id]
    var choices: Array = []
    for index in range(document["actions"].size()):
        var action: Dictionary = document["actions"][index]
        var target: Variant = action["next_event_id"]
        choices.append({
            "choice": action["action_id"], "kind": "action", "target_event_id": target,
            "outcome": "terminal" if target == null else "linked",
            "source": _source_at(event_id, "/actions/" + str(index)),
            "reference_source": _source_at(event_id, "/actions/" + str(index) + "/next_event_id"),
            "target_definition": null if target == null else _source_at(str(target), "/event_id")
        })
    if document.has("on_ignore_event_id"):
        var ignored: Variant = document["on_ignore_event_id"]
        choices.append({
            "choice": IGNORE_CHOICE, "kind": "ignore", "target_event_id": ignored,
            "outcome": "terminal" if ignored == null else "linked",
            "source": _source_at(event_id, "/on_ignore_event_id"),
            "reference_source": _source_at(event_id, "/on_ignore_event_id"),
            "target_definition": null if ignored == null else _source_at(str(ignored), "/event_id")
        })
    return choices


func _gate(event_id: String) -> Dictionary:
    if not _started or event_id.is_empty() or not _events.has(event_id):
        return {}
    var trigger: Dictionary = _events[event_id]["trigger"]
    var observed: Variant = _observations.get(event_id)
    var observed_signal: Variant = observed.get("signal") if observed is Dictionary else null
    var observed_conditions: Array = observed.get("conditions", []) if observed is Dictionary else []
    var missing: Array = []
    for required in trigger["conditions"]:
        if not observed_conditions.has(required):
            missing.append(required)
    var matches: bool = observed_signal == trigger["signal"]
    return {
        "event_id": event_id, "ready": observed is Dictionary and matches and missing.is_empty(),
        "required_signal": trigger["signal"], "observed_signal": observed_signal,
        "signal_matches": matches, "required_conditions": trigger["conditions"].duplicate(),
        "observed_conditions": observed_conditions.duplicate(), "missing_conditions": missing,
        "requirement_sources": {
            "signal": _source_at(event_id, "/trigger/signal"),
            "conditions": _source_at(event_id, "/trigger/conditions")
        },
        "observation_origin": "caller_injected" if observed is Dictionary else "not_supplied"
    }


func _diagnose(gate: Dictionary) -> Dictionary:
    if gate.is_empty():
        if not _started:
            return {
                "status": "not_started",
                "ready": false,
                "reason_codes": ["START_EVENT_REQUIRED"],
                "reasons": [],
                "next_step": "请从固定事件列表中明确选择起点，再点击开始预览。"
            }
        return {
            "status": "terminal",
            "ready": false,
            "reason_codes": ["TERMINAL"],
            "reasons": [],
            "next_step": "没有配置后续预览事件。"
        }
    var reasons: Array = []
    if gate["observation_origin"] == "not_supplied":
        reasons.append({
            "code": "OBSERVATION_NOT_SUPPLIED",
            "detail": "尚未提供该事件的合成观察值。",
            "source": gate["requirement_sources"]["signal"]
        })
    else:
        if not gate["signal_matches"]:
            reasons.append({
                "code": "SIGNAL_MISMATCH",
                "detail": "注入的合成 signal 与事件要求不一致。",
                "source": gate["requirement_sources"]["signal"]
            })
        if not gate["missing_conditions"].is_empty():
            reasons.append({
                "code": "REQUIRED_CONDITIONS_MISSING",
                "detail": "注入的合成 conditions 缺少必需标识符。",
                "missing": gate["missing_conditions"].duplicate(),
                "source": gate["requirement_sources"]["conditions"]
            })
    if not gate["ready"] and reasons.is_empty():
        reasons.append({
            "code": "GATE_UNAVAILABLE",
            "detail": "条件门禁未知阻断，保持关闭。",
            "source": gate["requirement_sources"]["signal"]
        })
    var required: Array = gate["required_conditions"]
    var additional: Array = []
    for item in gate["observed_conditions"]:
        if not required.has(item):
            additional.append(item)
    additional.sort()
    var codes: Array = []
    for reason in reasons:
        codes.append(reason["code"])
    return {
        "status": "ready" if gate["ready"] else "blocked",
        "ready": gate["ready"],
        "reason_codes": codes,
        "reasons": reasons,
        "additional_observed_conditions": additional,
        "next_step": "可以查看分支并显式选择。" if gate["ready"] else "请手动注入匹配的合成观察值；不会自动补齐。"
    }


func _breadcrumbs() -> Dictionary:
    var positions: Array = []
    if _started:
        positions.append({"cursor": 0, "event_id": _start_event_id, "via_choice": null, "from_event_id": null, "selected_prefix": true})
        for index in range(_history.size()):
            var entry: Dictionary = _history[index]
            positions.append({
                "cursor": index + 1, "event_id": entry["to_event_id"], "via_choice": entry["choice"],
                "from_event_id": entry["from_event_id"], "selected_prefix": index + 1 <= _cursor
            })
    return {
        "cursor": _cursor, "length": _history.size(), "positions": positions,
        "back_available": _cursor > 0, "redo_available": _cursor < _history.size(),
        "rollback_cursor_range": [0, _cursor], "navigation_is_preview_only": true
    }


func snapshot() -> Dictionary:
    var current: String = current_event_id()
    var gate: Dictionary = _gate(current)
    var configured: Array = _options_for(current)
    var available: Array = configured.duplicate(true) if gate.get("ready", false) and not _stale else []
    var selected_path: Array = []
    var trace: Array = []
    for index in range(_cursor):
        var entry: Dictionary = _history[index]
        selected_path.append(entry["choice"])
        trace.append({
            "step": index, "from_event_id": entry["from_event_id"], "selection": entry["choice"],
            "kind": entry["kind"], "to_event_id": entry["to_event_id"],
            "outcome": "terminal" if entry["to_event_id"] == null else "linked",
            "selected_at": entry["source"].duplicate(true),
            "reference_at": entry["reference_source"].duplicate(true),
            "target_definition": entry["target_definition"].duplicate(true) if entry["target_definition"] is Dictionary else null,
            "gate_at_selection": entry["gate_at_selection"].duplicate(true)
        })
    var status := "stale_blocked" if _stale else ("not_started" if not _started else ("terminal" if current.is_empty() else ("offered" if gate.get("ready", false) else "blocked")))
    var result: Dictionary = {
        "task_id": "GAME-WEB-REGION-028", "version": "r1", "candidate_only": true,
        "loaded": _loaded, "started": _started, "stale": _stale, "stale_reason": _stale_reason,
        "preview_status": status, "start_event_ids": event_ids(),
        "start_event_id": _start_event_id if _started else null,
        "current_event_id": null if current.is_empty() else current,
        "cursor": _cursor, "history_length": _history.size(),
        "can_back": _cursor > 0 and not _stale, "can_forward": _cursor < _history.size() and not _stale,
        "navigation_history": _history.duplicate(true), "selected_path": selected_path,
        "condition_gate": gate if not gate.is_empty() else null, "condition_diagnostics": _diagnose(gate),
        "navigation": _breadcrumbs(), "configured_choices": configured, "available_choices": available,
        "observations": _observations.duplicate(true), "source_snapshot_sha256": _source_snapshot_sha256,
        "source_files": _sources.duplicate(true), "trace": trace,
        "validator": "N28_LOCAL_FIXED_FIXTURE_GUARD", "not_pr9_checker": true,
        "no_runtime_effects": true, "no_source_writes": true, "no_persistence": true
    }
    result["state_snapshot_sha256"] = _canonical_sha(result)
    return result


func _error_view(error: Dictionary, state: Dictionary) -> Dictionary:
    var code: String = str(error.get("code", "UNKNOWN_ERROR"))
    var guidance := {
        "CONDITIONS_NOT_MET": ["gate", "条件门禁未满足。", "检查手动输入的 signal、conditions 及其来源；不要自动选择分支。"],
        "UNKNOWN_CHOICE": ["branch", "分支不存在。", "只能选择当前事件列出的 action_id 或显式配置的 @ignore。"],
        "TERMINAL_LOCKED": ["navigation", "当前事件已终止。", "可以返回或显式回滚，不能继续选择。"],
        "UNKNOWN_EVENT": ["source", "事件不在固定夹具中。", "不要猜测或自动映射事件 ID。"],
        "INVALID_SIGNAL": ["input", "signal 格式无效。", "请使用有效的大写合成 signal 标识符。"],
        "INVALID_CONDITIONS": ["input", "conditions 格式无效。", "请使用不重复的大写合成条件标识符；空输入表示空数组。"],
        "ROLLBACK_FORWARD_FORBIDDEN": ["navigation", "回滚方向不允许。", "回滚不能前进；请使用单独的前进导航。"],
        "CURSOR_OUT_OF_RANGE": ["navigation", "导航游标越界。", "请选择已记录且允许的导航位置。"],
        "STEP_LIMIT": ["limit", "达到预览步数上限。", "请返回或回滚，不要扩展本地步数限制。"],
        "SOURCE_NOT_READY": ["source", "固定合成夹具不可用。", "重新读取固定夹具或返回来源页面。"],
        "SOURCE_STALE": ["source", "固定夹具重载失败。", "当前旧快照只读；修复夹具后重新读取。"],
        "START_EVENT_REQUIRED": ["input", "尚未选择起始事件。", "从事件列表明确选择起点并点击开始预览。"]
    }
    var item: Array = guidance.get(code, ["review", "预览请求无法完成。", "检查结构化错误；不自动修复、不修改源文件。"])
    var related_sources: Array = []
    var gate_value: Variant = error.get("condition_gate")
    if gate_value is Dictionary:
        var diagnosis: Dictionary = _diagnose(gate_value)
        for reason in diagnosis.get("reasons", []):
            var source_value: Variant = reason.get("source", {})
            if source_value is Dictionary and not source_value.is_empty():
                related_sources.append({"reason_code": reason.get("code", "UNKNOWN"), "source": source_value.duplicate(true)})
    return {
        "code": code, "category": item[0], "title": item[1], "message": str(error.get("message", "")),
        "suggestion": item[2], "details": error.duplicate(true), "related_sources": related_sources,
        "cursor": state.get("cursor"), "state_snapshot_sha256": state.get("state_snapshot_sha256"),
        "source_state_changed": false, "auto_repair": false, "manual_review_only": true
    }


func _rejected(operation: String, code: String, message: String, details: Dictionary = {}) -> Dictionary:
    var state: Dictionary = snapshot() if _loaded else {}
    var error: Dictionary = {"code": code, "message": message}
    for key in details:
        error[key] = details[key]
    return {
        "ok": false,
        "status": "REJECTED",
        "operation": operation,
        "changed": false,
        "error": error,
        "error_view": _error_view(error, state),
        "snapshot": state
    }


func _accepted(operation: String, changed: bool = true, info: Dictionary = {}) -> Dictionary:
    return {
        "ok": true,
        "status": "APPLIED" if changed else "UNCHANGED",
        "operation": operation,
        "changed": changed,
        "info": info.duplicate(true),
        "snapshot": snapshot()
    }


func _set_observation(operation: String, event_id: Variant, signal_value: Variant, conditions_value: Variant, clearing: bool) -> Dictionary:
    if _stale:
        return _rejected(operation, "SOURCE_STALE", "重载失败，旧快照只读；禁止修改观察值。")
    if not _started:
        return _rejected(operation, "START_EVENT_REQUIRED", "请先明确选择起始事件。")
    if typeof(event_id) != TYPE_STRING or not _events.has(event_id):
        return _rejected(operation, "UNKNOWN_EVENT", "观察事件 ID 不在固定夹具目录。")
    var replacement: Variant = null
    if not clearing:
        if not _valid_id(signal_value):
            return _rejected(operation, "INVALID_SIGNAL", "合成 signal 标识符无效。")
        if typeof(conditions_value) != TYPE_ARRAY or conditions_value.size() > MAX_CONDITIONS:
            return _rejected(operation, "INVALID_CONDITIONS", "合成 conditions 必须是 0..16 个标识符。")
        var normalized: Array = []
        for item in conditions_value:
            if not _valid_id(item) or normalized.has(item):
                return _rejected(operation, "INVALID_CONDITIONS", "合成 conditions 存在无效或重复标识符。")
            normalized.append(item)
        normalized.sort()
        replacement = {"signal": signal_value, "conditions": normalized}

    var has_existing: bool = _observations.has(event_id)
    var existing: Variant = _observations.get(event_id)
    if (clearing and not has_existing) or (not clearing and existing == replacement):
        return _accepted(operation, false)

    var old_cursor: int = _cursor
    var old_length: int = _history.size()
    var rollback_at: int = -1
    for index in range(_cursor):
        if _history[index]["from_event_id"] == event_id:
            rollback_at = index
            break
    var policy: String
    if rollback_at >= 0:
        _history = _prefix(_history, rollback_at)
        _cursor = rollback_at
        policy = "rollback_to_safe_prefix"
    else:
        _history = _prefix(_history, _cursor)
        policy = "discard_redo" if old_length > old_cursor else "observation_only"

    if clearing:
        _observations.erase(event_id)
    else:
        _observations[event_id] = replacement
    return _accepted(operation, true, {
        "history_reset": rollback_at == 0,
        "redo_cleared": rollback_at < 0,
        "navigation_effect": {
            "policy": policy,
            "previous_cursor": old_cursor,
            "previous_history_length": old_length,
            "current_cursor": _cursor,
            "discarded_steps": old_length - _history.size(),
            "affected_event_id": event_id
        }
    })


func apply(command: Variant) -> Dictionary:
    if not _loaded:
        return _rejected("(blocked)", "SOURCE_NOT_READY", _load_error)
    if _stale:
        return _rejected("(blocked)", "SOURCE_STALE", "重载失败；旧快照保留但进入只读状态。")
    if not _started:
        return _rejected("(blocked)", "START_EVENT_REQUIRED", "请先从固定事件列表明确选择起点并开始预览。")
    if typeof(command) != TYPE_DICTIONARY:
        return _rejected("(invalid)", "INVALID_COMMAND", "预览命令必须是对象。")
    var operation: Variant = command.get("op")
    var allowed_fields := {
        "observe": ["op", "event_id", "signal", "conditions"],
        "clear_observation": ["op", "event_id"],
        "choose": ["op", "choice"],
        "back": ["op", "steps"],
        "forward": ["op", "steps"],
        "jump": ["op", "cursor"],
        "rollback": ["op", "cursor"]
    }
    if typeof(operation) != TYPE_STRING or not allowed_fields.has(operation):
        return _rejected("(unknown)", "UNKNOWN_OPERATION", "不支持该预览操作。")
    var expected: Array = allowed_fields[operation].duplicate()
    var provided: Array = command.keys()
    expected.sort()
    provided.sort()
    if expected != provided:
        return _rejected(str(operation), "COMMAND_FIELDS", "命令字段与预览契约不一致。", {
            "required_fields": expected
        })

    if operation == "observe":
        return _set_observation("observe", command["event_id"], command["signal"], command["conditions"], false)
    if operation == "clear_observation":
        return _set_observation("clear_observation", command["event_id"], null, null, true)

    if operation == "choose":
        var choice: Variant = command["choice"]
        if typeof(choice) != TYPE_STRING or str(choice).is_empty():
            return _rejected("choose", "INVALID_CHOICE", "分支选择必须是非空字符串。")
        var current: String = current_event_id()
        if current.is_empty():
            return _rejected("choose", "TERMINAL_LOCKED", "终止链接之后没有下一条预览分支。")
        var gate: Dictionary = _gate(current)
        if not gate.get("ready", false):
            return _rejected("choose", "CONDITIONS_NOT_MET", "手动注入的合成 signal/conditions 不满足要求。", {
                "condition_gate": gate
            })
        var selected: Dictionary = {}
        for option in _options_for(current):
            if option["choice"] == choice:
                selected = option
                break
        if selected.is_empty():
            var offered: Array = []
            for option in _options_for(current):
                offered.append(option["choice"])
            return _rejected("choose", "UNKNOWN_CHOICE", "当前事件未定义该分支。", {
                "available_choices": offered
            })
        if _cursor >= MAX_CHOICES:
            return _rejected("choose", "STEP_LIMIT", "预览最多允许 24 次显式分支选择。")
        var overwritten: int = _history.size() - _cursor
        _history = _prefix(_history, _cursor)
        _history.append({
            "from_event_id": current,
            "choice": choice,
            "to_event_id": selected["target_event_id"],
            "kind": selected["kind"],
            "source": selected["source"].duplicate(true),
            "reference_source": selected["reference_source"].duplicate(true),
            "target_definition": selected["target_definition"].duplicate(true) if selected["target_definition"] is Dictionary else null,
            "gate_at_selection": gate.duplicate(true)
        })
        _cursor += 1
        return _accepted("choose", true, {
            "navigation_effect": {
                "policy": "replace_redo_branch" if overwritten > 0 else "append",
                "discarded_steps": overwritten,
                "current_cursor": _cursor
            }
        })

    if operation == "rollback":
        var rollback_cursor: Variant = command["cursor"]
        if typeof(rollback_cursor) != TYPE_INT:
            return _rejected("rollback", "INVALID_CURSOR", "回滚游标必须是整数。")
        if rollback_cursor > _cursor:
            return _rejected("rollback", "ROLLBACK_FORWARD_FORBIDDEN", "回滚不能向前移动。", {
                "current_cursor": _cursor
            })
        if rollback_cursor < 0:
            return _rejected("rollback", "CURSOR_OUT_OF_RANGE", "回滚游标不能为负数。")
        var previous_length: int = _history.size()
        var previous_cursor: int = _cursor
        _history = _prefix(_history, rollback_cursor)
        _cursor = rollback_cursor
        return _accepted("rollback", previous_length != _cursor or previous_cursor != _cursor, {
            "navigation_effect": {
                "policy": "truncate_to_cursor",
                "previous_cursor": previous_cursor,
                "current_cursor": _cursor,
                "discarded_steps": previous_length - _history.size()
            }
        })

    var new_cursor: int
    if operation == "back" or operation == "forward":
        var steps: Variant = command["steps"]
        if typeof(steps) != TYPE_INT or steps < 1 or steps > MAX_CHOICES:
            return _rejected(str(operation), "INVALID_STEPS", "steps 必须是 1..24 的整数。")
        new_cursor = _cursor - steps if operation == "back" else _cursor + steps
    else:
        var requested: Variant = command["cursor"]
        if typeof(requested) != TYPE_INT:
            return _rejected("jump", "INVALID_CURSOR", "跳转游标必须是整数。")
        new_cursor = requested
    if new_cursor < 0 or new_cursor > _history.size():
        return _rejected(str(operation), "CURSOR_OUT_OF_RANGE", "目标位置不在已记录路径内。", {
            "current_cursor": _cursor,
            "history_length": _history.size()
        })
    var old_cursor: int = _cursor
    _cursor = new_cursor
    return _accepted(str(operation), old_cursor != _cursor, {
        "navigation_effect": {
            "policy": "navigate_without_truncation",
            "previous_cursor": old_cursor,
            "current_cursor": _cursor,
            "discarded_steps": 0
        }
    })


func load_status() -> Dictionary:
    return {
        "loaded": _loaded, "stale": _stale, "error": _load_error,
        "stale_reason": _stale_reason, "read_only": _stale
    }


func source_at_current() -> Dictionary:
    var current: String = current_event_id()
    if current.is_empty():
        return {}
    return _source_at(current, "/event_id")
