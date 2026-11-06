extends RefCounted
## Owns free/chapter quest sessions. Candidate: runtime acceptance NOT_RUN.
## No clocks, wallets, global rewards or scene/UI dependencies in this milestone.

const QuestRuntime = preload("res://runtime/quest_runtime.gd")
const SaveStore = preload("res://runtime/save_store.gd")

var _definition: Dictionary = {}
var _side_definition: Dictionary = {}
var _free: QuestRuntime = null
var _free_side: QuestRuntime = null
var _chapter: QuestRuntime = null
var _chapter_side: QuestRuntime = null
var _store: SaveStore = SaveStore.new()
var _mode: String = "free"


func configure(definition: Dictionary) -> Dictionary:
	return configure_with_side(definition, {})


func configure_with_side(definition: Dictionary, side_definition: Dictionary) -> Dictionary:
	# Reconfiguration is deliberately not an implicit destructive new-game action.
	if _free != null:
		return _failure("ALREADY_CONFIGURED")
	var staged: Dictionary = _fresh_pair(definition, side_definition)
	if not staged["ok"]:
		return staged
	_definition = definition.duplicate(true)
	_side_definition = side_definition.duplicate(true)
	_free = staged["quest"]
	_free_side = staged["side_quest"]
	return {"ok": true, "code": "CONFIGURED", "mode": _mode}


func _fresh_pair(definition: Dictionary, side_definition: Dictionary) -> Dictionary:
	var quest := QuestRuntime.new()
	var checked: Dictionary = quest.configure(definition)
	if not checked["ok"]:
		return checked
	var side: QuestRuntime = null
	if not side_definition.is_empty():
		side = QuestRuntime.new()
		checked = side.configure(side_definition)
		if not checked["ok"]:
			return {"ok": false, "code": "INVALID_SIDE_DEFINITION", "cause": checked}
	return {"ok": true, "quest": quest, "side_quest": side}


func enter_chapter() -> Dictionary:
	if _free == null:
		return _failure("NOT_CONFIGURED")
	if _chapter != null or _mode != "free":
		return _failure("CHAPTER_ALREADY_ACTIVE")
	var staged: Dictionary = _fresh_pair(_definition, _side_definition)
	if not staged["ok"]:
		return staged
	_chapter = staged["quest"]
	_chapter_side = staged["side_quest"]
	_mode = "chapter"
	return {"ok": true, "code": "CHAPTER_ENTERED", "mode": _mode}


func leave_chapter() -> Dictionary:
	if _mode != "chapter" or _chapter == null:
		return _failure("NO_ACTIVE_CHAPTER")
	# Free session is retained by identity, not reconstructed from chapter state.
	_chapter = null
	_chapter_side = null
	_mode = "free"
	return {"ok": true, "code": "CHAPTER_LEFT", "mode": _mode}


func start() -> Dictionary:
	var runtime: QuestRuntime = _active()
	return _failure("NOT_CONFIGURED") if runtime == null else runtime.start()


func observe(fact: String) -> Dictionary:
	var runtime: QuestRuntime = _active()
	return _failure("NOT_CONFIGURED") if runtime == null else runtime.observe(fact)


func choose(action_id: String) -> Dictionary:
	var runtime: QuestRuntime = _active()
	return _failure("NOT_CONFIGURED") if runtime == null else runtime.choose(action_id)


func side_start() -> Dictionary:
	var side := _active_side()
	return _failure("SIDE_QUEST_UNAVAILABLE") if side == null else side.start()


func side_choose(action_id: String) -> Dictionary:
	var side := _active_side()
	return _failure("SIDE_QUEST_UNAVAILABLE") if side == null else side.choose(action_id)


func side_view() -> Dictionary:
	var side := _active_side()
	if side == null:
		return _failure("SIDE_QUEST_UNAVAILABLE")
	var result: Dictionary = side.view()
	result["mode"] = _mode
	return result


func view() -> Dictionary:
	var runtime: QuestRuntime = _active()
	if runtime == null:
		return _failure("NOT_CONFIGURED")
	var result: Dictionary = runtime.view().duplicate(true)
	result["mode"] = _mode
	return result


