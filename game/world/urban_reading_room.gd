extends Node3D
## A ground-floor public passage and optional reading stop. Scene-local state only.
## All coordinates share modern_street's origin; no quest or save-store ownership.

const SEAT_FEET := Vector3(-21, 0, 20.8)
const SEAT_TARGET := Vector3(-21, 0.75, 20)
const STAND_POINTS := [Vector3(-21, 0, 19.45), Vector3(-22, 0, 19.45), Vector3(-20, 0, 19.45)]
const TRAY_SIZE := Vector3(0.62, 0.12, 0.42)
const TRAY_ANCHORS := {
	"reading_book": Vector3(-21.4, 0.76, 10.1),
	"reading_side": Vector3(-19.5, 0.58, 20.5),
	"reading_porch": Vector3(-13.35, 0.82, 17.4),
}
const TRAY_LABELS := {"reading_book": "阅览台", "reading_side": "长椅旁低台", "reading_porch": "前廊窄台"}
const PAGES := [
	["01 · 两条走法", "从临街门进来，穿过书架两侧都能到后巷。\n不想进屋，也可以沿外廊绕过楼角。"],
	["02 · 留一条路", "看完把书留在台上，后来的人也能翻。\n门口和书架两边留空，赶路的人就不用打断谁。"],
	["03 · 坐一会儿", "后门边有张长椅。\n没有要办的事，也可以坐着看看巷子。"],
]

var _materials: Dictionary = {}
var _font: Font
var _page_label: Label3D
var _bookmark: Node3D
var _lamp: OmniLight3D
var _bulb_material: StandardMaterial3D
var _page_index: int = -1
var _lamp_on: bool = true
var _tray: Node3D
var _tray_anchor: String = "reading_book"


func setup(materials: Dictionary, font: Font) -> void:
	_materials = materials.duplicate()
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.55, 0.70, 0.72, 0.20)
	glass.roughness = 0.22
	_materials["reading_glass"] = glass
	_font = font
	_build_shell()
	_build_furniture()
	_build_reading_desk()
	_build_seat()
	reset_visit()


func targets() -> Array[Dictionary]:
	var standing: Array[Vector3] = []
	for point in STAND_POINTS:
		standing.append(to_global(point))
	var result: Array[Dictionary] = [
		{"id": "reading_lamp", "label": "阅览灯", "position": to_global(Vector3(-14.5, 1.35, 13.4))},
		{"id": "reading_seat", "label": "阅览室长椅", "position": to_global(SEAT_TARGET),
			"feet": to_global(SEAT_FEET), "yaw": global_rotation.y, "stand_candidates": standing},
	]
	for id in TRAY_ANCHORS:
		if is_carrying() or _tray_anchor == id:
			result.append({"id": id, "label": TRAY_LABELS[id], "position": to_global(TRAY_ANCHORS[id] + Vector3(0, 0.18, 0))})
	return result


func caption(id: String) -> String:
	if TRAY_ANCHORS.has(id):
		if is_carrying():
			return "把书盘放到" + str(TRAY_LABELS[id])
		return "翻阅公共册"
	match id:
		"reading_lamp":
			return "关掉阅览灯" if _lamp_on else "打开阅览灯"
		"reading_seat":
			return "坐在阅览室长椅上"
	return ""


func turn_page() -> String:
	_page_index = (_page_index + 1) % PAGES.size()
	_update_page()
	return str(PAGES[_page_index][0]) + "\n" + str(PAGES[_page_index][1])


func toggle_lamp() -> String:
	_lamp_on = not _lamp_on
	_update_light()
	return "阅览灯亮了。" if _lamp_on else "阅览灯关了；仍可借日光翻书。"


func reset_visit() -> void:
	# Called only on construction or successful layout restore, never on failed or
	# cancelled restore. The five-field urban save remains byte-for-byte compatible.
	_tray_anchor = "reading_book"
	_project_tray()
	_page_index = -1
	_lamp_on = true
	_update_page()
	_update_light()


func is_carrying() -> bool:
	return _tray_anchor == "carried"


func has_tray(id: String) -> bool:
	return TRAY_ANCHORS.has(id) and _tray_anchor == id


func take_tray(id: String, toolbox_carried: bool) -> bool:
	if toolbox_carried or not has_tray(id):
		return false
	_tray_anchor = "carried"
	# Root places this same node at the hands immediately; there is no clone.
	return true


