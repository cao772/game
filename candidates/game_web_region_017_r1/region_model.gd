extends RefCounted
## GAME-WEB-REGION-017 r1. Public synthetic-only, memory-only trial model.
## No canonical scene, persistence, event bus, shared interface or external data.
const FIXTURE_PATH = "res://synthetic_regions.json"
const VERSION = "public-synthetic-region-017-v1"
const FALLBACK = {
    "schema_version": VERSION,
    "scenarios": [
        {"id": "A", "title": "A | 视线遮挡",
         "grid": ["#########", "#S..#..T#", "#...#...#", "#.......#", "#.......#", "#.......#", "#########"],
         "claimed": {"reachable": true, "visible": true}},
        {"id": "B", "title": "B | 绕行可达",
         "grid": ["##########", "#S.......#", "#.######.#", "#.#....#.#", "#.#.##.#.#", "#...##..T#", "##########"],
         "claimed": {"reachable": false, "visible": false}},
        {"id": "C", "title": "C | 不可达回退",
         "grid": ["#########", "#S......#", "#.......#", "#####.###", "#..#.#T##", "#....####", "#########"],
         "claimed": {"reachable": true, "visible": false}}
    ]
}
const DIRECTIONS = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]
const MAX_AUDIT = 12

var _catalog: Dictionary = {}
var _active: String = "A"
var _grid: Array[String] = []
var _start: Vector2i
var _target: Vector2i
var _player: Vector2i
var _preview: Array[Vector2i] = []
var _reported: Dictionary = {}
var _inspected: bool = false
var _audit: Array[String] = []
var _notice: String = ""
var _feedback: String = ""
var _source: String = "fallback"


func load_catalog() -> void:
    var chosen: Dictionary = FALLBACK.duplicate(true)
    _source = "embedded fallback"
    _notice = "内置纯合成样本。"
    if FileAccess.file_exists(FIXTURE_PATH):
        var file: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.READ)
        if file != null:
            var parsed: Variant = JSON.parse_string(file.get_as_text())
            if _valid_catalog(parsed):
                chosen = parsed.duplicate(true)
                _source = "synthetic_regions.json"
                _notice = "独立合成资源已读取（未验证运行）。"
            else:
                _notice = "外部占位资源无效，已降级至内置 A/B/C；无外部替代内容。"
        else:
            _notice = "外部占位资源不可读，已使用内置 A/B/C。"
    else:
        _notice = "外部占位资源缺失，已使用内置 A/B/C。"
    _catalog = chosen
    select_scene("A")


func _valid_catalog(raw: Variant) -> bool:
    if not (raw is Dictionary):
        return false
    var catalog: Dictionary = raw
    if catalog.get("schema_version") != VERSION:
        return false
    var scenarios: Variant = catalog.get("scenarios")
    if not (scenarios is Array) or scenarios.size() != 3:
        return false
    var ids: Dictionary = {}
    for value in scenarios:
        if not (value is Dictionary):
            return false
        var record: Dictionary = value
        var id: Variant = record.get("id")
        if not (id is String) or not ["A", "B", "C"].has(id) or ids.has(id):
            return false
        ids[id] = true
        var title: Variant = record.get("title")
        if not (title is String) or title.length() < 1 or title.length() > 40:
            return false
        var claims: Variant = record.get("claimed")
        if not (claims is Dictionary):
            return false
        if not (claims.get("reachable") is bool) or not (claims.get("visible") is bool):
            return false
        var rows: Variant = record.get("grid")
        if not (rows is Array) or rows.size() < 5 or rows.size() > 12:
            return false
        var width: int = -1
        var start_count: int = 0
        var target_count: int = 0
        for y in range(rows.size()):
            var row: Variant = rows[y]
            if not (row is String):
                return false
            if width == -1:
                width = row.length()
            if width < 5 or width > 16 or row.length() != width:
                return false
            for x in range(width):
                var ch: String = row.substr(x, 1)
                if not ["#", ".", "S", "T"].has(ch):
                    return false
                if (y == 0 or y == rows.size() - 1 or x == 0 or x == width - 1) and ch != "#":
                    return false
                if ch == "S":
                    start_count += 1
                elif ch == "T":
                    target_count += 1
        if start_count != 1 or target_count != 1:
            return false
    return ids.has("A") and ids.has("B") and ids.has("C")


func select_scene(id: String) -> bool:
    var record: Dictionary = {}
    for item in _catalog.get("scenarios", []):
        if item.get("id", "") == id:
            record = item
            break
    if record.is_empty():
        _feedback = "无效场景标识；未修改当前场景。"
        return false
    _active = id
    _grid.clear()
    for row in record["grid"]:
        _grid.append(row)
    for y in range(_grid.size()):
        for x in range(_grid[y].length()):
            var ch: String = _grid[y].substr(x, 1)
            if ch == "S":
                _start = Vector2i(x, y)
            elif ch == "T":
                _target = Vector2i(x, y)
    _player = _start
    _reported = record["claimed"].duplicate(true)
    _inspected = false
    _preview.clear()
    _audit.clear()
    _feedback = "合成场景 " + id + " 已重置，未记录任何真实世界变化。"
    return true


