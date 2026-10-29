extends "res://flow_input_004/input_settings_panel_004.gd"
## GAME-WEB-PLAY-INPUT-005 r1 — isolated revision of PR #19 panel.
## Does not edit 004, PR #15, InputMap, save core or game scene.
## Authoring/test status: NOT_RUN.

signal recoverable_save_failure(result: Dictionary)

const TRANSIENT_SAVE_ERRORS := [
    "TEMP_OCCUPIED", "WRITE_FAILED", "RENAME_FAILED", "MISSING_DIRECTORY"
]
const REVIEW_REQUIRED_ERRORS := [
    "LOAD_REQUIRED", "EXTERNAL_CHANGE", "EXTERNAL_DELETE",
    "INVALID_EXISTING", "MALFORMED_JSON", "INVALID_PROFILE",
    "POST_WRITE_VERIFY_FAILED", "COMMITTED_NEEDS_RELOAD",
    "MIGRATION_COMMITTED_NEEDS_RELOAD", "TARGET_EXISTS",
    "OCCUPIED_PATH", "INVALID_PATH"
]

var _retry_button: Button
var _repreview_button: Button
var _alternatives_bar: HBoxContainer
var _recovery_label: Label
var _retry_kind: String = ""
var _retry_profile_digest: String = ""
var _retry_disk_path: String = ""
var _last_result: Dictionary = {}
var _last_preview_action: StringName = &""
var _panel_safety_warning: String = ""
var _reviewed_v2_path: String = ""
var _reviewed_legacy_path: String = ""


func _ready() -> void:
    super._ready()
    _build_recovery_controls()
    visibility_changed.connect(_on_panel_visibility_changed)


func _build_recovery_controls() -> void:
    # The parent candidate constructs PanelContainer > MarginContainer > VBox.
    var panel := get_node_or_null("SettingsPanel")
    if panel == null or panel.get_child_count() == 0:
        return
    var margin := panel.get_child(0)
    if margin.get_child_count() == 0:
        return
    var stack := margin.get_child(0) as VBoxContainer
    if stack == null:
        return

    var caption := Label.new()
    caption.name = "RecoveryHeading"
    caption.text = "候选操作与失败恢复"
    caption.add_theme_font_size_override("font_size", 16)
    stack.add_child(caption)

    _recovery_label = Label.new()
    _recovery_label.name = "RecoveryMessage"
    _recovery_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _recovery_label.text = "重绑定先预览；写入失败不会自动改为只在内存应用。"
    stack.add_child(_recovery_label)

    _alternatives_bar = HBoxContainer.new()
    _alternatives_bar.name = "AvailableKeyAlternatives"
    stack.add_child(_alternatives_bar)

    var recovery_controls := HBoxContainer.new()
    recovery_controls.name = "RecoveryControls"
    stack.add_child(recovery_controls)
    _retry_button = Button.new()
    _retry_button.name = "RetrySave"
    _retry_button.text = "重试保存"
    _retry_button.disabled = true
    _retry_button.pressed.connect(retry_save)
    recovery_controls.add_child(_retry_button)

    _repreview_button = Button.new()
    _repreview_button.name = "Repreview"
    _repreview_button.text = "重新预览"
    _repreview_button.disabled = true
    _repreview_button.pressed.connect(repreview)
    recovery_controls.add_child(_repreview_button)


func _clear_alternatives() -> void:
    if _alternatives_bar == null:
        return
    for node in _alternatives_bar.get_children():
        _alternatives_bar.remove_child(node)
        node.queue_free()


func _show_alternatives(preview: Dictionary) -> void:
    _clear_alternatives()
    if _alternatives_bar == null or _pending_kind != "rebind":
        return
    if preview.get("can_apply", false):
        return
    if str(preview.get("code", "")) != "CONFLICT":
        return
    for alternative in preview.get("alternatives", []):
        if typeof(alternative) != TYPE_DICTIONARY:
            continue
        var keycode := int(alternative.get("keycode", -1))
        var label := str(alternative.get("key_label", ""))
        var button := Button.new()
        button.text = "改用 " + label
        button.name = "Alternative_" + str(keycode)
        button.pressed.connect(_select_alternative.bind(keycode))
        _alternatives_bar.add_child(button)


func _select_alternative(keycode: int) -> void:
    if _pending_kind != "rebind" or _pending_action == &"":
        return
    var action := _pending_action
    begin_rebind(action)
    preview_key_candidate(keycode)


func _clear_retry() -> void:
    _retry_kind = ""
    _retry_profile_digest = ""
    _retry_disk_path = ""
    if _retry_button != null:
        _retry_button.disabled = true


