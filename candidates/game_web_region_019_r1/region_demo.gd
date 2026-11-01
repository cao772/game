extends Control
## GAME-WEB-REGION-018 r1 | standalone A/B/C synthetic accessibility candidate.
## No external events, story, saved data, shared InputMap, real entities or locations.
## DESIGN ONLY, NOT_RUN.
const ModelScript = preload("res://region_model.gd")
const MapViewScript = preload("res://map_view.gd")
const GuideScript = preload("res://state_guide.gd")

var _model
var _guide
var _map
var _scene_select: OptionButton
var _text_select: OptionButton
var _motion_select: OptionButton
var _summary: Label
var _map_text: Label
var _feedback: Label
var _facts: Label
var _recovery: Label
var _audit: Label
var _focus_text: Label
var _live_card: TextEdit
var _pinned_card: TextEdit
var _next_step_label: Label
var _pinned: String = ""
var _controls: Array[Control] = []
var _window_focused: bool = true
var _release_gate: bool = false
var _restore_map_request: bool = false
var _text_scale: float = 1.0
var _motion: int = 0

func _ready() -> void:
    _model = ModelScript.new()
    _model.load_catalog()
    _guide = GuideScript.new()
    _create_ui()
    _apply_presentation()
    _refresh()

func _label(parent: Node, value: String) -> Label:
    var item := Label.new()
    item.text = value
    item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    if parent is HBoxContainer:
        item.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    else:
        item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(item)
    _controls.append(item)
    return item

func _focus_style(item: Control) -> void:
    item.focus_mode = Control.FOCUS_ALL
    var highlight := StyleBoxFlat.new()
    highlight.bg_color = Color(0, 0, 0, 0)
    highlight.border_color = Color.WHITE
    highlight.set_border_width_all(3)
    item.add_theme_stylebox_override("focus", highlight)
    item.focus_entered.connect(_update_focus_text)

func _button(parent: Node, title: String, handler: Callable) -> Button:
    var b := Button.new()
    b.text = title
    b.tooltip_text = title
    b.pressed.connect(handler)
    parent.add_child(b)
    _controls.append(b)
    _focus_style(b)
    return b

func _choice(parent: Node, entries: Array, handler: Callable) -> OptionButton:
    var c := OptionButton.new()
    for title in entries:
        c.add_item(title)
    c.item_selected.connect(handler)
    parent.add_child(c)
    _controls.append(c)
    _focus_style(c)
    return c

func _create_ui() -> void:
    var root := VBoxContainer.new()
    add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.offset_left = 14.0
    root.offset_top = 12.0
    root.offset_right = -14.0
    root.offset_bottom = -12.0

    _label(root, "GAME-WEB-REGION-019 | 公开合成 A/B/C | 状态证据与恢复导览 | NOT_RUN")
    var toolbar := HBoxContainer.new()
    root.add_child(toolbar)
    _label(toolbar, "切换场景：")
    _scene_select = _choice(toolbar, ["A | 遮挡但可绕行", "B | 路线误报", "C | 阻断与回退"], Callable(self, "_scene_changed"))
    _button(toolbar, "焦点转到网格", Callable(self, "_focus_map"))
    _button(toolbar, "重置本场景", Callable(self, "_reset_scene"))
    var settings := HBoxContainer.new()
    root.add_child(settings)
    _label(settings, "文字大小：")
    _text_select = _choice(settings, ["100%", "125%", "150%"], Callable(self, "_text_changed"))
    _label(settings, "动效：")
    _motion_select = _choice(settings, ["关闭（默认）", "舒缓", "标准"], Callable(self, "_motion_changed"))

    var body := HBoxContainer.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(body)

    var visual := VBoxContainer.new()
    visual.custom_minimum_size = Vector2(490, 300)
    visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_child(visual)
    _map = MapViewScript.new()
    _map.custom_minimum_size = Vector2(480, 300)
    _map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _map.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _map.cell_selected.connect(_cell_selected)
    _map.move_requested.connect(_map_move)
    _map.focus_entered.connect(_update_focus_text)
    _map.focus_exited.connect(_update_focus_text)
    visual.add_child(_map)
    _label(visual, "图例：# = 实体墙，. = 可通行，: = 预览路线，S = 起点，T = 目标，P = 当前格。格子中的字符比颜色优先。")

    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(460, 300)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_child(scroll)
    var panel := VBoxContainer.new()
    panel.custom_minimum_size = Vector2(440, 0)
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(panel)

    _summary = _label(panel, "")
    _focus_text = _label(panel, "")
    _label(panel, "完整键盘路径：Tab/Shift+Tab 选控件，Enter/Space 操作按钮；方向按钮可全程移动，不必聚焦网格。网格焦点下也可用 WASD/方向键，Esc 退出网格焦点。")
    var up := HBoxContainer.new()
    panel.add_child(up)
    _button(up, "向上一步 ↑", func(): _step(Vector2i(0, -1)))
    _button(up, "向下一步 ↓", func(): _step(Vector2i(0, 1)))
    var sideways := HBoxContainer.new()
    panel.add_child(sideways)
    _button(sideways, "向左一步 ←", func(): _step(Vector2i(-1, 0)))
    _button(sideways, "向右一步 →", func(): _step(Vector2i(1, 0)))
    var route := HBoxContainer.new()
    panel.add_child(route)
    _button(route, "预览到 T 路线", Callable(self, "_route_target"))
    _button(route, "预览返回 S", Callable(self, "_route_start"))
    _button(panel, "清除路线预览", Callable(self, "_clear_route"))
    _button(panel, "1. 重新核对可达与遮挡", Callable(self, "_inspect"))
    _button(panel, "2. 明确更正本地记录", Callable(self, "_correct"))
    _button(panel, "撤销最近移动或更正", Callable(self, "_undo"))
    _feedback = _label(panel, "")
    _recovery = _label(panel, "")
    _facts = _label(panel, "")
    _map_text = _label(panel, "")
    _audit = _label(panel, "")
    _label(panel, "019｜只读状态导览；固定快照仅保存于本次会话内存。")
    _next_step_label = _label(panel, "")
    _button(panel, "固定当前证据卡", Callable(self, "_pin_card"))
    _button(panel, "清除固定证据卡", Callable(self, "_unpin_card"))
    _live_card = _read_only_card(panel, "实时状态证据卡")
    _pinned_card = _read_only_card(panel, "固定对照卡（当前场景）")
    _label(panel, "只有合成数据；全部状态与撤销栈只在内存。切场景或重置会清空本地更正与撤销历史。无外部媒体/真实地图依赖。")

