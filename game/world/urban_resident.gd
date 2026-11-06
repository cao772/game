extends CharacterBody3D
## Workshop routine proxy. The scene calls advance() from its physics callback.
## phase is the current destination/dwell ID; goal advances during a dwell.
## Graph coordinates are world-space feet positions in the modern street.

const MODEL: PackedScene = preload("res://art/resident_merchant/merchant.glb")
const SPEED: float = 1.05
const ARRIVAL: float = 0.025
const LEVEL_TOLERANCE: float = 0.08
const MAX_STEP: float = 0.1
const PHASES := ["bench", "shelf", "yard", "terrace"]
const DWELL := {"bench": 25.0, "shelf": 12.0, "yard": 20.0, "terrace": 24.0}
const POINTS := {
	"bench": Vector3(18, 0, 11.5), "shelf": Vector3(22.5, 0, 23.1),
	"yard": Vector3(27, 0, 18.8), "center": Vector3(19, 0, 17.5),
	"front_in": Vector3(15.3, 0, 17.5), "front_out": Vector3(13.2, 0, 17.5),
	"back_in": Vector3(22.9, 0, 17.5), "back_out": Vector3(25, 0, 17.5),
	"south_front": Vector3(13.2, 0, 29.5), "south_back": Vector3(25, 0, 29.5),
	# Reach the stair from its ground end; never cut through its side or jump
	# from the rear lane onto the elevated slab. All heights are authored floors.
	"north_ground": Vector3(25, 0, 2), "stair_approach": Vector3(37.2, 0, 2),
	"stair_foot": Vector3(37.2, 0, 3), "stair_top": Vector3(37.2, 3, 11),
	"landing": Vector3(37.2, 3, 12), "deck_east": Vector3(33, 3, 12),
	"deck_inner": Vector3(33, 3, 8.5), "terrace": Vector3(29, 3, 8.5),
}
const EDGES := [
	["bench", "center", ""], ["shelf", "center", ""],
	["center", "back_in", ""], ["back_in", "back_out", "back_open"],
	["center", "front_in", ""], ["front_in", "front_out", "front_open"],
	["front_out", "south_front", ""], ["south_front", "south_back", ""],
	["south_back", "back_out", ""], ["back_out", "yard", ""],
	["back_out", "north_ground", ""], ["north_ground", "stair_approach", ""],
	["stair_approach", "stair_foot", ""], ["stair_foot", "stair_top", ""],
	["stair_top", "landing", ""], ["landing", "deck_east", ""],
	["deck_east", "deck_inner", ""], ["deck_inner", "terrace", ""],
]
const GATE_PLANE := {"front_open": 14.28, "back_open": 23.92}

var _animation: AnimationPlayer
var _visual: Node3D
var _player_probe: CapsuleShape3D
var _phase_index: int = 0
var _node: String = "bench"
var _remaining: float = 25.0
var _edge_from: String = ""
var _edge_to: String = ""
var _edge_gate: String = ""
var _gate_resolved: bool = false
var _returning: bool = false
var _conversing: bool = false
var _enabled: bool = true
var _moving: bool = false
var _blocked: String = ""
var _activity: String = "在工作台前等照明"
var _view: Dictionary = {}


