extends Control
## GAME-WEB-REGION-028 r1: explicit start + caller-supplied synthetic observation UI.
## Candidate only. No game event bus, save data, network or private content.

const ModelScript = preload("res://event_preview_model_candidate.gd")

var origin_route: String = "menu"
var _model
var _fixture_ready: bool = false
var _stale: bool = false
var _selected_start_event_id: String = ""
var _event_picker: OptionButton
var _start_button: Button
var _signal_input: LineEdit
var _conditions_input: LineEdit
var _status_label: Label
var _gate_label: Label
var _diagnostic_label: Label
var _source_label: Label
var _route_label: Label
var _trace_label: Label
var _notice_label: Label
var _choice_holder: VBoxContainer
var _back_button: Button
var _forward_button: Button
var _rollback_button: Button
var _observe_button: Button
var _clear_observation_button: Button
var _reload_dialog: ConfirmationDialog
var _last_notice: String = "仅使用公开合成事件夹具；请先明确选择起始事件。"

func _ready() -> void:
    _model = ModelScript.new()
    _build_ui()
    _perform_reload()

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

func _line_edit(parent: Node, placeholder: String) -> LineEdit:
    var item := LineEdit.new()
    item.placeholder_text = placeholder
    item.clear_button_enabled = true
    item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    item.focus_mode = Control.FOCUS_ALL
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
    scroll.offset_left = 12.0
    scroll.offset_top = 10.0
    scroll.offset_right = -12.0
    scroll.offset_bottom = -10.0

    var root := VBoxContainer.new()
    root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.custom_minimum_size = Vector2(760, 0)
    root.add_theme_constant_override("separation", 8)
    scroll.add_child(root)

    _label(root, "GAME-WEB-REGION-028｜合成事件预览修复候选｜NOT_RUN")
    _label(root, "来源：固定公开 EVENT_START / EVENT_NEXT / EVENT_END。只读结构检查与临时内存预览，不执行游戏事件、区域状态或存档。")
    _label(root, "条件输入必须由操作者填写；本界面不会从 trigger 自动读取 expected observation。")

    var start_row := HBoxContainer.new()
    root.add_child(start_row)
    _label(start_row, "起始事件：")
    _event_picker = OptionButton.new()
    _event_picker.custom_minimum_size = Vector2(190, 0)
    _event_picker.focus_mode = Control.FOCUS_ALL
    _event_picker.item_selected.connect(_on_start_selected)
    start_row.add_child(_event_picker)
    _start_button = _button(start_row, "开始 / 重置为所选起点", Callable(self, "_start_preview"))
    _button(start_row, "安全重新读取…", Callable(self, "_request_reload"))

    _status_label = _label(root, "")
    _gate_label = _label(root, "")
    _diagnostic_label = _label(root, "")
    _source_label = _label(root, "")

    _label(root, "手动输入当前事件的合成观察值（不是从事件定义自动填充）：")
    var signal_row := HBoxContainer.new()
    root.add_child(signal_row)
    _label(signal_row, "signal：")
    _signal_input = _line_edit(signal_row, "例如 SIGNAL_START")
    var conditions_row := HBoxContainer.new()
    root.add_child(conditions_row)
    _label(conditions_row, "conditions：")
    _conditions_input = _line_edit(conditions_row, "逗号分隔；允许留空，例如 FLAG_READY,FLAG_EXTRA")

    var observation_row := HBoxContainer.new()
    root.add_child(observation_row)
    _observe_button = _button(observation_row, "提交手动观察值", Callable(self, "_submit_observation"))
    _clear_observation_button = _button(observation_row, "清除当前事件观察值", Callable(self, "_clear_observation"))

    _label(root, "可选分支（只有当前事件门禁通过时才可选择）：")
    _choice_holder = VBoxContainer.new()
    root.add_child(_choice_holder)

    var navigation := HBoxContainer.new()
    root.add_child(navigation)
    _back_button = _button(navigation, "返回一步（保留 redo）", Callable(self, "_back"))
    _forward_button = _button(navigation, "前进一步（查看 redo）", Callable(self, "_forward"))
    _rollback_button = _button(navigation, "回滚到起点（丢弃后续）", Callable(self, "_rollback_root"))

    _route_label = _label(root, "")
    _trace_label = _label(root, "")
    _notice_label = _label(root, "")
    _label(root, "成功重载后清空预览 session；失败重载保留旧快照但强制只读。源 JSON 不写回。")

    _reload_dialog = ConfirmationDialog.new()
    _reload_dialog.title = "确认安全重载"
    _reload_dialog.dialog_text = "重新读取成功后会替换夹具并清空当前起点选择、手工输入、观察值与导航历史。继续吗？"
    _reload_dialog.confirmed.connect(_perform_reload)
    add_child(_reload_dialog)

