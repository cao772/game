extends Control
## GAME-WEB-REGION-026 r1: event-preview UI for fixed public synthetic fixtures.
## The menu owns this scene's lifetime and return route; this screen owns only
## its disposable preview model. No game events, saves, network or private data.

const ModelScript = preload("res://event_preview_model_candidate.gd")

var origin_route: String = "menu"
var _model
var _load_ok: bool = false
var _event_picker: OptionButton
var _status_label: Label
var _gate_label: Label
var _diagnostic_label: Label
var _source_label: Label
var _route_label: Label
var _notice_label: Label
var _choice_holder: VBoxContainer
var _back_button: Button
var _forward_button: Button
var _rollback_button: Button
var _observe_button: Button
var _mismatch_button: Button
var _clear_observation_button: Button
var _last_notice: String = "事件预览只读取固定公开合成夹具；不会执行游戏事件。"


func _ready() -> void:
    _model = ModelScript.new()
    _build_ui()
    _reload_fixtures()


func _label(parent: Node, value: String) -> Label:
    var item := Label.new()
    item.text = value
    item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(item)
    return item


func _button(parent: Node, caption: String, callback: Callable) -> Button:
    var item := Button.new()
    item.text = caption
    item.tooltip_text = caption
    item.focus_mode = Control.FOCUS_ALL
    item.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    item.pressed.connect(callback)
    parent.add_child(item)
    return item


func _clear_children(parent: Node) -> void:
    for child in parent.get_children():
        parent.remove_child(child)
        child.queue_free()


func _build_ui() -> void:
    var scroll := ScrollContainer.new()
    add_child(scroll)
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.offset_left = 10.0
    scroll.offset_top = 8.0
    scroll.offset_right = -10.0
    scroll.offset_bottom = -8.0

    var root := VBoxContainer.new()
    root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.custom_minimum_size = Vector2(680, 0)
    scroll.add_child(root)

    _label(root, "GAME-WEB-REGION-026｜独立合成事件预览｜NOT_RUN")
    _label(root, "入口来源：" + origin_route + "。这里只是静态分支预览，不是游戏事件触发器、事件总线或存档。")
    _label(root, "PR #18 的 Python 预览能力在此由固定夹具 GDScript 适配器重新表达；不是调用其 Python CLI，也不声称等价于 PR #9 检查器。")

    var start_row := HBoxContainer.new()
    root.add_child(start_row)
    _label(start_row, "显式起始事件：")
    _event_picker = OptionButton.new()
    _event_picker.focus_mode = Control.FOCUS_ALL
    _event_picker.item_selected.connect(_on_start_selected)
    start_row.add_child(_event_picker)
    _button(start_row, "重新读取固定事件夹具", Callable(self, "_reload_fixtures"))

    _status_label = _label(root, "")
    _gate_label = _label(root, "")
    _diagnostic_label = _label(root, "")
    _source_label = _label(root, "")

    var observations := HBoxContainer.new()
    root.add_child(observations)
    _observe_button = _button(observations, "手动注入匹配合成观察值", Callable(self, "_inject_matching"))
    _mismatch_button = _button(observations, "注入错误 signal（负例）", Callable(self, "_inject_mismatch"))
    _clear_observation_button = _button(observations, "清除当前事件观察值", Callable(self, "_clear_observation"))

    _label(root, "可选分支（只有当前事件的合成条件门禁就绪时才可选择）：")
    _choice_holder = VBoxContainer.new()
    root.add_child(_choice_holder)

    var navigation := HBoxContainer.new()
    root.add_child(navigation)
    _back_button = _button(navigation, "返回一步（保留 redo）", Callable(self, "_back"))
    _forward_button = _button(navigation, "前进一步（查看 redo）", Callable(self, "_forward"))
    _rollback_button = _button(navigation, "回滚到起点（丢弃后续）", Callable(self, "_rollback_root"))

    _route_label = _label(root, "")
    _notice_label = _label(root, "")
    _label(root, "分支选择、条件观察、返回和回滚均只改变本屏的临时内存预览记录。关闭预览不会将记录交给区域、菜单或游戏存档。")


