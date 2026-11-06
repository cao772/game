extends RefCounted
## Independent open-world state. No nodes, quest/session calls or file paths.
## Arrays hold [x, y, z]; headings are radians; anchors are object bottom centers.
## Command results have ok/code/detail. snapshot() alone returns a raw payload ({} before configure).
## Source/grammar review only. Godot, gameplay and storage acceptance NOT_RUN.

const SCHEMA := 1
const MAX_DAY := 1000000
const MAX_ADVANCE := 10080
const INTERACT_RADIUS := 3.0
const ROUTE_RADIUS := 4.0
const ATLAS_FIELDS := [
	"schema_version", "initial_region", "initial_day", "initial_minute",
	"regions", "routes", "anchors", "objects", "landmarks", "npcs"
]
const SNAPSHOT_FIELDS := ["schema_version", "config_hash", "player", "clock", "visited", "objects", "carried"]
const REGION_FIELDS := ["id", "label", "description", "color", "bounds", "spawn"]
const ROUTE_FIELDS := ["id", "reverse_id", "from", "to", "exit", "spawn", "spawn_heading", "travel_minutes", "label"]
const ANCHOR_FIELDS := ["id", "label", "region", "position"]
const OBJECT_FIELDS := ["id", "label", "kind", "size", "initial_anchor", "initial_quarter_turns"]
const LANDMARK_FIELDS := ["id", "label", "description", "region", "position", "radius"]
const NPC_FIELDS := ["id", "label", "schedule"]
const PERIOD_FIELDS := ["start", "end", "region", "position", "heading", "activity"]

var _regions: Dictionary = {}
var _routes: Dictionary = {}
var _anchors: Dictionary = {}
var _objects: Dictionary = {}
var _landmarks: Dictionary = {}
var _npcs: Dictionary = {}
var _config_hash: String = ""
var _state: Dictionary = {}


func configure(data: Dictionary) -> Dictionary:
	if not _state.is_empty():
		return _failure("ALREADY_CONFIGURED")
	var checked: Dictionary = _validate_atlas(data)
	if not checked["ok"]:
		return checked
	# Normalizing JSON numbers before hashing also accepts parse/stringify round trips.
	var staged: Dictionary = _canonical_numbers(data)
	var digest: String = JSON.stringify(staged, "", true, true).sha256_text()
	var regions: Dictionary = _index(staged["regions"])
	var object_states: Dictionary = {}
	for item in staged["objects"]:
		object_states[item["id"]] = {
			"anchor_id": item["initial_anchor"],
			"quarter_turns": int(item["initial_quarter_turns"])
		}
	var player: Dictionary = {
		"region": staged["initial_region"],
		"position": regions[staged["initial_region"]]["spawn"].duplicate(), "heading": 0.0
	}
	var fresh: Dictionary = {
		"schema_version": SCHEMA, "config_hash": digest, "player": player,
		"clock": {"day": int(staged["initial_day"]), "minute": int(staged["initial_minute"])},
		"visited": [], "objects": object_states, "carried": ""
	}
	# All candidate work is local until the configuration is known valid.
	_regions = regions
	_routes = _index(staged["routes"])
	_anchors = _index(staged["anchors"])
	_objects = _index(staged["objects"])
	_landmarks = _index(staged["landmarks"])
	_npcs = _index(staged["npcs"])
	_config_hash = digest
	_state = fresh
	return _success("CONFIGURED")


