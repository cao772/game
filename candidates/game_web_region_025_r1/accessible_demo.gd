extends Control
## GAME-WEB-REGION-024 | keyboard-first A/B/C validation/fallback UI.
## Derived from PR26 accessibility ideas + PR31 isolated data gateway.
## NOT_RUN. No shared InputMap, save, actors, private content or real map.
const GatewayScript = preload("res://validated_gateway.gd")
const CasesScript = preload("res://synthetic_cases.gd")
const StatusScript = preload("res://semantic_status.gd")
const GridScript = preload("res://keyboard_grid.gd")

var _gateway
var _cases
var _status
var _grid
var _scene: OptionButton
var _scale_choice: OptionButton
var _focus_label: Label
var _mode_label: Label
var _facts: Label
var _next_action: Label
var _map_readout: TextEdit
var _diagnostics: TextEdit
var _scaled: Array[Control] = []
var _action_buttons: Array[Button] = []
var _focus_grid_button: Button
var _font_scale: float = 1.0
var _window_focused: bool = true
var _release_gate: bool = false

func _ready() -> void:
    _gateway = GatewayScript.new()
    _cases = CasesScript.new()
    _status = StatusScript.new()
    _create_ui()
    _apply_text_scale()
    _gateway.load_local_synthetic()
    _refresh()
    set_process(false)

func _label(parent: Node, value: String) -> Label:
    var item := Label.new()
    item.text = value
    item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    item.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if parent is HBoxContainer else Control.SIZE_EXPAND_FILL
    parent.add_child(item)
    _scaled.append(item)
    return item

func _focus_style(item: Control) -> void:
    item.focus_mode = Control.FOCUS_ALL
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0, 0, 0, 0)
    style.border_color = Color.WHITE
    style.set_border_width_all(3)
    item.add_theme_stylebox_override("focus", style)
    item.focus_entered.connect(_update_focus)

func _button(parent: Node, caption: String, callback: Callable, changes_world: bool = false) -> Button:
    var item := Button.new()
    item.text = caption
    item.tooltip_text = caption
    item.pressed.connect(callback)
    parent.add_child(item)
    _scaled.append(item)
    _focus_style(item)
    if changes_world:
        _action_buttons.append(item)
    return item

func _choice(parent: Node, options: Array, callback: Callable) -> OptionButton:
    var item := OptionButton.new()
    for option in options:
        item.add_item(str(option))
    item.item_selected.connect(callback)
    parent.add_child(item)
    _scaled.append(item)
    _focus_style(item)
    return item

func _readout(parent: Node, title: String) -> TextEdit:
    _label(parent, title)
    var item := TextEdit.new()
    item.editable = false
    item.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    item.custom_minimum_size = Vector2(0, 175)
    item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    item.size_flags_vertical = Control.SIZE_EXPAND_FILL
    parent.add_child(item)
    _scaled.append(item)
    _focus_style(item)
    return item

func _create_ui() -> void:
    var scroll := ScrollContainer.new()
    add_child(scroll)
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.offset_left = 12.0
    scroll.offset_top = 12.0
    scroll.offset_right = -12.0
    scroll.offset_bottom = -12.0
    var root := VBoxContainer.new()
    root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.custom_minimum_size = Vector2(680, 0)
    scroll.add_child(root)

    _label(root, "GAME-WEB-REGION-024｜合成 A/B/C 键盘与状态可达候选｜NOT_RUN")
    _label(root, "纯键盘路径：Tab / Shift+Tab 选控件、Enter/Space 激活按钮；不需鼠标或颜色。网格拥有焦点时支持非连续按键 WASD/方向键，Esc 离开网格。")

    var source_row := HBoxContainer.new()
    root.add_child(source_row)
    _button(source_row, "重新读取固定合成数据", Callable(self, "_reload"))
    _button(source_row, "合成错误：版本", func(): _load_sample("BAD_VERSION"))
    _button(source_row, "合成错误：重复 ID", func(): _load_sample("DUPLICATE_ID"))
    _button(source_row, "合成错误：缺失 T", func(): _load_sample("MISSING_T"))

    var settings := HBoxContainer.new()
    root.add_child(settings)
    _label(settings, "合成场景：")
    _scene = _choice(settings, ["A", "B", "C"], Callable(self, "_select_scene"))
    _label(settings, "文字缩放：")
    _scale_choice = _choice(settings, ["100%", "125%", "150%"], Callable(self, "_text_changed"))
    _label(settings, "动效：关闭（固定，无信息依赖）")
    _focus_grid_button = _button(settings, "焦点转到网格", Callable(self, "_focus_grid"), true)

    _focus_label = _label(root, "键盘焦点：待初始化")
    _mode_label = _label(root, "")
    _next_action = _label(root, "")

    var move_row := HBoxContainer.new()
    root.add_child(move_row)
    _button(move_row, "向上一步 ↑", func(): _move(Vector2i(0, -1)), true)
    _button(move_row, "向下一步 ↓", func(): _move(Vector2i(0, 1)), true)
    _button(move_row, "向左一步 ←", func(): _move(Vector2i(-1, 0)), true)
    _button(move_row, "向右一步 →", func(): _move(Vector2i(1, 0)), true)

    var action_row := HBoxContainer.new()
    root.add_child(action_row)
    _button(action_row, "预览到目标 T", Callable(self, "_preview_target"), true)
    _button(action_row, "预览返回起点 S", Callable(self, "_preview_return"), true)
    _button(action_row, "1. 核对", Callable(self, "_inspect"), true)
    _button(action_row, "2. 明确更正内存记录", Callable(self, "_correct"), true)
    _button(action_row, "撤销最近操作", Callable(self, "_undo"), true)

    _facts = _label(root, "")
    _grid = GridScript.new()
    root.add_child(_grid)
    _grid.move_requested.connect(_move)
    _grid.focus_entered.connect(_update_focus)
    _grid.focus_exited.connect(_update_focus)
    _map_readout = _readout(root, "完整文字网格（逐行、字符图例与坐标；纯文本可选取阅读）")
    _diagnostics = _readout(root, "结构校验与回退：代码 / 字段路径 / 原因 / 处理建议")
    _label(root, "本候选只有内存记录、更正与撤销；不会保存事件、游戏世界或私人信息。文本不是屏幕阅读器实际播报证据。")

