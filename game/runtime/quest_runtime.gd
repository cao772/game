extends RefCounted
## Bounded per-session quest graph. Candidate; engine/runtime acceptance NOT_RUN.
## This module never awards inventory, changes a world clock or writes a file.

const MAX_FACTS := 128
# Input protection for old full-history saves; not a lifetime action budget.
const MAX_RESTORE_HISTORY := 256
const MAX_NODES := 64
const MAX_CANONICAL_HISTORY := MAX_NODES - 1
const MAX_ACTIONS := 16
const MAX_VERSION := 2147483647
const MAX_TEXT_KEY := 128
const DEFINITION_FIELDS := ["id", "version", "start", "facts", "nodes"]
const NODE_FIELDS := ["text_key", "terminal", "actions"]
const ACTION_FIELDS := [
	"id", "text_key", "target", "requires_all", "requires_any", "grants"
]
const SNAPSHOT_FIELDS := [
	"schema", "definition_id", "definition_version", "definition_sha256",
	"started", "node", "facts", "history"
]

var _definition: Dictionary = {}
var _definition_sha256: String = ""
var _configured: bool = false
var _started: bool = false
var _node: String = ""
var _facts: Dictionary = {}
var _history: Array = []


func configure(definition: Dictionary) -> Dictionary:
	var issue: Dictionary = _validate_definition(definition)
	if not issue["ok"]:
		return issue
	# All validation is read-only. Commit a private copy only after it succeeds.
	var staged: Dictionary = definition.duplicate(true)
	staged["version"] = int(staged["version"])
	_definition = staged
	_definition_sha256 = JSON.stringify(staged, "", true).sha256_text()
	_configured = true
	_started = false
	_node = ""
	_facts = {}
	_history = []
	return _success("CONFIGURED")


func observe(fact: String) -> Dictionary:
	if not _configured:
		return _failure("NOT_CONFIGURED")
	if not _definition["facts"].has(fact):
		return _failure("UNKNOWN_FACT", "fact")
	if _facts.has(fact):
		return _success("FACT_ALREADY_OBSERVED")
	_facts[fact] = true
	return _success("FACT_OBSERVED")


func start() -> Dictionary:
	if not _configured:
		return _failure("NOT_CONFIGURED")
	if _started:
		return _failure("ALREADY_STARTED")
	_started = true
	_node = _definition["start"]
	return _success("STARTED")


func choose(action_id: String) -> Dictionary:
	if not _configured:
		return _failure("NOT_CONFIGURED")
	if not _started:
		return _failure("NOT_STARTED")
	var current: Dictionary = _definition["nodes"][_node]
	if current["terminal"]:
		return _failure("TERMINAL_NODE")
	var action: Dictionary = _find_action(current, action_id)
	if action.is_empty():
		return _failure("ACTION_NOT_AT_CURRENT_NODE", "action_id")
	if not _gates_pass(action, _facts):
		return _failure("ACTION_REQUIREMENTS_UNMET", "action_id")
	# Preserve monotonic facts even when the action returns to a prior node.
	# History is a route witness, not a complete action/observation audit trail.
	var staged_facts: Dictionary = _facts.duplicate()
	for fact in action["grants"]:
		staged_facts[fact] = true
	var extended_history: Array = _history.duplicate()
	extended_history.append(action_id)
	var staged_history: Array = _loop_erased_route(extended_history)
	# All derived state is prepared before the commit; no external callouts.
	_facts = staged_facts
	_history = staged_history
	_node = action["target"]
	return {
		"ok": true, "code": "ACTION_APPLIED",
		"history_compacted": staged_history.size() < extended_history.size(),
		"history_steps": staged_history.size()
	}


func snapshot() -> Dictionary:
	# Query-only exception to command result shape: {} means not configured.
	if not _configured:
		return {}
	var fact_ids: Array = _facts.keys()
	fact_ids.sort()
	return {
		"schema": 1,
		"definition_id": _definition["id"],
		"definition_version": _definition["version"],
		"definition_sha256": _definition_sha256,
		"started": _started,
		"node": _node,
		"facts": fact_ids,
		"history": _history.duplicate()
	}