func view() -> Dictionary:
	if _state.is_empty():
		return _failure("NOT_CONFIGURED")
	var region_id: String = _state["player"]["region"]
	var minute: int = _state["clock"]["minute"]
	var routes: Array = []
	var anchors: Array = []
	var landmarks: Array = []
	var objects: Array = []
	var npcs: Array = []
	for route in _routes.values():
		if route["from"] == region_id:
			routes.append(route.duplicate(true))
	for anchor in _anchors.values():
		if anchor["region"] == region_id:
			var projected: Dictionary = anchor.duplicate(true)
			projected["occupied_by"] = _occupant(anchor["id"])
			anchors.append(projected)
	for landmark in _landmarks.values():
		if landmark["region"] == region_id:
			var projected: Dictionary = landmark.duplicate(true)
			projected["visited"] = _state["visited"].has(landmark["id"])
			landmarks.append(projected)
	for object_id in _objects:
		if object_id == _state["carried"]:
			continue
		var object_state: Dictionary = _state["objects"][object_id]
		var anchor: Dictionary = _anchors[object_state["anchor_id"]]
		if anchor["region"] == region_id:
			var projected: Dictionary = _objects[object_id].duplicate(true)
			projected.merge(object_state.duplicate(true), true)
			projected["region"] = region_id
			projected["position"] = anchor["position"].duplicate()
			objects.append(projected)
	for npc in _npcs.values():
		for period in npc["schedule"]:
			if minute >= period["start"] and minute < period["end"]:
				if period["region"] == region_id:
					var projected: Dictionary = period.duplicate(true)
					projected["id"] = npc["id"]
					projected["label"] = npc["label"]
					npcs.append(projected)
				break
	return {
		"ok": true, "code": "WORLD_VIEW", "config_hash": _config_hash,
		"state": snapshot(), "current_region": _regions[region_id].duplicate(true),
		"routes": routes, "anchors": anchors, "landmarks": landmarks, "objects": objects, "npcs": npcs
	}


func set_player(position: Array, heading: float) -> Dictionary:
	if _state.is_empty():
		return _failure("NOT_CONFIGURED")
	if not _position_in(position, _regions[_state["player"]["region"]]):
		return _failure("PLAYER_OUT_OF_BOUNDS")
	if not _number(heading, -1000000.0, 1000000.0):
		return _failure("INVALID_HEADING")
	_state["player"]["position"] = _float_vector(position)
	_state["player"]["heading"] = wrapf(heading, -PI, PI)
	return _success("PLAYER_UPDATED")


func travel(route_id: String) -> Dictionary:
	if _state.is_empty():
		return _failure("NOT_CONFIGURED")
	if not _routes.has(route_id):
		return _failure("UNKNOWN_ROUTE", route_id)
	var route: Dictionary = _routes[route_id]
	var nearby: Dictionary = _require_near(route["from"], route["exit"], ROUTE_RADIUS)
	if not nearby["ok"]:
		return nearby
	var clock: Dictionary = _advanced_clock(int(route["travel_minutes"]))
	if clock.is_empty():
		return _failure("CLOCK_LIMIT")
	_state["player"] = {
		"region": route["to"], "position": route["spawn"].duplicate(),
		"heading": float(route["spawn_heading"])
	}
	_state["clock"] = clock
	# A carried object has no anchor; it crosses regions with the player.
	return _success("TRAVELLED")


func advance_minutes(amount: int) -> Dictionary:
	if _state.is_empty():
		return _failure("NOT_CONFIGURED")
	if amount < 0 or amount > MAX_ADVANCE:
		return _failure("INVALID_MINUTES")
	var clock: Dictionary = _advanced_clock(amount)
	if clock.is_empty():
		return _failure("CLOCK_LIMIT")
	_state["clock"] = clock
	return _success("TIME_ADVANCED")


func discover(landmark_id: String) -> Dictionary:
	if _state.is_empty():
		return _failure("NOT_CONFIGURED")
	if not _landmarks.has(landmark_id):
		return _failure("UNKNOWN_LANDMARK", landmark_id)
	var landmark: Dictionary = _landmarks[landmark_id]
	var nearby: Dictionary = _require_near(landmark["region"], landmark["position"], landmark["radius"])
	if not nearby["ok"]:
		return nearby
	if _state["visited"].has(landmark_id):
		return _success("LANDMARK_ALREADY_DISCOVERED")
	_state["visited"].append(landmark_id)
	_state["visited"].sort()
	return _success("LANDMARK_DISCOVERED")


