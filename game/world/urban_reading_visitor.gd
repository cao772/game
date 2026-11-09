extends "res://world/urban_visit_actor.gd"
## One finite visit, advanced only by the street's physics callback.
## Public tray is read-only. The visitor's notebook is always their own visual.

const ReadingRoom = preload("res://world/urban_reading_room.gd")
const SPEED: float = 0.95
const POINTS := {
	"home": Vector3(-12, 0, 18.8), "porch_join": Vector3(-12.4, 0, 18.8),
	"porch_read": Vector3(-12, 0, 17.4), "front_out": Vector3(-12.4, 0, 11.3),
	"front_in": Vector3(-16, 0, 11.3), "desk_read": Vector3(-22.8, 0, 11.35),
	"west": Vector3(-22.8, 0, 17.8), "window": Vector3(-22.9, 0, 19),
	"rear_west": Vector3(-22.8, 0, 22.2), "rear_in": Vector3(-22.3, 0, 24),
	"back_out": Vector3(-25.3, 0, 24), "lane": Vector3(-29, 0, 24),
	"south_west": Vector3(-29, 0, 30), "south_east": Vector3(-12.4, 0, 30),
	"east": Vector3(-16, 0, 20.5), "side_read": Vector3(-18.45, 0, 20.5),
	"rear_middle": Vector3(-18.45, 0, 22.2), "rear_east": Vector3(-17, 0, 24),
	"quiet": Vector3(-17, 0, 25.5),
}
const EDGES := [
	["home", "porch_join"], ["home", "porch_read"],
	["porch_join", "front_out"], ["front_out", "front_in"],
	["front_in", "desk_read"], ["desk_read", "west"], ["west", "window"],
	["window", "rear_west"], ["rear_west", "rear_in"],
	["rear_in", "back_out"], ["back_out", "lane"],
	["lane", "south_west"], ["south_west", "south_east"], ["south_east", "porch_join"],
	["front_in", "east"], ["east", "side_read"], ["side_read", "rear_middle"],
	["rear_middle", "rear_west"], ["rear_middle", "rear_east"],
	["rear_east", "rear_in"], ["rear_east", "quiet"],
]
const READ_POINTS := {"reading_book": "desk_read", "reading_side": "side_read", "reading_porch": "porch_read"}
const DEFAULT_LINES := {
	"porch": "先看看公共册，再画自己的本子。",
	"read": "这页留在这里就好，我看看。",
	"sketch": "你接着用书盘，我画我的。",
	"stow": "今天先画到这里。",
	"return": "出去走一圈，回廊下歇会儿。",
	"done": "这一趟画完了，暂时不进屋。",
	"blocked": "等这边空一点，我再走。",
}

var _notebook: Node3D
var _pages: Node3D
var _pencil: Node3D
var _ink: Node3D
var _phase: String = "porch"
var _node: String = "home"
var _goal: String = "home"
var _edge_from: String = ""
var _edge_to: String = ""
var _retreating: bool = false
var _blocked_edges: Dictionary = {}
var _blocked_time: float = 0.0
var _remaining: float = 8.0
var _active_time: float = 0.0
var _sketch_elapsed: float = 0.0
var _selected_anchor: String = ""
var _retargets: int = 0
var _quiet_selected: bool = false
var _enabled: bool = true
var _moving: bool = false
var _blocked: bool = false
var _view: Dictionary = {}
var _activity: String = "在前廊看看街景"
var _display_name: String = "阅览来客"
var _lines: Dictionary = DEFAULT_LINES.duplicate()


func _ready() -> void:
	_build_actor()
	_build_notebook()
	reset_visit()


func configure(data: Dictionary) -> bool:
	# Invalid copy leaves a usable generic visitor, never aborts the routine.
	if data.size() != 3 or data.get("schema_version") != 1 or not data.get("display_name") is String or not data.get("lines") is Dictionary:
		return false
	if data["display_name"].strip_edges().is_empty() or data["display_name"].length() > 40:
		return false
	var lines: Dictionary = data["lines"]
	if lines.size() != DEFAULT_LINES.size():
		return false
	for key in DEFAULT_LINES:
		if not lines.get(key) is String or lines[key].strip_edges().is_empty() or lines[key].length() > 160:
			return false
	_display_name = data["display_name"]
	_lines = lines.duplicate(true)
	return true


