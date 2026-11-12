extends Node3D
## A presentation-only resident. Positions are feet positions in world space.
## The external controller owns routes, time, interpolation and persistent state.
## Heading is radians around +Y; zero faces +Z, matching the KayKit rig.

const Tally = preload("res://world/dock_tally.gd")
const MODEL_SCALE: float = 0.84
const IDLE: StringName = &"Idle"
const WALKING: StringName = &"Walking_A"
const INTERACT: StringName = &"Interact"
const GREETING: StringName = &"Cheer"

@export var model_scene: PackedScene
@export var collider_enabled: bool = true

var _body: AnimatableBody3D
var _model: Node3D
var _player: AnimationPlayer
var _tally: Node3D
var _checking := false
var _conversing: bool = false
var _requested_moving: bool = false
var _has_projection: bool = false
var _has_applied_pose: bool = false
var _projected_position := Vector3.ZERO
var _projected_heading: float = 0.0


func configure(model: PackedScene) -> void:
	if model_scene == model and is_instance_valid(_model):
		return
	model_scene = model
	if is_node_ready():
		_load_model()


func _ready() -> void:
	_body = AnimatableBody3D.new()
	_body.name = "ResidentBody"
	_body.collision_layer = 0
	_body.collision_mask = 2
	_body.sync_to_physics = true
	add_child(_body)
	# Drive this body's transform directly so physics synchronization can observe
	# each projection, even though the public Node3D also follows the same pose.
	_body.top_level = true
	_body.global_transform = global_transform
	var collider := CollisionShape3D.new()
	collider.name = "ResidentCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.8
	collider.shape = capsule
	collider.position = Vector3(0, 0.9, 0)
	_body.add_child(collider)
	_load_model()
	if _has_projection:
		_apply_transform()


func apply_projection(world_position: Vector3, heading: float, moving: bool, delivery_phase: String = "", progress: float = 0.0) -> void:
	# Conversation holds the current pose. Its owner also holds the route clock;
	# no stale destination is queued here for when the conversation ends.
	if _conversing:
		return
	_projected_position = world_position
	_projected_heading = heading
	_requested_moving = moving
	_has_projection = true
	if not is_inside_tree():
		return
	_apply_transform()
	if not delivery_phase.is_empty() and not is_instance_valid(_tally):
		_attach_tally()
	if is_instance_valid(_tally):
		_tally.visible = not delivery_phase.is_empty()
	_checking = delivery_phase == "check"
	if _checking and is_instance_valid(_player) and _player.has_animation(INTERACT):
		_pose_check(progress)
	else:
		_play_locomotion()


func set_conversing(value: bool) -> void:
	if _conversing == value:
		return
	_conversing = value
	_requested_moving = false
	if _checking:
		return # Keep the two marks aligned while the conversation holds world time.
	if _conversing:
		_play_greeting()
	else:
		# The next external projection decides whether walking resumes.
		_play_loop(IDLE)


func _apply_transform() -> void:
	global_position = _projected_position
	global_rotation = Vector3(0, _projected_heading, 0)
	if is_instance_valid(_body):
		if not _has_applied_pose:
			# Seed a newly spawned body without reporting travel from the origin.
			_body.sync_to_physics = false
			_body.global_transform = global_transform
			_body.sync_to_physics = true
			_has_applied_pose = true
		else:
			_body.global_transform = global_transform
		_body.collision_layer = 4 if collider_enabled and is_instance_valid(_model) else 0


func _attach_tally() -> void:
	if not is_instance_valid(_model):
		return
	_tally = Tally.new()
	var rigs := _model.find_children("*", "Skeleton3D", true, false)
	for node in rigs:
		var rig := node as Skeleton3D
		for index in range(rig.get_bone_count()):
			var name_key := String(rig.get_bone_name(index)).to_lower().replace(".", "").replace("_", "")
			if name_key != "handslotr":
				continue
			var grip := BoneAttachment3D.new()
			rig.add_child(grip)
			grip.bone_idx = index
			_tally.rotation.y = deg_to_rad(61.3)
			grip.add_child(_tally)
			return
	# Alternate rigs without a hand socket carry their sign on the bag.
	_tally.position = Vector3(-0.27, 0.86, 0.22)
	_model.add_child(_tally)


func _pose_check(progress: float) -> void:
	# Sample the actual Interact clip from world time. During the middle of the
	# stop the right hand holds the sign beside the mark fixed to the post.
	var clip_length := _player.get_animation(INTERACT).length
	var raised := 0.40 * clip_length
	var frame_time := raised * smoothstep(0.0, 0.18, progress)
	frame_time += (clip_length - raised) * smoothstep(0.82, 1.0, progress)
	if _player.current_animation != INTERACT:
		_player.play(INTERACT, 0.0)
	_player.speed_scale = 0.0
	_player.seek(frame_time, true)


func _load_model() -> void:
	_player = null
	_tally = null
	_checking = false
	_body.collision_layer = 0
	if is_instance_valid(_model):
		_body.remove_child(_model)
		_model.queue_free()
		_model = null
	if model_scene == null:
		push_warning("World resident needs a model_scene or configure(model).")
		return
	var instance := model_scene.instantiate()
	if not instance is Node3D:
		if instance != null:
			instance.free()
		push_warning("World resident expects a Node3D model.")
		return
	_model = instance as Node3D
	_model.scale = Vector3.ONE * MODEL_SCALE
	_body.add_child(_model)
	_body.collision_layer = 4 if collider_enabled and _has_applied_pose else 0
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_warning("World resident model has no AnimationPlayer.")
		return
	_player = players[0] as AnimationPlayer
	for clip in [IDLE, WALKING, INTERACT, GREETING]:
		if not _player.has_animation(clip):
			push_warning("World resident animation missing: %s" % clip)
			continue
		var animation := _player.get_animation(clip)
		animation.loop_mode = Animation.LOOP_LINEAR if clip == IDLE or clip == WALKING else Animation.LOOP_NONE
	if _conversing:
		_play_greeting()
	else:
		_play_locomotion()
	_player.advance(0.0)


func _play_locomotion() -> void:
	_play_loop(WALKING if _requested_moving else IDLE)


func _play_loop(clip: StringName) -> void:
	if not is_instance_valid(_player):
		return
	_player.speed_scale = 1.0
	var available := clip if _player.has_animation(clip) else IDLE
	if not _player.has_animation(available):
		return
	# Repeated frame projections must not restart the gait or idle cycle.
	if _player.current_animation == available and _player.is_playing():
		return
	_player.clear_queue()
	_player.play(available, 0.12)


func _play_greeting() -> void:
	if not is_instance_valid(_player):
		return
	_player.speed_scale = 1.0
	_player.clear_queue()
	if _player.has_animation(GREETING):
		_player.play(GREETING, 0.12)
		if _player.has_animation(IDLE):
			_player.queue(IDLE)
	else:
		_play_loop(IDLE)
