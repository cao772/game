extends RefCounted
## Read-only index of the atlas selected by the active regional scene.
const WorldState = preload("res://runtime/world_state.gd")

var regions: Dictionary = {}
var _anchors: Dictionary = {}
var _entries: Dictionary = {}

func configure(data: Dictionary) -> void:
	for region in data.regions:
		regions[region.id] = region.label
	for anchor in data.anchors:
		_anchors[anchor.id] = anchor
	for route in data.routes:
		_entries["route/" + route.id] = route
	for site in data.landmarks:
		_entries["site/" + site.id] = site
	for crate in data.objects:
		_entries["crate/" + crate.id] = crate

func point(key: String, state: Dictionary) -> Dictionary:
	if not _entries.has(key):
		return {}
	var raw: Dictionary = _entries[key]
	var kind := key.get_slice("/", 0)
	var row := {"key":key, "kind":kind, "name":raw.label, "held":false}
	var pos: Array
	var radius: float
	match kind:
		"route":
			row.region = raw["from"]
			row.detail = "%s → %s · 通行 %d 分钟" % [regions[row.region], regions[raw.to], raw.travel_minutes]
			pos = raw.exit
			radius = WorldState.ROUTE_RADIUS
		"site":
			if not state.visited.has(raw.id):
				return {}
			row.region = raw.region
			row.detail = raw.description
			pos = raw.position
			radius = raw.radius
		"crate":
			if state.carried == raw.id:
				row.region = state.player.region
				row.held = true
				row.detail = "随身携带 · 放到木台后，手图会再次标出箱位。"
				return row
			var anchor: Dictionary = _anchors[state.objects[raw.id].anchor_id]
			row.region = anchor.region
			row.detail = "%s · %s" % [regions[anchor.region], anchor.label]
			pos = anchor.position
			radius = WorldState.INTERACT_RADIUS
	_locate(row, pos, radius)
	return row

static func _locate(row: Dictionary, pos: Array, radius: float) -> void:
	row.position = Vector3(pos[0],pos[1],pos[2])
	row.radius = radius
	row.xz = Vector2(pos[0],pos[2])

func entries(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in _entries:
		var row := point(key, state)
		if not row.is_empty():
			result.append(row)
	return result

func leg(key: String, projection: Dictionary) -> Dictionary:
	var row := point(key, projection.state)
	if row.is_empty() or row.held:
		return row
	if row.region != projection.current_region.id:
		for route in projection.routes:
			if route.to == row.region:
				_locate(row, route.exit, WorldState.ROUTE_RADIUS)
				row.via = route.label
				row.minutes = route.travel_minutes
				return row
		return {}
	return row

static func directions(row: Dictionary, feet: Vector3) -> String:
	if row.is_empty():
		return ""
	if row.held:
		return "目的地 · %s（随身）" % row.name
	var delta: Vector2 = row.xz - Vector2(feet.x,feet.z)
	var name: String = row.name
	var kind: String = row.kind
	if row.has("via"):
		name += " · 先到「%s」" % row.via
		kind = "route"
	var where: String
	var target: Vector3 = row.position
	var horizontal := delta.length()
	if feet.distance_squared_to(target) <= row.radius * row.radius:
		where = {"route":"已到路口附近","site":"已在地标附近","crate":"已在木箱附近"}[kind]
	elif horizontal < 0.05:
		where = "%s · 水平 %.1f 米" % ["目标在上方" if target.y > feet.y else "目标在下方", horizontal]
	else:
		var compass := ["北","东北","东","东南","南","西南","西","西北"]
		var index := posmod(roundi(atan2(delta.x,-delta.y)/(PI/4.0)),8)
		where = "%s · 水平直线 %.1f 米" % [compass[index],horizontal]
	if row.has("via"):
		where += " · 通行 %d 分钟" % row.minutes
	return "目的地 · %s\n%s" % [name,where]