func _ready() -> void:
	collision_layer = 4
	collision_mask = 3
	safe_margin = 0.002
	floor_snap_length = 0.15
	floor_max_angle = deg_to_rad(45.0)
	floor_stop_on_slope = true
	floor_constant_speed = true
	floor_block_on_wall = true
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.875
	add_child(shape)
	# A small vertical envelope includes the capsule's ~0.021m geometric lift
	# on the 20.556deg stair ramp and the join between ramp and flat floor.
	_player_probe = CapsuleShape3D.new()
	_player_probe.radius = capsule.radius
	_player_probe.height = capsule.height + 0.2
	_visual = MODEL.instantiate() as Node3D
	_visual.scale = Vector3.ONE * 0.84
	add_child(_visual)
	var players := _visual.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_animation = players[0] as AnimationPlayer
		# Each resident gets its own animation resources before changing loop modes.
		for library_name in _animation.get_animation_library_list():
			var original := _animation.get_animation_library(library_name)
			var library := AnimationLibrary.new()
			for animation_name in original.get_animation_list():
				var animation := original.get_animation(animation_name).duplicate(true) as Animation
				library.add_animation(animation_name, animation)
			_animation.remove_animation_library(library_name)
			_animation.add_animation_library(library_name, library)
		for clip in [&"Idle", &"Walking_A", &"Interact", &"Cheer"]:
			if _animation.has_animation(clip):
				_animation.get_animation(clip).loop_mode = Animation.LOOP_NONE if clip == &"Cheer" else Animation.LOOP_LINEAR
	reset_routine()


func reset_routine() -> void:
	# The only explicit relocation; normal routing never assigns a world position.
	global_position = POINTS["bench"]
	velocity = Vector3.ZERO
	_phase_index = 0
	_node = "bench"
	_remaining = float(DWELL["bench"])
	_clear_edge()
	_conversing = false
	_enabled = true
	_moving = false
	_blocked = ""
	_activity = "在工作台前等照明"
	if is_instance_valid(_visual):
		_visual.rotation.y = PI
	_play(&"Idle")
	if is_instance_valid(_animation):
		_animation.seek(0.0, true)


func advance(delta: float, view: Dictionary, enabled: bool) -> void:
	_view = view.duplicate()
	_enabled = enabled
	_moving = false
	_blocked = ""
	if not enabled or _conversing:
		velocity = Vector3.ZERO
		if not _conversing:
			_activity = "暂时停步"
			_play(&"Idle")
		return
	if delta <= 0.0 or not is_finite(delta):
		return
	if _edge_to.is_empty() and _node == _phase():
		_settle(delta)
		if not _at_point(POINTS[_node]):
			_blocked = "obstacle"
			_activity = "等脚下站稳"
			_play(&"Idle")
			return
		_remaining = maxf(0.0, _remaining - minf(delta, MAX_STEP))
		if _remaining > 0.0:
			_work_or_rest()
			return
		_phase_index = (_phase_index + 1) % PHASES.size()
	if _edge_to.is_empty():
		var route := _route(_node, _phase())
		if route.size() < 2:
			velocity = Vector3.ZERO
			_blocked = "gate"
			_activity = "通路关着，等门打开"
			_play(&"Idle")
			return
		_edge_from = _node
		_edge_to = route[1]
		_edge_gate = _gate_for(_edge_from, _edge_to)
		_gate_resolved = false
		_returning = false
	_resolve_closed_crossing()
	_walk_edge(delta)


func set_conversing(value: bool) -> void:
	if _conversing == value:
		return
	_conversing = value
	velocity = Vector3.ZERO
	_moving = false
	_blocked = ""
	if value:
		_activity = "停下来和你聊两句"
		if is_instance_valid(_animation) and _animation.has_animation(&"Cheer"):
			_animation.clear_queue()
			_animation.play(&"Cheer", 0.12)
			if _animation.has_animation(&"Idle"):
				_animation.queue(&"Idle")
		else:
			_play(&"Idle")
	else:
		_play(&"Idle")


func status() -> Dictionary:
	var goal: String = _phase()
	if _edge_to.is_empty() and _node == _phase():
		goal = PHASES[(_phase_index + 1) % PHASES.size()]
	return {"id": "workshop_resident", "activity": _activity, "goal": goal,
		"moving": _moving, "blocked": _blocked, "phase": _phase()}


func interaction_target() -> Dictionary:
	return {"id": "workshop_resident", "label": "工坊住户",
		"position": global_position + Vector3.UP * 1.15}


