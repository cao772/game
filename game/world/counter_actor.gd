extends Node3D
## Position this node at floor height. The actor faces its local +Z axis.

const MODEL: PackedScene = preload("res://art/counter_actor/recipient.glb")
const IDLE: StringName = &"Idle"
const HANDOVER: StringName = &"Interact"
const GREETING: StringName = &"Cheer"

var _player: AnimationPlayer


func _ready() -> void:
	var model := MODEL.instantiate() as Node3D
	model.scale = Vector3.ONE * 0.84
	add_child(model)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_warning("Counter actor model has no AnimationPlayer.")
		return
	_player = players[0] as AnimationPlayer
	for clip in [IDLE, HANDOVER, GREETING]:
		if not _player.has_animation(clip):
			push_warning("Counter actor animation missing: %s" % clip)
			continue
		var animation := _player.get_animation(clip)
		animation.loop_mode = Animation.LOOP_LINEAR if clip == IDLE else Animation.LOOP_NONE
	reset_pose()


func acknowledge(delivered_now: bool) -> void:
	var clip := HANDOVER if delivered_now else GREETING
	if _player == null or not _player.has_animation(clip):
		return
	_player.clear_queue()
	_player.stop()
	_player.play(clip)
	if _player.has_animation(IDLE):
		_player.queue(IDLE)


func reset_pose() -> void:
	if _player == null:
		return
	_player.clear_queue()
	_player.stop()
	if _player.has_animation(IDLE):
		_player.play(IDLE)
		_player.advance(0.0)
