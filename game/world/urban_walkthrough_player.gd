extends CharacterBody3D
## Independent modern-street controller. Feet are the origin; no save/quest access.
## Hold RMB to look, release RMB/Esc to free the pointer; V changes camera mode.
## Disabled controls, GUI keyboard focus, window focus loss and tree pause freeze
## movement including gravity, discard a queued jump and release the pointer.
## Source authored only: engine, camera/collision and gameplay acceptance NOT_RUN.

const EYE_HEIGHT: float = 1.68
const WALK_SPEED: float = 2.0
const RUN_SPEED: float = 4.8
const GRAVITY: float = 18.0
const JUMP_SPEED: float = 4.8
const THIRD_DISTANCE: float = 2.2
const SHOULDER_OFFSET: float = 0.35
const LOOK_SENSITIVITY: float = 0.003
const SEATED_HEIGHT: float = 1.35
const SEATED_EYE_HEIGHT: float = 1.20
const POSE_QUERY_MASK: int = 1 | 4
const POSE_QUERY_LIFT: float = 0.03
const POSE_LEVEL_TOLERANCE: float = 0.08
const SEAT_REACH: float = 2.6
const STAND_REACH: float = 2.0

var controls_enabled: bool = true
var recover_pos := Vector3(0.0, 0.1, 20.0)

var _yaw: Node3D
var _pitch: Node3D
var _arm: SpringArm3D
var _camera: Camera3D
var _visual: Node3D
var _seated_visual: Node3D
var _collider: CollisionShape3D
var _body_capsule: CapsuleShape3D
var _seated: bool = false
var _seat_feet := Vector3.ZERO
var _stand_candidates: Array[Vector3] = []
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _third_person: bool = false
var _looking: bool = false
var _jump_queued: bool = false
var _body_hidden_near_wall: bool = true
var _gait: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.22
	safe_margin = 0.01
	_collider = CollisionShape3D.new()
	_body_capsule = CapsuleShape3D.new()
	_body_capsule.radius = 0.30
	_body_capsule.height = 1.75
	_collider.shape = _body_capsule
	_collider.position.y = 0.875
	add_child(_collider)
	_build_body()
	_yaw = Node3D.new()
	_yaw.position.y = EYE_HEIGHT
	add_child(_yaw)
	_pitch = Node3D.new()
	_yaw.add_child(_pitch)
	_arm = SpringArm3D.new()
	_arm.collision_mask = 1
	_arm.margin = 0.08
	var camera_volume := SphereShape3D.new()
	camera_volume.radius = 0.14
	_arm.shape = camera_volume
	_pitch.add_child(_arm)
	_arm.add_excluded_object(get_rid())
	_camera = Camera3D.new()
	_camera.fov = 75.0
	_camera.near = 0.05
	_camera.current = true
	_arm.add_child(_camera)
	_apply_camera_mode()
	release_pointer()


func _unhandled_input(event: InputEvent) -> void:
	# GUI gets first refusal; polling in _physics_process uses the same focus gate.
	if not _can_control():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_looking = event.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _looking else Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _looking:
		_yaw.rotation.y = wrapf(_yaw.rotation.y - event.relative.x * LOOK_SENSITIVITY, -PI, PI)
		_pitch.rotation.x = clampf(_pitch.rotation.x - event.relative.y * LOOK_SENSITIVITY, -1.25, 1.15)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_V:
				_third_person = not _third_person
				_apply_camera_mode()
				get_viewport().set_input_as_handled()
			KEY_SPACE:
				_jump_queued = not _seated
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				release_pointer()
				get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not _can_control():
		_stop_controls()
		_set_gait(0.0, delta)
		return
	# A mouse release consumed by GUI must still end capture.
	if _looking and (not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
		release_pointer()
	if _seated:
		velocity = Vector3.ZERO
		_jump_queued = false
		_set_gait(0.0, delta)
		return
	var axis := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	).limit_length()
	var direction: Vector3 = _yaw.global_transform.basis * Vector3(axis.x, 0.0, axis.y)
	direction.y = 0.0
	direction = direction.normalized() * axis.length()
	var speed: float = RUN_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) else WALK_SPEED
	velocity.x = move_toward(velocity.x, direction.x * speed, 16.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 16.0 * delta)
	if is_on_floor():
		velocity.y = JUMP_SPEED if _jump_queued else 0.0
	else:
		velocity.y -= GRAVITY * delta
	_jump_queued = false
	move_and_slide()
	if direction.length_squared() > 0.001:
		# The original modern-clothes proxy faces -Z, as does Camera3D.
		var facing: float = atan2(-direction.x, -direction.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, facing, minf(delta * 12.0, 1.0))
	var ground_speed: float = Vector2(velocity.x, velocity.z).length() if is_on_floor() else 0.0
	_set_gait(ground_speed, delta)
	if absf(position.x) > 48.0 or absf(position.z) > 32.0 or position.y < -6.0:
		position = recover_pos
		velocity = Vector3.ZERO
		_jump_queued = false
		_set_gait(0.0, 1.0)


