extends Node3D
## A public wash/preparation stop. All state belongs to this street visit.
## The root owns input qualification and single-hand arbitration, never this scene.

const BASIN_SIZE := Vector3(0.60, 0.24, 0.45)
const ANCHORS := {
	"wash_sink": Vector3(-43.6, 0.85, 8.3),
	"wash_prep": Vector3(-39, 0.78, 11.2),
	"wash_drain": Vector3(-34.5, 0.85, 8.3),
}
const TARGETS := {
	"wash_sink": Vector3(-43.6, 1.20, 8.55),
	"wash_prep": Vector3(-39, 1.12, 11.55),
	"wash_drain": Vector3(-34.5, 1.20, 8.55),
}
const LABELS := {"wash_sink": "接水槽", "wash_prep": "择洗台", "wash_drain": "沥水台"}
const TAP_DURATION: float = 6.0
const FILL_DURATION: float = 2.0
const DRIP_DURATION: float = 3.0
const MAX_STEP: float = 0.1

var _materials: Dictionary = {}
var _font: Font
var _basin: Node3D
var _water_surface: Node3D
var _water_material: StandardMaterial3D
var _loose_produce: Node3D
var _sorted_produce: Node3D
var _scraps: Node3D
var _stream: Node3D
var _drips: Node3D
var _basin_anchor: String = "wash_sink"
var _water: String = "empty"
var _produce: String = "unwashed"
var _tap_remaining: float = 0.0
var _fill_contact_elapsed: float = 0.0
var _drip_remaining: float = 0.0
var _active: bool = true


func setup(materials: Dictionary, font: Font) -> void:
	_materials = materials.duplicate()
	_font = font
	for pair in [["basin", "9eaeb0"], ["fresh_leaf", "658343"], ["old_leaf", "8d7850"], ["sink_dark", "465b5b"]]:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(pair[1])
		material.roughness = 0.8
		_materials[pair[0]] = material
	_water_material = StandardMaterial3D.new()
	_water_material.albedo_color = Color("76b7c0")
	_water_material.roughness = 0.2
	_materials["basin_water"] = _water_material
	var flow_material := StandardMaterial3D.new()
	flow_material.albedo_color = Color("a8d3d4")
	flow_material.roughness = 0.2
	_materials["flow"] = flow_material
	_build_shelter()
	_build_stations()
	_build_basin()
	reset_visit()


func targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in ANCHORS:
		# Stations remain usable even when their basin slot is empty.
		result.append({"id": id, "label": LABELS[id], "position": to_global(TARGETS[id])})
	return result


func caption(id: String) -> String:
	match id:
		"wash_sink":
			return "关水（最多6秒自动停）" if _tap_remaining > 0.0 else "打开接水龙头"
		"wash_prep":
			return "择洗盆里的菜"
		"wash_drain":
			return "倒掉盆水，保留菜"
	return ""


func summary() -> String:
	var water_label: String = {"empty": "无水", "clean": "清水", "used": "用过的水"}[_water]
	var result: String = "公共盆：" + water_label + " · " + ("菜已择洗" if _produce == "washed" else "菜未择洗")
	if _tap_remaining > 0.0:
		result += " · 龙头出水中"
	if _basin_anchor == "wash_sink" and _water == "empty" and _tap_remaining > 0.0:
		result += " · 连续接水 %.1f/2秒" % _fill_contact_elapsed
	if _drip_remaining > 0.0:
		result += " · 沥水台还在滴水"
	return result


func is_carrying() -> bool:
	return _basin_anchor == "carried"


func has_basin(id: String) -> bool:
	return ANCHORS.has(id) and _basin_anchor == id


func take_basin(id: String, hands_occupied: bool) -> bool:
	if hands_occupied or not has_basin(id):
		return false
	_basin_anchor = "carried"
	_fill_contact_elapsed = 0.0
	# Same node, projected to the player's hold pose by the root immediately.
	_refresh()
	return true


func place_basin(id: String) -> bool:
	if not is_carrying() or not ANCHORS.has(id):
		return false
	_basin_anchor = id
	_fill_contact_elapsed = 0.0
	_basin.position = ANCHORS[id]
	_basin.rotation = Vector3.ZERO
	_refresh()
	return true


