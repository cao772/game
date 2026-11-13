extends RefCounted
## Deterministic daily projection, independent of saves and the world-state hash.
## Same-region edges share an XYZ endpoint. Portal edges match raw atlas exit/spawn
## in all three axes before their player-entry Y clearance is lowered to ground Y.
## No elapsed-time state, file access, scene nodes or random values.
## Source/grammar review only; engine and gameplay acceptance NOT_RUN.

const Delivery = preload("res://runtime/shore_delivery.gd")
const Shore = preload("res://runtime/shore_water.gd")

const MAX_DAY := 1000000
const MAX_SEGMENTS := 32
const MAX_POINTS := 32
const EPSILON := 0.00001
const RESIDENT_IDS := ["merchant", "courier"]
const DATA_FIELDS := ["schema_version", "portal_ground_y", "residents"]
const STAY_FIELDS := ["start", "end", "station"]
const WALK_FIELDS := ["start", "end", "region", "points", "activity", "destination", "next_route"]
const REGION_FIELDS := ["id", "label", "description", "color", "bounds", "spawn"]
const ROUTE_FIELDS := ["id", "reverse_id", "from", "to", "exit", "spawn", "spawn_heading", "travel_minutes", "label"]
const PERIOD_FIELDS := ["start", "end", "region", "position", "heading", "activity"]

var _residents: Array = []
var _region_labels: Dictionary = {}


func configure(atlas: Dictionary, route_data: Dictionary) -> Dictionary:
	if not _residents.is_empty():
		return _failure("ALREADY_CONFIGURED")
	var source: Dictionary = _atlas_context(atlas)
	if not source["ok"]:
		return source
	if not _fields(route_data, DATA_FIELDS) or not _whole(route_data["schema_version"], 1, 1):
		return _failure("INVALID_ROUTE_DATA")
	# This schema targets the three existing flat road planes, not the lookout ramp.
	if not _number(route_data["portal_ground_y"], 0.0, 0.0):
		return _failure("UNSUPPORTED_PORTAL_GROUND")
	var rows: Variant = route_data["residents"]
	if typeof(rows) != TYPE_ARRAY or rows.size() != RESIDENT_IDS.size():
		return _failure("INVALID_RESIDENT_COUNT")
	var regions: Dictionary = source["regions"]
	var routes: Dictionary = source["routes"]
	var npcs: Dictionary = source["npcs"]
	var staged: Array = []
	var seen: Dictionary = {}
	for row in rows:
		if not _fields(row, ["id", "segments"]) or typeof(row["id"]) != TYPE_STRING:
			return _failure("INVALID_RESIDENT_FIELDS")
		var id: String = row["id"]
		if not RESIDENT_IDS.has(id) or seen.has(id):
			return _failure("INVALID_OR_DUPLICATE_RESIDENT", id)
		seen[id] = true
		var segments: Variant = row["segments"]
		if typeof(segments) != TYPE_ARRAY or segments.size() < 2 or segments.size() > MAX_SEGMENTS:
			return _failure("INVALID_SEGMENT_COUNT", id)
		var expanded: Array = []
		var dock_index := -1
		var expected_start: int = 0
		for segment in segments:
			var source_segment: Variant = segment
			if segment is Dictionary and segment.has("dock_round"):
				if dock_index >= 0 or id != "courier" or not _fields(segment, ["start", "end", "station", "dock_round"]):
					return _failure("INVALID_DOCK_ROUND", id)
				if typeof(segment.dock_round) != TYPE_BOOL or not segment.dock_round:
					return _failure("INVALID_DOCK_ROUND", id)
				source_segment = segment.duplicate()
				source_segment.erase("dock_round")
				dock_index = expanded.size()
			var parsed: Dictionary = _expand_segment(source_segment, npcs[id], regions, routes, expected_start)
			if not parsed["ok"]:
				return _failure(parsed["code"], id + "/" + str(expanded.size()))
			var item: Dictionary = parsed["segment"]
			expected_start = item["end"]
			expanded.append(item)
		if expected_start != 1440:
			return _failure("DAY_NOT_COVERED", id)
		var timelines := [expanded]
		if dock_index >= 0:
			var stay: Dictionary = expanded[dock_index]
			if stay.region != "SHORE" or stay.start >= Delivery.DEPART or stay.end <= Delivery.LAST_RETURN:
				return _failure("INVALID_DOCK_SHIFT", id)
			timelines.clear()
			for low in [false, true]:
				var timeline := expanded.slice(0, dock_index, 1, true)
				timeline.append_array(Delivery.timetable(stay, low))
				timeline.append_array(expanded.slice(dock_index + 1, expanded.size(), 1, true))
				timelines.append(timeline)
		for timeline in timelines:
			var checked := _prepare_day(timeline, routes, npcs[id], regions, float(route_data["portal_ground_y"]))
			if not checked["ok"]:
				return _failure(checked["code"], id + "/" + str(checked.get("detail", "")))
		staged.append({"id": id, "label": npcs[id]["label"], "timelines": timelines})
	var labels: Dictionary = {}
	for id in regions:
		labels[id] = regions[id]["label"]
	# No caller-owned dictionaries survive the successful configuration.
	_region_labels = labels
	_residents = staged
	return {"ok": true, "code": "RESIDENT_SCHEDULE_CONFIGURED"}


