extends CharacterBody3D
## Fixed-camera movement for the bounded source sample; no runtime acceptance yet.
var controls_enabled: bool = true
var recovery_position := Vector3(0, 1, 5)

func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO
	if controls_enabled and get_window().has_focus():
		direction = Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		direction = direction.limit_length()
	velocity.x = direction.x * 4.0
	velocity.z = direction.y * 4.0
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	# Recovery only; normal containment is provided by physical walls.
	if position.y < -5.0:
		position = recovery_position
		velocity = Vector3.ZERO