func take_object(object_id: String) -> Dictionary:
	if _state.is_empty():
		return _failure("NOT_CONFIGURED")
	if not _objects.has(object_id):
		return _failure("UNKNOWN_OBJECT", object_id)
	if _state["carried"] == object_id:
		return _success("OBJECT_ALREADY_CARRIED")
	if _state["carried"] != "":
		return _failure("HANDS_FULL")
	var anchor: Dictionary = _anchors[_state["objects"][object_id]["anchor_id"]]
	var nearby: Dictionary = _require_near(anchor["region"], anchor["position"], INTERACT_RADIUS)
	if not nearby["ok"]:
		return nearby
	_state["objects"][object_id]["anchor_id"] = ""
	_state["carried"] = object_id
	return _success("OBJECT_TAKEN")


func place_object(anchor_id: String) -> Dictionary:
	if _state.is_empty():
		return _failure("NOT_CONFIGURED")
	if not _anchors.has(anchor_id):
		return _failure("UNKNOWN_ANCHOR", anchor_id)
	if _state["carried"] == "":
		return _failure("NOT_CARRYING")
	var anchor: Dictionary = _anchors[anchor_id]
	var nearby: Dictionary = _require_near(anchor["region"], anchor["position"], INTERACT_RADIUS)
	if not nearby["ok"]:
		return nearby
	if _occupant(anchor_id) != "":
		return _failure("ANCHOR_OCCUPIED", anchor_id)
	# The explorer capsule is 0.32m radius, 1.65m high with a foot origin.
	# Never materialize a solid crate intersecting the player's current body.
	var carried_id: String = _state["carried"]
	var size: Array = _objects[carried_id]["size"]
	var turns: int = int(_state["objects"][carried_id]["quarter_turns"])
	var half_x: float = float(size[0 if turns % 2 == 0 else 2]) * 0.5
	var half_z: float = float(size[2 if turns % 2 == 0 else 0]) * 0.5
	var player_position: Array = _state["player"]["position"]
	var anchor_position: Array = anchor["position"]
	var dx: float = maxf(absf(float(player_position[0]) - float(anchor_position[0])) - half_x, 0.0)
	var dz: float = maxf(absf(float(player_position[2]) - float(anchor_position[2])) - half_z, 0.0)
	var vertical_overlap: bool = float(player_position[1]) < float(anchor_position[1]) + float(size[1]) and float(player_position[1]) + 1.65 > float(anchor_position[1])
	if vertical_overlap and dx * dx + dz * dz < 0.32 * 0.32:
		return _failure("PLAYER_BLOCKS_PLACEMENT", anchor_id)
	_state["objects"][_state["carried"]]["anchor_id"] = anchor_id
	_state["carried"] = ""
	return _success("OBJECT_PLACED")


func rotate_carried() -> Dictionary:
	if _state.is_empty():
		return _failure("NOT_CONFIGURED")
	if _state["carried"] == "":
		return _failure("NOT_CARRYING")
	var object_state: Dictionary = _state["objects"][_state["carried"]]
	object_state["quarter_turns"] = (int(object_state["quarter_turns"]) + 1) % 4
	return _success("CARRIED_ROTATED")


func snapshot() -> Dictionary:
	return _state.duplicate(true)