func _prepare_day(timeline: Array, routes: Dictionary, npc: Dictionary, regions: Dictionary, ground_y: float) -> Dictionary:
	var edges: Dictionary = _validate_edges(timeline, routes)
	if not edges["ok"]:
		return edges
	# Preserve the original midnight, 08:00 and 17:00 activity anchors exactly.
	for station in range(3):
		var period: Dictionary = npc["schedule"][station]
		var active: Dictionary = _at_minute(timeline, float(period["start"]))
		if active["points"].size() != 1 or active["region"] != period["region"] or not _same(active["points"][0], period["position"]):
			return _failure("ORIGINAL_STATION_NOT_COVERED", str(station))
	# All raw XYZ edge checks are complete before lowering portal foot positions.
	for index in range(timeline.size()):
		var current: Dictionary = timeline[index]
		if current["next_route"] != "":
			current["points"][-1][1] = ground_y
			var following: Dictionary = timeline[(index + 1) % timeline.size()]
			following["points"][0][1] = ground_y
	for item in timeline:
		if item.has("delivery_phase"):
			for point in item.points:
				if not _position_in(point, regions[item.region]):
					return _failure("INVALID_PATH_POSITION")
		var built: Dictionary = _compile_path(item)
		if not built["ok"]:
			return built
	return {"ok": true}


func project(day: int, minute: float) -> Dictionary:
	if _residents.is_empty():
		return _failure("NOT_CONFIGURED")
	if day < 1 or day > MAX_DAY or not _number(minute, 0.0, 1440.0):
		return _failure("INVALID_CLOCK")
	if minute == 1440.0:
		if day == MAX_DAY:
			return _failure("CLOCK_LIMIT")
		day += 1
		minute = 0.0
	var projected: Array = []
	for resident in _residents:
		var timelines: Array = resident["timelines"]
		var segments: Array = timelines[1] if timelines.size() == 2 and Shore.is_low(day) else timelines[0]
		var index: int = 0
		while minute >= segments[index]["end"]:
			index += 1
		var active: Dictionary = segments[index]
		var moving: bool = active["points"].size() > 1
		var progress: float = (minute - float(active["start"])) / float(active["end"] - active["start"])
		var pose: Dictionary = _pose(active, progress)
		var destination: String = active["destination"]
		var stop: String = active.get("stop_label", _region_labels[destination])
		var next_route: String = active["next_route"]
		var departure: float = 0.0
		if not moving:
			# Validation requires moving segments, so this bounded scan always finds one.
			for step in range(1, segments.size() + 1):
				var next_index: int = (index + step) % segments.size()
				var next_segment: Dictionary = segments[next_index]
				if next_segment["points"].size() > 1:
					destination = next_segment["destination"]
					stop = next_segment.get("stop_label", _region_labels[destination])
					next_route = next_segment["next_route"]
					departure = float(next_segment["start"]) - minute
					if next_index <= index:
						departure += 1440.0
					break
		projected.append({
			"id": resident["id"], "label": resident["label"], "region": active["region"],
			"position": pose["position"], "heading": pose["heading"], "moving": moving,
			"activity": active["activity"], "destination_region": destination,
			"destination": stop, "next_route": next_route, "delivery_phase": active.get("delivery_phase", ""),
			"departure_in_minutes": departure, "segment_start": active["start"],
			"segment_end": active["end"], "progress": progress
		})
	return {"ok": true, "code": "RESIDENTS_PROJECTED", "day": day, "minute": minute, "residents": projected}


