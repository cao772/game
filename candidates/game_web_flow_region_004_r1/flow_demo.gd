extends Node3D
## GAME-WEB-FLOW-REGION-004 r1 — isolated synthetic graybox UI flow.
## No real scene, script/event/save integration or private game content.
const FlowModel = preload("res://flow_model_candidate.gd")
const PromptScene = preload("res://interaction_prompt_candidate.tscn")
const TargetPicker = preload("res://target_picker_candidate.gd")
const FeedbackJournal = preload("res://feedback_journal_candidate.gd")
const Navigation = preload("res://navigation_candidate.gd")
const FocusRecovery = preload("res://focus_recovery_candidate.gd")
const DATA_PATH := "res://synthetic_targets.json"
const SPEED := 2.3

var _model = FlowModel.new()
var _journal = FeedbackJournal.new()
var _navigation = Navigation.new()
var _focus_guard = FocusRecovery.new()
var _prompt
var _player_mesh: MeshInstance3D
var _marker_meshes: Dictionary = {}
var _status_label: Label
var _feedback_label: Label
var _history_label: Label
var _camera: Camera3D
var _system_hiding: bool = false
var _ready_for_demo: bool = false
var _raw_fixture: Array = []
var _last_prompt_focus_role: StringName = &"none"
var _in_nav_step: bool = false


func _ready() -> void:
    _build_world()
    _build_interface()
    var content: String = FileAccess.get_file_as_string(DATA_PATH)
    var parsed: Variant = JSON.parse_string(content)
    if not parsed is Dictionary:
        _feedback_label.text = "BLOCKED：无法读取合成目标目录。"
        return
    var document: Dictionary = parsed
    if document.get("schema_version", "") != "synthetic-targets-v1":
        _feedback_label.text = "BLOCKED：合成目录版本不匹配。"
        return
    if not document.get("targets") is Array:
        _feedback_label.text = "BLOCKED：合成目录缺少 targets 数组。"
        return
    _raw_fixture = (document["targets"] as Array).duplicate(true)
    if not _model.load_targets(_raw_fixture):
        _feedback_label.text = "BLOCKED：合成目录校验失败，无任何目标启用。"
        return
    _ready_for_demo = true
    _build_target_markers()
    set_demo_position(Vector2(0.0, 3.0))
    _feedback_label.text = "合成目录已载入；靠近方块可查看操作提示。"
    # OS window focus notifications are separate from prompt focus changes.
    get_window().focus_exited.connect(_on_window_unfocused)
    get_window().focus_entered.connect(_on_window_returned)


func _make_box(
    name: String, dimensions: Vector3, at: Vector3, color: Color
) -> MeshInstance3D:
    var mesh_node := MeshInstance3D.new()
    mesh_node.name = name
    var box_mesh := BoxMesh.new()
    box_mesh.size = dimensions
    mesh_node.mesh = box_mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 1.0
    mesh_node.material_override = material
    mesh_node.position = at
    add_child(mesh_node)
    return mesh_node


func _build_world() -> void:
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.045, 0.065, 0.10)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.65, 0.75, 0.90)
    env.ambient_light_energy = 0.72
    environment.environment = env
    add_child(environment)

    var key_light := DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-55, 20, 0)
    key_light.light_energy = 0.8
    add_child(key_light)

    _make_box("SyntheticFloor", Vector3(10.6, 0.12, 9.0),
        Vector3(0, -0.07, 0), Color(0.18, 0.23, 0.30))
    # No bedroom layout, narrative corridor, real NPC or event cue is imported.
    _camera = Camera3D.new()
    _camera.name = "FixedTrialCamera"
    _camera.position = Vector3(0, 8.5, 9.0)
    _camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    _camera.size = 12.5
    _camera.current = true
    add_child(_camera)
    _camera.look_at(Vector3.ZERO, Vector3.UP)

    _player_mesh = _make_box("SyntheticPlayerMarker",
        Vector3(0.35, 0.65, 0.35), Vector3(0, 0.35, 3.0),
        Color(0.22, 0.86, 0.95))