func _process(_delta: float) -> void:
	if not _can_control() and _looking:
		release_pointer()
	if not _third_person:
		_visual.hide()
		_seated_visual.hide()
		return
	# Hysteresis prevents the body flashing at the compression threshold.
	var camera_distance: float = _arm.get_hit_length()
	if camera_distance < 0.80:
		_body_hidden_near_wall = true
	elif camera_distance > 1.00:
		_body_hidden_near_wall = false
	_visual.visible = not _seated and not _body_hidden_near_wall
	_seated_visual.visible = _seated and not _body_hidden_near_wall


func _can_control() -> bool:
	return controls_enabled and is_inside_tree() and not get_tree().paused and get_window().has_focus() and get_viewport().gui_get_focus_owner() == null


func _apply_camera_mode() -> void:
	_yaw.position.y = SEATED_EYE_HEIGHT if _seated else EYE_HEIGHT
	# Sweep from the central eye point toward the shoulder camera. Moving the arm
	# origin sideways could start the shape inside an adjacent wall.
	var shoulder_angle: float = atan2(SHOULDER_OFFSET, THIRD_DISTANCE) if _third_person else 0.0
	_arm.rotation.y = shoulder_angle
	_arm.spring_length = Vector2(SHOULDER_OFFSET, THIRD_DISTANCE).length() if _third_person else 0.0
	# Undo the sweep's yaw so the view stays aligned with movement and mouse aim.
	_camera.rotation.y = -shoulder_angle
	_camera.position = Vector3.ZERO
	_body_hidden_near_wall = true
	_visual.hide() # Wait for the arm's first collision update before revealing it.
	_seated_visual.hide()


func mode_label() -> String:
	return "近距第三人称" if _third_person else "第一人称"


func interaction_camera() -> Camera3D:
	return _camera


func interaction_allowed() -> bool:
	return _can_control()


func reset_pose(at: Vector3) -> void:
	_stop_controls()
	_clear_seated_pose()
	position = at
	_yaw.rotation = Vector3.ZERO
	_pitch.rotation = Vector3.ZERO
	_apply_camera_mode()


func is_seated() -> bool:
	return _seated


func seat_at(feet: Vector3, yaw: float, stand_candidates: Array[Vector3]) -> Dictionary:
	# Root calls from its physics-frame E handler after target range/LOS checks.
	# Coordinates are global floor-space feet, never the height of the seat mesh.
	if not _pose_query_ready():
		return {"ok": false, "code": "POSE_QUERY_UNAVAILABLE"}
	if not _can_control():
		return {"ok": false, "code": "CONTROLS_BLOCKED"}
	if _seated:
		return {"ok": false, "code": "ALREADY_SEATED"}
	if not is_on_floor():
		return {"ok": false, "code": "MUST_BE_ON_FLOOR"}
	if not _finite_point(feet) or not is_finite(yaw):
		return {"ok": false, "code": "INVALID_SEAT_POSE"}
	if global_position.distance_to(feet) > SEAT_REACH or absf(global_position.y - feet.y) > POSE_LEVEL_TOLERANCE:
		return {"ok": false, "code": "SEAT_OUT_OF_REACH"}
	if stand_candidates.is_empty() or stand_candidates.size() > 8:
		return {"ok": false, "code": "INVALID_STAND_CANDIDATES"}
	for candidate in stand_candidates:
		if not _finite_point(candidate) or candidate.distance_to(feet) > STAND_REACH or absf(candidate.y - feet.y) > POSE_LEVEL_TOLERANCE:
			return {"ok": false, "code": "INVALID_STAND_CANDIDATES"}
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if not _pose_clear(space, feet, SEATED_HEIGHT) or not _floor_supported(space, feet):
		return {"ok": false, "code": "SEAT_BLOCKED"}
	# Standing-height sweep is deliberately conservative: no shrinking through a
	# rail or low opening on the way in. A clear endpoint alone is not enough.
	if not _pose_path_clear(space, global_position, feet):
		return {"ok": false, "code": "SEAT_PATH_BLOCKED"}
	var has_exit := false
	for candidate in stand_candidates:
		if _pose_path_clear(space, feet, candidate):
			has_exit = true
			break
	if not has_exit:
		return {"ok": false, "code": "NO_CLEAR_STAND_POINT"}
	# Only commit after all checks pass; no node/pose mutation on any failure.
	_seated = true
	_seat_feet = feet
	_stand_candidates.assign(stand_candidates)
	global_position = feet
	_body_capsule.height = SEATED_HEIGHT
	_collider.position.y = SEATED_HEIGHT * 0.5
	velocity = Vector3.ZERO
	_jump_queued = false
	_yaw.rotation.y = wrapf(yaw, -PI, PI)
	_pitch.rotation = Vector3.ZERO
	_seated_visual.rotation.y = _yaw.rotation.y
	_set_gait(0.0, 1.0)
	_apply_camera_mode()
	return {"ok": true, "code": "SEATED"}


