extends "res://world/urban_visit_actor.gd"
## This visitor brings one personal bundle; the public wash station has no dependency on it.

const ROUTE := [
	Vector3(-27.7, 0, 16.6), Vector3(-29, 0, 15.4), Vector3(-46.7, 0, 15.4),
	Vector3(-46.7, 0, 8.3), Vector3(-45.2, 0, 8.3),
]
const CORNER := 2
const LAST := 4
const WORK_SURFACE := Vector3(-44.4, 0.85, 8.3)
const SPEED := 1.05
const WAIT_LIMIT := 6.0

var display_name := "带布包的来客"
var keep_line := "这对杯碟我想自己留着。"
var _phase := "outward"
var _next := 1
var _elapsed := 0.0
var _wait := 0.0
var _enabled := true
var _space: BoxShape3D
var _kit: Node3D
var _bag: Node3D
var _dishes: Node3D
var _cup: Node3D
var _tag: Node3D


func _ready() -> void:
	_build_actor()
	_space = BoxShape3D.new()
	_space.size = Vector3(0.58, 0.48, 0.46)
	_build_kit()
	reset_visit()


func reset_visit() -> void:
	global_position = ROUTE[0]
	velocity = Vector3.ZERO
	_phase = "outward"
	_next = 1
	_elapsed = 0.0
	_wait = 0.0
	_enabled = true
	_face(ROUTE[1])
	_play(&"Idle")
	_present_bundle(0.0)


