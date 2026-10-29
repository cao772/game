extends Control
## GAME-WEB-FLOW-INPUT-004 r1 — standalone Godot Control UI candidate.
## Depends on PR #15 files without modifying them; NO global InputMap writes.
## Scene uses its own isolated root. No automatic load/save. NOT_RUN.

signal panel_closed
signal operation_finished(result: Dictionary)

const Backend = preload("res://flow_input_004/input_settings_ui_backend_004.gd")
const Bindings = preload("res://input_bindings_candidate.gd")

@export var v2_profile_path: String = "user://input_bindings_candidate_v2.json"
@export var legacy_profile_path: String = "user://input_bindings_candidate.json"

var backend = Backend.new()
var _rows: Dictionary = {}
var _status: Label
var _preview: Label
var _confirm_memory: Button
var _confirm_save: Button
var _cancel_button: Button
var _capture_action: StringName = &""
var _pending_kind: String = ""
var _pending_action: StringName = &""
var _pending_key: int = -1
var _pending_token: String = ""
var _pending_profile_hash: String = ""
var _preview_details: Dictionary = {}
var _blocked_router: Node = null
var _old_router_processing: bool = false


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    set_process_input(true)
    _build_ui()
    backend.profile_changed.connect(_on_profile_changed)
    _refresh_rows()
    _show_status("仅候选配置；打开界面不会自动读取或写入文件。")


func _exit_tree() -> void:
    _restore_router()
    backend.cancel_workflow()


func _build_ui() -> void:
    var panel := PanelContainer.new()
    panel.name = "SettingsPanel"
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(panel)

    var margin := MarginContainer.new()
    for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
        margin.add_theme_constant_override(side, 16)
    panel.add_child(margin)

    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 10)
    margin.add_child(stack)

    var title := Label.new()
    title.text = "输入设置｜独立技术候选"
    title.add_theme_font_size_override("font_size", 22)
    stack.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "配置仅影响本候选的按键映射，不修改 Godot 全局 InputMap。"
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(subtitle)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.custom_minimum_size = Vector2(0, 240)
    stack.add_child(scroll)
    var list := VBoxContainer.new()
    list.name = "BindingRows"
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(list)

    for action in Bindings.ACTIONS:
        var line := HBoxContainer.new()
        list.add_child(line)
        var action_label := Label.new()
        action_label.text = _action_title(action)
        action_label.custom_minimum_size.x = 150
        action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        line.add_child(action_label)

        var key_button := Button.new()
        key_button.name = "Bind_" + action
        key_button.custom_minimum_size.x = 120
        key_button.pressed.connect(begin_rebind.bind(StringName(action)))
        key_button.tooltip_text = "选择新的逻辑键位"
        line.add_child(key_button)

        var reset_button := Button.new()
        reset_button.name = "Reset_" + action
        reset_button.text = "恢复此项"
        reset_button.pressed.connect(preview_reset_action.bind(StringName(action)))
        line.add_child(reset_button)
        _rows[action] = key_button

    var actions := HBoxContainer.new()
    stack.add_child(actions)
    _add_button(actions, "读取 V2 配置", Callable(self, "load_current"))
    _add_button(actions, "保存当前配置", Callable(self, "save_current"))
    _add_button(actions, "迁移已有 V1", Callable(self, "preview_migration"))
    _add_button(actions, "恢复全部默认", Callable(self, "preview_restore_all"))

    _status = Label.new()
    _status.name = "StatusMessage"
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(_status)

    _preview = Label.new()
    _preview.name = "PreviewMessage"
    _preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(_preview)

    var confirms := HBoxContainer.new()
    stack.add_child(confirms)
    _confirm_memory = _add_button(confirms, "仅本次应用", Callable(self, "apply_memory"))
    _confirm_save = _add_button(confirms, "保存后应用", Callable(self, "apply_and_save"))
    _cancel_button = _add_button(confirms, "取消操作", Callable(self, "cancel_preview"))
    _confirm_memory.disabled = true
    _confirm_save.disabled = true
    _cancel_button.disabled = true

    var bottom := HBoxContainer.new()
    stack.add_child(bottom)
    _add_button(bottom, "关闭设置", Callable(self, "close_panel"))
    var hint := Label.new()
    hint.text = "Esc 也可以被重新绑定；取消操作请使用按钮。"
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    bottom.add_child(hint)