func _request_reload() -> void:
    if not _fixture_ready:
        _perform_reload()
        return
    var state: Dictionary = _model.snapshot()
    var has_session: bool = bool(state.get("started", false)) or int(state.get("history_length", 0)) > 0 or not state.get("observations", {}).is_empty() or not _selected_start_event_id.is_empty() or not _signal_input.text.is_empty() or not _conditions_input.text.is_empty()
    if has_session:
        _reload_dialog.popup_centered()
    else:
        _perform_reload()

func _populate_picker(event_ids: Array, selected_id: String) -> void:
    _event_picker.clear()
    var selected_index := -1
    for event_id in event_ids:
        _event_picker.add_item(str(event_id))
        if str(event_id) == selected_id:
            selected_index = _event_picker.item_count - 1
    _event_picker.select(selected_index)

func _perform_reload() -> void:
    var previous_selection := _selected_start_event_id
    var result: Dictionary = _model.load_fixed_fixtures()
    var load_state: Dictionary = _model.load_status()
    _fixture_ready = bool(load_state.get("loaded", false))
    _stale = bool(load_state.get("stale", false))
    if bool(result.get("ok", false)):
        _selected_start_event_id = ""
        _populate_picker(_model.event_ids(), "")
        _signal_input.text = ""
        _conditions_input.text = ""
        _last_notice = "新夹具已完整校验并原子替换；预览处于等待显式选择起点状态。"
    else:
        if _fixture_ready:
            var preserved: Dictionary = _model.snapshot()
            var old_start: Variant = preserved.get("start_event_id")
            _selected_start_event_id = str(old_start) if old_start != null else previous_selection
            _populate_picker(_model.event_ids(), _selected_start_event_id)
            _last_notice = "重载失败：旧快照与历史已保留，但现已 STALE_BLOCKED，只读且禁止继续操作。原因：" + str(result.get("reason", "未知错误"))
        else:
            _selected_start_event_id = ""
            _populate_picker([], "")
            _last_notice = "BLOCKED：首次读取失败，没有可用夹具。原因：" + str(result.get("reason", "未知错误"))
    _refresh_view()

func _on_start_selected(index: int) -> void:
    if not _fixture_ready or _stale or index < 0:
        return
    _selected_start_event_id = _event_picker.get_item_text(index)
    _last_notice = "已选择起点 " + _selected_start_event_id + "；只有点击“开始 / 重置”才会改变预览状态。"
    _refresh_view()

func _start_preview() -> void:
    if not _fixture_ready or _stale or _selected_start_event_id.is_empty():
        return
    var result: Dictionary = _model.begin(_selected_start_event_id)
    if bool(result.get("ok", false)):
        _signal_input.text = ""
        _conditions_input.text = ""
        _last_notice = "已显式开始预览：" + _selected_start_event_id + "；观察值尚未提供。"
    else:
        _last_notice = "无法开始：" + str(result.get("reason", "未知错误"))
    _refresh_view()

func _parse_conditions_input() -> Array:
    var raw := _conditions_input.text.strip_edges()
    var conditions: Array = []
    if raw.is_empty():
        return conditions
    for token in raw.split(",", true):
        conditions.append(token.strip_edges())
    return conditions

func _sync_inputs_from_current_observation() -> void:
    var event_id := _model.current_event_id()
    if event_id.is_empty():
        _signal_input.text = ""
        _conditions_input.text = ""
        return
    var state: Dictionary = _model.snapshot()
    var observations: Dictionary = state.get("observations", {})
    if not observations.has(event_id):
        _signal_input.text = ""
        _conditions_input.text = ""
        return
    var observation: Dictionary = observations[event_id]
    _signal_input.text = str(observation.get("signal", ""))
    var conditions: Array = observation.get("conditions", [])
    var condition_tokens := PackedStringArray()
    for condition in conditions:
        condition_tokens.append(str(condition))
    _conditions_input.text = ", ".join(condition_tokens)