func restore(data: Dictionary) -> Dictionary:
	if _state.is_empty():
		return _failure("NOT_CONFIGURED")
	if not _fields(data, SNAPSHOT_FIELDS) or not _whole(data["schema_version"], SCHEMA, SCHEMA):
		return _failure("INVALID_WORLD_SNAPSHOT")
	if typeof(data["config_hash"]) != TYPE_STRING or data["config_hash"] != _config_hash:
		return _failure("CONFIG_MISMATCH")
	var player: Variant = data["player"]
	if not _fields(player, ["region", "position", "heading"]):
		return _failure("INVALID_PLAYER")
	if not _reference(player["region"], _regions):
		return _failure("UNKNOWN_PLAYER_REGION")
	if not _position_in(player["position"], _regions[player["region"]]) or not _heading(player["heading"]):
		return _failure("INVALID_PLAYER_POSITION")
	var clock: Variant = data["clock"]
	if not _fields(clock, ["day", "minute"]):
		return _failure("INVALID_CLOCK")
	if not _whole(clock["day"], 1, MAX_DAY) or not _whole(clock["minute"], 0, 1439):
		return _failure("INVALID_CLOCK")
	var visited: Variant = data["visited"]
	if typeof(visited) != TYPE_ARRAY or visited.size() > _landmarks.size():
		return _failure("INVALID_VISITED")
	var seen: Dictionary = {}
	for landmark_id in visited:
		if not _reference(landmark_id, _landmarks) or seen.has(landmark_id):
			return _failure("INVALID_VISITED")
		seen[landmark_id] = true
	var carried: Variant = data["carried"]
	if typeof(carried) != TYPE_STRING or (carried != "" and not _objects.has(carried)):
		return _failure("INVALID_CARRIED_OBJECT")
	var object_states: Variant = data["objects"]
	if typeof(object_states) != TYPE_DICTIONARY or object_states.size() != _objects.size():
		return _failure("INVALID_OBJECT_STATES")
	var occupied: Dictionary = {}
	for object_id in _objects:
		if not object_states.has(object_id):
			return _failure("MISSING_OBJECT", object_id)
		var item: Variant = object_states[object_id]
		if not _fields(item, ["anchor_id", "quarter_turns"]) or not _whole(item["quarter_turns"], 0, 3):
			return _failure("INVALID_OBJECT_STATE", object_id)
		if typeof(item["anchor_id"]) != TYPE_STRING:
			return _failure("INVALID_ANCHOR", object_id)
		if object_id == carried:
			if item["anchor_id"] != "":
				return _failure("CARRIED_OBJECT_HAS_ANCHOR", object_id)
		else:
			if not _anchors.has(item["anchor_id"]):
				return _failure("INVALID_ANCHOR", object_id)
			if occupied.has(item["anchor_id"]):
				return _failure("ANCHOR_OCCUPIED", item["anchor_id"])
			occupied[item["anchor_id"]] = object_id
	# Deep copy, normalize JSON numbers, then commit once. Failures above never mutate live state.
	var staged: Dictionary = data.duplicate(true)
	staged["schema_version"] = SCHEMA
	staged["player"]["position"] = _float_vector(player["position"])
	staged["player"]["heading"] = float(player["heading"])
	staged["clock"] = {"day": int(clock["day"]), "minute": int(clock["minute"])}
	staged["visited"].sort()
	for object_id in _objects:
		staged["objects"][object_id]["quarter_turns"] = int(object_states[object_id]["quarter_turns"])
	_state = staged
	return _success("WORLD_RESTORED")