func _clear_recovery() -> void:
    _clear_retry()
    if _repreview_button != null:
        _repreview_button.disabled = true
    if _recovery_label != null:
        _recovery_label.text = ""
    _last_result.clear()


func _profile_digest_now() -> String:
    return JSON.stringify(backend.profile()).sha256_text()


func _result_dict(ok: bool, code: String, message: String) -> Dictionary:
    return {"ok": ok, "code": code, "message": message,
        "changed": false, "persisted": false, "committed": false}


func _failed_save(result: Dictionary, origin: String) -> void:
    _last_result = result.duplicate(true)
    var code := str(result.get("code", "UNKNOWN"))
    var committed := bool(result.get("committed", false))
    _clear_retry()

    if committed:
        _reset_pending()
        _clear_alternatives()
        _recovery_label.text = "磁盘可能已提交，内存结果未确认。请人工核对目标文件，再显式读取；禁止自动重试。"
        _repreview_button.disabled = true
        return

    if TRANSIENT_SAVE_ERRORS.has(code) and origin != "migration":
        # Retain precisely the reviewed proposal. Retry only after a new
        # explicit click, and only if memory and destination are unchanged.
        _retry_kind = origin
        _retry_profile_digest = _profile_digest_now()
        _retry_disk_path = v2_profile_path
        _retry_button.disabled = false
        _repreview_button.disabled = false
        if origin == "pending":
            _confirm_memory.disabled = true
            _confirm_save.disabled = true
            _cancel_button.disabled = false
        _recovery_label.text = "未写入磁盘，当前键位保持不变。可修复文件条件后点“重试保存”，或取消。"
        recoverable_save_failure.emit(result.duplicate(true))
        return

    # A one-use migration token is consumed by PR #15 on confirmation.
    # Stale/external/invalid profiles must not be retried or overwritten.
    _reset_pending()
    _clear_alternatives()
    _repreview_button.disabled = true
    if REVIEW_REQUIRED_ERRORS.has(code) or origin == "migration":
        _recovery_label.text = "目标配置需复核。没有执行自动修复、覆盖或恢复默认；请检查文件后显式读取或重新预览。"
    else:
        _recovery_label.text = "保存未完成，未执行内存回退或自动重试。请查看错误说明。"


func begin_rebind(action_id: StringName) -> void:
    _clear_recovery()
    _clear_alternatives()
    _last_preview_action = action_id
    _reviewed_v2_path = v2_profile_path
    _reviewed_legacy_path = legacy_profile_path
    super.begin_rebind(action_id)


# Handle ALL key events during capture, even rejected ones: do not leak
# them to the host's unhandled input. Actual focus gate is runtime only;
# headless acceptance uses preview_key_candidate's injectable seam.
func _input(event: InputEvent) -> void:
    if _capture_action == &"" or not is_visible_in_tree():
        return
    if not event is InputEventKey:
        return
    get_viewport().set_input_as_handled()
    if not is_inside_tree() or get_tree().paused or not get_window().has_focus():
        _show_status("窗口未聚焦或已暂停；不会接受此次按键。")
        return
    var key := event as InputEventKey
    if not key.pressed or key.echo:
        return
    if key.ctrl_pressed or key.alt_pressed or key.shift_pressed or key.meta_pressed:
        _show_status("不支持组合键；请按单独键位或点取消。")
        return
    preview_key_candidate(int(key.keycode))


func preview_key_candidate(code: int) -> Dictionary:
    _clear_retry()
    var result := super.preview_key_candidate(code)
    _show_alternatives(result)
    if _recovery_label != null and result.get("can_apply", false):
        _recovery_label.text = "尚未写盘，确认后才会修改按键。"
    return result


func preview_reset_action(action_id: StringName) -> Dictionary:
    _clear_recovery()
    _clear_alternatives()
    _last_preview_action = action_id
    _reviewed_v2_path = v2_profile_path
    _reviewed_legacy_path = legacy_profile_path
    return super.preview_reset_action(action_id)


func preview_restore_all() -> Dictionary:
    _clear_recovery()
    _clear_alternatives()
    _last_preview_action = &""
    _reviewed_v2_path = v2_profile_path
    _reviewed_legacy_path = legacy_profile_path
    return super.preview_restore_all()


func preview_migration() -> Dictionary:
    _clear_recovery()
    _clear_alternatives()
    _last_preview_action = &""
    _reviewed_v2_path = v2_profile_path
    _reviewed_legacy_path = legacy_profile_path
    return super.preview_migration()


func apply_memory() -> Dictionary:
    _clear_retry()
    _clear_alternatives()
    var result := super.apply_memory()
    if result.get("ok", false):
        _repreview_button.disabled = true
        if _recovery_label != null:
            _recovery_label.text = "已应用到本次内存配置；未自动保存到磁盘。"
    return result