func _add_button(parent: Node, caption: String,
        callback: Callable) -> Button:
    var button := Button.new()
    button.text = caption
    button.pressed.connect(callback)
    parent.add_child(button)
    return button


func _action_title(action_id: String) -> String:
    match action_id:
        "observe":
            return "观察"
        "open_door":
            return "开门"
        "withdraw":
            return "退出当前操作"
        "reset_round":
            return "重置回合"
        "cancel":
            return "取消"
    return action_id


func _refresh_rows() -> void:
    if _rows.is_empty():
        return
    for action in Bindings.ACTIONS:
        var code := backend.workflow.settings.bindings.binding_for(StringName(action))
        var label := backend.key_label(code)
        var default_code := backend.workflow.settings.bindings.default_binding_for(
            StringName(action)
        )
        if code != default_code:
            label += "  (已修改)"
        var button: Button = _rows[action]
        button.text = label


func _on_profile_changed(_profile: Dictionary) -> void:
    _refresh_rows()


func _show_status(message: String) -> void:
    if _status != null:
        _status.text = message


func _display_result(result: Dictionary) -> void:
    var prefix := "完成" if result.get("ok", false) else "未执行"
    if not result.get("ok", false) and result.get("committed", false):
        prefix = "需复核：磁盘可能已变更"
    _show_status("%s｜%s：%s" % [
        prefix, str(result.get("code", "UNKNOWN")),
        str(result.get("message", ""))
    ])
    operation_finished.emit(result.duplicate(true))
    _refresh_rows()


func _profile_hash() -> String:
    return JSON.stringify(backend.profile()).sha256_text()


func _reset_pending() -> void:
    _capture_action = &""
    _pending_kind = ""
    _pending_action = &""
    _pending_key = -1
    _pending_token = ""
    _pending_profile_hash = ""
    _preview_details.clear()
    if _preview != null:
        _preview.text = ""
    if _confirm_memory != null:
        _confirm_memory.disabled = true
        _confirm_save.disabled = true
        _cancel_button.disabled = true


func _set_confirmation(memory_allowed: bool, save_allowed: bool) -> void:
    _confirm_memory.disabled = not memory_allowed
    _confirm_save.disabled = not save_allowed
    _cancel_button.disabled = false


func _preview_summary(preview: Dictionary) -> String:
    var text := "预览｜%s" % str(preview.get("explanation",
        preview.get("message", "")))
    if preview.has("proposed_key_label"):
        text += "\n拟使用键位：" + str(preview["proposed_key_label"])
    for conflict in preview.get("conflicts", []):
        var descriptions := PackedStringArray()
        for owner in conflict.get("owners", []):
            descriptions.append(_action_title(str(owner.get("action_id", ""))))
        text += "\n冲突：" + str(conflict.get("key_label", "")) + \
            " 已关联 " + "、".join(descriptions)
    var suggestions := PackedStringArray()
    for suggestion in preview.get("alternatives", []):
        suggestions.append(str(suggestion.get("key_label", "")))
    if not suggestions.is_empty():
        text += "\n可尝试其他空闲键：" + "、".join(suggestions)
    for step in preview.get("next_steps", []):
        text += "\n· " + str(step)
    return text