func advance(delta: float, enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		suspend_activity()
		return
	if delta <= 0.0 or not is_finite(delta):
		return
	var step := minf(delta, MAX_STEP)
	if _phase == "outward" or _phase == "return":
		_travel(delta, step)
		_present_bundle(0.0)
	elif _phase == "done":
		_settle(delta)
		_play(&"Idle")
		_present_bundle(0.0)
	elif not _at_point(ROUTE[LAST]):
		# Leave the one bundle where it was until the actor returns to the counter.
		_walk_towards(ROUTE[LAST], delta, step)
	else:
		_settle(delta)
		_play(&"Idle")
		if _at_point(ROUTE[LAST]) and _table_free():
			_wait = 0.0
			_work(step)
		else:
			_wait += step


func _travel(delta: float, step: float) -> void:
	var target: Vector3 = ROUTE[_next]
	if not _at_point(target):
		if _walk_towards(target, delta, step):
			_wait = 0.0
		else:
			_wait += step
			if _phase == "outward" and _wait >= WAIT_LIMIT:
				_turn_back(_next - 1)
		return
	_settle(delta)
	if not _at_point(target):
		return
	if _phase == "return":
		if _next == 0:
			_phase = "done"
			_play(&"Idle")
		else:
			_next -= 1
		return
	if _next == CORNER or _next == LAST:
		if not _sweep_clear(ROUTE[LAST], ROUTE[LAST]) or not _table_free():
			_wait += step
			_play(&"Idle")
			if _wait >= WAIT_LIMIT:
				_turn_back(_next - 1)
			return
	_wait = 0.0
	if _next == LAST:
		_face(WORK_SURFACE)
		_play(&"Idle")
		_phase = "unpack"
		_elapsed = 0.0
	else:
		_next += 1


func _turn_back(index: int) -> void:
	_phase = "return"
	_next = maxi(index, 0)
	_wait = 0.0


func _walk_towards(target: Vector3, delta: float, step: float) -> bool:
	var offset := _horizontal(target - global_position)
	var motion := offset.limit_length(SPEED * step)
	if offset.length() <= ARRIVAL or not _sweep_clear(global_position, global_position + motion):
		_settle(delta)
		_play(&"Idle")
		return false
	var before := global_position
	var fall_speed := 0.0 if is_on_floor() else velocity.y - 20.0 * step
	velocity = motion / delta
	velocity.y = fall_speed
	move_and_slide()
	apply_floor_snap()
	var advanced := _horizontal(global_position - before).dot(motion.normalized()) > 0.00001
	if advanced:
		_face(target)
	_play(&"Walking_A" if advanced else &"Idle")
	return advanced


func _table_free() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _space
	query.transform.origin = WORK_SURFACE + Vector3.UP * 0.25
	query.collision_mask = 2 | 4
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _work(step: float) -> void:
	_face(WORK_SURFACE)
	_elapsed += step
	match _phase:
		"unpack":
			_present_bundle(smoothstep(0.0, 1.5, _elapsed))
			if _elapsed >= 1.5:
				_phase = "compare"
				_elapsed = 0.0
		"compare":
			_cup.position.x = 0.035 * smoothstep(3.0, 3.6, _elapsed)
			_cup.rotation.y = 0.8 * smoothstep(8.0, 8.7, _elapsed)
			if _elapsed >= 12.0:
				_phase = "keep"
				_elapsed = 0.0
		"keep":
			_tag.visible = _elapsed < 3.0
			_tag.position.y = 0.023 + 0.10 * sin(PI * clampf(_elapsed / 3.0, 0.0, 1.0))
			if _elapsed >= 4.0:
				_phase = "pack"
				_elapsed = 0.0
		"pack":
			_present_bundle(1.0 - smoothstep(0.0, 3.0, _elapsed))
			if _elapsed >= 3.0:
				_turn_back(LAST - 1)


func possible_next_position(delta: float) -> Vector3:
	if not _enabled or delta <= 0.0 or not is_finite(delta):
		return global_position
	var index := _next if _phase in ["outward", "return"] else LAST
	if _phase == "done":
		return global_position
	return global_position + _horizontal(ROUTE[index] - global_position).limit_length(SPEED * minf(delta, MAX_STEP))


func suspend_activity() -> void:
	_enabled = false
	velocity = Vector3.ZERO
	if is_instance_valid(_animation):
		_animation.pause()


func interaction_target() -> Dictionary:
	return {"id": "cup_visitor", "label": display_name, "position": global_position + Vector3.UP * 1.15}


func describe(carrying_basin: bool) -> String:
	var words := "借西头那块干台看一下颜色。"
	if _wait > 0.0:
		words = "等这边空一点吧。"
	elif _phase == "keep" or _phase == "pack":
		words = keep_line
	elif _phase == "return" or _phase == "done":
		words = "杯碟都在我自己的包里。"
	elif carrying_basin:
		words = "盆你用。我带了自己的东西。"
	elif _phase == "compare":
		words = "杯柄朝这边，颜色看得更清楚。"
	return display_name + "：“" + words + "”"


func _present_bundle(openness: float) -> void:
	var carried := _visual.to_global(Vector3(0.22, 0.90, 0.24))
	# Lift the bottom above the rim before crossing it, then lower onto the top.
	var across := smoothstep(0.25, 0.75, openness)
	var at := carried.lerp(WORK_SURFACE, across)
	var clearance := maxf(carried.y, WORK_SURFACE.y) + 0.14
	at.y = lerpf(carried.y, clearance, smoothstep(0.0, 0.25, openness))
	at.y = lerpf(at.y, WORK_SURFACE.y, smoothstep(0.75, 1.0, openness))
	_kit.global_position = at
	_kit.rotation.y = lerp_angle(_visual.rotation.y, 0.0, across)
	_bag.visible = openness < 0.55
	_dishes.visible = not _bag.visible
	if openness == 0.0:
		_cup.position.x = 0.0
		_cup.rotation.y = 0.0
		_tag.visible = true
		_tag.position.y = 0.023


func _build_kit() -> void:
	_kit = Node3D.new()
	_kit.name = "PersonalCupBundle"
	add_child(_kit)
	_kit.top_level = true
	_bag = _box(_kit, Vector3(0, 0.12, 0), Vector3(0.32, 0.24, 0.22), Color("8d7560"))
	_box(_bag, Vector3(0, 0, 0), Vector3(0.045, 0.25, 0.225), Color("524d48"))
	_dishes = Node3D.new()
	_kit.add_child(_dishes)
	_box(_dishes, Vector3(0, 0.005, 0), Vector3(0.55, 0.01, 0.42), Color("bbaa8d"))
	_disc(_dishes, Vector3(0, 0.022, 0), 0.135, 0.024, Color("c77c43"))
	_cup = Node3D.new()
	_dishes.add_child(_cup)
	_disc(_cup, Vector3(0, 0.098, 0), 0.07, 0.128, Color("243f60"))
	_disc(_cup, Vector3(0, 0.163, 0), 0.058, 0.003, Color("152c42"))
	var handle := TorusMesh.new()
	handle.inner_radius = 0.023
	handle.outer_radius = 0.035
	var handle_node := _mesh(_cup, handle, Vector3(0.079, 0.108, 0), Color("243f60"))
	handle_node.rotation.x = PI * 0.5
	_tag = _box(_dishes, Vector3(-0.19, 0.023, 0.08), Vector3(0.085, 0.006, 0.048), Color("ede3c9"))


func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _mesh(parent, box, at, color)


func _disc(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius * 0.83
	disc.height = height
	return _mesh(parent, disc, at, color)


func _mesh(parent: Node3D, shape: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	piece.mesh = shape
	piece.material_override = material
	piece.position = at
	parent.add_child(piece)
	return piece