func possible_next_position(delta: float) -> Vector3:
	if not _enabled or _conversing or delta <= 0.0 or not is_finite(delta):
		return global_position
	var next: String = _edge_to
	var from: String = _edge_from
	if next.is_empty():
		from = _node
		var destination := _phase()
		if _node == destination:
			if _remaining > minf(delta, MAX_STEP):
				return global_position
			destination = PHASES[(_phase_index + 1) % PHASES.size()]
		var route := _route(_node, destination)
		if route.size() < 2:
			return global_position
		next = route[1]
	return global_position + _edge_motion(from, next, minf(delta, MAX_STEP))


func _resolve_closed_crossing() -> void:
	if _edge_gate.is_empty() or _gate_resolved or bool(_view.get(_edge_gate, false)):
		return
	# Resolve once to the endpoint on the CURRENT side. Never pick a nearest graph
	# node or draw a new line through the wall when a door changes mid-edge.
	var from_point: Vector3 = POINTS[_edge_from]
	var to_point: Vector3 = POINTS[_edge_to]
	var direction: float = signf(to_point.x - from_point.x)
	var far_side: float = (global_position.x - float(GATE_PLANE[_edge_gate])) * direction
	if far_side <= 0.0:
		_edge_to = _edge_from
		_returning = true
	_gate_resolved = true


func _walk_edge(delta: float) -> void:
	var offset := _horizontal(POINTS[_edge_to] - global_position)
	if offset.length() <= ARRIVAL:
		_settle(delta)
		if _at_point(POINTS[_edge_to]):
			_arrive()
		else:
			_blocked = "obstacle"
			_activity = "等脚下站稳"
		_play(&"Idle")
		return
	# move_and_slide uses the engine's full physics delta. Bound the requested
	# displacement, then divide by that original delta, not by the capped step.
	var planned := _edge_motion(_edge_from, _edge_to, minf(delta, MAX_STEP))
	var intended := _horizontal(planned) / delta
	# Check players separately: an uphill floor can be the first world hit and
	# otherwise conceal a player farther along the same swept capsule motion.
	if _player_in_path(planned):
		_blocked = "player"
	var probe := KinematicCollision3D.new()
	if _blocked.is_empty() and test_move(global_transform, intended * delta, probe, safe_margin, false, 4):
		_blocked = _collision_kind(probe)
	if not _blocked.is_empty():
		_settle(delta)
		_activity = "等你先过" if _blocked == "player" else "前面暂时走不过去"
		_play(&"Idle")
		return
	var before := global_position
	velocity.x = intended.x
	velocity.z = intended.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * minf(delta, MAX_STEP)
	move_and_slide()
	# Bounded movement drops <0.04m per frame on this ramp, inside the 0.15m
	# snap range. Snap is a collision operation, never an authored-y assignment.
	apply_floor_snap()
	for index in range(get_slide_collision_count()):
		var kind := _collision_kind(get_slide_collision(index))
		if not kind.is_empty():
			_blocked = kind
			if kind == "player":
				break
	_moving = _horizontal(global_position - before).length() > 0.00001
	if is_instance_valid(_visual) and _moving:
		_visual.rotation.y = atan2(intended.x, intended.z)
	_activity = "先退回门边，再换条路" if _returning else "正往" + {"bench": "工作台", "shelf": "货架", "yard": "后院", "terrace": "晒台"}[_phase()] + "走"
	if not _moving and not _blocked.is_empty():
		_activity = "等你先过" if _blocked == "player" else "前面暂时走不过去"
	_play(&"Walking_A" if _moving else &"Idle")
	if _at_point(POINTS[_edge_to]):
		_arrive()


func _edge_motion(from: String, to: String, delta: float) -> Vector3:
	var motion := _horizontal(POINTS[to] - global_position).limit_length(SPEED * delta)
	var segment: Vector3 = POINTS[to] - POINTS[from]
	var run := _horizontal(segment).length()
	if run > 0.0001:
		motion.y = motion.length() * segment.y / run
	return motion