# Public test seam: begin rebind, inject logical keycode, then apply/cancel.
func begin_rebind(action_id: StringName) -> void:
    _reset_pending()
    if not Bindings.ACTIONS.has(String(action_id)):
        _show_status("未知动作，不接收输入。")
        return
    _capture_action = action_id
    _cancel_button.disabled = false
    _show_status("按下希望绑定的按键；Esc 可设为键位，取消请点“取消操作”。")
    _preview.text = "等待单次键盘按下；不会立刻修改配置。"


# During capture _input precedes the PR #15 unhandled-key dispatch.
# Even rejected keys are marked handled so they cannot leak into the game.
func _input(event: InputEvent) -> void:
    if _capture_action == &"" or not is_visible_in_tree():
        return
    if not event is InputEventKey:
        return
    get_viewport().set_input_as_handled()
    var key := event as InputEventKey
    if not key.pressed or key.echo:
        return
    if key.ctrl_pressed or key.alt_pressed \
            or key.shift_pressed or key.meta_pressed:
        _show_status("不支持组合键，请只按一个逻辑键，或取消。")
        return
    preview_key_candidate(int(key.keycode))


func preview_key_candidate(code: int) -> Dictionary:
    if _capture_action == &"":
        return {"ok": false, "code": "NO_CAPTURE"}
    var action := _capture_action
    _capture_action = &""
    var details := backend.preview(action, code)
    _pending_kind = "rebind"
    _pending_action = action
    _pending_key = code
    _pending_profile_hash = _profile_hash()
    _preview_details = details.duplicate(true)
    _preview.text = _preview_summary(details)
    var can_apply: bool = bool(details.get("can_apply", false))
    _set_confirmation(can_apply, can_apply)
    _show_status("待确认：检查冲突并选择仅应用或保存后应用。" if can_apply
        else "键位冲突或无效：请取消并重新选择。")
    return details.duplicate(true)


func preview_reset_action(action_id: StringName) -> Dictionary:
    _reset_pending()
    var details := backend.workflow.settings.preview_reset_action(action_id)
    if not details.get("can_apply", false):
        _show_status("此项默认键位已被其他动作占用，请先处理冲突或恢复全部默认。")
    else:
        _show_status("待确认：仅恢复这一项，不会改变其他动作的键位。")
    _pending_kind = "reset_one"
    _pending_action = action_id
    _pending_key = int(backend.workflow.settings.bindings.default_binding_for(action_id))
    _pending_profile_hash = _profile_hash()
    _preview_details = details.duplicate(true)
    _preview.text = _preview_summary(details)
    _set_confirmation(bool(details.get("can_apply", false)),
        bool(details.get("can_apply", false)))
    return details.duplicate(true)


func preview_restore_all() -> Dictionary:
    _reset_pending()
    var details := backend.preview_restore()
    _pending_kind = "restore_all"
    _pending_profile_hash = _profile_hash()
    _preview_details = details.duplicate(true)
    var change_lines := PackedStringArray()
    for change in details.get("changes", []):
        change_lines.append("%s：%s → %s" % [
            _action_title(str(change["action_id"])),
            str(change["from_label"]), str(change["to_label"])
        ])
    _preview.text = "恢复全部默认：" + (
        "\n" + "\n".join(change_lines) if not change_lines.is_empty()
        else "\n已经是默认键位。")
    _show_status("恢复全部默认会替换五个动作的当前按键，需再次确认。")
    _set_confirmation(true, true)
    return details.duplicate(true)


func preview_migration() -> Dictionary:
    _reset_pending()
    var result := backend.preview_migration(legacy_profile_path, v2_profile_path)
    if not result.get("ok", false):
        _display_result(result)
        return result
    _pending_kind = "migration"
    _pending_token = str(result.get("confirmation_token", ""))
    _pending_profile_hash = _profile_hash()
    _preview_details = result.duplicate(true)
    _preview.text = "迁移预览：旧 V1 将保留，仅新增独立 V2 文件。" + \
        "\n目标：" + str(result.get("destination", ""))
    for change in result.get("changes", []):
        _preview.text += "\n%s：%s → %s" % [
            _action_title(str(change["action_id"])),
            str(change["from_label"]), str(change["to_label"])
        ]
    _show_status("只有确认“保存后应用”才执行迁移。")
    _set_confirmation(false, true)
    return result.duplicate(true)