func _validate_atlas(data: Dictionary) -> Dictionary:
	if not _fields(data, ATLAS_FIELDS) or not _whole(data["schema_version"], SCHEMA, SCHEMA):
		return _failure("INVALID_ATLAS_FIELDS")
	var collections: Array = [
		["regions", REGION_FIELDS, 16], ["routes", ROUTE_FIELDS, 64],
		["anchors", ANCHOR_FIELDS, 128], ["objects", OBJECT_FIELDS, 32],
		["landmarks", LANDMARK_FIELDS, 128], ["npcs", NPC_FIELDS, 32]
	]
	for spec in collections:
		var issue: Dictionary = _validate_rows(data[spec[0]], spec[1], spec[2])
		if not issue["ok"]:
			return _failure("INVALID_ATLAS_COLLECTION", str(spec[0]) + ":" + issue["code"])
	var regions: Dictionary = _index(data["regions"])
	if regions.size() < 3 or not _reference(data["initial_region"], regions):
		return _failure("INVALID_INITIAL_REGION")
	if not _whole(data["initial_day"], 1, MAX_DAY) or not _whole(data["initial_minute"], 0, 1439):
		return _failure("INVALID_INITIAL_CLOCK")
	for region in regions.values():
		var bounds: Variant = region["bounds"]
		if not _fields(bounds, ["min", "max"]) or not _vector(bounds["min"]) or not _vector(bounds["max"]):
			return _failure("INVALID_REGION_BOUNDS", region["id"])
		for axis in range(3):
			if bounds["min"][axis] >= bounds["max"][axis]:
				return _failure("INVALID_REGION_BOUNDS", region["id"])
		if bounds["max"][0] - bounds["min"][0] != 64 or bounds["max"][2] - bounds["min"][2] != 64:
			return _failure("REGION_SIZE_MUST_BE_64", region["id"])
		if not _position_in(region["spawn"], region) or not _text(region["description"], 240):
			return _failure("INVALID_REGION", region["id"])
		if not _vector(region["color"], 0.0, 1.0):
			return _failure("INVALID_REGION_COLOR", region["id"])
	var routes: Dictionary = _index(data["routes"])
	var neighbors: Dictionary = {}
	for region_id in regions:
		neighbors[region_id] = []
	for route in routes.values():
		if not _reference(route["from"], regions) or not _reference(route["to"], regions) or route["from"] == route["to"]:
			return _failure("INVALID_ROUTE_REGION", route["id"])
		if not _position_in(route["exit"], regions[route["from"]]) or not _position_in(route["spawn"], regions[route["to"]]):
			return _failure("INVALID_ROUTE_POSITION", route["id"])
		if not _heading(route["spawn_heading"]) or not _whole(route["travel_minutes"], 1, 1440):
			return _failure("INVALID_ROUTE_TIMING", route["id"])
		if not _reference(route["reverse_id"], routes):
			return _failure("MISSING_REVERSE_ROUTE", route["id"])
		var reverse: Dictionary = routes[route["reverse_id"]]
		if reverse["reverse_id"] != route["id"] or reverse["from"] != route["to"] or reverse["to"] != route["from"]:
			return _failure("INVALID_REVERSE_ROUTE", route["id"])
		if not neighbors[route["from"]].has(route["to"]):
			neighbors[route["from"]].append(route["to"])
	var reached: Array = [data["initial_region"]]
	var cursor: int = 0
	while cursor < reached.size():
		for neighbor in neighbors[reached[cursor]]:
			if not reached.has(neighbor):
				reached.append(neighbor)
		cursor += 1
	if reached.size() != regions.size():
		return _failure("DISCONNECTED_WORLD")
	for region_id in neighbors:
		if neighbors[region_id].size() < 2:
			return _failure("REGION_REQUIRES_TWO_NEIGHBORS", region_id)
	var anchors: Dictionary = _index(data["anchors"])
	for anchor in anchors.values():
		if not _located(anchor, regions):
			return _failure("INVALID_ANCHOR_POSITION", anchor["id"])
	var occupied: Dictionary = {}
	for item in data["objects"]:
		if item["kind"] != "crate" or not _vector(item["size"], 0.1, 2.0):
			return _failure("INVALID_OBJECT_KIND_OR_SIZE", item["id"])
		if not _reference(item["initial_anchor"], anchors) or not _whole(item["initial_quarter_turns"], 0, 3):
			return _failure("INVALID_INITIAL_OBJECT", item["id"])
		if occupied.has(item["initial_anchor"]):
			return _failure("INITIAL_ANCHOR_OCCUPIED", item["initial_anchor"])
		occupied[item["initial_anchor"]] = item["id"]
	for landmark in data["landmarks"]:
		if not _located(landmark, regions) or not _number(landmark["radius"], 1.0, 8.0) or not _text(landmark["description"], 240):
			return _failure("INVALID_LANDMARK", landmark["id"])
	for npc in data["npcs"]:
		var schedule: Variant = npc["schedule"]
		if typeof(schedule) != TYPE_ARRAY or schedule.size() != 3:
			return _failure("INVALID_SCHEDULE", npc["id"])
		var expected_start: int = 0
		for period in schedule:
			if not _fields(period, PERIOD_FIELDS):
				return _failure("INVALID_SCHEDULE_PERIOD", npc["id"])
			if not _whole(period["start"], expected_start, expected_start) or not _whole(period["end"], expected_start + 1, 1440):
				return _failure("SCHEDULE_GAP_OR_OVERLAP", npc["id"])
			if not _located(period, regions) or not _heading(period["heading"]) or not _text(period["activity"], 160):
				return _failure("INVALID_SCHEDULE_LOCATION", npc["id"])
			expected_start = int(period["end"])
		if expected_start != 1440:
			return _failure("SCHEDULE_MUST_COVER_DAY", npc["id"])
	return _success("ATLAS_VALID")


