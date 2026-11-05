extends RefCounted
## Application boundary for validated world observations and dialogue choices.
## Source-only milestone: engine, gameplay and tests NOT_RUN.

const Session = preload("res://runtime/session_coordinator.gd")
const MAX_TEXT := 2048
const MAX_SPEAKER := 80
const MAX_BINDINGS := 128
const MAX_LINES := 1152

var _session: Session = null
var _observations: Dictionary = {}
var _dialogue: Dictionary = {}
var _intro_key: String = ""
var _revision: int = 0


func configure(definition: Dictionary, presentation: Dictionary) -> Dictionary:
	return configure_with_side(definition, presentation, {})


func configure_with_side(definition: Dictionary, presentation: Dictionary, side_definition: Dictionary) -> Dictionary:
	if _session != null:
		return _error("ALREADY_CONFIGURED")
	var staged: Session = Session.new()
	var checked: Dictionary = staged.configure_with_side(definition, side_definition)
	if not checked.get("ok", false):
		return checked
	checked = _validate_presentation(definition, presentation)
	if not checked["ok"]:
		return checked
	_session = staged
	_observations = presentation["observations"].duplicate(true)
	_dialogue = presentation["dialogue"].duplicate(true)
	_intro_key = presentation["intro_key"]
	_revision = 1
	return {"ok": true, "code": "APPLICATION_READY", "revision": _revision}


func present() -> Dictionary:
	if _session == null:
		return _error("NOT_CONFIGURED")
	var state: Dictionary = _session.view()
	if not state.get("ok", false):
		return state
	var key: String = state["text_key"] if state["started"] else _intro_key
	var line: Dictionary = _dialogue[key]
	var options: Array = []
	for item in state["options"]:
		var option_line: Dictionary = _dialogue[item["text_key"]]
		options.append({"action_id": item["id"], "text": option_line["text"], "revision": _revision})
	return {
		"ok": true, "code": "PRESENTATION", "revision": _revision,
		"mode": state["mode"], "node": state["node"],
		"started": state["started"], "terminal": state["terminal"],
		"speaker": line["speaker"], "text": line["text"], "options": options
	}


func start(expected_revision: int) -> Dictionary:
	var gate: Dictionary = _guard(expected_revision)
	return gate if not gate["ok"] else _finish(_session.start())


func observe_interaction(interaction_id: String, expected_revision: int) -> Dictionary:
	var gate: Dictionary = _guard(expected_revision)
	if not gate["ok"]:
		return gate
	if not _observations.has(interaction_id):
		return _error("UNKNOWN_WORLD_INTERACTION")
	# Map a scene-owned interaction, never infer observations from unmet gates.
	return _finish(_session.observe(_observations[interaction_id]))


func choose(action_id: String, expected_revision: int) -> Dictionary:
	var gate: Dictionary = _guard(expected_revision)
	return gate if not gate["ok"] else _finish(_session.choose(action_id))


func side_view() -> Dictionary:
	if _session == null:
		return _error("NOT_CONFIGURED")
	var state: Dictionary = _session.side_view()
	state["revision"] = _revision
	return state


func side_start(expected_revision: int) -> Dictionary:
	var gate: Dictionary = _guard(expected_revision)
	return gate if not gate["ok"] else _finish(_session.side_start())


func side_choose(action_id: String, expected_revision: int) -> Dictionary:
	var gate: Dictionary = _guard(expected_revision)
	return gate if not gate["ok"] else _finish(_session.side_choose(action_id))


func save(expected_revision: int) -> Dictionary:
	var gate: Dictionary = _guard(expected_revision)
	return gate if not gate["ok"] else _session.save_active()


func load_latest(expected_revision: int) -> Dictionary:
	var gate: Dictionary = _guard(expected_revision)
	return gate if not gate["ok"] else _finish(_session.load_active())


func load_archived(generation: int, expected_revision: int) -> Dictionary:
	var gate: Dictionary = _guard(expected_revision)
	return gate if not gate["ok"] else _finish(_session.load_archived(generation))


func archive_saves(expected_revision: int, keep: int = 32) -> Dictionary:
	var gate: Dictionary = _guard(expected_revision)
	return gate if not gate["ok"] else _session.archive_active(keep)