func _cell(point: Vector2i) -> String:
    if point.y < 0 or point.y >= _grid.size():
        return "#"
    if point.x < 0 or point.x >= _grid[point.y].length():
        return "#"
    return _grid[point.y].substr(point.x, 1)


func _passable(point: Vector2i) -> bool:
    return _cell(point) != "#"


func _route(goal: Vector2i) -> Array[Vector2i]:
    var empty: Array[Vector2i] = []
    if not _passable(goal) or not _passable(_player):
        return empty
    var queue: Array[Vector2i] = [_player]
    var prior: Dictionary = {_player: _player}
    var head: int = 0
    while head < queue.size():
        var cursor: Vector2i = queue[head]
        head += 1
        if cursor == goal:
            break
        for direction in DIRECTIONS:
            var step: Vector2i = cursor + direction
            if _passable(step) and not prior.has(step):
                prior[step] = cursor
                queue.append(step)
    if not prior.has(goal):
        return empty
    var path: Array[Vector2i] = []
    var cursor: Vector2i = goal
    while cursor != _player:
        path.push_front(cursor)
        cursor = prior[cursor]
    path.push_front(_player)
    return path


func _visible() -> bool:
    # Grid sampling is an explanatory occlusion proxy, not physical ray-casting.
    var delta: Vector2i = _target - _player
    var steps: int = maxi(absi(delta.x), absi(delta.y)) * 8
    if steps < 1:
        return true
    for i in range(steps + 1):
        var ratio: float = float(i) / float(steps)
        var point := Vector2i(
            roundi(lerpf(float(_player.x), float(_target.x), ratio)),
            roundi(lerpf(float(_player.y), float(_target.y), ratio))
        )
        if _cell(point) == "#":
            return false
    return true


func show_target_route() -> void:
    _preview = _route(_target)
    _feedback = "到目标：不可达；仍可规划返回起点。" if _preview.is_empty() else "目标路线已显示；不自动移动。"


func show_recovery_route() -> void:
    _preview = _route(_start)
    _feedback = "当前无法计算安全回退，请保持原位。" if _preview.is_empty() else "回到起点的可走路线已显示；不自动移动。"


func preview_cell(point: Vector2i) -> void:
    if not _passable(point):
        _feedback = "此格为实心遮挡，不可选为可达目标。"
        return
    _preview = _route(point)
    _feedback = "此格暂不可达，改用返回起点路线。" if _preview.is_empty() else "已预览选中格的路线；不自动行走。"


func move_player(direction: Vector2i) -> void:
    if not DIRECTIONS.has(direction):
        _feedback = "无效的移动方向。"
        return
    var next_point: Vector2i = _player + direction
    if not _passable(next_point):
        _feedback = "被实心格阻挡；可查看目标路线或返回起点。"
        return
    _player = next_point
    _preview.clear()
    _inspected = false
    _feedback = "已移动一个合成格；需重新核对当前视线与可达性。"


func inspect() -> void:
    _inspected = true
    var reachable: bool = not _route(_target).is_empty()
    var visible: bool = _visible()
    _feedback = "已检查：路线%s、视线%s。记录更正需另行确认。" % [
        "可达" if reachable else "不可达", "可见" if visible else "遮挡"
    ]
    _append_audit("核对：可达=%s，视线=%s" % [str(reachable), str(visible)])


func correct_record() -> void:
    if not _inspected:
        _feedback = "先执行本地核对，再明确提交更正。"
        return
    var actual := {"reachable": not _route(_target).is_empty(), "visible": _visible()}
    if _reported == actual:
        _feedback = "记录与当前观察一致，无需更正。"
        return
    _reported = actual.duplicate(true)
    _append_audit("更正：记录改为可达=%s，视线=%s" % [
        str(actual["reachable"]), str(actual["visible"])
    ])
    _feedback = "本地候选记录已更正；无文件写入，不影响原始样本。"


func _append_audit(message: String) -> void:
    _audit.append(message)
    while _audit.size() > MAX_AUDIT:
        _audit.pop_front()


func snapshot() -> Dictionary:
    var reachable: bool = not _route(_target).is_empty()
    return {
        "id": _active, "grid": _grid.duplicate(), "player": _player,
        "start": _start, "target": _target, "preview": _preview.duplicate(),
        "claimed": _reported.duplicate(true),
        "inspected": _inspected,
        "actual_reachable": reachable, "actual_visible": _visible(),
        "source": _source, "notice": _notice,
        "feedback": _feedback, "audit": _audit.duplicate()
    }