func use_station(id: String) -> String:
	match id:
		"wash_sink":
			if _tap_remaining > 0.0:
				_tap_remaining = 0.0
				_fill_contact_elapsed = 0.0
				_refresh()
				return "龙头已关，未接满的进度清零。" if _water == "empty" else "龙头已关。"
			_tap_remaining = TAP_DURATION
			_fill_contact_elapsed = 0.0
			_refresh()
			return "龙头打开了，最多出水6秒。空盆需在水槽连续接水2秒；用过的水要先去沥水台倒掉。"
		"wash_prep":
			if not has_basin(id):
				return "先把公共盆放到择洗台，再处理盆里的菜。"
			if _produce == "washed":
				return "这盆菜已经择洗好了，无需重复处理。"
			if _water != "clean":
				return "需要一盆清水：空盆先去接水，用过的水先去沥水台倒掉。"
			_produce = "washed"
			_water = "used"
			_refresh()
			return "菜已择洗归拢，水已用过；可以带到沥水台倒水。"
		"wash_drain":
			if not has_basin(id):
				return "先把公共盆放到沥水台，再倒水。"
			if _water == "empty":
				return "盆里已经没有水，菜的状态保持。"
			_water = "empty"
			_fill_contact_elapsed = 0.0
			_drip_remaining = DRIP_DURATION
			_refresh()
			return "水已倒掉，菜仍留在盆里；余水在沥水格下滴落。"
	return ""


func advance(delta: float, enabled: bool) -> void:
	_active = enabled
	if not enabled or delta <= 0.0 or not is_finite(delta):
		_refresh()
		return
	var step := minf(delta, MAX_STEP)
	# Only water actually emitted in this interval counts, including the last
	# fraction before auto-shutoff. No elapsed wall time or off-station credit.
	var flow_step := minf(step, _tap_remaining)
	if flow_step > 0.0 and _basin_anchor == "wash_sink" and _water == "empty":
		_fill_contact_elapsed = minf(FILL_DURATION, _fill_contact_elapsed + flow_step)
		if _fill_contact_elapsed >= FILL_DURATION:
			_water = "clean"
			_fill_contact_elapsed = 0.0
	else:
		_fill_contact_elapsed = 0.0
	_tap_remaining = maxf(0.0, _tap_remaining - step)
	if _tap_remaining <= 0.000001:
		_tap_remaining = 0.0
		_fill_contact_elapsed = 0.0
	_drip_remaining = maxf(0.0, _drip_remaining - step)
	_refresh()


func suspend_activity() -> void:
	# Pause presentation immediately; budgets and continuous-contact credit stay.
	_active = false
	_refresh()


func reset_visit() -> void:
	_basin_anchor = "wash_sink"
	_water = "empty"
	_produce = "unwashed"
	_tap_remaining = 0.0
	_fill_contact_elapsed = 0.0
	_drip_remaining = 0.0
	_active = true
	_basin.position = ANCHORS["wash_sink"]
	_basin.rotation = Vector3.ZERO
	_refresh()


func placement_occupied(id: String, feet: Vector3) -> bool:
	if not ANCHORS.has(id):
		return true
	var base: Vector3 = to_global(ANCHORS[id])
	return absf(feet.x - base.x) < BASIN_SIZE.x * 0.5 + 0.34 and absf(feet.z - base.z) < BASIN_SIZE.z * 0.5 + 0.34 and feet.y < base.y + BASIN_SIZE.y + 0.04 and feet.y + 1.75 > base.y


func present_carried(at: Vector3, yaw: float) -> void:
	if is_carrying():
		_basin.global_position = at
		_basin.global_rotation = Vector3(0, yaw, 0)


func _refresh() -> void:
	_water_surface.visible = _water != "empty"
	_water_material.albedo_color = Color("918770") if _water == "used" else Color("76b7c0")
	_loose_produce.visible = _produce == "unwashed"
	_sorted_produce.visible = _produce == "washed"
	_scraps.visible = _produce == "washed"
	_stream.visible = _active and _tap_remaining > 0.0
	# With no basin at the sink, the stream reaches the sink's inset instead.
	var lower: float = 1.0 if _basin_anchor == "wash_sink" else 0.865
	_stream.position.y = (1.43 + lower) * 0.5
	_stream.scale.y = 1.43 - lower
	_drips.visible = _active and _drip_remaining > 0.0


func _build_shelter() -> void:
	for x in [-45.6, -39.25, -32.9]:
		for z in [7.4, 14.1]:
			_box(Vector3(x, 1.4, z), Vector3(0.18, 2.8, 0.18), "metal", true)
	for z in [7.4, 14.1]:
		_box(Vector3(-39.25, 2.725, z), Vector3(13.5, 0.15, 0.18), "metal", true)
	_box(Vector3(-39.25, 2.87, 10.75), Vector3(13.5, 0.14, 7.5), "shop", true)
	_label("共享洗择棚", Vector3(-32.45, 2.4, 11.9), PI * 0.5, 0.005)
	_label("接水 · 择洗 · 沥水", Vector3(-42, 2.05, 7.55), 0, 0.003)