func _build_target_markers() -> void:
    for target in _model.all_targets():
        var id: StringName = target["id"]
        var ground: Vector2 = target["position"]
        var mark: MeshInstance3D = _make_box(
            "Synthetic_" + str(id), Vector3(0.55, 0.75, 0.55),
            Vector3(ground.x, 0.38, ground.y),
            Color(0.41, 0.49, 0.62)
        )
        _marker_meshes[id] = mark
        var label := Label3D.new()
        label.name = "MarkerLabel_" + str(id)
        label.text = str(target["label"])
        label.font_size = 24
        label.pixel_size = 0.005
        label.position = Vector3(ground.x, 1.15, ground.y)
        add_child(label)


func _button(parent: VBoxContainer, caption: String, callback: Callable) -> Button:
    var item := Button.new()
    item.text = caption
    item.focus_mode = Control.FOCUS_ALL
    parent.add_child(item)
    item.pressed.connect(callback)
    return item


func _build_interface() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var host := Control.new()
    layer.add_child(host)
    host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    # Let 3D marker clicks pass through empty overlay regions to _unhandled_input.
    host.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var panel := PanelContainer.new()
    panel.position = Vector2(14, 14)
    panel.size = Vector2(364, 680)
    host.add_child(panel)
    var scroller := ScrollContainer.new()
    scroller.custom_minimum_size = Vector2(344, 666)
    scroller.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.add_child(scroller)
    var layout := VBoxContainer.new()
    layout.custom_minimum_size = Vector2(322, 0)
    layout.add_theme_constant_override("separation", 5)
    scroller.add_child(layout)

    var heading := Label.new()
    heading.text = "灰盒交互流程 / 纯合成占位"
    layout.add_child(heading)
    var help := Label.new()
    help.text = "WASD 移动方块标记，靠近目标后用提示按钮或 Tab / Enter。"
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(help)
    _button(layout, "前往 A（接近）", func(): set_demo_position(Vector2(-1.2, 0.3)))
    _button(layout, "前往 B（接近）", func(): set_demo_position(Vector2(0.0, 0.3)))
    _button(layout, "A/B 之间（多目标）", func(): set_demo_position(Vector2(-0.6, 0.0)))
    _button(layout, "远离所有目标", func(): set_demo_position(Vector2(0.0, 3.1)))
    _button(layout, "选择上一个提示目标", _previous_selection)
    _button(layout, "选择下一个提示目标", _cycle_selection)
    _button(layout, "将焦点移至提示确认键", _focus_prompt_action)
    _button(layout, "释放键盘焦点到灰盒", _focus_world)
    _button(layout, "确认当前提示目标", _confirm_selection)
    _button(layout, "重新显示已关闭提示", _reopen)
    _button(layout, "导航接近 A（仅模拟直线）", func(): start_navigation(&"placeholder_a"))
    _button(layout, "导航接近 B（仅模拟直线）", func(): start_navigation(&"placeholder_b"))
    _button(layout, "导航接近 C（仅模拟直线）", func(): start_navigation(&"placeholder_c"))
    _button(layout, "暂停导航", _pause_navigation)
    _button(layout, "手动继续导航", _resume_navigation)
    _button(layout, "取消导航", _cancel_navigation)
    _button(layout, "重置合成流程", _reset_demo)

    _status_label = Label.new()
    _status_label.custom_minimum_size = Vector2(290, 0)
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(_status_label)
    _feedback_label = Label.new()
    _feedback_label.custom_minimum_size = Vector2(290, 0)
    _feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(_feedback_label)
    var history_title := Label.new()
    history_title.text = "最近交互反馈（仅内存，最多12条）："
    layout.add_child(history_title)
    _history_label = Label.new()
    _history_label.custom_minimum_size = Vector2(310, 0)
    _history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(_history_label)

    _prompt = PromptScene.instantiate()
    host.add_child(_prompt)
    _prompt.position = Vector2(660, 36)
    _prompt.size = Vector2(500, 280)
    _prompt.placeholder_changed.connect(_on_prompt_selection_changed)
    _prompt.prompt_visibility_changed.connect(_on_prompt_visibility_changed)
    _prompt.interaction_requested.connect(_on_prompt_confirmed)
    _prompt.focus_state_changed.connect(_on_prompt_focus_changed)


