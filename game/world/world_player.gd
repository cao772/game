extends CharacterBody3D
## Camera-relative explorer. Source only; movement and camera need engine acceptance.

const MODEL = preload("res://art/explorer_actor/explorer.glb")
const DEFAULT_UPWARD_PITCH := 0.18
const RIDGE_UPWARD_PITCH := PI * 65.0 / 180.0
var controls_enabled := true
var recovery_position := Vector3(0, 1, 8)
var _pivot: Node3D
var _arm: SpringArm3D
var _visual: Node3D
var _animation: AnimationPlayer
var _jump := false
var _looking := false
var _clip := ""
var _upward_pitch := DEFAULT_UPWARD_PITCH

func _ready() -> void:
	collision_layer = 2
	collision_mask = 13 # Ground (1), residents (4) and flooded shore (8).
	floor_snap_length = 0.35
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.65
	collider.shape = shape
	collider.position.y = 0.825
	add_child(collider)
	_visual = MODEL.instantiate() as Node3D
	_visual.scale = Vector3.ONE * 0.78
	add_child(_visual)
	var players := _visual.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_animation = players[0] as AnimationPlayer
		for clip in ["Idle", "Walking_A", "Running_A", "Jump_Idle"]:
			if _animation.has_animation(clip):
				_animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_pivot = Node3D.new()
	_pivot.position.y = 1.35
	add_child(_pivot)
	_arm = SpringArm3D.new()
	_arm.spring_length = 6.0
	_arm.margin = 0.25
	_arm.rotation.x = -0.25
	_arm.collision_mask = 17 # Solid land and the actual surface of the lake.
	var camera_shape := SphereShape3D.new()
	camera_shape.radius = 0.2
	_arm.shape = camera_shape
	_pivot.add_child(_arm)
	_arm.add_excluded_object(get_rid())
	var camera := Camera3D.new()
	camera.fov = 65.0
	camera.current = true
	_arm.add_child(camera)

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_looking = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _looking else Input.MOUSE_MODE_VISIBLE
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_arm.spring_length = maxf(2.5, _arm.spring_length - 0.5)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_arm.spring_length = minf(9.0, _arm.spring_length + 0.5)
	elif event is InputEventMouseMotion and _looking:
		_pivot.rotation.y -= event.relative.x * 0.004
		_tilt_camera(-event.relative.y * 0.003)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE:
			_jump = true
		elif event.keycode == KEY_ESCAPE:
			release_pointer()

func _physics_process(delta: float) -> void:
	var enabled := controls_enabled and get_window().has_focus()
	if not enabled:
		release_pointer()
		_jump = false
		velocity = Vector3.ZERO
		if _animation != null and _clip != "Idle" and _animation.has_animation("Idle"):
			_animation.play("Idle", 0.15)
			_clip = "Idle"
		return
	if _looking and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		release_pointer()
	var axis := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).limit_length()
	var running := Input.is_physical_key_pressed(KEY_SHIFT)
	_pivot.rotation.y += (float(Input.is_physical_key_pressed(KEY_LEFT)) - float(Input.is_physical_key_pressed(KEY_RIGHT))) * delta * 1.8
	var pitch_input := float(Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_DOWN))
	_tilt_camera(pitch_input * delta * 1.35)
	# The camera can tilt towards the kite. Walking follows its horizontal heading.
	# Adapted from Godot's MIT 3D platformer (4.1); see third_party/godot-platformer.
	var direction := _pivot.global_transform.basis * Vector3(axis.x, 0, axis.y)
	var speed := 7.0 if running else 4.2
	velocity.x = move_toward(velocity.x, direction.x * speed, 22.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 22.0 * delta)
	if is_on_floor():
		velocity.y = 7.0 if enabled and _jump else 0.0
	else:
		velocity.y -= 20.0 * delta
	_jump = false
	move_and_slide()
	if direction.length_squared() > 0.01:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(direction.x, direction.z), minf(12.0 * delta, 1.0))
	var next_clip := "Idle"
	if not is_on_floor():
		next_clip = "Jump_Idle"
	elif Vector2(velocity.x, velocity.z).length() > 0.25:
		next_clip = "Running_A" if running else "Walking_A"
	if _animation != null and next_clip != _clip and _animation.has_animation(next_clip):
		_animation.play(next_clip, 0.15)
		_clip = next_clip
	if position.y < -4.0 or absf(position.x) > 33.0 or absf(position.z) > 33.0:
		position = recovery_position
		velocity = Vector3.ZERO

func heading() -> float:
	return wrapf(_pivot.rotation.y, -PI, PI)

func facing() -> float:
	return _visual.rotation.y

func set_heading(value: float) -> void:
	_pivot.rotation.y = value
	_visual.rotation.y = value + PI

func set_ridge_sky_view(on_ridge: bool) -> void:
	_upward_pitch = RIDGE_UPWARD_PITCH if on_ridge else DEFAULT_UPWARD_PITCH
	_tilt_camera(0.0)

func _tilt_camera(amount: float) -> void:
	_arm.rotation.x = clampf(_arm.rotation.x + amount, -1.1, _upward_pitch)

func set_map_frozen(frozen: bool) -> void:
	controls_enabled = not frozen
	set_physics_process(not frozen)
	if is_instance_valid(_animation):
		_animation.process_mode = Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT
	if frozen:
		_jump = false
		release_pointer()

func release_pointer() -> void:
	_looking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _exit_tree() -> void:
	release_pointer()
