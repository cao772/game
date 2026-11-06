extends "res://runtime/save_store.gd"
## Same bounded record protocol; the open world cannot select quest save slots.


func _valid_slot(slot: String) -> bool:
	return slot == "world_free"