func stand_up() -> Dictionary:
	if not _pose_query_ready():
		return {"ok": false, "code": "POSE_QUERY_UNAVAILABLE"}
	if not _can_control():
		return {"ok": false, "code": "CONTROLS_BLOCKED"}
	if not _seated:
		return {"ok": false, "code": "NOT_SEATED"}
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for candidate in _stand_candidates:
		if candidate.distance_to(_seat_feet) > STAND_REACH or absf(candidate.y - _seat_feet.y) > POSE_LEVEL_TOLERANCE:
			continue
		# Recheck the entire path and destination now: an NPC may have walked into
		# a previously valid exit. Never use a saved positive occupancy result.
		if not _pose_path_clear(space, global_position, candidate):
			continue
		global_position = candidate
		_clear_seated_pose()
		velocity = Vector3.ZERO
		_jump_queued = false
		_visual.rotation.y = _yaw.rotation.y
		_apply_camera_mode()
		return {"ok": true, "code": "STOOD_UP"}
	return {"ok": false, "code": "STAND_BLOCKED"}


func _pose_query_ready() -> bool:
	return is_inside_tree() and is_node_ready() and Engine.is_in_physics_frame() and get_world_3d() != null


func _finite_point(point: Vector3) -> bool:
	return is_finite(point.x) and is_finite(point.y) and is_finite(point.z)


func _pose_query(feet: Vector3, height: float) -> PhysicsShapeQueryParameters3D:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.30
	shape.height = height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	# Raise the query slightly above its authored supporting floor. The actual
	# capsule keeps its feet at zero; do not exempt the bench or any world body.
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (height * 0.5 + POSE_QUERY_LIFT))
	query.collision_mask = POSE_QUERY_MASK
	query.exclude = [get_rid()]
	query.margin = 0.005
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return query


func _pose_clear(space: PhysicsDirectSpaceState3D, feet: Vector3, height: float) -> bool:
	return space.intersect_shape(_pose_query(feet, height), 1).is_empty()


func _pose_path_clear(space: PhysicsDirectSpaceState3D, start: Vector3, finish: Vector3) -> bool:
	if not _pose_clear(space, start, 1.75) or not _pose_clear(space, finish, 1.75):
		return false
	var query := _pose_query(start, 1.75)
	query.motion = finish - start
	# cast_motion ignores shapes already overlapped, hence the explicit start
	# and end intersection checks above (Godot 4.1 PhysicsDirectSpaceState3D).
	var fractions: PackedFloat32Array = space.cast_motion(query)
	if fractions.size() != 2 or fractions[0] < 1.0 or fractions[1] < 1.0:
		return false
	var steps: int = maxi(1, int(ceil(start.distance_to(finish) / 0.25)))
	for index in range(steps + 1):
		if not _floor_supported(space, start.lerp(finish, float(index) / float(steps))):
			return false
	return true


func _floor_supported(space: PhysicsDirectSpaceState3D, feet: Vector3) -> bool:
	# Centre plus foot-width samples prevent standing on a rail or across an edge.
	for offset in [Vector3.ZERO, Vector3(0.20, 0, 0), Vector3(-0.20, 0, 0), Vector3(0, 0, 0.20), Vector3(0, 0, -0.20)]:
		var point: Vector3 = feet + offset
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.12, point - Vector3.UP * 0.12, 1, [get_rid()])
		ray.hit_from_inside = true
		ray.hit_back_faces = false
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty():
			return false
		var normal: Vector3 = hit["normal"]
		var surface: Vector3 = hit["position"]
		if normal.dot(Vector3.UP) < cos(floor_max_angle) or absf(surface.y - feet.y) > POSE_LEVEL_TOLERANCE:
			return false
	return true


func _clear_seated_pose() -> void:
	_seated = false
	_seat_feet = Vector3.ZERO
	_stand_candidates.clear()
	_body_capsule.height = 1.75
	_collider.position.y = 0.875
	_yaw.position.y = EYE_HEIGHT
	_seated_visual.hide()


