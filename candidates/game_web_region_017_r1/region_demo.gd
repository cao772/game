extends Control
## GAME-WEB-REGION-017 r1 public-only standalone host; NOT_RUN.
## No InputMap, story, event, save, private data or shared interface.
const ModelScript = preload("res://region_model.gd")
const MapViewScript = preload("res://map_view.gd")

var _model
var _map
var _selector: OptionButton
var _scene_status: Label
var _feedback: Label
var _facts: Label
var _audit: Label
var _key_status: Label
var _window_focused: bool = true
var _release_gate: bool = false
var _restore_map_request: bool = false


func _ready() -> void:
    _model = ModelScript.new()
    _model.load_catalog()
    _build_ui()
    _refresh()


func _make_label(host: Node, content: String) -> Label:
    var item := Label.new()
    item.text = content
    item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    host.add_child(item)
    return item


func _make_button(host: Node, caption: String, handler: Callable) -> Button:
    var item := Button.new()
    item.text = caption
    item.focus_mode = Control.FOCUS_ALL
    item.pressed.connect(handler)
    host.add_child(item)
    return item


func _build_ui() -> void:
    var root := VBoxContainer.new()
    add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.offset_left = 16.0
    root.offset_top = 12.0
    root.offset_right = -16.0
    root.offset_bottom = -12.0

    _make_label(root, "GAME-WEB-REGION-017 | A/B/C 合成占位框架 | NOT_RUN")
    var toolbar := HBoxContainer.new()
    root.add_child(toolbar)
    _make_label(toolbar, "场景选择（仅虚构字母）：")
    _selector = OptionButton.new()
    for item in ["A | 遮挡且可绕行", "B | 路线绕行", "C | 不可达与回退"]:
        _selector.add_item(item)
    _selector.item_selected.connect(_on_scene_changed)
    toolbar.add_child(_selector)
    _make_button(toolbar, "把焦点交给网格", Callable(self, "_focus_map"))
    _make_button(toolbar, "重置本地样本", Callable(self, "_reset_scene"))
    var body := HBoxContainer.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(body)
    _map = MapViewScript.new()
    _map.custom_minimum_size = Vector2(620, 480)
    _map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _map.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _map.cell_selected.connect(_on_cell_selected)
    _map.move_requested.connect(_on_move_requested)
    body.add_child(_map)

    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(380, 300)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_child(scroll)
    var side := VBoxContainer.new()
    side.custom_minimum_size = Vector2(350, 0)
    side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(side)

    _scene_status = _make_label(side, "")
    _make_button(side, "显示到目标 T 的可达路线", Callable(self, "_route_target"))
    _make_button(side, "显示回到起点 S 的恢复路线", Callable(self, "_route_recover"))
    _make_button(side, "核对路线与视线", Callable(self, "_inspect"))
    _make_button(side, "明确提交本地记录更正", Callable(self, "_correct"))
    _feedback = _make_label(side, "")
    _facts = _make_label(side, "")
    _audit = _make_label(side, "")
    _key_status = _make_label(side, "")
    _make_label(side, "键盘：先聚焦网格，WASD/方向键每次移动一格；Tab/Shift+Tab 操作按钮；Esc 退出网格焦点。")
    _make_label(side, "全部反馈仅存在内存。关闭窗口或重置即丢失；不写存档、世界状态或任何外部事件。")


func _bool_word(v: bool) -> String:
    return "是" if v else "否"


func _refresh() -> void:
    var view: Dictionary = _model.snapshot()
    _map.set_state(view)
    _scene_status.text = "场景 %s | 数据：%s\n%s\n当前位置 %s；目标 %s" % [
        view["id"], view["source"], view["notice"], str(view["player"]), str(view["target"])
    ]
    _feedback.text = "操作反馈：%s" % view["feedback"]
    var claims: Dictionary = view["claimed"]
    var actual_text := "未执行核对（只显示记录主张）。"
    if view["inspected"]:
        actual_text = "本地核对：目标可达=%s、直线可见=%s" % [
            _bool_word(view["actual_reachable"]), _bool_word(view["actual_visible"])
        ]
    _facts.text = "待纠错的合成记录：目标可达=%s、直线可见=%s\n%s\n蓝线为预览，不自动行走。" % [
        _bool_word(claims["reachable"]), _bool_word(claims["visible"]), actual_text
    ]
    var entries: Array = view["audit"]
    _audit.text = "本地更正日志（最多 12 条）：" + ("\n" + "\n".join(entries) if not entries.is_empty() else "暂无")
    _key_status.text = "窗口焦点：%s；移动键释放门禁：%s；地图焦点：%s" % [
        _bool_word(_window_focused), "等待全部松开" if _release_gate else "已解除", _bool_word(_map.has_focus())
    ]


func _on_scene_changed(index: int) -> void:
    if index < 0 or index > 2:
        return
    _model.select_scene(["A", "B", "C"][index])
    _refresh()


func _focus_map() -> void:
    _map.grab_focus()
    _refresh()


func _reset_scene() -> void:
    _model.select_scene(_model.snapshot()["id"])
    _refresh()


func _route_target() -> void:
    _model.show_target_route()
    _refresh()


func _route_recover() -> void:
    _model.show_recovery_route()
    _refresh()


func _inspect() -> void:
    _model.inspect()
    _refresh()


func _correct() -> void:
    _model.correct_record()
    _refresh()


func _on_cell_selected(cell: Vector2i) -> void:
    _model.preview_cell(cell)
    _refresh()


func _on_move_requested(direction: Vector2i) -> void:
    if not _window_focused or _release_gate or not _map.has_focus():
        _key_status.text = "移动被焦点/键释放防护拒绝。请回到窗口并松开 WASD/方向键。"
        return
    _model.move_player(direction)
    _refresh()


func _all_movement_released() -> bool:
    for key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
        if Input.is_key_pressed(key):
            return false
    return true


func _process(_delta: float) -> void:
    if not _window_focused:
        return
    var changed: bool = false
    if _release_gate and _all_movement_released():
        _release_gate = false
        changed = true
    if _restore_map_request:
        _restore_map_request = false
        var owner: Control = get_viewport().gui_get_focus_owner()
        if owner == null and _map != null:
            _map.grab_focus()
            changed = true
    if changed and _map != null:
        _refresh()


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        _window_focused = false
        _release_gate = true
        _restore_map_request = _map != null and _map.has_focus()
    elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
        _window_focused = true
        # Restoring control focus never auto-confirms, changes records, or moves.