func _process(delta: float) -> void:
    if not _ready_for_demo or get_tree().paused or not get_window().has_focus():
        return
    var focused: Control = get_viewport().gui_get_focus_owner()
    if focused is LineEdit or focused is TextEdit:
        return
    # Movement must not run behind a keyboard-focused prompt.
    if _prompt.is_prompt_shown():
        if _prompt.focus_state()["role"] != &"none":
            return

    # A held key after Alt-Tab is never treated as newly pressed.
    if not _focus_guard.consume_key_release_gate(_all_movement_keys_released()):
        return

    # Explicit navigation owns motion until arrival, pause or cancellation.
    # A returned window never resumes it automatically.
    if _navigation.is_moving():
        _advance_navigation(delta)
        return

    # No InputMap configuration: this is an isolated trial movement scheme.
    var vector := Vector2.ZERO
    if Input.is_key_pressed(KEY_A):
        vector.x -= 1
    if Input.is_key_pressed(KEY_D):
        vector.x += 1
    if Input.is_key_pressed(KEY_W):
        vector.y -= 1
    if Input.is_key_pressed(KEY_S):
        vector.y += 1
    if vector == Vector2.ZERO:
        return
    if _navigation.is_paused():
        _navigation.cancel("用户按 WASD，取消暂停中的导航")
        _publish_feedback("navigation", "手动移动已取消暂停的导航。")
    set_demo_position(_model.player_position() + vector.normalized() * SPEED * delta)


# Explicit, finite and deterministic test seam. No engine input needed.
func set_demo_position(position: Vector2) -> bool:
    if not _ready_for_demo:
        return false
    if not _in_nav_step and _navigation.is_moving():
        _navigation.cancel("用户手动更改模拟位置")
        _publish_feedback("navigation", "手动位置变更已取消自动导航。")
    var result: Dictionary = _model.move_player(position)
    if not result.get("ok", false):
        return false

    var current: Vector2 = _model.player_position()
    _player_mesh.position = Vector3(current.x, 0.35, current.y)
    if result.get("changed", false):
        if not _in_nav_step:
            _sync_prompt()
        _update_marker_colors()
        var entered: Array = result.get("entered", [])
        var left: Array = result.get("left", [])
        if not entered.is_empty():
            _publish_feedback("enter", "接近目标：%s" % str(entered))
        elif not left.is_empty():
            _publish_feedback("leave", "离开目标：%s" % str(left))
        else:
            _publish_feedback("info", "目标排序已改变，当前选择按 ID 保持。")

    _update_status()
    return true


# Only unhandled world clicks attempt to select an actual visible cube.
# Existing Godot UI controls consume their own clicks before this callback.
func _unhandled_input(event: InputEvent) -> void:
    if not _ready_for_demo or get_tree().paused or not get_window().has_focus():
        return
    if not event is InputEventMouseButton:
        return
    var mouse_event := event as InputEventMouseButton
    if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
        return
    if _camera == null:
        return
    var origin: Vector3 = _camera.project_ray_origin(mouse_event.position)
    var ray: Vector3 = _camera.project_ray_normal(mouse_event.position)
    if absf(ray.y) <= 0.0001:
        return
    # Ray intersection with the midpoint of the synthetic cube marker.
    var travel: float = (0.38 - origin.y) / ray.y
    if travel < 0.0:
        return
    var hit: Vector3 = origin + ray * travel
    if select_marker_at(Vector2(hit.x, hit.z)):
        get_viewport().set_input_as_handled()


# Deterministic seam for future headless checks of click selection.
# Returns true only when a real synthetic marker is hit, including
# out-of-range refusal; unrelated floor clicks remain unhandled.
func select_marker_at(ground: Vector2) -> bool:
    if not _ready_for_demo:
        return false
    var result: Dictionary = TargetPicker.choose_at(
        ground, _model.all_targets(), _model.nearby_ids()
    )
    if not result.get("hit", false):
        return false
    var id: StringName = result["target_id"]
    if not result.get("eligible", false) or not _prompt.is_prompt_shown():
        _publish_feedback(
            "rejected", "目标 %s 当前不可交互；先接近或重新显示提示。" % id, id
        )
        return true

    var eligible: Array[Dictionary] = _model.prompt_entries()
    for i in range(eligible.size()):
        if eligible[i]["id"] == id:
            if _prompt.select_target(i):
                _focus_prompt_action()
                return true
            break
    _publish_feedback("rejected", "目标列表已变化，请重新选择。", id)
    _sync_prompt()
    return true