func _apply(command: Dictionary) -> void:
    if not _fixture_ready or _stale:
        return
    var before_event := _model.current_event_id()
    var result: Dictionary = _model.apply(command)
    if bool(result.get("ok", false)):
        var info: Dictionary = result.get("info", {})
        var effect: Dictionary = info.get("navigation_effect", {})
        _last_notice = str(result.get("operation", "操作")) + "：" + str(result.get("status", "完成"))
        if not effect.is_empty():
            _last_notice += "；导航策略 " + str(effect.get("policy", "")) + "；丢弃 " + str(effect.get("discarded_steps", 0)) + " 步"
        var after_event := _model.current_event_id()
        if before_event != after_event:
            _sync_inputs_from_current_observation()
    else:
        var error: Dictionary = result.get("error", {})
        var view: Dictionary = result.get("error_view", {})
        _last_notice = "REJECTED " + str(view.get("category", "review")) + " / " + str(view.get("title", "预览请求无法完成")) + " [" + str(error.get("code", "UNKNOWN")) + "]：" + str(error.get("message", ""))
        _last_notice += "；" + str(view.get("suggestion", "人工复核，不自动修复。"))
        var related: Array = view.get("related_sources", [])
        for item in related:
            _last_notice += "；来源 " + _format_source(item.get("source", {}))
        if error.has("available_choices"):
            _last_notice += "；当前可选分支：" + str(error.get("available_choices", []))
    _refresh_view()

func _submit_observation() -> void:
    var event_id := _model.current_event_id()
    if event_id.is_empty():
        return
    _apply({
        "op": "observe",
        "event_id": event_id,
        "signal": _signal_input.text.strip_edges(),
        "conditions": _parse_conditions_input()
    })

func _clear_observation() -> void:
    var event_id := _model.current_event_id()
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

func _format_source(value: Variant) -> String:
    if not (value is Dictionary) or value.is_empty():
        return "(无目标定义)"
    return "%s %s @ %s" % [
        str(value.get("file", "")),
        str(value.get("pointer", "")),
        str(value.get("sha256", "")).substr(0, 12)
    ]