func _reload_fixtures() -> void:
    var loaded: Dictionary = _model.load_fixed_fixtures()
    _load_ok = bool(loaded.get("ok", false))
    _event_picker.clear()
    if _load_ok:
        var ids: Array = _model.event_ids()
        for event_id in ids:
            _event_picker.add_item(str(event_id))
        var start_index: int = ids.find("EVENT_START")
        if start_index < 0 and not ids.is_empty():
            start_index = 0
        if start_index >= 0:
            _event_picker.select(start_index)
            var started: Dictionary = _model.begin(str(ids[start_index]))
            _last_notice = "固定合成夹具已由 N26 本地结构守卫接受；这不等于 PR #9 checker PASS。"
            if not bool(started.get("ok", false)):
                _load_ok = false
                _last_notice = str(started.get("reason", "无法开始预览。"))
    else:
        _last_notice = "BLOCKED：" + str(loaded.get("reason", "固定合成事件夹具不可用。"))
    _refresh_view()


func _on_start_selected(index: int) -> void:
    if not _load_ok or index < 0:
        return
    var event_id: String = _event_picker.get_item_text(index)
    var result: Dictionary = _model.begin(event_id)
    _last_notice = "已显式重置预览起点：" + event_id if result.get("ok", false) else "REJECTED：" + str(result.get("reason", "未知错误"))
    _refresh_view()


func _apply(command: Dictionary) -> void:
    if not _load_ok:
        return
    var result: Dictionary = _model.apply(command)
    if bool(result.get("ok", false)):
        var info: Dictionary = result.get("info", {})
        var effect: Dictionary = info.get("navigation_effect", {})
        _last_notice = str(result.get("operation", "操作")) + "：" + str(result.get("status", "完成"))
        if not effect.is_empty():
            _last_notice += "；导航策略 " + str(effect.get("policy", "")) + "；丢弃 " + str(effect.get("discarded_steps", 0)) + " 步"
    else:
        var error: Dictionary = result.get("error", {})
        var view: Dictionary = result.get("error_view", {})
        _last_notice = "REJECTED " + str(error.get("code", "UNKNOWN")) + "：" + str(error.get("message", "")) + "；" + str(view.get("suggestion", "人工复核，不自动修复。"))
    _refresh_view()


func _inject_matching() -> void:
    var event_id: String = _model.current_event_id()
    if event_id.is_empty():
        return
    var expected: Dictionary = _model.expected_observation(event_id)
    if expected.is_empty():
        return
    _apply({
        "op": "observe",
        "event_id": event_id,
        "signal": expected["signal"],
        "conditions": expected["conditions"]
    })


func _inject_mismatch() -> void:
    var event_id: String = _model.current_event_id()
    if event_id.is_empty():
        return
    var expected: Dictionary = _model.expected_observation(event_id)
    if expected.is_empty():
        return
    _apply({
        "op": "observe",
        "event_id": event_id,
        "signal": "SIGNAL_SYNTHETIC_MISMATCH",
        "conditions": expected["conditions"]
    })


func _clear_observation() -> void:
    var event_id: String = _model.current_event_id()
    if event_id.is_empty():
        return
    _apply({"op": "clear_observation", "event_id": event_id})


func _choose(choice: String) -> void:
    _apply({"op": "choose", "choice": choice})


func _back() -> void:
    _apply({"op": "back", "steps": 1})


func _forward() -> void:
    _apply({"op": "forward", "steps": 1})


func _rollback_root() -> void:
    _apply({"op": "rollback", "cursor": 0})