func _player_in_path(motion: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _player_probe
	query.transform = Transform3D(global_transform.basis, global_position + Vector3.UP * 0.875)
	query.collision_mask = 2
	query.exclude = [get_rid()]
	query.margin = 0.005
	query.collide_with_areas = false
	# cast_motion ignores shapes overlapped at its start, so check both poses.
	if not space.intersect_shape(query, 1).is_empty():
		return true
	query.motion = motion
	var fractions: PackedFloat32Array = space.cast_motion(query)
	if fractions.size() != 2 or fractions[0] < 1.0 or fractions[1] < 1.0:
		return true
	query.transform.origin += motion
	query.motion = Vector3.ZERO
	return not space.intersect_shape(query, 1).is_empty()


func _at_point(point: Vector3) -> bool:
	# Horizontal proximity alone must not finish an upper-floor edge from below.
	if not is_on_floor() or _horizontal(point - global_position).length() > ARRIVAL:
		return false
	if absf(point.y - global_position.y) > LEVEL_TOLERANCE:
		return false
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.1,
		global_position - Vector3.UP * 0.12, 1, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return false
	var normal: Vector3 = hit["normal"]
	var surface: Vector3 = hit["position"]
	return normal.y >= cos(floor_max_angle) and absf(surface.y - point.y) <= LEVEL_TOLERANCE


func _arrive() -> void:
	_node = _edge_to
	_clear_edge()
	if _node == _phase():
		_remaining = float(DWELL[_phase()])


func _clear_edge() -> void:
	_edge_from = ""
	_edge_to = ""
	_edge_gate = ""
	_gate_resolved = false
	_returning = false


func _settle(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * minf(delta, MAX_STEP)
	move_and_slide()
	apply_floor_snap()


func _collision_kind(hit: KinematicCollision3D) -> String:
	var obstacle: bool = false
	for index in range(hit.get_collision_count()):
		var body := hit.get_collider(index) as CollisionObject3D
		if body != null and (body.collision_layer & 2) != 0:
			return "player"
		if hit.get_normal(index).y < cos(floor_max_angle):
			obstacle = true
	if obstacle:
		return "gate" if not _edge_gate.is_empty() and not bool(_view.get(_edge_gate, false)) else "obstacle"
	return ""


func _work_or_rest() -> void:
	var working: bool = _phase() == "shelf" or (_phase() == "bench" and bool(_view.get("lamp_on", false)) and str(_view.get("toolbox_anchor", "")) == "bench")
	if _phase() == "bench":
		_activity = "在工作台前整理工具" if working else ("在工作台前等照明" if not bool(_view.get("lamp_on", false)) else "在工作台前等工具箱")
	elif _phase() == "shelf":
		_activity = "整理货架上的物件"
	elif _phase() == "terrace":
		_activity = "站在晒台边看看街景"
	else:
		_activity = "在后院歇一会儿"
	if is_instance_valid(_visual):
		# The northward view follows the open cross street, not the adjacent facade.
		_visual.rotation.y = PI if _phase() in ["bench", "terrace"] else 0.0
	_play(&"Interact" if working else &"Idle")


func _phase() -> String:
	return PHASES[_phase_index]


func _gate_for(from: String, to: String) -> String:
	for edge in EDGES:
		if (edge[0] == from and edge[1] == to) or (edge[1] == from and edge[0] == to):
			return str(edge[2])
	return ""


func _route(from: String, to: String) -> Array[String]:
	# Weighted shortest route naturally prefers the back door; the front-door
	# detour MUST go south, then north at x=25, before approaching the yard.
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
			if next.is_empty() or not pending.has(next):
				continue
			if not str(edge[2]).is_empty() and not bool(_view.get(edge[2], false)):
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
	var cursor: String = to
	route.append(cursor)
	while cursor != from:
		cursor = str(previous[cursor])
		route.append(cursor)
	route.reverse()
	return route


func _horizontal(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)


func _play(clip: StringName) -> void:
	if not is_instance_valid(_animation) or not _animation.has_animation(clip):
		return
	if _animation.current_animation == clip and _animation.is_playing():
		return
	_animation.clear_queue()
	_animation.play(clip, 0.12)