func _sync_prompt() -> void:
    if _in_nav_step or _navigation.is_moving():
        return
    var current: Dictionary = _model.snapshot()
    var eligible: Array[Dictionary] = _model.prompt_entries()
    if eligible.is_empty() or current["dismissed"]:
        if _prompt.is_prompt_shown():
            _system_hiding = true
            _prompt.hide_prompt()
            _system_hiding = false
        return

    if not _prompt.is_prompt_shown():
        var target_index: int = 0
        for i in range(eligible.size()):
            if eligible[i]["id"] == _model.selected_id():
                target_index = i
                break
        _prompt.show_for_targets(eligible, target_index)
    else:
        # Preserve stable ID even when the distance-sorted list reorders.
        _prompt.synchronize_targets(eligible, _model.selected_id())


func _on_prompt_selection_changed(id: StringName) -> void:
    if not _model.mark_selected(id):
        _publish_feedback("rejected", "选中目标不在当前范围内。", id)
        _sync_prompt()
        return
    _update_marker_colors()
    _publish_feedback("selection", "当前选中合成目标：%s" % id, id)
    _update_status()


func _on_prompt_visibility_changed(shown: bool) -> void:
    if not shown:
        _focus_guard.clear_pending()
    if not shown and not _system_hiding and not _model.nearby_ids().is_empty():
        _model.dismiss_prompt()
        _publish_feedback("dismiss", "提示已手动隐藏；离开所有目标或主动重新显示。")
    _update_status()


# Public candidate seam for trial-only navigation; no A* or real scene path.
func start_navigation(id: StringName) -> bool:
    if not _ready_for_demo or get_tree().paused or not get_window().has_focus():
        return false
    if not _navigation.start_to_target(id, _model.all_targets(), _model.player_position()):
        _publish_feedback("rejected", "无法导航：目标不属于公开合成目录。", id)
        return false

    # Suppress the prompt during travel; explicit navigation is not dismissal.
    if _prompt.is_prompt_shown():
        _system_hiding = true
        _prompt.hide_prompt()
        _system_hiding = false
    _focus_world()

    if _navigation.state()["mode"] == &"arrived":
        _model.mark_selected(id)
        _sync_prompt()
        _update_marker_colors()
        _publish_feedback("navigation", "目标已在模拟接近范围内：" + str(id), id)
    else:
        _publish_feedback(
            "navigation", "开始直线导航：" + str(id) + "（仅合成坐标）", id
        )
    _update_status()
    return true


func _advance_navigation(delta: float) -> void:
    var step: Dictionary = _navigation.advance(_model.player_position(), delta)
    if not step.get("ok", false):
        return
    _in_nav_step = true
    var moved: bool = set_demo_position(step["position"])
    _in_nav_step = false
    if not moved:
        _navigation.cancel("模拟位置更新被拒绝")
        _publish_feedback("rejected", "合成导航被拒绝，已停止。")
        return

    if step.get("arrived", false):
        var reached_id: StringName = step["target_id"]
        # Arrival chooses the goal by stable ID rather than nearest-list index.
        if not _model.mark_selected(reached_id):
            _publish_feedback("rejected", "到达后目标不可交互，保守拒绝。", reached_id)
        _sync_prompt()
        _update_marker_colors()
        _publish_feedback("navigation", "已到达目标接近范围：" + str(reached_id),
            reached_id)
        _update_status()


func _pause_navigation() -> void:
    if _navigation.pause_manually():
        _publish_feedback("navigation", "导航已暂停，需主动继续。")
    else:
        _publish_feedback("rejected", "当前没有正在运行的合成导航。")
    _update_status()