func reset_visit() -> void:
	# Initialization / successful explicit restore only. Movement never teleports.
	global_position = POINTS["home"]
	velocity = Vector3.ZERO
	_phase = "porch"
	_node = "home"
	_goal = "home"
	_edge_to = ""
	_edge_from = ""
	_retreating = false
	_blocked_edges.clear()
	_blocked_time = 0.0
	_remaining = 8.0
	_active_time = 0.0
	_sketch_elapsed = 0.0
	_selected_anchor = ""
	_retargets = 0
	_quiet_selected = false
	_enabled = true
	_moving = false
	_blocked = false
	_activity = "在前廊看看街景"
	_visual.rotation.y = PI * 0.5
	_play(&"Idle")
	_present_notebook()


func advance(delta: float, view: Dictionary, enabled: bool) -> void:
	_view = view.duplicate()
	_enabled = enabled
	_moving = false
	if not enabled:
		suspend_activity()
		return
	if delta <= 0.0 or not is_finite(delta):
		return
	var step := minf(delta, MAX_STEP)
	_active_time += step
	if not _edge_to.is_empty() or _node != _goal:
		if _edge_to.is_empty():
			_reconsider_public()
			var route := _route(_node, _goal)
			if route.size() < 2:
				_wait_for_route(step)
				_settle(delta)
				_present_notebook()
				return
			_edge_from = _node
			_edge_to = route[1]
		_walk(delta, step)
	else:
		_settle(delta)
		if _at_point(POINTS[_goal]):
			_dwell(step)
		else:
			_activity = "等脚下站稳"
			_play(&"Idle")
	_present_notebook()


func refresh_reading(view: Dictionary) -> void:
	# Called after player tray input, in the SAME physics frame. No time advances.
	_view = view.duplicate()
	if _phase == "read" and str(_view.get("anchor", "")) != _selected_anchor:
		_begin_sketch()
		_activity = "公共册被带走了，准备画自己的本子"
		_play(&"Idle")
		_present_notebook()


func suspend_activity() -> void:
	_enabled = false
	velocity = Vector3.ZERO
	_moving = false
	# Pause the exact animation pose; do not reset the route, paper or timers.
	if is_instance_valid(_animation):
		_animation.pause()


func interaction_target() -> Dictionary:
	return {"id": "reading_visitor", "label": _display_name, "position": global_position + Vector3.UP * 1.15}


func status() -> Dictionary:
	return {"name": _display_name, "activity": _activity, "phase": _phase, "goal": _goal,
		"moving": _moving, "blocked": _blocked, "done": _phase == "done"}


func describe() -> String:
	var key := _phase
	if key == "approach_public":
		key = "porch"
	elif key == "approach_sketch":
		key = "sketch"
	if _blocked:
		key = "blocked"
	return _display_name + " · " + _activity + "\n“" + str(_lines.get(key, _lines["porch"])) + "”"


func possible_next_position(delta: float) -> Vector3:
	if not _enabled or delta <= 0.0 or not is_finite(delta):
		return global_position
	# Conservative next-step occupancy, including a route about to start.
	var next := _edge_to
	if next.is_empty() and _node != _goal:
		var route := _route(_node, _goal)
		if route.size() >= 2:
			next = route[1]
	if next.is_empty():
		return global_position
	return global_position + _horizontal(POINTS[next] - global_position).limit_length(SPEED * minf(delta, MAX_STEP))


