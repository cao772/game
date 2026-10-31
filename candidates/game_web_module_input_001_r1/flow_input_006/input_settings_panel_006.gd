extends "res://flow_input_005/input_settings_panel_005.gd"
## GAME-WEB-INPUT-006 r1 — independent optional swap/undo/focus panel.
## Uses unchanged PR #19 and PR #15 candidates; NEVER InputMap.
## Source-only development. Godot/tests/CI: NOT_RUN.

const Planner006 = preload("res://flow_input_006/input_change_planner_006.gd")

var change_planner = Planner006.new()
var _swap_button: Button = null
var _undo_button: Button = null
var _focus_message: Label = null
var _swap_candidate: Dictionary = {}
var _undo_plan: Dictionary = {}
var _return_focus: Control = null
var _focus_origin: Control = null


func _ready() -> void:
    super._ready()
    _install_controls_006()
    _arrange_tab_order()
    _refresh_undo()


func _install_controls_006() -> void:
    var panel := get_node_or_null("SettingsPanel")
    if panel == null or panel.get_child_count() == 0:
        return
    var margin := panel.get_child(0)
    if margin.get_child_count() == 0:
        return
    var stack := margin.get_child(0) as VBoxContainer
    if stack == null:
        return

    var heading := Label.new()
    heading.text = "冲突处理与撤销（候选）"
    heading.add_theme_font_size_override("font_size", 16)
    stack.add_child(heading)

    var controls := HBoxContainer.new()
    controls.name = "ResolveAndUndoControls"
    stack.add_child(controls)

    _swap_button = Button.new()
    _swap_button.name = "PreviewSwap"
    _swap_button.text = "预览交换占用键"
    _swap_button.tooltip_text = "双方按键同时交换；不会直接应用，仍需再次确认"
    _swap_button.disabled = true
    _swap_button.pressed.connect(choose_swap)
    controls.add_child(_swap_button)

    _undo_button = Button.new()
    _undo_button.name = "PreviewUndo"
    _undo_button.text = "撤销上次配置变更"
    _undo_button.tooltip_text = "预览上一项成功变更；磁盘变更必须保存后撤销"
    _undo_button.disabled = true
    _undo_button.pressed.connect(preview_undo)
    controls.add_child(_undo_button)

    _focus_message = Label.new()
    _focus_message.name = "AccessibleFocusHint"
    _focus_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _focus_message.text = "Tab / Shift+Tab 切换按钮，Enter 或空格确认；捕获键位时按 Backspace 取消。"
    stack.add_child(_focus_message)

    # Existing rows are retained exactly; supply descriptive tooltips
    # without changing their configured action IDs or key bindings.
    for action in _rows:
        var row_button: Button = _rows[action]
        row_button.tooltip_text = "修改“%s”的按键；选择后先预览" % _action_title(str(action))
        row_button.focus_mode = Control.FOCUS_ALL


func _collect_buttons(node: Node, result: Array[Button]) -> void:
    for child in node.get_children():
        if child is Button:
            result.append(child as Button)
        _collect_buttons(child, result)


func _arrange_tab_order() -> void:
    var all_buttons: Array[Button] = []
    _collect_buttons(self, all_buttons)
    if all_buttons.is_empty():
        return
    for i in range(all_buttons.size()):
        var button := all_buttons[i]
        button.focus_mode = Control.FOCUS_ALL
        var next_button := all_buttons[(i + 1) % all_buttons.size()]
        var prior_button := all_buttons[(i - 1 + all_buttons.size()) % all_buttons.size()]
        button.focus_next = button.get_path_to(next_button)
        button.focus_previous = button.get_path_to(prior_button)
        if button.tooltip_text.is_empty():
            button.tooltip_text = button.text
        if not button.focus_entered.is_connected(_on_control_focused):
            button.focus_entered.connect(_on_control_focused.bind(button))


func _on_control_focused(button: Button) -> void:
    if _focus_message == null:
        return
    _focus_message.text = "焦点：" + button.text + \
        "。Tab 切换，Enter/空格选择；等待按键绑定时 Backspace 取消。"


func _focus_first() -> void:
    if _rows.has("observe"):
        var first: Button = _rows["observe"]
        if first.is_inside_tree() and first.visible and not first.disabled:
            first.grab_focus()


func _return_to_origin() -> void:
    if is_instance_valid(_focus_origin) and _focus_origin.is_inside_tree() \
            and _focus_origin.visible and not _focus_origin.is_disabled():
        _focus_origin.grab_focus()
    _focus_origin = null


