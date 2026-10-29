extends Node3D
## GAME-WEB-FLOW-REGION-004 r1 — isolated synthetic graybox UI flow.
## No real scene, script/event/save integration or private game content.
const FlowModel = preload("res://flow_model_candidate.gd")
const PromptScene = preload("res://interaction_prompt_candidate.tscn")
const TargetPicker = preload("res://target_picker_candidate.gd")
const FeedbackJournal = preload("res://feedback_journal_candidate.gd")
const DATA_PATH := "res://synthetic_targets.json"
const SPEED := 2.3

var _model = FlowModel.new()
var _journal = FeedbackJournal.new()
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
    panel.position = Vector2(16, 16)
    panel.custom_minimum_size = Vector2(300, 0)
    host.add_child(panel)
    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 5)
    panel.add_child(layout)

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
    set_demo_position(_model.player_position() + vector.normalized() * SPEED * delta)


# Explicit, finite and deterministic test seam. No engine input needed.
func set_demo_position(position: Vector2) -> bool:
    if not _ready_for_demo:
        return false
    var result: Dictionary = _model.move_player(position)
    if not result.get("ok", false):
        return false

    var current: Vector2 = _model.player_position()
    _player_mesh.position = Vector3(current.x, 0.35, current.y)
    if result.get("changed", false):
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
    if not shown and not _system_hiding and not _model.nearby_ids().is_empty():
        _model.dismiss_prompt()
        _publish_feedback("dismiss", "提示已手动隐藏；离开所有目标或主动重新显示。")
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
    ) % [
        p.x, p.y,
        str(state["nearby_ids"]),
        str(state["selected_id"]),
        str(_prompt.is_prompt_shown()),
        int(state["confirm_count"]),
        str(state["dismissed"]),
        str(_prompt.focus_state()["role"]),
        _journal.count()
    ]
