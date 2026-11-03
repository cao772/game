extends RefCounted
## Owns free/chapter quest sessions. Candidate: runtime acceptance NOT_RUN.
## No clocks, wallets, global rewards or scene/UI dependencies in this milestone.

const QuestRuntime = preload("res://runtime/quest_runtime.gd")
const SaveStore = preload("res://runtime/save_store.gd")

var _definition: Dictionary = {}
var _free: QuestRuntime = null
var _chapter: QuestRuntime = null
var _store: SaveStore = SaveStore.new()
var _mode: String = "free"


func configure(definition: Dictionary) -> Dictionary:
	# Reconfiguration is deliberately not an implicit destructive new-game action.
	if _free != null:
		return _failure("ALREADY_CONFIGURED")
	var proposed: QuestRuntime = QuestRuntime.new()
	var checked: Dictionary = proposed.configure(definition)
	if not checked.get("ok", false):
		return checked
	_definition = definition.duplicate(true)
	_free = proposed
	return {"ok": true, "code": "CONFIGURED", "mode": _mode}


func enter_chapter() -> Dictionary:
	if _free == null:
		return _failure("NOT_CONFIGURED")
	if _chapter != null or _mode != "free":
		return _failure("CHAPTER_ALREADY_ACTIVE")
	var proposed: QuestRuntime = QuestRuntime.new()
	var checked: Dictionary = proposed.configure(_definition)
	if not checked.get("ok", false):
		return checked
	_chapter = proposed
	_mode = "chapter"
	return {"ok": true, "code": "CHAPTER_ENTERED", "mode": _mode}


func leave_chapter() -> Dictionary:
	if _mode != "chapter" or _chapter == null:
		return _failure("NO_ACTIVE_CHAPTER")
	# Free session is retained by identity, not reconstructed from chapter state.
	_chapter = null
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
	return {"schema": 1, "mode": _mode, "quest": runtime.snapshot()}


func save_active() -> Dictionary:
	if _active() == null:
		return _failure("NOT_CONFIGURED")
	# Only this active mode is persisted; chapter writes cannot select free's slot.
	return _store.write_record(_mode, snapshot())


func load_active() -> Dictionary:
	if _active() == null:
		return _failure("NOT_CONFIGURED")
	var record: Dictionary = _store.read_latest(_mode)
	if not record.get("ok", false):
		return record
	var payload_value: Variant = record.get("payload")
	if typeof(payload_value) != TYPE_DICTIONARY:
		return _failure("INVALID_SESSION_PAYLOAD")
	var payload: Dictionary = payload_value
	if payload.size() != 3 or not payload.has_all(["schema", "mode", "quest"]):
		return _failure("INVALID_SESSION_FIELDS")
	var schema: Variant = payload["schema"]
	if (typeof(schema) != TYPE_INT and typeof(schema) != TYPE_FLOAT) or schema != 1:
		return _failure("UNSUPPORTED_SESSION_SCHEMA")
	if typeof(payload["mode"]) != TYPE_STRING or payload["mode"] != _mode:
		return _failure("SAVE_MODE_MISMATCH")
	if typeof(payload["quest"]) != TYPE_DICTIONARY:
		return _failure("INVALID_QUEST_PAYLOAD")
	# A valid hash is not semantic validation. Restore into a new instance first.
	var proposed: QuestRuntime = QuestRuntime.new()
	var configured: Dictionary = proposed.configure(_definition)
	if not configured.get("ok", false):
		return configured
	var restored: Dictionary = proposed.restore(payload["quest"])
	if not restored.get("ok", false):
		return restored
	if _mode == "free":
		_free = proposed
	else:
		_chapter = proposed
	return {
		"ok": true, "code": "SESSION_RESTORED", "mode": _mode,
		"generation": record.get("generation"), "skipped": record.get("skipped", [])
	}


func _active() -> QuestRuntime:
	return _chapter if _mode == "chapter" else _free


func _failure(code: String) -> Dictionary:
	return {"ok": false, "code": code}