func _dwell(step: float) -> void:
	_moving = false
	_blocked = false
	_play(&"Idle")
	match _phase:
		"porch":
			_activity = "在前廊看看街景"
			_remaining = maxf(0.0, _remaining - step)
			if _remaining == 0.0:
				_select_public()
		"approach_public":
			_reconsider_public()
			if _phase == "approach_public" and _node == _goal:
				_phase = "read"
				_remaining = 12.0
				_blocked_time = 0.0
		"read":
			if str(_view.get("anchor", "")) != _selected_anchor:
				_begin_sketch()
			elif _can_see_public():
				_blocked_time = 0.0
				_remaining = maxf(0.0, _remaining - step)
				var page := int(_view.get("page", -1))
				_activity = "在看公共册的封面" if page < 0 else "在看公共册第%d页" % (page + 1)
				_face(ReadingRoom.TRAY_ANCHORS[_selected_anchor])
				if _remaining == 0.0:
					_begin_sketch()
			else:
				_activity = "等视线前空一点"
				_blocked_time += step
				if _blocked_time >= 4.0:
					_begin_sketch()
		"approach_sketch":
			_phase = "sketch"
			_remaining = 30.0
			_sketch_elapsed = 0.0
			_face(global_position + (Vector3.LEFT if _goal == "window" else Vector3.FORWARD))
		"sketch":
			_sketch_elapsed += step
			_remaining = maxf(0.0, _remaining - step)
			_activity = "在窗边补画自己的速写" if _goal == "window" else "在安静角落校对自己的草稿"
			if _remaining == 0.0:
				_phase = "stow"
				_remaining = 3.0
		"stow":
			_activity = "合上自己的本子，收好笔"
			_remaining = maxf(0.0, _remaining - step)
			if _remaining == 0.0:
				_phase = "return"
				_goal = "lane"
		"return":
			if _node == "home":
				_phase = "done"
				_activity = "这一趟画完了，在前廊歇着"
				_visual.rotation.y = PI * 0.5
			else:
				_goal = "home"
		"done":
			_activity = "这一趟画完了，在前廊歇着"


func _select_public() -> void:
	_selected_anchor = str(_view.get("anchor", ""))
	if READ_POINTS.has(_selected_anchor):
		_phase = "approach_public"
		_goal = READ_POINTS[_selected_anchor]
	else:
		_begin_sketch()


func _reconsider_public() -> void:
	# Only at a confirmed safe node, once. Never chase a carried book mid-edge.
	if _phase != "approach_public" or str(_view.get("anchor", "")) == _selected_anchor:
		return
	if _retargets == 0 and READ_POINTS.has(str(_view.get("anchor", ""))):
		_retargets += 1
		_select_public()
	else:
		_begin_sketch()


func _begin_sketch() -> void:
	_phase = "approach_sketch"
	_goal = "quiet" if _quiet_selected else "window"
	_blocked_time = 0.0


func _can_see_public() -> bool:
	if not ReadingRoom.TRAY_ANCHORS.has(_selected_anchor):
		return false
	var target: Vector3 = ReadingRoom.TRAY_ANCHORS[_selected_anchor] + Vector3.UP * 0.18
	var eye := global_position + Vector3.UP * 1.6
	if eye.distance_to(target) > 2.6:
		return false
	var ray := PhysicsRayQueryParameters3D.create(eye, target, 1 | 2 | 4, [get_rid()])
	ray.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _walk(delta: float, step: float) -> void:
	var offset := _horizontal(POINTS[_edge_to] - global_position)
	if offset.length() <= ARRIVAL:
		_settle(delta)
		if _at_point(POINTS[_edge_to]):
			_arrive()
		return
	var motion := offset.limit_length(SPEED * step)
	if not _sweep_clear(global_position, global_position + motion):
		_wait_for_route(step)
		_settle(delta)
		return
	_blocked = false
	_blocked_time = 0.0
	var before := global_position
	velocity = motion / delta
	velocity.y = 0.0 if is_on_floor() else -20.0 * step
	move_and_slide()
	apply_floor_snap()
	_moving = _horizontal(global_position - before).length() > 0.00001
	if _moving:
		_face(global_position + motion)
	_activity = "先退回已走过的路点" if _retreating else "走向" + _goal_label()
	_play(&"Walking_A" if _moving else &"Idle")
	if _at_point(POINTS[_edge_to]):
		_arrive()