func _validate_rows(value: Variant, fields: Array, limit: int) -> Dictionary:
	if typeof(value) != TYPE_ARRAY or value.is_empty() or value.size() > limit:
		return _failure("INVALID_COUNT")
	var seen: Dictionary = {}
	for row in value:
		if not _fields(row, fields):
			return _failure("INVALID_FIELDS")
		if not _identifier(row["id"]) or seen.has(row["id"]):
			return _failure("INVALID_OR_DUPLICATE_ID")
		if not _text(row["label"], 80):
			return _failure("INVALID_LABEL")
		seen[row["id"]] = true
	return _success("ROWS_VALID")


func _require_near(region_id: String, position: Array, radius: float) -> Dictionary:
	if _state["player"]["region"] != region_id:
		return _failure("WRONG_REGION")
	var player_position: Array = _state["player"]["position"]
	var distance_squared: float = 0.0
	for axis in range(3):
		distance_squared += pow(float(player_position[axis]) - float(position[axis]), 2.0)
	return _success("NEARBY") if distance_squared <= radius * radius else _failure("TOO_FAR")


func _occupant(anchor_id: String) -> String:
	for object_id in _state["objects"]:
		if _state["objects"][object_id]["anchor_id"] == anchor_id:
			return object_id
	return ""


func _advanced_clock(amount: int) -> Dictionary:
	var total: int = int(_state["clock"]["minute"]) + amount
	var day: int = int(_state["clock"]["day"]) + int(total / 1440)
	return {} if day > MAX_DAY else {"day": day, "minute": total % 1440}


func _fields(value: Variant, expected: Array) -> bool:
	return typeof(value) == TYPE_DICTIONARY and value.size() == expected.size() and value.has_all(expected)


func _number(value: Variant, minimum: float, maximum: float) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value)) and value >= minimum and value <= maximum


func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, float(minimum), float(maximum)) and float(value) == floor(float(value))


func _heading(value: Variant) -> bool:
	return _number(value, -PI, PI)


func _text(value: Variant, limit: int) -> bool:
	return typeof(value) == TYPE_STRING and not value.strip_edges().is_empty() and value.length() <= limit


func _identifier(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.is_empty() or value.length() > 64:
		return false
	for character in value:
		if not "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_".contains(character):
			return false
	return true


func _reference(value: Variant, index: Dictionary) -> bool:
	return typeof(value) == TYPE_STRING and index.has(value)


func _vector(value: Variant, minimum: float = -4096.0, maximum: float = 4096.0) -> bool:
	if typeof(value) != TYPE_ARRAY or value.size() != 3:
		return false
	for component in value:
		if not _number(component, minimum, maximum):
			return false
	return true


func _position_in(value: Variant, region: Dictionary) -> bool:
	if not _vector(value):
		return false
	for axis in range(3):
		if value[axis] < region["bounds"]["min"][axis] or value[axis] > region["bounds"]["max"][axis]:
			return false
	return true


func _located(value: Dictionary, regions: Dictionary) -> bool:
	return _reference(value["region"], regions) and _position_in(value["position"], regions[value["region"]])


func _float_vector(value: Array) -> Array:
	return [float(value[0]), float(value[1]), float(value[2])]


func _index(rows: Array) -> Dictionary:
	var indexed: Dictionary = {}
	for row in rows:
		indexed[row["id"]] = row
	return indexed


func _canonical_numbers(value: Variant) -> Variant:
	# Called only after bounded schema validation, never on arbitrary save data.
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for item in value:
			result.append(_canonical_numbers(item))
		return result
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		for key in value:
			result[key] = _canonical_numbers(value[key])
		return result
	return value


func _success(code: String) -> Dictionary:
	return {"ok": true, "code": code}


func _failure(code: String, detail: String = "") -> Dictionary:
	return {"ok": false, "code": code, "detail": detail}