func enter_chapter(expected_revision: int) -> Dictionary:
	var gate: Dictionary = _guard(expected_revision)
	if not gate["ok"]:
		return gate
	if _session.view()["mode"] != "free":
		return _error("CHAPTER_ALREADY_ACTIVE")
	# Save before changing mode; failed persistence leaves the live mode alone.
	var saved: Dictionary = _session.save_active()
	if not saved.get("ok", false):
		return {"ok": false, "code": "SAVE_BEFORE_SWITCH_FAILED", "cause": saved}
	var switched: Dictionary = _finish(_session.enter_chapter())
	switched["saved_before_switch"] = saved
	return switched


func leave_chapter(expected_revision: int) -> Dictionary:
	var gate: Dictionary = _guard(expected_revision)
	if not gate["ok"]:
		return gate
	if _session.view()["mode"] != "chapter":
		return _error("NO_ACTIVE_CHAPTER")
	var saved: Dictionary = _session.save_active()
	if not saved.get("ok", false):
		return {"ok": false, "code": "SAVE_BEFORE_SWITCH_FAILED", "cause": saved}
	var switched: Dictionary = _finish(_session.leave_chapter())
	switched["saved_before_switch"] = saved
	return switched


func _guard(expected_revision: int) -> Dictionary:
	if _session == null:
		return _error("NOT_CONFIGURED")
	if expected_revision != _revision:
		return {"ok": false, "code": "STALE_PRESENTATION", "revision": _revision}
	return {"ok": true, "code": "CURRENT"}


func _finish(result: Dictionary) -> Dictionary:
	if result.get("ok", false):
		_revision += 1
	var answer: Dictionary = result.duplicate(true)
	answer["revision"] = _revision
	return answer


func _validate_presentation(definition: Dictionary, presentation: Dictionary) -> Dictionary:
	if presentation.size() != 3 or not presentation.has_all(["intro_key", "observations", "dialogue"]):
		return _error("INVALID_PRESENTATION_FIELDS")
	if typeof(presentation["intro_key"]) != TYPE_STRING:
		return _error("INVALID_INTRO_KEY")
	if typeof(presentation["observations"]) != TYPE_DICTIONARY or typeof(presentation["dialogue"]) != TYPE_DICTIONARY:
		return _error("INVALID_PRESENTATION_DATA")
	var observations: Dictionary = presentation["observations"]
	var dialogue: Dictionary = presentation["dialogue"]
	if observations.size() > MAX_BINDINGS or dialogue.is_empty() or dialogue.size() > MAX_LINES:
		return _error("PRESENTATION_LIMIT")
	var required_keys: Array = [presentation["intro_key"]]
	var granted_facts: Dictionary = {}
	for node in definition["nodes"].values():
		required_keys.append(node["text_key"])
		for action in node["actions"]:
			required_keys.append(action["text_key"])
			for fact in action["grants"]:
				granted_facts[fact] = true
	for interaction_id in observations:
		if not _identifier(interaction_id):
			return _error("INVALID_INTERACTION_ID")
		var fact: Variant = observations[interaction_id]
		if typeof(fact) != TYPE_STRING or not definition["facts"].has(fact):
			return _error("UNKNOWN_OBSERVATION_FACT")
		if granted_facts.has(fact):
			return _error("WORLD_CANNOT_GRANT_ACTION_FACT")
	for key in dialogue:
		if typeof(key) != TYPE_STRING or key.is_empty() or key.length() > 128:
			return _error("INVALID_DIALOGUE_KEY")
		if typeof(dialogue[key]) != TYPE_DICTIONARY:
			return _error("INVALID_DIALOGUE_LINE")
		var line: Dictionary = dialogue[key]
		if line.size() != 2 or not line.has_all(["speaker", "text"]):
			return _error("INVALID_DIALOGUE_FIELDS")
		if typeof(line["speaker"]) != TYPE_STRING or line["speaker"].length() > MAX_SPEAKER:
			return _error("INVALID_SPEAKER")
		if typeof(line["text"]) != TYPE_STRING or line["text"].is_empty() or line["text"].length() > MAX_TEXT:
			return _error("INVALID_DIALOGUE_TEXT")
	for key in required_keys:
		if not dialogue.has(key):
			return _error("MISSING_DIALOGUE_LINE")
	return {"ok": true, "code": "PRESENTATION_VALID"}


func _identifier(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.is_empty() or value.length() > 64:
		return false
	for index in range(value.length()):
		var code: int = value.unicode_at(index)
		var upper: bool = code >= 65 and code <= 90
		if (index == 0 and not upper) or (not upper and not (code >= 48 and code <= 57) and code != 95):
			return false
	return true


func _error(code: String) -> Dictionary:
	return {"ok": false, "code": code}