func place_tray(id: String) -> bool:
	if not is_carrying() or not TRAY_ANCHORS.has(id):
		return false
	_tray_anchor = id
	_project_tray()
	return true


func placement_occupied(id: String, feet: Vector3) -> bool:
	if not TRAY_ANCHORS.has(id):
		return true
	var base: Vector3 = to_global(TRAY_ANCHORS[id])
	return absf(feet.x - base.x) < TRAY_SIZE.x * 0.5 + 0.34 and absf(feet.z - base.z) < TRAY_SIZE.z * 0.5 + 0.34 and feet.y < base.y + TRAY_SIZE.y + 0.04 and feet.y + 1.75 > base.y


func present_carried(at: Vector3, yaw: float) -> void:
	if is_carrying():
		_tray.global_position = at
		_tray.global_rotation = Vector3(0, yaw, 0)


func _project_tray() -> void:
	if TRAY_ANCHORS.has(_tray_anchor):
		_tray.position = TRAY_ANCHORS[_tray_anchor]
		_tray.rotation = Vector3.ZERO


func _build_tray() -> void:
	_tray = Node3D.new()
	_tray.name = "UniqueReadingTray"
	add_child(_tray)
	# Build existing helpers at local offsets, then transfer each visual into the
	# tray without keeping its old global transform. No physics body moves here.
	_tray_piece(Vector3(0, 0.025, 0), Vector3(0.62, 0.05, 0.42), "shop")
	_tray_piece(Vector3(0, 0.065, 0), Vector3(0.56, 0.03, 0.36), "paint")
	for x in [-0.30, 0.30]:
		_tray_piece(Vector3(x, 0.07, 0), Vector3(0.02, 0.09, 0.42), "shop")
	for z in [-0.20, 0.20]:
		_tray_piece(Vector3(0, 0.07, z), Vector3(0.58, 0.09, 0.02), "shop")
	_page_label = _label("", Vector3(0, 0.085, 0), 0, 0.0012)
	remove_child(_page_label)
	_tray.add_child(_page_label)
	_page_label.rotation.x = -PI * 0.5
	_bookmark = _tray_piece(Vector3(-0.22, 0.10, 0.13), Vector3(0.025, 0.02, 0.16), "metal")


func _tray_piece(at: Vector3, size: Vector3, material: String) -> Node3D:
	var piece := _box(at, size, material)
	remove_child(piece)
	_tray.add_child(piece)
	return piece


func _update_page() -> void:
	_page_label.text = "街角阅览册\n随手翻阅" if _page_index < 0 else str(PAGES[_page_index][0])
	_bookmark.position.x = -0.22 + float(_page_index + 1) * 0.11


func _update_light() -> void:
	_lamp.visible = _lamp_on
	_bulb_material.emission_enabled = _lamp_on
	_bulb_material.albedo_color = Color("fff0c4") if _lamp_on else Color("8b8b81")


func _build_shell() -> void:
	# Replace only the west/south block's ground fill. Existing upper slab begins
	# at y3. Doors are always open, 2.4m wide, with 2.5m clearance and zero threshold.
	_box(Vector3(-19.1, 1.5, 7.15), Vector3(9.8, 3, 0.3), "concrete", true)
	_box(Vector3(-19.1, 1.5, 27.85), Vector3(9.8, 3, 0.3), "concrete", true)
	# Front opening z10.1..12.5; rear opening z22.8..25.2.
	_box(Vector3(-14.2, 1.5, 8.55), Vector3(0.3, 3, 3.1), "concrete", true)
	_box(Vector3(-14.2, 1.5, 20.25), Vector3(0.3, 3, 15.5), "concrete", true)
	_box(Vector3(-14.2, 2.75, 11.3), Vector3(0.3, 0.5, 2.4), "concrete", true)
	# A closed rear window gives the seat an alley view without another exit.
	_box(Vector3(-24, 1.5, 12.9), Vector3(0.3, 3, 11.8), "concrete", true)
	_box(Vector3(-24, 0.5, 20.3), Vector3(0.3, 1.0, 3.0), "concrete", true)
	_box(Vector3(-24, 2.7, 20.3), Vector3(0.3, 0.6, 3.0), "concrete", true)
	_box(Vector3(-24, 1.7, 20.3), Vector3(0.08, 1.4, 3.0), "reading_glass", true)
	_box(Vector3(-24, 1.7, 20.3), Vector3(0.12, 1.4, 0.05), "frame")
	_box(Vector3(-24, 1.5, 22.3), Vector3(0.3, 3, 1.0), "concrete", true)
	_box(Vector3(-24, 1.5, 26.6), Vector3(0.3, 3, 2.8), "concrete", true)
	_box(Vector3(-24, 2.75, 24), Vector3(0.3, 0.5, 2.4), "concrete", true)
	# No raised floor: keep the street's existing y0 collision support.
	_box(Vector3(-14.01, 2.65, 11.3), Vector3(0.08, 0.4, 3.6), "shop")
	_label("共享阅览室", Vector3(-13.95, 2.65, 11.3), PI * 0.5, 0.005)
	_label("后巷 · 可通行", Vector3(-23.8, 2.55, 24), PI * 0.5, 0.004)
	_label("共享阅览室", Vector3(-24.2, 2.55, 24), -PI * 0.5, 0.004)