func release_pointer() -> void:
	_looking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _stop_controls() -> void:
	release_pointer()
	_jump_queued = false
	velocity = Vector3.ZERO


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		_stop_controls()


func _exit_tree() -> void:
	release_pointer()


func _build_body() -> void:
	_visual = Node3D.new()
	_visual.name = "ModernClothesProxy"
	add_child(_visual)
	var jacket := _material(Color("29343e"))
	var trousers := _material(Color("20262d"))
	var shoes := _material(Color("161a20"))
	var skin := _material(Color("c99c80"))
	_box(_visual, Vector3(0.0, 1.17, 0.0), Vector3(0.45, 0.60, 0.25), jacket)
	_box(_visual, Vector3(0.0, 1.21, -0.129), Vector3(0.018, 0.43, 0.012), trousers)
	_capsule(_visual, Vector3(0.0, 1.61, 0.0), 0.13, 0.26, skin)
	_capsule(_visual, Vector3(0.0, 1.47, 0.0), 0.065, 0.13, skin)
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.105, 0.85, 0.0)
		_visual.add_child(leg)
		_legs.append(leg)
		_capsule(leg, Vector3(0.0, -0.39, 0.0), 0.085, 0.78, trousers)
		_box(leg, Vector3(0.0, -0.80, -0.035), Vector3(0.18, 0.10, 0.29), shoes)
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.285, 1.40, 0.0)
		_visual.add_child(arm)
		_arms.append(arm)
		_capsule(arm, Vector3(0.0, -0.24, 0.0), 0.065, 0.50, jacket)
		_capsule(arm, Vector3(0.0, -0.54, 0.0), 0.05, 0.13, skin)
	_visual.hide()
	_build_seated_body(jacket, trousers, shoes, skin)


func _build_seated_body(jacket: Material, trousers: Material, shoes: Material, skin: Material) -> void:
	_seated_visual = Node3D.new()
	_seated_visual.name = "SeatedModernClothesProxy"
	add_child(_seated_visual)
	# Original clothing palette; a pose proxy, not a rig or final realistic avatar.
	_box(_seated_visual, Vector3(0, 0.56, 0), Vector3(0.36, 0.18, 0.28), trousers)
	_box(_seated_visual, Vector3(0, 0.92, 0), Vector3(0.45, 0.56, 0.25), jacket)
	_box(_seated_visual, Vector3(0, 0.94, -0.129), Vector3(0.018, 0.40, 0.012), trousers)
	_capsule(_seated_visual, Vector3(0, 1.18, 0), 0.065, 0.12, skin)
	_capsule(_seated_visual, Vector3(0, 1.29, 0), 0.13, 0.26, skin)
	for side in [-1.0, 1.0]:
		_box(_seated_visual, Vector3(side * 0.105, 0.54, -0.20), Vector3(0.17, 0.17, 0.43), trousers)
		_capsule(_seated_visual, Vector3(side * 0.105, 0.29, -0.38), 0.08, 0.44, trousers)
		_box(_seated_visual, Vector3(side * 0.105, 0.07, -0.44), Vector3(0.18, 0.10, 0.28), shoes)
		_capsule(_seated_visual, Vector3(side * 0.285, 0.88, 0), 0.065, 0.42, jacket)
		_box(_seated_visual, Vector3(side * 0.285, 0.67, -0.12), Vector3(0.12, 0.12, 0.28), jacket)
		_capsule(_seated_visual, Vector3(side * 0.285, 0.65, -0.29), 0.05, 0.12, skin)
	_seated_visual.hide()


func _set_gait(speed: float, delta: float) -> void:
	if speed > 0.10:
		_gait = wrapf(_gait + speed * delta * 4.8, 0.0, TAU)
	var amplitude: float = 0.38 * minf(speed / WALK_SPEED, 1.3) if speed > 0.10 else 0.0
	for index in range(_legs.size()):
		var swing: float = sin(_gait + index * PI) * amplitude
		_legs[index].rotation.x = lerpf(_legs[index].rotation.x, swing, minf(delta * 14.0, 1.0))
		_arms[index].rotation.x = lerpf(_arms[index].rotation.x, -swing * 0.65, minf(delta * 14.0, 1.0))


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material


func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh(parent, at, mesh, material)


func _capsule(parent: Node3D, at: Vector3, radius: float, height: float, material: Material) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	_mesh(parent, at, mesh, material)


func _mesh(parent: Node3D, at: Vector3, geometry: Mesh, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = geometry
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