func _expand_segment(value: Variant, npc: Dictionary, regions: Dictionary, routes: Dictionary, expected_start: int) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("INVALID_SEGMENT")
	var staying: bool = value.has("station")
	if not _fields(value, STAY_FIELDS if staying else WALK_FIELDS):
		return _failure("INVALID_SEGMENT_FIELDS")
	if not _whole(value["start"], expected_start, expected_start) or not _whole(value["end"], expected_start + 1, 1440):
		return _failure("TIMELINE_GAP_OR_OVERLAP")
	var expanded: Dictionary = {"start": int(value["start"]), "end": int(value["end"])}
	if staying:
		if not _whole(value["station"], 0, 2):
			return _failure("UNKNOWN_STATION")
		var station: Dictionary = npc["schedule"][int(value["station"])]
		expanded.merge({
			"region": station["region"], "points": [station["position"].duplicate()],
			"heading": float(station["heading"]), "activity": station["activity"],
			"destination": station["region"], "next_route": ""
		})
	else:
		if not _reference(value["region"], regions) or not _reference(value["destination"], regions):
			return _failure("UNKNOWN_REGION")
		if not _text(value["activity"], 160) or typeof(value["next_route"]) != TYPE_STRING:
			return _failure("INVALID_WALK_FIELDS")
		if value["next_route"] != "" and not _reference(value["next_route"], routes):
			return _failure("UNKNOWN_ROUTE")
		var points: Variant = value["points"]
		if typeof(points) != TYPE_ARRAY or points.size() < 2 or points.size() > MAX_POINTS:
			return _failure("INVALID_POINT_COUNT")
		for point in points:
			if not _position_in(point, regions[value["region"]]):
				return _failure("INVALID_PATH_POSITION")
		expanded.merge({
			"region": value["region"], "points": points.duplicate(true), "heading": 0.0,
			"activity": value["activity"], "destination": value["destination"], "next_route": value["next_route"]
		})
	return {"ok": true, "segment": expanded}


func _validate_edges(segments: Array, routes: Dictionary) -> Dictionary:
	var has_walk: bool = false
	for index in range(segments.size()):
		var current: Dictionary = segments[index]
		var following: Dictionary = segments[(index + 1) % segments.size()]
		has_walk = has_walk or current["points"].size() > 1
		if current["region"] == following["region"]:
			if current["next_route"] != "" or not _same(current["points"][-1], following["points"][0]):
				return _failure("DISCONTINUOUS_LOCAL_PATH", str(index))
		else:
			if not routes.has(current["next_route"]):
				return _failure("PORTAL_ROUTE_REQUIRED", str(index))
			var route: Dictionary = routes[current["next_route"]]
			if route["from"] != current["region"] or route["to"] != following["region"]:
				return _failure("PORTAL_REGION_MISMATCH", str(index))
			if current["points"].size() < 2 or following["points"].size() < 2:
				return _failure("PORTAL_REQUIRES_WALK", str(index))
			if not _same(current["points"][-1], route["exit"]) or not _same(following["points"][0], route["spawn"]):
				return _failure("PORTAL_POSITION_MISMATCH", str(index))
		# A final destination must be reached along this outing before another rest.
		if current["points"].size() > 1:
			if following["points"].size() > 1 and following["destination"] != current["destination"]:
				return _failure("OUTING_DESTINATION_CHANGED", str(index))
			if following["points"].size() == 1 and current["destination"] != following["region"]:
				return _failure("OUTING_DESTINATION_NOT_REACHED", str(index))
	return {"ok": true} if has_walk else _failure("WALK_REQUIRED")


