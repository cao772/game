extends Control
## GAME-WEB-REGION-018 r1 | text-first synthetic grid; NOT_RUN.
signal cell_selected(cell: Vector2i)
signal move_requested(direction: Vector2i)
var _state: Dictionary = {}
var _tile_size: float = 32.0
var _origin: Vector2 = Vector2.ZERO
var _scale: float = 1.0
var _motion_mode: int = 0
var _elapsed: float = 0.0
var _phase: float = 0.0

func _ready() -> void:
    focus_mode = Control.FOCUS_ALL
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_process(false)

func set_state(value: Dictionary) -> void:
    _state = value.duplicate(true)
    queue_redraw()

func set_accessibility_options(text_scale: float, motion_mode: int) -> void:
    _scale = clampf(text_scale, 1.0, 1.5)
    _motion_mode = clampi(motion_mode, 0, 2) # 关闭/舒缓/标准，均非信息来源
    _elapsed = 0.0
    _phase = 0.0
    set_process(_motion_mode != 0)
    queue_redraw()

func _process(delta: float) -> void:
    if _motion_mode == 0:
        return
    _elapsed += minf(delta, 0.10)
    var interval: float = 0.60 if _motion_mode == 1 else 0.15
    if _elapsed >= interval:
        _elapsed = 0.0
        _phase += interval
        queue_redraw()

func _grid_geometry() -> Vector2i:
    var rows: Array = _state.get("grid", [])
    if rows.is_empty():
        return Vector2i.ZERO
    return Vector2i(str(rows[0]).length(), rows.size())

func _draw() -> void:
    var dims: Vector2i = _grid_geometry()
    var font: Font = ThemeDB.fallback_font
    if dims.x < 1 or dims.y < 1:
        draw_string(font, Vector2(16, 32), "合成网格缺失：请检查必需源码。", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
        return
    _tile_size = minf((size.x - 24.0) / float(dims.x), (size.y - 70.0) / float(dims.y))
    _tile_size = maxf(8.0, _tile_size)
    _origin = Vector2((size.x - float(dims.x) * _tile_size) / 2.0, 10.0)
    var rows: Array = _state.get("grid", [])
    var preview: Array = _state.get("preview", [])
    var player: Vector2i = _state.get("player", Vector2i.ZERO)
    var target: Vector2i = _state.get("target", Vector2i.ZERO)
    var start: Vector2i = _state.get("start", Vector2i.ZERO)
    for y in range(dims.y):
        for x in range(dims.x):
            var cell := Vector2i(x, y)
            var blocked: bool = str(rows[y]).substr(x, 1) == "#"
            var background := Color(0.18, 0.22, 0.26) if blocked else Color(0.42, 0.46, 0.50)
            var symbol := "#" if blocked else "."
            if preview.has(cell) and not blocked:
                background = Color(0.20, 0.40, 0.53)
                symbol = ":"
            if cell == start:
                symbol = "S"
            if cell == target:
                symbol = "T"
            if cell == player:
                symbol = "P"
            var rect := Rect2(_origin + Vector2(x, y) * _tile_size,
                Vector2.ONE * maxf(1.0, _tile_size - 2.0))
            draw_rect(rect, background)
            draw_string(font, rect.position + Vector2(4.0, _tile_size * 0.70),
                symbol, HORIZONTAL_ALIGNMENT_LEFT, -1,
                maxi(12, mini(int(_tile_size * 0.60), int(20.0 * _scale))), Color.WHITE)
            if cell == player:
                var border := Color.WHITE
                if _motion_mode != 0:
                    border.a = 0.70 + 0.30 * absf(sinf(_phase * (1.0 if _motion_mode == 1 else 3.0)))
                draw_rect(rect.grow(-1.0), border, false, 3.0)
    if has_focus():
        draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color.WHITE, false, 3.0)
    draw_string(font, Vector2(12, size.y - 16),
        "# 墙   . 路面   : 路线   S 起点   T 目标   P 当前",
        HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, int(14.0 * _scale)), Color.WHITE)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            var dims: Vector2i = _grid_geometry()
            if dims.x == 0:
                return
            var point: Vector2 = (event.position - _origin) / _tile_size
            var cell := Vector2i(floori(point.x), floori(point.y))
            if cell.x >= 0 and cell.y >= 0 and cell.x < dims.x and cell.y < dims.y:
                grab_focus()
                cell_selected.emit(cell)
                accept_event()
    elif event is InputEventKey and event.pressed and not event.echo and has_focus():
        var direction := Vector2i.ZERO
        match event.keycode:
            KEY_W, KEY_UP: direction = Vector2i(0, -1)
            KEY_S, KEY_DOWN: direction = Vector2i(0, 1)
            KEY_A, KEY_LEFT: direction = Vector2i(-1, 0)
            KEY_D, KEY_RIGHT: direction = Vector2i(1, 0)
            KEY_ESCAPE:
                release_focus()
                queue_redraw()
                accept_event()
                return
        if direction != Vector2i.ZERO:
            move_requested.emit(direction)
            accept_event()

func _notification(what: int) -> void:
    if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
        queue_redraw()