func _refresh_undo() -> void:
    if _undo_button == null:
        return
    var available: Dictionary = change_planner.peek(backend.profile(), v2_profile_path)
    _undo_button.disabled = not available.get("ok", false)
    _undo_button.tooltip_text = "预览撤销；不自动恢复旧磁盘文件" if available.get(
        "ok", false) else "当前没有可安全撤销的配置变更"


func _clear_swap() -> void:
    _swap_candidate.clear()
    if _swap_button != null:
        _swap_button.disabled = true


func _offer_swap(action: StringName, keycode: int) -> void:
    _clear_swap()
    var result: Dictionary = change_planner.preview_swap(
        backend.workflow.settings, action, keycode
    )
    if result.get("ok", false):
        _swap_candidate = result.duplicate(true)
        _swap_button.disabled = false
        _swap_button.tooltip_text = "预览“%s”和“%s”交换按键" % [
            _action_title(str(result["action_id"])),
            _action_title(str(result["owner_action"]))
        ]
        _show_status("当前按键被占用：可选空闲键，或点击“预览交换占用键”。")
    _arrange_tab_order()


func _show_alternatives(preview: Dictionary) -> void:
    super._show_alternatives(preview)
    _arrange_tab_order()


func begin_rebind(action_id: StringName) -> void:
    _clear_swap()
    _undo_plan.clear()
    if _rows.has(String(action_id)):
        _focus_origin = _rows[String(action_id)]
    super.begin_rebind(action_id)
    _refresh_undo()


# Backspace is intentionally outside the supported bindable-key whitelist
# of PR #15: keyboard-only users can cancel a capture without a mouse.
# Escape remains configurable; it is not taken over for UI cancellation.
func _input(event: InputEvent) -> void:
    if _capture_action != &"" and is_visible_in_tree() \
            and event is InputEventKey:
        var key := event as InputEventKey
        if key.pressed and not key.echo and key.keycode == KEY_BACKSPACE \
                and not key.ctrl_pressed and not key.alt_pressed \
                and not key.shift_pressed and not key.meta_pressed:
            get_viewport().set_input_as_handled()
            cancel_preview()
            return
    super._input(event)


func preview_key_candidate(code: int) -> Dictionary:
    _clear_swap()
    var result := super.preview_key_candidate(code)
    if result.get("code", "") == "CONFLICT":
        _offer_swap(_pending_action, code)
    else:
        _arrange_tab_order()
    return result


func preview_reset_action(action_id: StringName) -> Dictionary:
    _clear_swap()
    _undo_plan.clear()
    if _rows.has(String(action_id)):
        _focus_origin = _rows[String(action_id)]
    var result := super.preview_reset_action(action_id)
    if result.get("code", "") == "CONFLICT":
        _offer_swap(action_id, _pending_key)
    return result


func preview_restore_all() -> Dictionary:
    _clear_swap()
    _undo_plan.clear()
    return super.preview_restore_all()


func preview_migration() -> Dictionary:
    _clear_swap()
    _undo_plan.clear()
    return super.preview_migration()


# Swap is always an explicit SECOND preview, not a collision auto-fix.
func choose_swap() -> Dictionary:
    if _swap_candidate.is_empty() or not _swap_candidate.get("ok", false):
        return {"ok": false, "code": "NO_SWAP", "message": "没有可交换的键位"}
    if change_planner.digest(backend.profile()) != str(_swap_candidate["base_digest"]):
        _clear_swap()
        _reset_pending()
        var stale := {"ok": false, "code": "SWAP_STALE",
            "message": "配置已变化，请重新选择键位"}
        _display_result(stale)
        return stale
    var plan := _swap_candidate.duplicate(true)
    _clear_swap()
    _pending_kind = "swap"
    _pending_action = StringName(plan["action_id"])
    _pending_key = int(plan["occupied_keycode"])
    _pending_profile_hash = _profile_hash()
    _preview_details = {"ok": true, "can_apply": true, "code": "SWAP_READY"}
    _swap_candidate = plan.duplicate(true)
    _preview.text = "交换预览（不自动执行）"
    for change in plan["changes"]:
        _preview.text += "\n%s：%s → %s" % [
            _action_title(str(change["action_id"])),
            backend.key_label(int(change["from_keycode"])),
            backend.key_label(int(change["to_keycode"]))
        ]
    _set_confirmation(true, true)
    _show_status("交换需要再次确认。仅内存应用或保存后应用；取消则完全不变。")
    _arrange_tab_order()
    if _confirm_memory != null:
        _confirm_memory.grab_focus()
    return plan


func _finish_custom(result: Dictionary, success: bool) -> Dictionary:
    if success:
        _reset_pending()
        _clear_swap()
        _undo_plan.clear()
        _clear_recovery()
        _clear_alternatives()
    _display_result(result)
    _refresh_undo()
    if success:
        _return_to_origin()
    return result