func restore(data: Dictionary) -> Dictionary:
	if not _configured:
		return _failure("NOT_CONFIGURED")
	if not _exact_fields(data, SNAPSHOT_FIELDS):
		return _failure("INVALID_SNAPSHOT_FIELDS")
	if not _whole_number(data["schema"], 1, 1):
		return _failure("UNSUPPORTED_SNAPSHOT_SCHEMA", "schema")
	if typeof(data["definition_id"]) != TYPE_STRING:
		return _failure("INVALID_DEFINITION_ID", "definition_id")
	if data["definition_id"] != _definition["id"]:
		return _failure("DEFINITION_ID_MISMATCH", "definition_id")
	if not _whole_number(data["definition_version"], 1, MAX_VERSION):
		return _failure("INVALID_DEFINITION_VERSION", "definition_version")
	if int(data["definition_version"]) != _definition["version"]:
		return _failure("DEFINITION_VERSION_MISMATCH", "definition_version")
	if typeof(data["definition_sha256"]) != TYPE_STRING:
		return _failure("INVALID_DEFINITION_FINGERPRINT", "definition_sha256")
	if data["definition_sha256"] != _definition_sha256:
		return _failure("DEFINITION_FINGERPRINT_MISMATCH", "definition_sha256")
	if typeof(data["started"]) != TYPE_BOOL or typeof(data["node"]) != TYPE_STRING:
		return _failure("INVALID_SNAPSHOT_STATE")
	var fact_issue: String = _identifier_list_error(data["facts"], MAX_FACTS)
	if not fact_issue.is_empty():
		return _failure("INVALID_SNAPSHOT_FACTS", "facts:" + fact_issue)
	var staged_facts: Dictionary = {}
	for fact in data["facts"]:
		if not _definition["facts"].has(fact):
			return _failure("UNKNOWN_SNAPSHOT_FACT", "facts")
		staged_facts[fact] = true
	if typeof(data["history"]) != TYPE_ARRAY:
		return _failure("INVALID_SNAPSHOT_HISTORY", "history")
	var history: Array = data["history"]
	if history.size() > MAX_RESTORE_HISTORY:
		return _failure("RESTORE_HISTORY_LIMIT", "history")
	for action_id in history:
		if not _identifier(action_id):
			return _failure("INVALID_HISTORY_ACTION", "history")
	if not data["started"]:
		if data["node"] != "" or not history.is_empty():
			return _failure("UNSTARTED_SNAPSHOT_HAS_PROGRESS")
	else:
		if not _definition["nodes"].has(data["node"]):
			return _failure("UNKNOWN_SNAPSHOT_NODE", "node")
		var replay_node: String = _definition["start"]
		for index in range(history.size()):
			var current: Dictionary = _definition["nodes"][replay_node]
			if current["terminal"]:
				return _failure("HISTORY_AFTER_TERMINAL", "history/%d" % index)
			var action: Dictionary = _find_action(current, history[index])
			if action.is_empty():
				return _failure("HISTORY_PATH_MISMATCH", "history/%d" % index)
			# Facts are monotonic and may be externally observed before start.
			# Their exact observation times are deliberately not inferred.
			if not _gates_pass(action, staged_facts):
				return _failure("HISTORY_REQUIREMENTS_MISSING", "history/%d" % index)
			for fact in action["grants"]:
				if not staged_facts.has(fact):
					return _failure("HISTORY_GRANT_MISSING", "history/%d" % index)
			replay_node = action["target"]
		if replay_node != data["node"]:
			return _failure("HISTORY_NODE_MISMATCH", "node")
	# Validate every original step BEFORE erasing loops. Invalid actions,
	# missing grants and post-terminal steps cannot hide inside a removed loop.
	var staged_history: Array = _loop_erased_route(history)
	# No earlier branch changes live state, even for almost-valid snapshots.
	_started = data["started"]
	_node = data["node"]
	_facts = staged_facts
	_history = staged_history
	return {
		"ok": true, "code": "RESTORED",
		"history_normalized": staged_history != history,
		"history_input_steps": history.size(), "history_steps": staged_history.size()
	}