func _wait_for_route(step: float) -> void:
	_blocked = true
	_moving = false
	_blocked_time += step
	_activity = "等这边空一点"
	_play(&"Idle")
	var patience: float = 4.0 if _phase == "approach_sketch" else 6.0
	if _blocked_time < patience or _retreating:
		return
	_blocked_time = 0.0
	if not _edge_to.is_empty():
		_blocked_edges[_edge_key(_edge_from, _edge_to)] = _active_time + 30.0
		# Return through the traversed segment, still checking every swept step.
		_edge_to = _edge_from
		_retreating = true
	if _phase == "approach_public":
		_begin_sketch()
	elif _phase == "approach_sketch" and not _quiet_selected:
		_quiet_selected = true
		_goal = "quiet"
	elif _phase == "return":
		_goal = "home" # A blocked back exit can fall back to the front entrance.


func _arrive() -> void:
	_node = _edge_to
	_edge_from = ""
	_edge_to = ""
	_retreating = false
	_blocked_time = 0.0
	_blocked = false
	_moving = false
	_play(&"Idle")
	_reconsider_public()


func _route(from: String, to: String) -> Array[String]:
	var distance: Dictionary = {from: 0.0}
	var previous: Dictionary = {}
	var pending: Array = POINTS.keys()
	while not pending.is_empty():
		var current: String = str(pending[0])
		for candidate in pending:
			if float(distance.get(candidate, INF)) < float(distance.get(current, INF)):
				current = str(candidate)
		pending.erase(current)
		if not distance.has(current) or current == to:
			break
		for edge in EDGES:
			var next: String = str(edge[1]) if edge[0] == current else (str(edge[0]) if edge[1] == current else "")
			if next.is_empty() or not pending.has(next) or float(_blocked_edges.get(_edge_key(current, next), 0.0)) > _active_time:
				continue
			var a: Vector3 = POINTS[current]
			var b: Vector3 = POINTS[next]
			var cost: float = float(distance[current]) + a.distance_to(b)
			if cost < float(distance.get(next, INF)):
				distance[next] = cost
				previous[next] = current
	var route: Array[String] = []
	if not distance.has(to):
		return route
	var cursor := to
	route.append(cursor)
	while cursor != from:
		cursor = str(previous[cursor])
		route.append(cursor)
	route.reverse()
	return route


func _edge_key(a: String, b: String) -> String:
	return a + ":" + b if a < b else b + ":" + a


func _goal_label() -> String:
	if _phase == "approach_public":
		return "公共册旁"
	if _phase == "approach_sketch":
		return "安静角落" if _goal == "quiet" else "窗边"
	return "后巷" if _goal == "lane" else "前廊"


func _build_notebook() -> void:
	_notebook = Node3D.new()
	_notebook.name = "PersonalNotebook"
	_visual.add_child(_notebook)
	_piece(_notebook, Vector3.ZERO, Vector3(0.40, 0.035, 0.28), Color("914e3f"))
	_pages = _piece(_notebook, Vector3(0, 0.023, 0), Vector3(0.36, 0.014, 0.24), Color("e8dec6"))
	_ink = Node3D.new()
	_notebook.add_child(_ink)
	for index in range(5):
		_piece(_ink, Vector3(-0.12 + index * 0.052, 0.032, -0.03 + (index % 2) * 0.02), Vector3(0.037, 0.004, 0.06), Color("636457"))
	_pencil = _piece(_notebook, Vector3(0.08, 0.05, 0), Vector3(0.012, 0.012, 0.17), Color("6c6651"))


func _present_notebook() -> void:
	var open: bool = _phase == "sketch"
	_notebook.position = Vector3(0, 1.18, 0.46) if open else Vector3(0.30, 0.67, 0.08)
	_notebook.rotation = Vector3(-0.25, 0, 0) if open else Vector3(0, 0, PI * 0.5)
	_pages.visible = open
	_ink.visible = open
	_pencil.position = Vector3(0.06 + sin(_sketch_elapsed * 3.0) * 0.04, 0.05, 0.01) if open else Vector3(0.16, 0.03, 0)
	# A finite visual progress cue, never a new inventory page or quest flag.
	for index in range(_ink.get_child_count()):
		(_ink.get_child(index) as Node3D).visible = _sketch_elapsed >= float(index + 1) * 5.0


func _piece(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> Node3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	return mesh