func _compile_path(segment: Dictionary) -> Dictionary:
	var points: Array = segment["points"]
	var distances: Array = [0.0]
	var total: float = 0.0
	for index in range(1, points.size()):
		var difference: Vector3 = _vector(points[index]) - _vector(points[index - 1])
		# Consecutive identical points and purely vertical travel have no walk heading.
		if Vector2(difference.x, difference.z).length() <= EPSILON:
			return _failure("DEGENERATE_PATH_EDGE")
		total += difference.length()
		distances.append(total)
	segment["distances"] = distances
	segment["length"] = total
	return {"ok": true}


func _pose(segment: Dictionary, progress: float) -> Dictionary:
	var points: Array = segment["points"]
	if points.size() == 1:
		return {"position": points[0].duplicate(), "heading": segment["heading"]}
	var target: float = progress * float(segment["length"])
	var distances: Array = segment["distances"]
	for index in range(1, points.size()):
		if target < float(distances[index]) or index == points.size() - 1:
			var start: Vector3 = _vector(points[index - 1])
			var finish: Vector3 = _vector(points[index])
			var fraction: float = (target - float(distances[index - 1])) / float(distances[index] - distances[index - 1])
			var position: Vector3 = start.lerp(finish, clampf(fraction, 0.0, 1.0))
			var direction: Vector3 = finish - start
			return {"position": [position.x, position.y, position.z], "heading": atan2(direction.x, direction.z)}
	return {} # Unreachable for a compiled path with at least two points.


func _atlas_context(atlas: Dictionary) -> Dictionary:
	# Only the three source sections used by projection are copied. Existing atlas
	# fields for objects, discoveries and saves remain owned by WorldState.
	if not atlas.has_all(["schema_version", "regions", "routes", "npcs"]) or not _whole(atlas["schema_version"], 1, 1):
		return _failure("INVALID_ATLAS")
	var regions_result: Dictionary = _index_rows(atlas["regions"], REGION_FIELDS, 16)
	var routes_result: Dictionary = _index_rows(atlas["routes"], ROUTE_FIELDS, 64)
	var npcs_result: Dictionary = _index_rows(atlas["npcs"], ["id", "label", "schedule"], 2)
	if not regions_result["ok"] or not routes_result["ok"] or not npcs_result["ok"]:
		return _failure("INVALID_ATLAS_COLLECTION")
	var regions: Dictionary = regions_result["rows"]
	var routes: Dictionary = routes_result["rows"]
	var npcs: Dictionary = npcs_result["rows"]
	if npcs.size() != 2 or not npcs.has_all(RESIDENT_IDS):
		return _failure("ATLAS_RESIDENTS_MISMATCH")
	for region in regions.values():
		if not _fields(region["bounds"], ["min", "max"]) or not _point(region["bounds"]["min"]) or not _point(region["bounds"]["max"]):
			return _failure("INVALID_ATLAS_BOUNDS")
		for axis in range(3):
			if region["bounds"]["min"][axis] >= region["bounds"]["max"][axis]:
				return _failure("INVALID_ATLAS_BOUNDS")
		if region["bounds"]["min"][1] > 0.0 or region["bounds"]["max"][1] < 0.0:
			return _failure("PORTAL_GROUND_OUT_OF_BOUNDS")
		if not _position_in(region["spawn"], region) or not _text(region["description"], 240) or not _point(region["color"], 0.0, 1.0):
			return _failure("INVALID_ATLAS_REGION")
	for route in routes.values():
		if not _reference(route["from"], regions) or not _reference(route["to"], regions) or route["from"] == route["to"]:
			return _failure("INVALID_ATLAS_ROUTE_REGION")
		if not _position_in(route["exit"], regions[route["from"]]) or not _position_in(route["spawn"], regions[route["to"]]):
			return _failure("INVALID_ATLAS_PORTAL")
		if not _number(route["spawn_heading"], -PI, PI) or not _whole(route["travel_minutes"], 1, 1440) or not _reference(route["reverse_id"], routes):
			return _failure("INVALID_ATLAS_ROUTE")
		var reverse: Dictionary = routes[route["reverse_id"]]
		if reverse["from"] != route["to"] or reverse["to"] != route["from"] or reverse["reverse_id"] != route["id"]:
			return _failure("INVALID_ATLAS_REVERSE_ROUTE")
	for npc in npcs.values():
		var schedule: Variant = npc["schedule"]
		if typeof(schedule) != TYPE_ARRAY or schedule.size() != 3:
			return _failure("INVALID_ATLAS_STATIONS")
		var dock_index := -1
		var expected_start: int = 0
		for period in schedule:
			if not _fields(period, PERIOD_FIELDS):
				return _failure("INVALID_ATLAS_STATION_FIELDS")
			if not _whole(period["start"], expected_start, expected_start) or not _whole(period["end"], expected_start + 1, 1440):
				return _failure("INVALID_ATLAS_STATION_TIME")
			if not _reference(period["region"], regions) or not _position_in(period["position"], regions[period["region"]]):
				return _failure("INVALID_ATLAS_STATION_POSITION")
			if not _number(period["heading"], -PI, PI) or not _text(period["activity"], 160):
				return _failure("INVALID_ATLAS_STATION")
			expected_start = int(period["end"])
		if expected_start != 1440:
			return _failure("INVALID_ATLAS_STATION_COVERAGE")
	return {"ok": true, "regions": regions, "routes": routes, "npcs": npcs}