func _refresh_view() -> void:
    if not is_node_ready():
        return
    if not _fixture_ready:
        _status_label.text = "事件来源状态：BLOCKED"
        _gate_label.text = "没有可选择的事件分支。"
        _diagnostic_label.text = "恢复：检查本目录固定公开 JSON 夹具后，显式重试读取。"
        _source_label.text = "不扫描其他目录，不使用真实事件，不自动切换备用数据。"
        _clear_children(_choice_holder)
        _back_button.disabled = true
        _forward_button.disabled = true
        _rollback_button.disabled = true
        _observe_button.disabled = true
        _clear_observation_button.disabled = true
        _start_button.disabled = true
        _event_picker.disabled = true
        _signal_input.editable = false
        _conditions_input.editable = false
        _route_label.text = "导航历史：无"
        _trace_label.text = "来源追溯：无"
        _notice_label.text = _last_notice
        return

    var state: Dictionary = _model.snapshot()
    _stale = bool(state.get("stale", false))
    _event_picker.disabled = _stale
    _start_button.disabled = _stale or _selected_start_event_id.is_empty()
    if _stale:
        _status_label.text = "事件来源状态：STALE_BLOCKED · 旧快照已保留，只读"
    else:
        _status_label.text = "事件来源状态：FIXTURE_READY · 预览 " + str(state.get("preview_status", "not_started"))
    _status_label.text += " · fixture SHA256 " + str(state.get("source_snapshot_sha256", ""))
    if bool(state.get("started", false)):
        _status_label.text += " · active start " + str(state.get("start_event_id", ""))

    if not bool(state.get("started", false)):
        _gate_label.text = "条件门禁：尚未开始；请选择起始事件并点击开始预览。"
        _diagnostic_label.text = "条件诊断：START_EVENT_REQUIRED。不会自动选择 EVENT_START 或第一个事件。"
        var selected_source: Dictionary = _model.source_for_event(_selected_start_event_id) if not _selected_start_event_id.is_empty() else {}
        _source_label.text = "所选起点来源：" + _format_source(selected_source)
        _clear_children(_choice_holder)
        _back_button.disabled = true
        _forward_button.disabled = true
        _rollback_button.disabled = true
        _observe_button.disabled = true
        _clear_observation_button.disabled = true
        _signal_input.editable = false
        _conditions_input.editable = false
        _route_label.text = "导航路径：尚未开始。"
        _trace_label.text = "来源追溯：开始预览后逐步记录 action / reference / target definition。"
        _notice_label.text = _last_notice
        return

    var current_value: Variant = state.get("current_event_id")
    var current_id: String = "" if current_value == null else str(current_value)
    var gate_value: Variant = state.get("condition_gate")
    var gate: Dictionary = gate_value if gate_value is Dictionary else {}
    var diagnosis: Dictionary = state.get("condition_diagnostics", {})
    var ready: bool = bool(gate.get("ready", false)) and not _stale
    var terminal: bool = current_id.is_empty()
    _gate_label.text = "当前事件：" + ("(终止)" if terminal else current_id)
    if not terminal:
        _gate_label.text += "｜门禁 " + ("READY" if ready else "BLOCKED")
        _gate_label.text += "｜observed signal " + str(gate.get("observed_signal", "(未提供)"))
        _gate_label.text += " / required " + str(gate.get("required_signal", ""))
        _gate_label.text += "｜missing " + str(gate.get("missing_conditions", []))
        _gate_label.text += "｜additional " + str(diagnosis.get("additional_observed_conditions", []))
    else:
        _gate_label.text += "｜终止分支，无后续事件。"

    var reason_text := "无阻断原因"
    var reasons: Array = diagnosis.get("reasons", [])
    if _stale:
        reason_text = "STALE_BLOCKED：" + str(state.get("stale_reason", "重载失败"))
    elif not reasons.is_empty():
        reason_text = ""
        for reason in reasons:
            if not reason_text.is_empty():
                reason_text += "；"
            reason_text += str(reason.get("code", "UNKNOWN")) + "：" + str(reason.get("detail", ""))
            reason_text += " @ " + _format_source(reason.get("source", {}))
    _diagnostic_label.text = "条件诊断：" + reason_text + "｜下一步：" + ("修复夹具后重新读取；当前旧快照只读。" if _stale else str(diagnosis.get("next_step", "")))

    var definition: Dictionary = _model.source_at_current()
    _source_label.text = "事件定义：" + _format_source(definition)
    if not gate.is_empty():
        var requirement_sources: Dictionary = gate.get("requirement_sources", {})
        _source_label.text += "｜signal 要求：" + _format_source(requirement_sources.get("signal", {}))
        _source_label.text += "｜conditions 要求：" + _format_source(requirement_sources.get("conditions", {}))

    _clear_children(_choice_holder)
    var configured: Array = state.get("configured_choices", [])
    var available: Array = state.get("available_choices", [])
    for option in configured:
        var choice_id := str(option.get("choice", ""))
        var target: Variant = option.get("target_event_id")
        var target_text := "(终止)" if target == null else str(target)
        var label := choice_id + " → " + target_text + ("（忽略）" if option.get("kind") == "ignore" else "")
        var item := _button(_choice_holder, label, Callable(self, "_choose").bind(choice_id))
        var enabled := false
        for candidate in available:
            if candidate.get("choice") == choice_id:
                enabled = true
                break
        item.disabled = _stale or not ready or not enabled
        var target_definition: Variant = option.get("target_definition")
        _label(_choice_holder, "action 来源：" + _format_source(option.get("source", {})) +
            "｜引用来源：" + _format_source(option.get("reference_source", {})) +
            "｜目标定义：" + _format_source(target_definition))

    _back_button.disabled = _stale or not bool(state.get("can_back", false))
    _forward_button.disabled = _stale or not bool(state.get("can_forward", false))
    _rollback_button.disabled = _stale or (int(state.get("cursor", 0)) == 0 and int(state.get("history_length", 0)) == 0)
    _observe_button.disabled = _stale or terminal
    _clear_observation_button.disabled = _stale or terminal or not state.get("observations", {}).has(current_id)
    _signal_input.editable = not _stale and not terminal
    _conditions_input.editable = not _stale and not terminal

    var positions: Array = state.get("navigation", {}).get("positions", [])
    var route_text := ""
    for position in positions:
        if not route_text.is_empty():
            route_text += " → "
        var position_event: Variant = position.get("event_id")
        var position_label := "(终止)" if position_event == null else str(position_event)
        route_text += str(position.get("cursor", 0)) + ":" + position_label + (" [已选]" if position.get("selected_prefix", false) else " [redo]")
    _route_label.text = "导航路径：" + route_text + "｜游标 " + str(state.get("cursor", 0)) + "/" + str(state.get("history_length", 0))

    var trace_lines := PackedStringArray()
    for entry in state.get("trace", []):
        trace_lines.append(
            str(entry.get("from_event_id", "")) + " --" + str(entry.get("selection", "")) +
            "--> " + ("(终止)" if entry.get("to_event_id") == null else str(entry.get("to_event_id", ""))) +
            "；action " + _format_source(entry.get("selected_at", {})) +
            "；reference " + _format_source(entry.get("reference_at", {})) +
            "；target " + _format_source(entry.get("target_definition"))
        )
    _trace_label.text = "来源追溯：" + ("无已选分支" if trace_lines.is_empty() else "\n".join(trace_lines))
    _notice_label.text = _last_notice
