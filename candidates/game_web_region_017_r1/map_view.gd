extends Control
## Synthetic 2D grid display only; no sprites, authored map, or external assets.
signal cell_selected(cell: Vector2i)
signal move_requested(direction: Vector2i)

var _state: Dictionary = {}
var _tile_size: float = 32.0
var _origin: Vector2 = Vector2.ZERO


func _ready() -> void:
    focus_mode = Control.FOCUS_ALL
    mouse_filter = Control.MOUSE_FILTER_STOP


func set_state(value: Dictionary) -> void:
    _state = value.duplicate(true)
    queue_redraw()


func _grid_geometry() -> Vector2i:
    var rows: Array = _state.get("grid", [])
    if rows.is_empty():
        return Vector2i.ZERO
    return Vector2i(str(rows[0]).length(), rows.size())


func _draw() -> void:
    var dims: Vector2i = _grid_geometry()
    if dims.x < 1 or dims.y < 1:
        draw_string(ThemeDB.fallback_font, Vector2(18, 34), "无可绘制的合成地图", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
        return
    _tile_size = minf((size.x - 28.0) / float(dims.x), (size.y - 48.0) / float(dims.y))
    _tile_size = maxf(8.0, _tile_size)
    _origin = Vector2((size.x - float(dims.x) * _tile_size) / 2.0, 16.0)
    var rows: Array = _state.get("grid", [])
    var preview: Array = _state.get("preview", [])
    var player: Vector2i = _state.get("player", Vector2i.ZERO)
    var target: Vector2i = _state.get("target", Vector2i.ZERO)
    var start: Vector2i = _state.get("start", Vector2i.ZERO)
    for y in range(dims.y):
        for x in range(dims.x):
            var cell := Vector2i(x, y)
            var blocked: bool = str(rows[y]).substr(x, 1) == "#"
            var tint := Color(0.22, 0.25, 0.31) if blocked else Color(0.48, 0.51, 0.55)
            if preview.has(cell) and not blocked:
                tint = Color(0.24, 0.56, 0.66)
            if cell == start:
                tint = Color(0.23, 0.58, 0.40)
            if cell == target:
                tint = Color(0.65, 0.45, 0.18)
            if cell == player:
                tint = Color(0.88, 0.77, 0.34)
            var rect := Rect2(_origin + Vector2(x, y) * _tile_size, Vector2.ONE * (_tile_size - 2.0))
            draw_rect(rect, tint)
            if cell == player or cell == target or cell == start:
                var mark := "P" if cell == player else ("T" if cell == target else "S")
                draw_string(ThemeDB.fallback_font, rect.position + Vector2(7, _tile_size * 0.68), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, int(_tile_size * 0.35)), Color(0.07, 0.09, 0.13))
    if has_focus():
        draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(0.6, 0.85, 0.95), false, 2.0)
    draw_string(ThemeDB.fallback_font, Vector2(12, size.y - 8), "P 玩家  S 起点  T 目标  深色=实体遮挡  蓝色=预览路线",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.9, 0.9))


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
        var dir := Vector2i.ZERO
        match event.keycode:
            KEY_W, KEY_UP: dir = Vector2i(0, -1)
            KEY_S, KEY_DOWN: dir = Vector2i(0, 1)
            KEY_A, KEY_LEFT: dir = Vector2i(-1, 0)
            KEY_D, KEY_RIGHT: dir = Vector2i(1, 0)
            KEY_ESCAPE:
                release_focus()
                queue_redraw()
                accept_event()
                return
        if dir != Vector2i.ZERO:
            move_requested.emit(dir)
            accept_event()


func _notification(what: int) -> void:
    if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
        queue_redraw()