func _resume_navigation() -> void:
    if not get_window().has_focus() or get_tree().paused:
        _publish_feedback("rejected", "窗口未聚焦或暂停，不允许继续导航。")
        return
    if not _all_movement_keys_released():
        _publish_feedback("rejected", "请先松开 WASD，再主动继续导航。")
        return
    if not _focus_guard.consume_key_release_gate(true):
        _publish_feedback("rejected", "尚未完成窗口恢复输入保护。")
        return
    if _navigation.resume_after_focus_return(true):
        if _prompt.is_prompt_shown():
            _system_hiding = true
            _prompt.hide_prompt()
            _system_hiding = false
        _focus_world()
        _publish_feedback("navigation", "用户主动恢复合成导航。")
    else:
        _publish_feedback("rejected", "没有可继续的已暂停导航。")
    _update_status()


func _cancel_navigation() -> void:
    if _navigation.cancel():
        _sync_prompt()
        _update_marker_colors()
        _publish_feedback("navigation", "用户取消合成导航。")
    else:
        _publish_feedback("rejected", "当前没有可取消的合成导航。")
    _update_status()


func _all_movement_keys_released() -> bool:
    return (
        not Input.is_key_pressed(KEY_W)
        and not Input.is_key_pressed(KEY_A)
        and not Input.is_key_pressed(KEY_S)
        and not Input.is_key_pressed(KEY_D)
    )


func _on_window_unfocused() -> void:
    # Prior prompt role is cached while the native window was focused.
    # PR #10's live role can already report 'none' by the time this fires.
    var shown: bool = _prompt.is_prompt_shown()
    _focus_guard.capture_window_loss(
        _last_prompt_focus_role, _prompt.active_target_id(), shown
    )
    var stopped: bool = _navigation.pause_for_focus_loss()
    if stopped:
        _publish_feedback("focus", "窗口失焦：导航已安全暂停，返回后不会自动继续。")
    else:
        _publish_feedback("focus", "窗口失焦：保留选择，等待安全恢复焦点。")
    _update_status()


func _on_window_returned() -> void:
    _focus_guard.mark_window_returned()
    _publish_feedback(
        "focus", "窗口已返回；需要先松开 WASD。暂停的导航须手动继续。"
    )
    call_deferred("_restore_focus_after_window_return")
    _update_status()


func _restore_focus_after_window_return() -> void:
    if not get_window().has_focus() or not _ready_for_demo:
        return
    var owner: Control = get_viewport().gui_get_focus_owner()
    var host_focused: bool = (
        owner != null
        and owner != _prompt
        and not _prompt.is_ancestor_of(owner)
    )
    var claim: Dictionary = _focus_guard.claim_focus(
        _prompt.is_prompt_shown(), _prompt.active_target_id(), host_focused
    )
    if not claim.get("restore", false):
        _update_status()
        return

    var button: Button = null
    match claim.get("role", &"action"):
        &"previous":
            button = _prompt.get_node("Padding/Content/Navigation/PreviousButton")
        &"next":
            button = _prompt.get_node("Padding/Content/Navigation/NextButton")
        &"dismiss":
            button = _prompt.get_node("Padding/Content/DismissButton")
        _:
            button = _prompt.get_node("Padding/Content/ActionButton")

    # If list shrank from multiple targets, fallback to the action button.
    if not button.is_visible_in_tree() or button.focus_mode == Control.FOCUS_NONE:
        button = _prompt.get_node("Padding/Content/ActionButton")
    button.grab_focus()
    _publish_feedback("focus", "已恢复相同占位目标的提示焦点（未确认）。")
    _update_status()


func _on_prompt_focus_changed(role: StringName) -> void:
    # Remember prompt-owned focus even if the OS later clears gui focus.
    # A focus exit to host while window is active clears the remembered role.
    if get_window().has_focus():
        _last_prompt_focus_role = role
    _update_status()


func _on_prompt_confirmed(id: StringName) -> void:
    # The prompt emits an ID only; model must independently guard proximity.
    var result: Dictionary = _model.confirm(id)
    if result.get("ok", false):
        _publish_feedback("success", str(result["feedback"]), id)
    else:
        _publish_feedback(
            "rejected", "确认被拒绝：" + str(result.get("reason", "未知原因")), id
        )
    _update_status()


func _previous_selection() -> void:
    if not _prompt.is_prompt_shown() or not _prompt.cycle_target(-1):
        _publish_feedback("rejected", "当前没有可向前切换的提示目标。")
    _update_status()