func _commit_swap(persist: bool) -> Dictionary:
    var before: Dictionary = backend.profile()
    if _pending_kind != "swap" or _swap_candidate.is_empty() \
            or not _pending_is_current() \
            or change_planner.digest(before) != str(
                _swap_candidate.get("base_digest", "")):
        _reset_pending()
        _clear_swap()
        return _finish_custom({
            "ok": false, "code": "STALE_SWAP",
            "message": "请重新预览交换"
        }, false)
    if _reviewed_v2_path != v2_profile_path \
            or _reviewed_legacy_path != legacy_profile_path:
        _reset_pending()
        _clear_swap()
        return _finish_custom({
            "ok": false, "code": "STALE_PATH",
            "message": "文件位置已变化"
        }, false)
    var candidate: Dictionary = _swap_candidate["profile"].duplicate(true)
    var verified := backend.workflow.settings.bindings.inspect_profile(candidate)
    if not verified["ok"]:
        _reset_pending()
        _clear_swap()
        return _finish_custom({
            "ok": false, "code": "INVALID_SWAP",
            "message": str(verified["error"])
        }, false)

    var result: Dictionary
    if persist:
        result = backend._commit_candidate(v2_profile_path, candidate)
    else:
        var applied := backend.workflow.settings.bindings.apply_profile(candidate)
        result = {
            "ok": bool(applied["ok"]),
            "code": "SWAP_APPLIED" if applied["ok"] else "SWAP_FAILED",
            "message": "",
            "changed": bool(applied["changed"]),
            "persisted": false, "committed": false
        }

    if not result.get("ok", false):
        if persist:
            _failed_save(result, "pending")
            _display_result(result)
        else:
            _reset_pending()
            _clear_swap()
            _display_result(result)
        return result

    var after: Dictionary = backend.profile()
    change_planner.record(before, after,
        "disk" if persist else "memory", v2_profile_path if persist else "")
    return _finish_custom(result, true)


func _preview_differences(before: Dictionary, after: Dictionary) -> String:
    var by_action: Dictionary = {}
    for entry in before["bindings"]:
        by_action[str(entry["action_id"])] = int(entry["keycode"])
    var lines := PackedStringArray()
    for item in after["bindings"]:
        var action := str(item["action_id"])
        var next_code := int(item["keycode"])
        var old_code := int(by_action[action])
        if next_code != old_code:
            lines.append("%s：%s → %s" % [
                _action_title(action), backend.key_label(old_code),
                backend.key_label(next_code)
            ])
    return "\n".join(lines)


func preview_undo() -> Dictionary:
    var proposed: Dictionary = change_planner.peek(backend.profile(), v2_profile_path)
    if not proposed.get("ok", false):
        _show_status("无法撤销：" + str(proposed.get("message", "")))
        _refresh_undo()
        return proposed
    cancel_preview()
    _clear_swap()
    _undo_plan = proposed.duplicate(true)
    _pending_kind = "undo"
    _pending_profile_hash = _profile_hash()
    _reviewed_v2_path = v2_profile_path
    _reviewed_legacy_path = legacy_profile_path
    _preview_details = {"ok": true, "can_apply": true, "code": "UNDO_READY"}
    _preview.text = "撤销预览（只撤销最后一项成功的配置变更）：\n" + \
        _preview_differences(proposed["after"], proposed["before"])
    var to_disk := proposed["scope"] == "disk"
    _set_confirmation(not to_disk, to_disk)
    _show_status("磁盘变更须“保存后应用”撤销；内存变更只能“仅本次应用”撤销。")
    _arrange_tab_order()
    if to_disk:
        _confirm_save.grab_focus()
    else:
        _confirm_memory.grab_focus()
    return proposed


