extends Area3D
## Scene author assigns an observation ID and collision shape/mask.
## Explicit interaction only: entering the area does not advance a quest.

const Application = preload("res://runtime/quest_application.gd")
@export var interaction_id: String = ""


func interact(actor: PhysicsBody3D, application: Application, expected_revision: int) -> Dictionary:
	if not is_instance_valid(actor) or not is_instance_valid(application):
		return {"ok": false, "code": "INVALID_INTERACTION_CONTEXT"}
	if not is_inside_tree() or not actor.is_inside_tree() or get_tree().paused:
		return {"ok": false, "code": "INTERACTION_UNAVAILABLE"}
	if not monitoring or not overlaps_body(actor):
		return {"ok": false, "code": "ACTOR_OUTSIDE_INTERACTION"}
	return application.observe_interaction(interaction_id, expected_revision)