func _focus_prompt_action() -> void:
    if not _prompt.is_prompt_shown():
        _publish_feedback("rejected", "尚无可聚焦的提示按钮。")
        return
    var action: Button = _prompt.get_node("Padding/Content/ActionButton")
    action.grab_focus()
    _update_status()


func _focus_world() -> void:
    get_viewport().gui_release_focus()
    _update_status()


func _cycle_selection() -> void:
    if not _prompt.is_prompt_shown() or not _prompt.cycle_target(1):
        _publish_feedback("rejected", "当前没有可向后切换的提示目标。")
    _update_status()


func _confirm_selection() -> void:
    if not _prompt.is_prompt_shown():
        _publish_feedback("rejected", "没有可确认的提示；请靠近或重新显示。")
        return
    # Normal host pathway still obeys native window focus and tree pause.
    if not _prompt.request_interaction():
        _publish_feedback("rejected", "操作已被窗口焦点或暂停状态拦截。")


func _reopen() -> void:
    if not _model.reopen_prompt():
        _publish_feedback("rejected", "附近没有可重新显示的占位目标。")
        return
    _sync_prompt()
    _publish_feedback("info", "已重新显示占位目标提示。")
    _update_status()


func _reset_demo() -> void:
    _navigation.reset()
    _focus_guard.reset()
    _last_prompt_focus_role = &"none"
    # Reset is in-memory only; never touches files or any real scene.
    if not _ready_for_demo:
        return
    var records: Array = _raw_fixture.duplicate(true)
    _system_hiding = true
    _prompt.hide_prompt()
    _system_hiding = false
    if not _model.load_targets(records):
        _publish_feedback("rejected", "BLOCKED：合成重置失败。")
        return
    _journal.clear()
    set_demo_position(Vector2(0.0, 3.0))
    _update_marker_colors()
    _publish_feedback("reset", "合成流程已重置，确认计数归零。")


func _update_marker_colors() -> void:
    var eligible: Array[StringName] = _model.nearby_ids()
    var selected: StringName = _model.selected_id()
    for id in _marker_meshes:
        var node: MeshInstance3D = _marker_meshes[id]
        var material := StandardMaterial3D.new()
        if id == selected and eligible.has(id):
            material.albedo_color = Color(1.0, 0.80, 0.34)
        elif eligible.has(id):
            material.albedo_color = Color(0.35, 0.85, 0.49)
        else:
            material.albedo_color = Color(0.41, 0.49, 0.62)
        node.material_override = material


func flow_snapshot() -> Dictionary:
    var result: Dictionary = _model.snapshot()
    result["prompt_shown"] = _prompt.is_prompt_shown()
    result["prompt_target"] = _prompt.active_target_id()
    result["focus_role"] = _prompt.focus_state()["role"]
    result["feedback_history"] = _journal.entries()
    result["navigation"] = _navigation.state()
    result["focus_recovery"] = _focus_guard.snapshot()
    return result


func _publish_feedback(
    kind: String, message: String, target_id: StringName = &""
) -> void:
    # Every entry is local and bounded. No event bus, save or analytics.
    if _journal.append(kind, message, target_id):
        _feedback_label.text = message
        _history_label.text = _journal.lines_for_display(6)


func _update_status() -> void:
    var state: Dictionary = _model.snapshot()
    var p: Vector2 = state["player"]
    _status_label.text = (
        "位置 x=%.2f z=%.2f\n可接近：%s\n选中：%s | 提示：%s"
        + "\n已确认：%d | 手动隐藏：%s\n控件焦点：%s | 反馈条数：%d"
        + "\n导航：%s → %s | 回焦待处理：%s"
    ) % [
        p.x, p.y,
        str(state["nearby_ids"]),
        str(state["selected_id"]),
        str(_prompt.is_prompt_shown()),
        int(state["confirm_count"]),
        str(state["dismissed"]),
        str(_prompt.focus_state()["role"]),
        _journal.count(),
        str(_navigation.state()["mode"]),
        str(_navigation.state()["target_id"]),
        str(_focus_guard.snapshot()["pending_restore"])
    ]
