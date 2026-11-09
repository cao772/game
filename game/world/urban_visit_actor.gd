extends CharacterBody3D
## Shared flat-street movement and presentation for visitors driven by the street.

const MODEL: PackedScene = preload("res://art/resident_merchant/merchant.glb")
const MAX_STEP: float = 0.1
const ARRIVAL: float = 0.025
var _visual: Node3D
var _animation: AnimationPlayer
var _probe: CapsuleShape3D


func _build_actor() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	safe_margin = 0.002
	floor_snap_length = 0.15
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	collider.shape = capsule
	collider.position.y = 0.875
	add_child(collider)
	_probe = CapsuleShape3D.new()
	_probe.radius = 0.31
	_probe.height = 1.73
	_visual = MODEL.instantiate() as Node3D
	_visual.scale = Vector3.ONE * 0.84
	add_child(_visual)
	var players := _visual.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_animation = players[0] as AnimationPlayer
		# Shared GLB resources must not have loop flags changed by this instance.
		for library_name in _animation.get_animation_library_list():
			var original := _animation.get_animation_library(library_name)
			var library := AnimationLibrary.new()
			for clip in original.get_animation_list():
				var animation := original.get_animation(clip).duplicate(true) as Animation
				if clip in [&"Idle", &"Walking_A"]:
					animation.loop_mode = Animation.LOOP_LINEAR
				library.add_animation(clip, animation)
			_animation.remove_animation_library(library_name)
			_animation.add_animation_library(library_name, library)


func _at_point(at: Vector3) -> bool:
	return is_on_floor() and absf(global_position.y - at.y) <= 0.08 and _horizontal(global_position - at).length() <= ARRIVAL


func _settle(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * minf(delta, MAX_STEP)
	move_and_slide()
	apply_floor_snap()


func _sweep_clear(start: Vector3, finish: Vector3) -> bool:
	# Lift the conservative capsule .025m off the authored flat floor. The actual
	# character still uses floor collision. Include world, player AND residents.
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _probe
	query.transform = Transform3D(Basis.IDENTITY, start + Vector3.UP * 0.89)
	query.collision_mask = 1 | 2 | 4
	query.exclude = [get_rid()]
	query.margin = 0.005
	query.collide_with_areas = false
	var space := get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	query.motion = finish - start
	var fractions: PackedFloat32Array = space.cast_motion(query)
	if fractions.size() != 2 or fractions[0] < 1.0 or fractions[1] < 1.0:
		return false
	query.transform.origin = finish + Vector3.UP * 0.89
	query.motion = Vector3.ZERO
	return space.intersect_shape(query, 1).is_empty()


func _face(point: Vector3) -> void:
	var offset := _horizontal(point - global_position)
	if offset.length_squared() > 0.00001:
		_visual.rotation.y = atan2(offset.x, offset.z)


func _horizontal(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)


func _play(clip: StringName) -> void:
	if not is_instance_valid(_animation) or not _animation.has_animation(clip):
		return
	if _animation.current_animation == clip and _animation.is_playing():
		return
	_animation.play(clip, 0.12)