func _index_rows(value: Variant, fields: Array, limit: int) -> Dictionary:
	if typeof(value) != TYPE_ARRAY or value.is_empty() or value.size() > limit:
		return _failure("INVALID_COUNT")
	var indexed: Dictionary = {}
	for row in value:
		if not _fields(row, fields) or not _identifier(row["id"]) or not _text(row["label"], 80):
			return _failure("INVALID_FIELDS")
		if indexed.has(row["id"]):
			return _failure("DUPLICATE_ID")
		indexed[row["id"]] = row
	return {"ok": true, "rows": indexed}


func _at_minute(segments: Array, minute: float) -> Dictionary:
	for segment in segments:
		if minute >= segment["start"] and minute < segment["end"]:
			return segment
	return {}


func _fields(value: Variant, expected: Array) -> bool:
	return typeof(value) == TYPE_DICTIONARY and value.size() == expected.size() and value.has_all(expected)


func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and value >= minimum and value <= maximum


func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, float(minimum), float(maximum)) and float(value) == floor(float(value))


func _text(value: Variant, limit: int) -> bool:
	return typeof(value) == TYPE_STRING and not value.strip_edges().is_empty() and value.length() <= limit


func _identifier(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.is_empty() or value.length() > 64:
		return false
	for character in value:
		if not "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_".contains(character):
			return false
	return true


func _reference(value: Variant, items: Dictionary) -> bool:
	return typeof(value) == TYPE_STRING and items.has(value)


func _point(value: Variant, minimum: float = -4096.0, maximum: float = 4096.0) -> bool:
	if typeof(value) != TYPE_ARRAY or value.size() != 3:
		return false
	for component in value:
		if not _number(component, minimum, maximum):
			return false
	return true


func _position_in(value: Variant, region: Dictionary) -> bool:
	if not _point(value):
		return false
	for axis in range(3):
		if value[axis] < region["bounds"]["min"][axis] or value[axis] > region["bounds"]["max"][axis]:
			return false
	return true


func _same(left: Array, right: Array) -> bool:
	for axis in range(3):
		if absf(float(left[axis]) - float(right[axis])) > EPSILON:
			return false
	return true


func _vector(point: Array) -> Vector3:
	return Vector3(float(point[0]), float(point[1]), float(point[2]))


func _failure(code: String, detail: String = "") -> Dictionary:
	return {"ok": false, "code": code, "detail": detail}
