extends RefCounted
## REGION-022 | isolated synthetic interaction state, NO loader or game APIs.
## Candidate source only. All runtime behavior remains NOT_RUN.
const DIRECTIONS = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]
const MAX_UNDO = 16
const MAX_LOG = 12

var _grid: Array = []
var _id: String = ""
var _start: Vector2i = Vector2i.ZERO
var _target: Vector2i = Vector2i.ZERO
var _player: Vector2i = Vector2i.ZERO
var _claim: Dictionary = {}
var _inspected: bool = false
var _preview: Array = []
var _undo: Array = []
var _log: Array = []
var _feedback: String = "未加载合成场景。"
var _ready: bool = false

func reset() -> void:
    _grid.clear()
    _id = ""
    _claim.clear()
    _inspected = false
    _preview.clear()
    _undo.clear()
    _log.clear()
    _ready = false
    _feedback = "无活动合成场景。"

func configure(scene: Dictionary) -> bool:
    # Caller owns validation and strips extra fields. Never read files here.
    reset()
    if not (scene.has("grid") and scene.has("id") and scene.has("claimed")):
        return false
    _id = str(scene["id"])
    _grid = scene["grid"].duplicate(true)
    _claim = scene["claimed"].duplicate(true)
    var found_s := false
    var found_t := false
    for y in range(_grid.size()):
        var row: String = str(_grid[y])
        for x in range(row.length()):
            if row.substr(x, 1) == "S":
                _start = Vector2i(x, y)
                found_s = true
            elif row.substr(x, 1) == "T":
                _target = Vector2i(x, y)
                found_t = true
    if not found_s or not found_t:
        reset()
        return false
    _player = _start
    _ready = true
    _feedback = "纯合成 " + _id + " 已重置；记录主张尚未核对。"
    return true

func _cell(p: Vector2i) -> String:
    if p.y < 0 or p.y >= _grid.size():
        return "#"
    var row: String = str(_grid[p.y])
    if p.x < 0 or p.x >= row.length():
        return "#"
    return row.substr(p.x, 1)

func _walkable(p: Vector2i) -> bool:
    return _cell(p) != "#"

func _route(goal: Vector2i) -> Array:
    var empty: Array = []
    if not _ready or not _walkable(_player) or not _walkable(goal):
        return empty
    var queue: Array = [_player]
    var back: Dictionary = {_player: _player}
    var head := 0
    while head < queue.size():
        var p: Vector2i = queue[head]
        head += 1
        if p == goal:
            break
        for step in DIRECTIONS:
            var next_point: Vector2i = p + step
            if _walkable(next_point) and not back.has(next_point):
                back[next_point] = p
                queue.append(next_point)
    if not back.has(goal):
        return empty
    var path: Array = []
    var cursor: Vector2i = goal
    while cursor != _player:
        path.push_front(cursor)
        cursor = back[cursor]
    path.push_front(_player)
    return path

func _visible() -> bool:
    # Grid sampling only, NOT Godot raycast or physical visibility.
    var delta: Vector2i = _target - _player
    var steps: int = maxi(absi(delta.x), absi(delta.y)) * 8
    if steps <= 0:
        return true
    for i in range(steps + 1):
        var ratio: float = float(i) / float(steps)
        var check := Vector2i(
            roundi(lerpf(float(_player.x), float(_target.x), ratio)),
            roundi(lerpf(float(_player.y), float(_target.y), ratio))
        )
        if _cell(check) == "#":
            return false
    return true

func _remember(kind: String) -> void:
    _undo.append({"kind": kind, "player": _player, "claim": _claim.duplicate(true)})
    while _undo.size() > MAX_UNDO:
        _undo.pop_front()

func _note(value: String) -> void:
    _log.append(value)
    while _log.size() > MAX_LOG:
        _log.pop_front()

func move(direction: Vector2i) -> void:
    if not _ready:
        _feedback = "没有有效合成场景，禁止移动。"
        return
    if not DIRECTIONS.has(direction):
        _feedback = "仅允许四个正交方向。"
        return
    var next_point: Vector2i = _player + direction
    if not _walkable(next_point):
        _feedback = "墙格不可进入；可预览返回 S 或撤销。"
        return
    _remember("移动")
    _player = next_point
    _inspected = false
    _preview.clear()
    _feedback = "已移动一格；位置改变后需重新核对。"

func preview_target() -> void:
    _preview = _route(_target)
    _feedback = "目标 T 当前不可达，仍可返回起点。" if _preview.is_empty() else "已预览 T 路线；没有自动移动。"

func preview_return() -> void:
    _preview = _route(_start)
    _feedback = "起点返回路线不可计算，停止继续移动。" if _preview.is_empty() else "已预览返回 S 路线；没有自动移动。"

func inspect() -> void:
    if not _ready:
        _feedback = "没有有效合成场景，不能核对。"
        return
    _inspected = true
    _note("本地模拟核对已触发（非测试结果）。")
    _feedback = "本地模拟核对已触发；仍须明确更正才会改变主张。"

func correct() -> void:
    if not _ready or not _inspected:
        _feedback = "先加载合成场景，再点击核对；不能直接更正。"
        return
    var actual := {"reachable": not _route(_target).is_empty(), "visible": _visible()}
    if _claim == actual:
        _feedback = "本地记录与模拟观察相同；无更改。"
        return
    _remember("合成记录更正")
    _claim = actual.duplicate(true)
    _note("本地合成记录已显式更正。")
    _feedback = "仅更正内存主张；原始 JSON 没有被修改。"

func undo() -> void:
    if not _ready or _undo.is_empty():
        _feedback = "无可撤销动作；可预览返回 S 或重置场景。"
        return
    var state: Dictionary = _undo.pop_back()
    _player = state["player"]
    _claim = state["claim"].duplicate(true)
    _preview.clear()
    _inspected = false
    _note("已撤销最近一次" + str(state["kind"]) + "，须重新核对。")
    _feedback = "已撤销，仅影响本地内存。"

func snapshot() -> Dictionary:
    var result: Dictionary = {
        "ready": _ready, "id": _id, "grid": _grid.duplicate(),
        "start": _start, "target": _target, "player": _player,
        "claim": _claim.duplicate(true), "inspected": _inspected,
        "preview": _preview.duplicate(), "undo_depth": _undo.size(),
        "log": _log.duplicate(), "feedback": _feedback,
        "actual": {} # No observed facts exposed before explicit Inspect.
    }
    if _ready and _inspected:
        result["actual"] = {
            "reachable": not _route(_target).is_empty(), "visible": _visible()
        }
    return result
