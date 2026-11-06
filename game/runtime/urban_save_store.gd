extends "res://runtime/save_store.gd"
## Reuses the bounded record protocol with a dedicated urban save slot.


func _valid_slot(slot: String) -> bool:
	return slot == "urban_free"