func _build_stations() -> void:
	_box(Vector3(-43, 0.425, 8.3), Vector3(3.6, 0.85, 1.0), "trim", true)
	_box(Vector3(-39, 0.39, 11.2), Vector3(2.6, 0.78, 1.2), "trim", true)
	_box(Vector3(-34.5, 0.425, 8.3), Vector3(2, 0.85, 1.0), "trim", true)
	# Visual recess/drainage only; the continuous support collision stays simple.
	_box(Vector3(-43.6, 0.856, 8.3), Vector3(0.9, 0.012, 0.7), "sink_dark")
	_box(Vector3(-43.6, 1.15, 7.99), Vector3(0.04, 0.6, 0.04), "metal")
	_box(Vector3(-43.6, 1.43, 8.15), Vector3(0.04, 0.04, 0.36), "metal")
	_stream = _box(Vector3(-43.6, 1.2, 8.3), Vector3(0.018, 1, 0.018), "flow")
	for x in [-35.1, -34.8, -34.5, -34.2, -33.9]:
		_box(Vector3(x, 0.86, 8.3), Vector3(0.035, 0.012, 0.7), "sink_dark")
	_drips = Node3D.new()
	_drips.position = Vector3(-34.5, 0.6, 8.84)
	add_child(_drips)
	for x in [-0.16, 0.0, 0.16]:
		_local_piece(_drips, Vector3(x, 0, 0), Vector3(0.012, 0.28, 0.012), "flow")
	_scraps = Node3D.new()
	_scraps.position = Vector3(-39.9, 0.792, 11.2)
	add_child(_scraps)
	for index in range(3):
		_local_piece(_scraps, Vector3(index * 0.12, 0, (index % 2) * 0.07), Vector3(0.09, 0.015, 0.05), "old_leaf")
	_label("接水槽", Vector3(-43.6, 1.5, 7.9), 0, 0.0025)
	_label("择洗台", Vector3(-39, 1.4, 10.7), 0, 0.0025)
	_label("沥水台", Vector3(-34.5, 1.5, 7.9), 0, 0.0025)


func _build_basin() -> void:
	_basin = Node3D.new()
	_basin.name = "UniquePublicBasin"
	add_child(_basin)
	_local_piece(_basin, Vector3(0, 0.015, 0), Vector3(0.60, 0.03, 0.45), "basin")
	for x in [-0.285, 0.285]:
		_local_piece(_basin, Vector3(x, 0.135, 0), Vector3(0.03, 0.21, 0.45), "basin")
	for z in [-0.21, 0.21]:
		_local_piece(_basin, Vector3(0, 0.135, z), Vector3(0.54, 0.21, 0.03), "basin")
	_water_surface = _local_piece(_basin, Vector3(0, 0.13, 0), Vector3(0.54, 0.008, 0.39), "basin_water")
	_loose_produce = Node3D.new()
	_sorted_produce = Node3D.new()
	_basin.add_child(_loose_produce)
	_basin.add_child(_sorted_produce)
	for index in range(4):
		_local_piece(_loose_produce, Vector3(-0.18 + index * 0.11, 0.155, -0.07 + (index % 2) * 0.11), Vector3(0.09, 0.035, 0.14), "fresh_leaf")
		_local_piece(_loose_produce, Vector3(-0.15 + index * 0.09, 0.19, 0.03), Vector3(0.05, 0.012, 0.06), "old_leaf")
		_local_piece(_sorted_produce, Vector3(-0.15 + index * 0.1, 0.155, 0), Vector3(0.085, 0.04, 0.18), "fresh_leaf")


func _local_piece(parent: Node3D, at: Vector3, size: Vector3, material: String) -> Node3D:
	var piece := _box(at, size, material)
	remove_child(piece)
	parent.add_child(piece)
	return piece


func _label(text: String, at: Vector3, yaw: float, pixel: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = _font
	label.font_size = 40
	label.pixel_size = pixel
	label.outline_size = 0
	label.modulate = Color("f0ead7")
	label.position = at
	label.rotation.y = yaw
	add_child(label)


func _box(at: Vector3, size: Vector3, material: String, solid: bool = false) -> Node3D:
	var piece: Node3D = StaticBody3D.new() if solid else Node3D.new()
	piece.position = at
	add_child(piece)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = _materials[material]
	piece.add_child(visual)
	if solid:
		var body := piece as StaticBody3D
		body.collision_layer = 1
		body.collision_mask = 2 | 4
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
	return piece
