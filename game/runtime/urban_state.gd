extends RefCounted
## Fixed urban interaction state, independent of scene nodes and player position.
## view()/snapshot() return raw payload copies; commands return only ok/code.
## Source and grammar review only. Godot, gameplay and save I/O NOT_RUN.

const SCHEMA_VERSION := 1
const STATE_FIELDS := [
	"schema_version", "front_open", "back_open", "lamp_on", "toolbox_anchor"
]
const BOOL_FIELDS := ["front_open", "back_open", "lamp_on"]
const PLACE_ANCHORS := ["bench", "shelf", "yard"]
const TOOLBOX_ANCHORS := ["bench", "shelf", "yard", "carried"]

var _state: Dictionary = {
	"schema_version": SCHEMA_VERSION,
	"front_open": true,
	"back_open": false,
	"lamp_on": true,
	"toolbox_anchor": "bench"
}


func view() -> Dictionary:
	return _state.duplicate(true)


func snapshot() -> Dictionary:
	return _state.duplicate(true)


func toggle_gate(gate_id: String) -> Dictionary:
	match gate_id:
		"front_gate":
			_state["front_open"] = not _state["front_open"]
		"back_gate":
			_state["back_open"] = not _state["back_open"]
		_:
			return _result(false, "UNKNOWN_GATE")
	return _result(true, "GATE_TOGGLED")


func toggle_lamp() -> Dictionary:
	_state["lamp_on"] = not _state["lamp_on"]
	return _result(true, "LAMP_TOGGLED")


func take_toolbox() -> Dictionary:
	if _state["toolbox_anchor"] == "carried":
		return _result(false, "ALREADY_CARRIED")
	_state["toolbox_anchor"] = "carried"
	return _result(true, "TOOLBOX_TAKEN")


func place_toolbox(anchor: String) -> Dictionary:
	if not PLACE_ANCHORS.has(anchor):
		return _result(false, "INVALID_ANCHOR")
	if _state["toolbox_anchor"] != "carried":
		return _result(false, "NOT_CARRYING")
	_state["toolbox_anchor"] = anchor
	return _result(true, "TOOLBOX_PLACED")


func restore(payload: Dictionary) -> Dictionary:
	if payload.size() != STATE_FIELDS.size():
		return _result(false, "INVALID_FIELDS")
	for key in payload:
		if typeof(key) != TYPE_STRING or not STATE_FIELDS.has(key):
			return _result(false, "INVALID_FIELDS")
	if not _valid_version(payload["schema_version"]):
		return _result(false, "INVALID_SCHEMA_VERSION")
	for key in BOOL_FIELDS:
		if typeof(payload[key]) != TYPE_BOOL:
			return _result(false, "INVALID_BOOL")
	var anchor: Variant = payload["toolbox_anchor"]
	if typeof(anchor) != TYPE_STRING or not TOOLBOX_ANCHORS.has(anchor):
		return _result(false, "INVALID_ANCHOR")
	# Normalize JSON's 1.0 to integer 1, then replace only after all checks pass.
	# One anchor represents the single toolbox, including when it is carried.
	var candidate: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"front_open": payload["front_open"],
		"back_open": payload["back_open"],
		"lamp_on": payload["lamp_on"],
		"toolbox_anchor": anchor
	}
	_state = candidate
	return _result(true, "RESTORED")


func _valid_version(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return value == SCHEMA_VERSION
	if typeof(value) == TYPE_FLOAT:
		return is_finite(value) and value == float(SCHEMA_VERSION)
	return false


func _result(ok: bool, code: String) -> Dictionary:
	return {"ok": ok, "code": code}