func _apply_text_scale() -> void:
    var pixels: int = roundi(16.0 * _font_scale)
    for item in _scaled:
        item.add_theme_font_size_override("font_size", pixels)
    if _grid != null:
        _grid.set_text_scale(_font_scale)

func _text_changed(index: int) -> void:
    if index < 0 or index > 2:
        return
    _font_scale = [1.0, 1.25, 1.5][index]
    _apply_text_scale()
    _refresh()

func _reload() -> void:
    _gateway.load_local_synthetic()
    _scene.select(0)
    _refresh()

func _load_sample(kind: String) -> void:
    var sample: Dictionary = _cases.example(kind)
    if sample.get("kind") != "VARIANT":
        return
    _gateway.load_example(sample["value"])
    _scene.select(0)
    _refresh()

func _select_scene(index: int) -> void:
    if index < 0 or index >= 3:
        return
    _gateway.select(["A", "B", "C"][index])
    _refresh()

func _focus_grid() -> void:
    if _gateway.snapshot().get("mode", "BLOCKED") == "BLOCKED":
        return
    _grid.grab_focus()
    _update_focus()

func _move(direction: Vector2i) -> void:
    if not _window_focused or _release_gate:
        _next_action.text = "键盘移动暂时暂停：切回窗口并松开所有移动键后，再操作方向按钮或网格。"
        return
    _gateway.move(direction)
    _refresh()

func _preview_target() -> void:
    _gateway.preview_target()
    _refresh()

func _preview_return() -> void:
    _gateway.preview_return()
    _refresh()

func _inspect() -> void:
    _gateway.inspect()
    _refresh()

func _correct() -> void:
    _gateway.correct()
    _refresh()

func _undo() -> void:
    _gateway.undo()
    _refresh()

func _set_text(control: TextEdit, value: String) -> void:
    if control.text == value:
        return
    var line: int = control.scroll_vertical
    control.text = value
    control.scroll_vertical = line

func _refresh() -> void:
    var snapshot: Dictionary = _gateway.snapshot()
    var blocked: bool = str(snapshot.get("mode", "BLOCKED")) == "BLOCKED"
    _scene.disabled = blocked
    for item in _action_buttons:
        item.disabled = blocked
    _grid.focus_mode = Control.FOCUS_NONE if blocked else Control.FOCUS_ALL
    if blocked and _grid.has_focus():
        _grid.release_focus()
    _mode_label.text = _status.provenance(snapshot) + "\n" + str(snapshot.get("source_message", ""))
    _facts.text = _status.facts(snapshot)
    _next_action.text = _status.next_action(snapshot)
    var map_text: String = _status.text_map(snapshot)
    _grid.set_map_text(map_text)
    _set_text(_map_readout, map_text)
    _set_text(_diagnostics, _status.diagnostics(snapshot))
    _update_focus()

func _update_focus() -> void:
    if _focus_label == null:
        return
    var owner: Control = get_viewport().gui_get_focus_owner()
    var label := "无控件拥有焦点；可使用 Tab 进入原生按钮。"
    if owner == _grid:
        label = "网格键盘区；WASD 或方向键移动，Esc 退出，Tab 到其他控件。"
    elif owner is OptionButton:
        var chosen: OptionButton = owner as OptionButton
        label = "选择器：" + (chosen.get_item_text(chosen.selected) if chosen.selected >= 0 else "尚未选择")
    elif owner is Button:
        label = "按钮：" + str((owner as Button).text)
    elif owner is TextEdit:
        label = "只读文字区：可选取、滚动、Tab 离开；该区域不控制 P。"
    _focus_label.text = "当前焦点：" + label + "\n窗口：" + ("聚焦" if _window_focused else "未聚焦") +         "；移动门禁：" + ("等待松开全部移动键" if _release_gate else "可响应新操作")

func _keys_released() -> bool:
    for key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
        if Input.is_key_pressed(key):
            return false
    return true

func _process(_delta: float) -> void:
    if not _window_focused:
        return
    if _release_gate and _keys_released():
        _release_gate = false
        set_process(false)
        _update_focus()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        _window_focused = false
        _release_gate = true
        set_process(true)
        _update_focus()
    elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
        _window_focused = true
        # Never auto-move, correct, change the scene or steal occupied focus.
        _update_focus()