func _refresh_view() -> void:
    if not is_node_ready():
        return
    if not _load_ok:
        _status_label.text = "事件来源状态：BLOCKED · " + str(_model.load_status().get("error", "固定夹具不可用。"))
        _gate_label.text = "没有可选择的事件分支。"
        _diagnostic_label.text = "恢复：确认本目录三个固定公开 JSON 文件存在且结构有效，然后显式重新读取。"
        _source_label.text = "不扫描其他目录，不使用真实事件，不自动切换备用数据。"
        _clear_children(_choice_holder)
        _back_button.disabled = true
        _forward_button.disabled = true
        _rollback_button.disabled = true
        _observe_button.disabled = true
        _mismatch_button.disabled = true
        _clear_observation_button.disabled = true
        _event_picker.disabled = true
        _route_label.text = "导航历史：无"
        _notice_label.text = _last_notice
        return

    _event_picker.disabled = false
    var state: Dictionary = _model.snapshot()
    var current_value: Variant = state.get("current_event_id")
    var current_id: String = "" if current_value == null else str(current_value)
    var gate_value: Variant = state.get("condition_gate")
    var gate: Dictionary = gate_value if gate_value is Dictionary else {}
    var diagnosis: Dictionary = state.get("condition_diagnostics", {})
    var ready: bool = bool(gate.get("ready", false))
    _status_label.text = "当前事件：" + (current_id if not current_id.is_empty() else "终止") + "｜预览状态：" + str(state.get("preview_status", "blocked")) + "｜固定夹具：" + str(state.get("source_snapshot_sha256", ""))
    if gate.is_empty():
        _gate_label.text = "终止链接：没有下一事件条件或分支。"
    else:
        _gate_label.text = "条件门禁：" + ("READY（合成观察值匹配）" if ready else "BLOCKED") + "｜signal " + ("(未提供)" if gate.get("observed_signal") == null else str(gate.get("observed_signal"))) + " / required " + str(gate.get("required_signal", "")) + "｜缺少条件：" + str(gate.get("missing_conditions", []))
    var reasons: Array = diagnosis.get("reason_codes", [])
    var reason_text: String = "无阻断原因"
    if not reasons.is_empty():
        reason_text = ""
        for reason in reasons:
            if not reason_text.is_empty():
                reason_text += ", "
            reason_text += str(reason)
    _diagnostic_label.text = "条件诊断：" + reason_text + "｜下一步：" + str(diagnosis.get("next_step", ""))
    var definition: Dictionary = _model.source_at_current()
    _source_label.text = "来源：" + str(definition.get("file", "(终止)")) + " " + str(definition.get("pointer", "")) + "｜来源 SHA256：" + str(definition.get("sha256", ""))

    _clear_children(_choice_holder)
    var configured: Array = state.get("configured_choices", [])
    var available: Array = state.get("available_choices", [])
    for option in configured:
        var choice_id: String = str(option.get("choice", ""))
        var target: Variant = option.get("target_event_id")
        var target_text: String = "(终止)" if target == null else str(target)
        var label: String = choice_id + " → " + target_text + ("（忽略）" if option.get("kind") == "ignore" else "")
        var item := _button(_choice_holder, label, Callable(self, "_choose").bind(choice_id))
        var enabled: bool = false
        for candidate in available:
            if candidate.get("choice") == choice_id:
                enabled = true
                break
        item.disabled = not ready or not enabled

    _back_button.disabled = not bool(state.get("can_back", false))
    _forward_button.disabled = not bool(state.get("can_forward", false))
    _rollback_button.disabled = int(state.get("cursor", 0)) == 0 and int(state.get("history_length", 0)) == 0
    var terminal: bool = current_id.is_empty()
    _observe_button.disabled = terminal
    _mismatch_button.disabled = terminal
    _clear_observation_button.disabled = terminal or not state.get("observations", {}).has(current_id)
    var positions: Array = state.get("navigation", {}).get("positions", [])
    var route_text: String = ""
    for position in positions:
        if not route_text.is_empty():
            route_text += " → "
        var position_event: Variant = position.get("event_id")
        var position_label: String = "(终止)" if position_event == null else str(position_event)
        route_text += str(position.get("cursor", 0)) + ":" + position_label + (" [当前/已选]" if position.get("selected_prefix", false) else " [redo]")
    _route_label.text = "导航路径：" + route_text + "｜游标 " + str(state.get("cursor", 0)) + "/" + str(state.get("history_length", 0))
    _notice_label.text = _last_notice