func _build_furniture() -> void:
	# A low island leaves sightlines above it and two independent walkable sides.
	_box(Vector3(-19.1, 0.65, 16.5), Vector3(1.0, 1.3, 4), "shop", true)
	for z in [15.1, 16.3, 17.5]:
		for side in [-1.0, 1.0]:
			for book in range(4):
				_box(Vector3(-19.1 + side * 0.51, 0.85, z + book * 0.18), Vector3(0.035, 0.35, 0.12), "paint" if book % 2 == 0 else "trim")
	# Wall shelf is a static furnishing; books aren't additional inventory items.
	_box(Vector3(-18, 0.9, 7.65), Vector3(3, 1.8, 0.5), "shop", true)
	for x in [-19.1, -18.5, -17.9, -17.3]:
		_box(Vector3(x, 1.2, 7.94), Vector3(0.3, 0.4, 0.04), "paint")


func _build_reading_desk() -> void:
	_box(Vector3(-21.4, 0.38, 10), Vector3(2.2, 0.76, 1.0), "trim", true)
	# Two extra supports stay outside the west through-route and all stand paths.
	_box(Vector3(-19.5, 0.29, 20.5), Vector3(0.80, 0.58, 0.60), "trim", true)
	_box(Vector3(-13.35, 0.41, 17.4), Vector3(0.80, 0.82, 0.65), "trim", true)
	_build_tray()
	_box(Vector3(-14.39, 1.35, 13.4), Vector3(0.08, 0.18, 0.14), "frame")
	_label("阅览灯", Vector3(-14.41, 1.6, 13.4), -PI * 0.5, 0.0025)
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(-21.4, 2.5, 10)
	_lamp.light_color = Color("ffebc9")
	_lamp.light_energy = 1.3
	_lamp.omni_range = 5.0
	_lamp.shadow_enabled = false
	add_child(_lamp)
	_bulb_material = StandardMaterial3D.new()
	_bulb_material.emission = Color("ffe4a8")
	var bulb := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.8, 0.08, 0.3)
	bulb.mesh = mesh
	bulb.material_override = _bulb_material
	bulb.position = Vector3(-21.4, 2.7, 10)
	add_child(bulb)


func _build_seat() -> void:
	# Same existing source geometry contract as the terrace seat: visual cushion,
	# solid back/arms outside the controller capsule. All stand points face -Z.
	_box(Vector3(-21, 0.48, 20.9), Vector3(1.8, 0.08, 0.54), "shop")
	_box(Vector3(-21, 0.72, 21.28), Vector3(1.8, 0.44, 0.1), "shop", true)
	for x in [-21.9, -20.1]:
		_box(Vector3(x, 0.72, 20.95), Vector3(0.08, 0.08, 0.65), "metal", true)
		for z in [20.65, 21.05]:
			_box(Vector3(x, 0.25, z), Vector3(0.08, 0.5, 0.08), "metal", true)


func _label(text: String, at: Vector3, yaw: float, pixel: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = _font
	label.font_size = 40
	label.pixel_size = pixel
	label.outline_size = 0
	label.modulate = Color("eeeeDF") if pixel > 0.002 else Color("303b36")
	label.position = at
	label.rotation.y = yaw
	add_child(label)
	return label


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
		body.collision_mask = 6
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
	return piece