func _save_pending_once() -> Dictionary:
    var result: Dictionary
    match _pending_kind:
        "rebind", "reset_one":
            if not _preview_details.get("can_apply", false):
                return _result_dict(false, "CONFLICT", "冲突预览不可提交")
            result = backend.rebind_and_save(
                _pending_action, _pending_key, v2_profile_path)
        "restore_all":
            result = backend.restore_defaults_and_save(v2_profile_path)
        "migration":
            result = backend.confirm_migration(_pending_token, v2_profile_path)
        _:
            result = _result_dict(false, "NO_PENDING", "没有待确认的配置变更")
    return result


func apply_and_save() -> Dictionary:
    if _reviewed_v2_path != v2_profile_path \
            or _reviewed_legacy_path != legacy_profile_path:
        _reset_pending()
        _clear_retry()
        var path_changed := _result_dict(false, "STALE_PATH", "配置路径已改变，请重新预览")
        _display_result(path_changed)
        return path_changed
    if not _pending_is_current() or not _preview_details.get("ok", false):
        _reset_pending()
        _clear_alternatives()
        var stale := _result_dict(false, "STALE_PREVIEW", "配置已变化，请重新预览")
        _display_result(stale)
        return stale

    var origin := "migration" if _pending_kind == "migration" else "pending"
    var result := _save_pending_once()
    if result.get("ok", false):
        _reset_pending()
        _clear_recovery()
        _clear_alternatives()
        _display_result(result)
        if _recovery_label != null:
            _recovery_label.text = "已验证配置保存步骤，并将有效配置应用到内存。"
        return result

    _failed_save(result, origin)
    _display_result(result)
    return result


func save_current() -> Dictionary:
    _clear_recovery()
    _clear_alternatives()
    # Base implementation cancels any outstanding preview before saving.
    var result := super.save_current()
    if result.get("ok", false):
        return result
    _failed_save(result, "save_current")
    return result


func load_current() -> Dictionary:
    _clear_recovery()
    _clear_alternatives()
    return super.load_current()


func retry_save() -> Dictionary:
    if _retry_kind.is_empty() or _retry_button == null:
        return _result_dict(false, "NO_RETRY", "没有可重试的保存操作")
    if _retry_disk_path != v2_profile_path \
            or _retry_profile_digest != _profile_digest_now():
        _reset_pending()
        _clear_recovery()
        var changed := _result_dict(false, "STALE_RETRY",
            "文件路径或内存配置已变化，请重新预览")
        _display_result(changed)
        return changed

    var kind := _retry_kind
    _clear_retry()
    if kind == "save_current":
        return save_current()
    if not _pending_is_current() or not _preview_details.get("ok", false):
        _reset_pending()
        return _result_dict(false, "STALE_RETRY", "待确认操作已失效")
    # Explicit user retry, same proposal. The backend rechecks the file
    # against its current known digest every time; no blind overwrite.
    return apply_and_save()


func repreview() -> Dictionary:
    # New preview invalidates prior confirmation tokens; no persistence.
    var kind := _pending_kind
    var action := _pending_action
    var code := _pending_key
    _clear_recovery()
    match kind:
        "rebind":
            begin_rebind(action)
            return preview_key_candidate(code)
        "reset_one":
            return preview_reset_action(action)
        "restore_all":
            return preview_restore_all()
        "migration":
            return preview_migration()
    return _result_dict(false, "NO_PENDING", "没有待重新预览的操作")


func cancel_preview() -> void:
    super.cancel_preview()
    _clear_recovery()
    _clear_alternatives()
    _last_preview_action = &""


func close_panel() -> void:
    super.close_panel()
    _clear_recovery()
    _clear_alternatives()


func _on_panel_visibility_changed() -> void:
    if not visible:
        # A host may hide the node without calling close_panel().
        cancel_preview()
        _restore_router()


func open_for_router(router: Node = null) -> Dictionary:
    var result := super.open_for_router(router)
    if result.get("ok", false) and router == null:
        _panel_safety_warning = "未提供宿主键盘路由节点：仅用于独立预览；嵌入游戏前须接入路由暂停。"
        _show_status(_panel_safety_warning)
    else:
        _panel_safety_warning = ""
    return result


func ui_state_005() -> Dictionary:
    var state := ui_state()
    state["retry_available"] = _retry_button != null and not _retry_button.disabled
    state["repreview_available"] = _repreview_button != null and not _repreview_button.disabled
    state["retry_kind"] = _retry_kind
    state["last_result"] = _last_result.duplicate(true)
    state["recovery_message"] = _recovery_label.text if _recovery_label != null else ""
    state["host_router_warning"] = _panel_safety_warning
    return state