func _read_only_card(parent: Node, caption: String) -> TextEdit:
    _label(parent, caption)
    var card := TextEdit.new()
    card.editable = false
    card.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    card.custom_minimum_size = Vector2(0, 210)
    card.focus_mode = Control.FOCUS_ALL
    parent.add_child(card)
    _controls.append(card)
    return card

func _pin_card() -> void:
    _pinned = _guide.render(_model.snapshot())
    _refresh()

func _unpin_card() -> void:
    _pinned = ""
    _refresh()

func _bool_word(value: bool) -> String:
    return "是" if value else "否"

func _apply_presentation() -> void:
    var px: int = roundi(17.0 * _text_scale)
    for item in _controls:
        item.add_theme_font_size_override("font_size", px)
    _map.set_accessibility_options(_text_scale, _motion)

func _text_changed(index: int) -> void:
    _text_scale = [1.0, 1.25, 1.5][clampi(index, 0, 2)]
    _apply_presentation()
    _refresh()

func _motion_changed(index: int) -> void:
    _motion = clampi(index, 0, 2)
    _apply_presentation()
    _refresh()

func _scene_changed(index: int) -> void:
    if index < 0 or index >= 3:
        return
    _model.select_scene(["A", "B", "C"][index])
    _pinned = "" # Pinned evidence never carries into a new scene.
    _refresh()

func _focus_map() -> void:
    _map.grab_focus()
    _refresh()

func _reset_scene() -> void:
    _model.select_scene(str(_model.snapshot()["id"]))
    _pinned = ""
    _refresh()

func _route_target() -> void:
    _model.show_target_route()
    _refresh()

func _route_start() -> void:
    _model.show_recovery_route()
    _refresh()

func _clear_route() -> void:
    _model.clear_preview()
    _refresh()

func _inspect() -> void:
    _model.inspect()
    _refresh()

func _correct() -> void:
    _model.correct_record()
    _refresh()

func _undo() -> void:
    _model.undo_last()
    _refresh()

func _step(direction: Vector2i) -> void:
    if not _window_focused or _release_gate:
        _recovery.text = "移动暂停：请切回窗口、松开全部移动键，再用方向按钮或重新聚焦网格。"
        return
    _model.move_player(direction)
    _refresh()

func _map_move(direction: Vector2i) -> void:
    if not _map.has_focus():
        return
    _step(direction)

func _cell_selected(cell: Vector2i) -> void:
    _model.preview_cell(cell)
    _refresh()