func view() -> Dictionary:
	if not _configured:
		return _failure("NOT_CONFIGURED")
	var result: Dictionary = {
		"ok": true, "code": "VIEW", "started": _started, "node": _node,
		"terminal": false, "text_key": "", "available_actions": [],
		"options": [], "history_kind": "loop_erased_route", "history_steps": _history.size(),
		"history_capacity": MAX_CANONICAL_HISTORY,
		# Retained for earlier callers; it no longer gates action availability.
		"history_limit_reached": false
	}
	if not _started:
		return result
	var current: Dictionary = _definition["nodes"][_node]
	result["terminal"] = current["terminal"]
	result["text_key"] = current["text_key"]
	if current["terminal"]:
		return result
	for action in current["actions"]:
		if _gates_pass(action, _facts):
			result["available_actions"].append(action["id"])
			result["options"].append({"id": action["id"], "text_key": action["text_key"]})
	return result


func _loop_erased_route(history: Array) -> Array:
	# Private helper: callers have already validated the entire input path.
	# Route nodes are unique after each step, hence at most N-1 action edges.
	var route: Array = []
	var route_nodes: Array = [_definition["start"]]
	var current_node: String = _definition["start"]
	for action_id in history:
		var action: Dictionary = _find_action(_definition["nodes"][current_node], action_id)
		var target: String = action["target"]
		var prior_index: int = route_nodes.find(target)
		if prior_index >= 0:
			route.resize(prior_index)
			route_nodes.resize(prior_index + 1)
		else:
			route.append(action_id)
			route_nodes.append(target)
		current_node = target
	return route


func _validate_definition(definition: Dictionary) -> Dictionary:
	if not _exact_fields(definition, DEFINITION_FIELDS):
		return _failure("INVALID_DEFINITION_FIELDS")
	if not _identifier(definition["id"]):
		return _failure("INVALID_DEFINITION_ID", "id")
	if not _whole_number(definition["version"], 1, MAX_VERSION):
		return _failure("INVALID_DEFINITION_VERSION", "version")
	var fact_issue: String = _identifier_list_error(definition["facts"], MAX_FACTS)
	if not fact_issue.is_empty():
		return _failure("INVALID_DEFINITION_FACTS", "facts:" + fact_issue)
	if typeof(definition["nodes"]) != TYPE_DICTIONARY:
		return _failure("INVALID_NODES", "nodes")
	var nodes: Dictionary = definition["nodes"]
	if nodes.is_empty() or nodes.size() > MAX_NODES:
		return _failure("NODE_LIMIT", "nodes")
	if not _identifier(definition["start"]) or not nodes.has(definition["start"]):
		return _failure("INVALID_START_NODE", "start")
	var seen_actions: Dictionary = {}
	for node_id in nodes:
		if not _identifier(node_id):
			return _failure("INVALID_NODE_ID", "nodes")
		if typeof(nodes[node_id]) != TYPE_DICTIONARY:
			return _failure("INVALID_NODE", "nodes/" + node_id)
		var node: Dictionary = nodes[node_id]
		if not _exact_fields(node, NODE_FIELDS):
			return _failure("INVALID_NODE_FIELDS", "nodes/" + node_id)
		if not _text_key(node["text_key"]) or typeof(node["terminal"]) != TYPE_BOOL:
			return _failure("INVALID_NODE_METADATA", "nodes/" + node_id)
		if typeof(node["actions"]) != TYPE_ARRAY:
			return _failure("INVALID_ACTIONS", "nodes/" + node_id)
		var actions: Array = node["actions"]
		if actions.size() > MAX_ACTIONS:
			return _failure("ACTION_LIMIT", "nodes/" + node_id)
		if bool(node["terminal"]) != actions.is_empty():
			return _failure("NODE_TERMINAL_ACTION_MISMATCH", "nodes/" + node_id)
		for index in range(actions.size()):
			var path: String = "nodes/%s/actions/%d" % [node_id, index]
			if typeof(actions[index]) != TYPE_DICTIONARY:
				return _failure("INVALID_ACTION", path)
			var action: Dictionary = actions[index]
			if not _exact_fields(action, ACTION_FIELDS):
				return _failure("INVALID_ACTION_FIELDS", path)
			if not _identifier(action["id"]) or not _text_key(action["text_key"]):
				return _failure("INVALID_ACTION_METADATA", path)
			if seen_actions.has(action["id"]):
				return _failure("DUPLICATE_ACTION_ID", path)
			seen_actions[action["id"]] = true
			if not _identifier(action["target"]) or not nodes.has(action["target"]):
				return _failure("UNKNOWN_ACTION_TARGET", path)
			for field in ["requires_all", "requires_any", "grants"]:
				var list_issue: String = _identifier_list_error(action[field], MAX_FACTS)
				if not list_issue.is_empty():
					return _failure("INVALID_ACTION_FACTS", path + "/" + field + ":" + list_issue)
				for fact in action[field]:
					if not definition["facts"].has(fact):
						return _failure("UNKNOWN_ACTION_FACT", path + "/" + field)
	return _validate_graph(nodes, definition["start"])


