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

var controls_enabled: bool = true
var recover_pos := Vector3(0.0, 0.1, 20.0)

var _yaw: Node3D
var _pitch: Node3D
var _arm: SpringArm3D
var _camera: Camera3D
var _visual: Node3D
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
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.30
	capsule.height = 1.75
	collider.shape = capsule
	collider.position.y = 0.875
	add_child(collider)
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
				_jump_queued = true
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
		return
	# Hysteresis prevents the body flashing at the compression threshold.
	var camera_distance: float = _arm.get_hit_length()
	if camera_distance < 0.80:
		_body_hidden_near_wall = true
	elif camera_distance > 1.00:
		_body_hidden_near_wall = false
	_visual.visible = not _body_hidden_near_wall


func _can_control() -> bool:
	return controls_enabled and is_inside_tree() and not get_tree().paused and get_window().has_focus() and get_viewport().gui_get_focus_owner() == null


func _apply_camera_mode() -> void:
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


func mode_label() -> String:
	return "近距第三人称" if _third_person else "第一人称"


func interaction_camera() -> Camera3D:
	return _camera


func interaction_allowed() -> bool:
	return _can_control()


func reset_pose(at: Vector3) -> void:
	_stop_controls()
	position = at
	_yaw.rotation = Vector3.ZERO
	_pitch.rotation = Vector3.ZERO


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