func _textual_grid(view: Dictionary) -> String:
    var lines: PackedStringArray = []
    var rows: Array = view.get("grid", [])
    var route: Array = view.get("preview", [])
    var player: Vector2i = view.get("player", Vector2i.ZERO)
    var start: Vector2i = view.get("start", Vector2i.ZERO)
    var target: Vector2i = view.get("target", Vector2i.ZERO)
    for y in range(rows.size()):
        var marks := ""
        for x in range(str(rows[y]).length()):
            var p := Vector2i(x, y)
            var ch: String = str(rows[y]).substr(x, 1)
            if route.has(p) and ch != "#":
                ch = ":"
            if p == start:
                ch = "S"
            if p == target:
                ch = "T"
            if p == player:
                ch = "P"
            marks += ch
        lines.append("行%02d | %s" % [y, marks])
    return "无颜色依赖的字符地图（左起列 0）：\n" + "\n".join(lines)

func _refresh() -> void:
    var s: Dictionary = _model.snapshot()
    _map.set_state(s)
    _summary.text = "当前合成场景 %s | 数据来源：%s\n%s\nP 位置：%s，T 位置：%s | 动效：%s | 可撤销：%s（本地 %d 步）" % [
        s["id"], s["source"], s["notice"], str(s["player"]), str(s["target"]),
        ["关闭", "舒缓", "标准"][_motion], _bool_word(s["undo_available"]), s["undo_depth"]
    ]
    _feedback.text = "操作反馈：" + str(s["feedback"])
    var claim: Dictionary = s["claimed"]
    var observed := "尚未核对；展示的只是合成记录主张。"
    if s["inspected"]:
        observed = "本次核对：可达=%s、直线可见=%s。按【明确更正】才能修改本地记录。" % [
            _bool_word(s["actual_reachable"]), _bool_word(s["actual_visible"])
        ]
    _facts.text = "合成记录：可达=%s；直线可见=%s。\n%s\n注意：可达不等于可直视；移动后需重新核对。" % [
        _bool_word(claim["reachable"]), _bool_word(claim["visible"]), observed
    ]
    if s["inspected"] and claim != {"reachable": s["actual_reachable"], "visible": s["actual_visible"]}:
        _recovery.text = "下一步：资料与观察不一致。选择【明确更正】，之后可按【撤销】还原。"
    elif not s["actual_reachable"]:
        _recovery.text = "恢复提示：T 不能走到；选择【预览返回 S】，或逐步撤销移动；不要穿墙。"
    elif not s["inspected"]:
        _recovery.text = "下一步：可先预览路线，再【核对】。误走可撤销；格子受阻不会改变当前位置。"
    else:
        _recovery.text = "已核对：若想查看其他结果可换场景、先撤销操作，或重置本地样本。"
    _map_text.text = _textual_grid(s)
    var logs: Array = s["audit"]
    var log_lines := PackedStringArray()
    for item in logs:
        log_lines.append(str(item))
    _audit.text = "本地操作/更正说明（最多 12 条）：" + ("\n" + "\n".join(log_lines) if not log_lines.is_empty() else "无")
    _live_card.text = _guide.render(s)
    _pinned_card.text = _pinned if not _pinned.is_empty() else "尚未固定证据卡。"
    _next_step_label.text = _guide.next_step(s)
    _update_focus_text()

func _update_focus_text() -> void:
    if _focus_text == null or _map == null:
        return
    var owner: Control = get_viewport().gui_get_focus_owner()
    var focus_name := "无控件持有焦点（Tab 可进入操作区）"
    if owner == _map:
        focus_name = "网格（WASD/方向键移动；Esc 释放）"
    elif owner is Button:
        focus_name = "按钮：" + str((owner as Button).text)
    elif owner is OptionButton:
        focus_name = "下拉选择"
    elif owner is TextEdit:
        focus_name = "只读证据卡（Tab 可移出）"
    _focus_text.text = "当前键盘焦点：" + focus_name + "\n窗口状态：" + (
        "已聚焦" if _window_focused else "未聚焦"
    ) + "；按键门禁：" + ("需松开移动键" if _release_gate else "正常")

func _all_movement_released() -> bool:
    for key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
        if Input.is_key_pressed(key):
            return false
    return true

func _process(_delta: float) -> void:
    if not _window_focused:
        return
    var changed := false
    if _release_gate and _all_movement_released():
        _release_gate = false
        changed = true
    if _restore_map_request:
        _restore_map_request = false
        var owner: Control = get_viewport().gui_get_focus_owner()
        if owner == null and _map != null:
            _map.grab_focus()
            changed = true
    if changed:
        _update_focus_text()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        _window_focused = false
        _release_gate = true
        _restore_map_request = _map != null and _map.has_focus()
    elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
        _window_focused = true
        # Never auto-move, inspect, correct or grab an occupied control.
