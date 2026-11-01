extends PanelContainer
## GAME-WEB-REGION-024: local keyboard-focused synthetic map surface. NOT_RUN.
## This surface emits movement requests only; it cannot mutate game data.
signal move_requested(direction: Vector2i)

var _label: Label
var _scale: float = 1.0

func _ready() -> void:
    focus_mode = Control.FOCUS_ALL
    mouse_filter = Control.MOUSE_FILTER_STOP
    custom_minimum_size = Vector2(360, 170)
    _label = Label.new()
    _label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_child(_label)
    _label.text = "网格键盘区：Tab 聚焦；WASD/方向键每次移动一格；Esc 离开。"
    _apply_focus_style()
    set_text_scale(_scale)

func set_map_text(value: String) -> void:
    if _label != null and _label.text != value:
        _label.text = value

func set_text_scale(value: float) -> void:
    _scale = clampf(value, 1.0, 1.5)
    if _label != null:
        _label.add_theme_font_size_override("font_size", roundi(16.0 * _scale))

func _apply_focus_style() -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.15, 0.16, 0.19)
    style.border_color = Color.WHITE if has_focus() else Color(0.46, 0.48, 0.50)
    style.set_border_width_all(4 if has_focus() else 1)
    style.set_content_margin_all(12)
    add_theme_stylebox_override("panel", style)

func _notification(what: int) -> void:
    if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
        _apply_focus_style()

func _gui_input(event: InputEvent) -> void:
    if not has_focus() or not (event is InputEventKey):
        return
    var key: InputEventKey = event
    if not key.pressed or key.echo or key.alt_pressed or key.ctrl_pressed or key.meta_pressed:
        return
    var direction := Vector2i.ZERO
    match key.keycode:
        KEY_W, KEY_UP: direction = Vector2i(0, -1)
        KEY_S, KEY_DOWN: direction = Vector2i(0, 1)
        KEY_A, KEY_LEFT: direction = Vector2i(-1, 0)
        KEY_D, KEY_RIGHT: direction = Vector2i(1, 0)
        KEY_ESCAPE:
            release_focus()
            accept_event()
            return
    if direction != Vector2i.ZERO:
        move_requested.emit(direction)
        accept_event()