func _commit_undo(persist: bool) -> Dictionary:
    var expected_scope := "disk" if persist else "memory"
    var latest: Dictionary = change_planner.peek(backend.profile(), v2_profile_path)
    if _pending_kind != "undo" or _undo_plan.is_empty() \
            or not _pending_is_current() or not latest.get("ok", false) \
            or str(_undo_plan.get("scope", "")) != expected_scope \
            or str(latest.get("scope", "")) != expected_scope \
            or str(_undo_plan.get("path", "")) != str(latest.get("path", "")) \
            or str(_undo_plan["after"]) != str(latest["after"]):
        _reset_pending()
        _undo_plan.clear()
        return _finish_custom({
            "ok": false, "code": "UNDO_STALE",
            "message": "撤销目标或当前配置已变化，请重新预览"
        }, false)
    if _reviewed_v2_path != v2_profile_path \
            or _reviewed_legacy_path != legacy_profile_path:
        _reset_pending()
        _undo_plan.clear()
        return _finish_custom({
            "ok": false, "code": "STALE_PATH", "message": "保存路径已变化"
        }, false)

    var goal: Dictionary = _undo_plan["before"].duplicate(true)
    var checked := backend.workflow.settings.bindings.inspect_profile(goal)
    if not checked["ok"]:
        _reset_pending()
        _undo_plan.clear()
        return _finish_custom({
            "ok": false, "code": "INVALID_UNDO",
            "message": str(checked["error"])
        }, false)

    var result: Dictionary
    if persist:
        result = backend._commit_candidate(v2_profile_path, goal)
    else:
        var applied := backend.workflow.settings.bindings.apply_profile(goal)
        result = {
            "ok": bool(applied["ok"]),
            "code": "UNDO_APPLIED" if applied["ok"] else "UNDO_FAILED",
            "message": "", "changed": bool(applied["changed"]),
            "persisted": false, "committed": false
        }

    if not result.get("ok", false):
        if persist:
            _failed_save(result, "pending")
        else:
            _reset_pending()
            _undo_plan.clear()
        _display_result(result)
        return result

    change_planner.pop_after_success()
    return _finish_custom(result, true)


func _record_result(before: Dictionary, result: Dictionary,
        scope: String, mode: String) -> void:
    if result.get("ok", false):
        if mode == "migration":
            # Migration creates a V2 document, never deletes V1. This is
            # not a reversible operation; do not offer fake undo.
            change_planner.clear()
        elif result.get("changed", false):
            change_planner.record(before, backend.profile(), scope,
                v2_profile_path if scope == "disk" else "")
    _refresh_undo()


func apply_memory() -> Dictionary:
    if _pending_kind == "swap":
        return _commit_swap(false)
    if _pending_kind == "undo":
        return _commit_undo(false)
    var before: Dictionary = backend.profile()
    var result: Dictionary = super.apply_memory()
    _record_result(before, result, "memory", "")
    _return_to_origin()
    return result


func apply_and_save() -> Dictionary:
    if _pending_kind == "swap":
        return _commit_swap(true)
    if _pending_kind == "undo":
        return _commit_undo(true)
    var mode: String = _pending_kind
    var before: Dictionary = backend.profile()
    var result: Dictionary = super.apply_and_save()
    _record_result(before, result, "disk", mode)
    if result.get("ok", false):
        _return_to_origin()
    return result


func retry_save() -> Dictionary:
    # Parent's retry delegates back into the appropriate virtual
    # apply_and_save (including the new swap/undo operation).
    var result: Dictionary = super.retry_save()
    _refresh_undo()
    return result


func save_current() -> Dictionary:
    var result: Dictionary = super.save_current()
    if result.get("ok", false):
        # A separate save can persist an earlier memory-only change;
        # its old on-disk state is not journaled, so discard old undo.
        change_planner.clear()
    _refresh_undo()
    return result


func load_current() -> Dictionary:
    var result: Dictionary = super.load_current()
    if result.get("ok", false):
        # Explicit external file load is a new history epoch.
        change_planner.clear()
    _refresh_undo()
    return result


func cancel_preview() -> void:
    super.cancel_preview()
    _clear_swap()
    _undo_plan.clear()
    _refresh_undo()
    _return_to_origin()


func open_for_router(router: Node = null) -> Dictionary:
    if is_inside_tree():
        _return_focus = get_viewport().gui_get_focus_owner()
    var result: Dictionary = super.open_for_router(router)
    if result.get("ok", false):
        _arrange_tab_order()
        _focus_first()
    return result


func _restore_outer_focus() -> void:
    if is_instance_valid(_return_focus) and _return_focus.is_inside_tree() \
            and _return_focus.visible and not _return_focus.is_disabled():
        _return_focus.grab_focus()
    _return_focus = null


func close_panel() -> void:
    super.close_panel()
    _clear_swap()
    _undo_plan.clear()
    _restore_outer_focus()


func ui_state_006() -> Dictionary:
    var state: Dictionary = ui_state_005()
    state["swap_available"] = _swap_button != null and not _swap_button.disabled
    state["undo_available"] = _undo_button != null and not _undo_button.disabled
    state["undo_depth"] = change_planner.size()
    state["undo_scope"] = str(_undo_plan.get("scope", ""))
    state["focused_control"] = ""
    if is_inside_tree():
        var focused: Control = get_viewport().gui_get_focus_owner()
        if focused != null and is_ancestor_of(focused):
            state["focused_control"] = focused.name
    return state