func _validate_graph(nodes: Dictionary, start_node: String) -> Dictionary:
	var reached: Dictionary = {start_node: true}
	var frontier: Array = [start_node]
	var cursor: int = 0
	while cursor < frontier.size():
		var node_id: String = frontier[cursor]
		cursor += 1
		for action in nodes[node_id]["actions"]:
			var target: String = action["target"]
			if not reached.has(target):
				reached[target] = true
				frontier.append(target)
	if reached.size() != nodes.size():
		return _failure("UNREACHABLE_NODE", "nodes")
	# Reverse reachability: a cycle is fine if it has a route to a terminal.
	var can_finish: Dictionary = {}
	for node_id in nodes:
		if nodes[node_id]["terminal"]:
			can_finish[node_id] = true
	for _pass in range(nodes.size()):
		var grew: bool = false
		for node_id in nodes:
			if can_finish.has(node_id):
				continue
			for action in nodes[node_id]["actions"]:
				if can_finish.has(action["target"]):
					can_finish[node_id] = true
					grew = true
					break
		if not grew:
			break
	if can_finish.size() != nodes.size():
		return _failure("NODE_CANNOT_REACH_TERMINAL", "nodes")
	return _success("DEFINITION_VALID")


func _find_action(node: Dictionary, action_id: String) -> Dictionary:
	for action in node["actions"]:
		if action["id"] == action_id:
			return action
	return {}


func _gates_pass(action: Dictionary, facts: Dictionary) -> bool:
	for fact in action["requires_all"]:
		if not facts.has(fact):
			return false
	if action["requires_any"].is_empty():
		return true
	for fact in action["requires_any"]:
		if facts.has(fact):
			return true
	return false


func _identifier(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var text: String = value
	if text.is_empty() or text.length() > 64:
		return false
	for index in range(text.length()):
		var code: int = text.unicode_at(index)
		var upper: bool = code >= 65 and code <= 90
		if index == 0 and not upper:
			return false
		if not upper and not (code >= 48 and code <= 57) and code != 95:
			return false
	return true


func _identifier_list_error(value: Variant, maximum: int) -> String:
	if typeof(value) != TYPE_ARRAY:
		return "not_array"
	var values: Array = value
	if values.size() > maximum:
		return "limit"
	var seen: Dictionary = {}
	for item in values:
		if not _identifier(item):
			return "identifier"
		if seen.has(item):
			return "duplicate"
		seen[item] = true
	return ""


func _whole_number(value: Variant, minimum: int, maximum: int) -> bool:
	# JSON numbers arrive as floats; bool is never an integer version/schema.
	if typeof(value) == TYPE_INT:
		return value >= minimum and value <= maximum
	if typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(value) and value >= minimum and value <= maximum and value == floor(value)


func _text_key(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not value.is_empty() and value.length() <= MAX_TEXT_KEY


func _exact_fields(value: Dictionary, fields: Array) -> bool:
	return value.size() == fields.size() and value.has_all(fields)


func _success(code: String) -> Dictionary:
	return {"ok": true, "code": code}


func _failure(code: String, path: String = "") -> Dictionary:
	var result: Dictionary = {"ok": false, "code": code}
	if not path.is_empty():
		result["path"] = path
	return result