func _pending_is_current() -> bool:
    return not _pending_kind.is_empty() and _pending_profile_hash == _profile_hash()


func apply_memory() -> Dictionary:
    if not _pending_is_current():
        _reset_pending()
        var stale := {"ok": false, "code": "STALE_PREVIEW",
            "message": "配置已变化，请重新预览"}
        _display_result(stale)
        return stale
    var result: Dictionary
    match _pending_kind:
        "rebind", "reset_one":
            if not _preview_details.get("can_apply", false):
                result = {"ok": false, "code": "CONFLICT",
                    "message": "冲突不能应用"}
            else:
                result = backend.rebind_memory(_pending_action, _pending_key)
        "restore_all":
            result = backend.restore_defaults_memory()
        _:
            result = {"ok": false, "code": "CONFIRM_REQUIRED",
                "message": "迁移必须通过持久化确认"}
    _reset_pending()
    _display_result(result)
    return result


func apply_and_save() -> Dictionary:
    if not _pending_is_current():
        _reset_pending()
        var stale := {"ok": false, "code": "STALE_PREVIEW",
            "message": "配置已变化，请重新预览"}
        _display_result(stale)
        return stale
    var result: Dictionary
    match _pending_kind:
        "rebind", "reset_one":
            if not _preview_details.get("can_apply", false):
                result = {"ok": false, "code": "CONFLICT",
                    "message": "冲突不能持久化"}
            else:
                result = backend.rebind_and_save(
                    _pending_action, _pending_key, v2_profile_path)
        "restore_all":
            result = backend.restore_defaults_and_save(v2_profile_path)
        "migration":
            result = backend.confirm_migration(_pending_token, v2_profile_path)
        _:
            result = {"ok": false, "code": "NO_PENDING",
                "message": "没有待确认操作"}
    _reset_pending()
    _display_result(result)
    return result


func cancel_preview() -> void:
    backend.cancel_workflow()
    _reset_pending()
    _show_status("已取消，未应用此次待确认操作。")


func save_current() -> Dictionary:
    cancel_preview()
    var result := backend.save_current(v2_profile_path)
    _display_result(result)
    return result


func load_current() -> Dictionary:
    cancel_preview()
    var result := backend.load_v2(v2_profile_path)
    _display_result(result)
    return result


# Host may opt in to temporarily disable its PR #15 keyboard adapter while
# the settings panel is visible. No auto attachment or global scene changes.
func open_for_router(router: Node = null) -> Dictionary:
    _restore_router()
    if router != null:
        if not is_instance_valid(router) or not router.is_inside_tree():
            return {"ok": false, "code": "INVALID_ROUTER"}
        _blocked_router = router
        _old_router_processing = router.is_processing_unhandled_key_input()
        router.set_process_unhandled_key_input(false)
    show()
    return {"ok": true, "code": "PANEL_OPEN"}


func _restore_router() -> void:
    if is_instance_valid(_blocked_router):
        _blocked_router.set_process_unhandled_key_input(_old_router_processing)
    _blocked_router = null
    _old_router_processing = false


func close_panel() -> void:
    cancel_preview()
    _restore_router()
    hide()
    panel_closed.emit()


func ui_state() -> Dictionary:
    return {
        "capture_action": String(_capture_action),
        "pending_kind": _pending_kind,
        "pending_action": String(_pending_action),
        "pending_key": _pending_key,
        "status": _status.text if _status != null else "",
        "preview": _preview.text if _preview != null else "",
        "profile": backend.profile(),
        "can_apply_memory": _confirm_memory != null and not _confirm_memory.disabled,
        "can_apply_save": _confirm_save != null and not _confirm_save.disabled
    }