func snapshot() -> Dictionary:
	var runtime: QuestRuntime = _active()
	if runtime == null:
		return {}
	var payload := {"schema": 1, "mode": _mode, "quest": runtime.snapshot()}
	var side := _active_side()
	if side != null:
		payload["schema"] = 2
		payload["side_quest"] = side.snapshot()
	return payload


func save_active() -> Dictionary:
	if _active() == null:
		return _failure("NOT_CONFIGURED")
	# Only this active mode is persisted; chapter writes cannot select free's slot.
	return _store.write_record(_mode, snapshot())


func load_active() -> Dictionary:
	if _active() == null:
		return _failure("NOT_CONFIGURED")
	var record: Dictionary = _store.read_latest(_mode)
	return _restore_record(record)


func archive_active(keep: int = 32) -> Dictionary:
	if _active() == null:
		return _failure("NOT_CONFIGURED")
	return _store.archive_older(_mode, keep)


func load_archived(generation: int) -> Dictionary:
	if _active() == null:
		return _failure("NOT_CONFIGURED")
	return _restore_record(_store.read_archived(_mode, generation))


func _restore_record(record: Dictionary) -> Dictionary:
	if not record.get("ok", false):
		return record
	var payload_value: Variant = record.get("payload")
	if typeof(payload_value) != TYPE_DICTIONARY:
		return _failure("INVALID_SESSION_PAYLOAD")
	var payload: Dictionary = payload_value
	if not payload.has_all(["schema", "mode", "quest"]):
		return _failure("INVALID_SESSION_FIELDS")
	var schema: Variant = payload["schema"]
	if (typeof(schema) != TYPE_INT and typeof(schema) != TYPE_FLOAT) or (schema != 1 and schema != 2):
		return _failure("UNSUPPORTED_SESSION_SCHEMA")
	if schema == 1 and payload.size() != 3:
		return _failure("INVALID_SESSION_FIELDS")
	if schema == 2:
		if payload.size() != 4 or not payload.has("side_quest"):
			return _failure("INVALID_SESSION_FIELDS")
		if _side_definition.is_empty():
			return _failure("SIDE_DEFINITION_REQUIRED")
		if typeof(payload["side_quest"]) != TYPE_DICTIONARY:
			return _failure("INVALID_SIDE_PAYLOAD")
	if typeof(payload["mode"]) != TYPE_STRING or payload["mode"] != _mode:
		return _failure("SAVE_MODE_MISMATCH")
	if typeof(payload["quest"]) != TYPE_DICTIONARY:
		return _failure("INVALID_QUEST_PAYLOAD")
	# Validate both quests off to the side. Legacy records start the optional
	# quest fresh; a bad companion snapshot leaves the live pair untouched.
	var staged: Dictionary = _fresh_pair(_definition, _side_definition)
	if not staged["ok"]:
		return staged
	var quest: QuestRuntime = staged["quest"]
	var side: QuestRuntime = staged["side_quest"]
	var restored: Dictionary = quest.restore(payload["quest"])
	if not restored.get("ok", false):
		return restored
	if schema == 2:
		var side_restored: Dictionary = side.restore(payload["side_quest"])
		if not side_restored["ok"]:
			return {"ok": false, "code": "SIDE_RESTORE_FAILED", "cause": side_restored}
	if _mode == "free":
		_free = quest
		_free_side = side
	else:
		_chapter = quest
		_chapter_side = side
	return {
		"ok": true, "code": "SESSION_RESTORED", "mode": _mode,
		"generation": record.get("generation"), "skipped": record.get("skipped", []),
		"history_normalized": restored.get("history_normalized", false),
		"history_input_steps": restored.get("history_input_steps", 0),
		"history_steps": restored.get("history_steps", 0)
	}


func _active() -> QuestRuntime:
	return _chapter if _mode == "chapter" else _free


func _active_side() -> QuestRuntime:
	return _chapter_side if _mode == "chapter" else _free_side


func _failure(code: String) -> Dictionary:
	return {"ok": false, "code": code}
