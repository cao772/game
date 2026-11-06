extends Node3D
## Local coordinates match the modern street's origin. All anchors are box-bottom
## positions; the street owns state, input, carried visuals and close permission.

const WorkRules = preload("res://runtime/urban_work_rules.gd")
const ANCHORS := {
	"bench": Vector3(18, 0.9, 10),
	"shelf": Vector3(22.5, 1.0, 24.7),
	"yard": Vector3(27, 0.9, 20.5),
}
const GATE_X := {"front_gate": 14.28, "back_gate": 23.92}
const TOOLBOX_SIZE := Vector3(0.65, 0.38, 0.38)

var _materials: Dictionary = {}
var _geometry: Node3D
var _gates: Dictionary = {}
var _toolbox: Node3D
var _toolbox_lid: Node3D
var _toolbox_tools: Node3D
var _activity_status: Dictionary = {}
var _lamp: OmniLight3D
var _lamp_material: StandardMaterial3D
var _view := {"front_open": false, "back_open": false, "lamp_on": false, "toolbox_anchor": "bench"}


func setup(materials: Dictionary, font: Font) -> void:
	if is_instance_valid(_geometry):
		remove_child(_geometry)
		_geometry.queue_free()
	_gates.clear()
	_toolbox = null
	_toolbox_lid = null
	_toolbox_tools = null
	_lamp = null
	_lamp_material = null
	_activity_status.clear()
	_materials = materials
	_geometry = Node3D.new()
	_geometry.name = "WorkshopGeometry"
	add_child(_geometry)
	_build_shell()
	_build_gate("front_gate", 14.28)
	_build_gate("back_gate", 23.92)
	_build_furniture()
	_build_lamp()
	_build_toolbox()
	if font != null:
		var sign := Label3D.new()
		sign.text = "维修工坊"
		sign.font = font
		sign.font_size = 42
		sign.pixel_size = 0.006
		sign.outline_size = 0
		sign.modulate = Color("e6e4d7")
		sign.position = Vector3(14.08, 2.78, 17.5)
		sign.rotation.y = -PI * 0.5
		_geometry.add_child(sign)
	apply_view(_view)


func apply_view(view: Dictionary) -> void:
	# Accept partial projections without resetting unrelated presentation state.
	for key in ["front_open", "back_open", "lamp_on", "toolbox_anchor"]:
		if view.has(key):
			_view[key] = view[key]
	if not is_instance_valid(_geometry):
		return
	for id in ["front_gate", "back_gate"]:
		var opened: bool = bool(_view["front_open" if id == "front_gate" else "back_open"])
		var gate: Dictionary = _gates[id]
		var leaf: Node3D = gate["leaf"]
		# Instant lift into the header: no pending tween can outlive a restored view.
		leaf.position.y = 2.55 if opened else 0.0
		leaf.scale.y = 0.12 if opened else 1.0
		var shape: CollisionShape3D = gate["shape"]
		shape.set_deferred("disabled", opened)
	var light_on: bool = bool(_view["lamp_on"])
	_lamp.visible = light_on
	_lamp_material.emission_enabled = light_on
	var anchor: String = str(_view["toolbox_anchor"])
	_toolbox.visible = ANCHORS.has(anchor)
	if _toolbox.visible:
		_toolbox.position = ANCHORS[anchor]
		# The rear hinge faces away from the resident on either work surface.
		_toolbox.rotation.y = PI if anchor == "bench" else 0.0
	# Re-evaluate against the NEW layout even before the next activity update.
	# Taking/moving the box or switching off indoor light closes an old open lid.
	_apply_activity()


func present_activity(status: Dictionary) -> void:
	_activity_status = status.duplicate(true)
	_apply_activity()


func _apply_activity() -> void:
	if not is_instance_valid(_toolbox) or not is_instance_valid(_toolbox_lid) or not is_instance_valid(_toolbox_tools):
		return
	var site: String = WorkRules.work_site(_activity_status, _view)
	var opened: bool = _toolbox.visible and not site.is_empty() and site == str(_view["toolbox_anchor"])
	# Display only: no collider, tween, gameplay clock or saved state is added.
	_toolbox_lid.rotation.x = deg_to_rad(105.0) if opened else 0.0
	_toolbox_tools.visible = opened


func targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		{"id": "front_gate", "label": "前卷帘门", "position": Vector3(14.2, 1.1, 17.5)},
		{"id": "back_gate", "label": "后卷帘门", "position": Vector3(24, 1.1, 17.5)},
		{"id": "lamp_switch", "label": "工坊照明", "position": Vector3(15, 1.2, 15)},
		{"id": "bench", "label": "工作台", "position": ANCHORS["bench"] + Vector3(0, 0.19, 0)},
		{"id": "shelf", "label": "货架", "position": ANCHORS["shelf"] + Vector3(0, 0.19, 0)},
		{"id": "yard", "label": "院内工作台", "position": ANCHORS["yard"] + Vector3(0, 0.19, 0)},
	]
	for target in result:
		target["position"] = to_global(target["position"])
	return result


func gate_occupied(id: String, player_pos: Vector3) -> bool:
	if not GATE_X.has(id):
		return true
	var feet := to_local(player_pos)
	# Conservatively expand the 0.08 x 2.5 x 2.4m leaf by the player's
	# 0.3m radius / 1.75m height and a 0.15m closing margin.
	return absf(feet.x - float(GATE_X[id])) <= 0.49 \
		and absf(feet.z - 17.5) <= 1.65 \
		and feet.y <= 2.65 and feet.y + 1.75 >= -0.15


func is_gate_collider(id: String, collider: Object) -> bool:
	if not _gates.has(id):
		return false
	var shape: CollisionShape3D = _gates[id]["shape"]
	return collider == shape.get_parent()


func _build_shell() -> void:
	# The existing upper floor starts at y=3 and remains the workshop ceiling.
	for x in [14.3, 23.9]:
		for z in [11.65, 23.35]:
			_box(_geometry, Vector3(x, 1.5, z), Vector3(0.2, 3, 9.3), "concrete", true)
		_box(_geometry, Vector3(x, 2.75, 17.5), Vector3(0.2, 0.5, 2.4), "concrete", true)
	_box(_geometry, Vector3(19.1, 1.5, 7.1), Vector3(9.8, 3, 0.2), "concrete", true)
	_box(_geometry, Vector3(19.1, 1.5, 27.9), Vector3(9.8, 3, 0.2), "concrete", true)
	# Painted floor is visual only; the street's existing y=0 floor stays continuous.
	_box(_geometry, Vector3(19.1, 0.006, 17.5), Vector3(9.4, 0.012, 20.6), "paving")
	for z in [16.05, 18.95]:
		_box(_geometry, Vector3(19.1, 0.014, z), Vector3(9.4, 0.008, 0.04), "paint")


func _build_gate(id: String, x: float) -> void:
	var leaf := Node3D.new()
	leaf.name = id + "Leaf"
	leaf.position = Vector3(x, 0, 17.5)
	_geometry.add_child(leaf)
	_box(leaf, Vector3(0, 1.25, 0), Vector3(0.08, 2.5, 2.4), "frame")
	for index in range(12):
		_box(leaf, Vector3(0, 0.1 + index * 0.2, 0), Vector3(0.09, 0.018, 2.35), "trim")
	_box(_geometry, Vector3(x, 2.8, 17.5), Vector3(0.32, 0.3, 2.65), "metal")
	var body := StaticBody3D.new()
	body.name = id + "Body"
	body.position = Vector3(x, 1.25, 17.5)
	body.collision_layer = 1
	body.collision_mask = 2
	_geometry.add_child(body)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.08, 2.5, 2.4)
	collider.shape = box
	body.add_child(collider)
	_gates[id] = {"leaf": leaf, "shape": collider}


func _build_furniture() -> void:
	# A closed cabinet workbench has a top surface at y=0.9.
	_box(_geometry, Vector3(18, 0.45, 10), Vector3(3.2, 0.9, 1.2), "shop", true)
	_box(_geometry, Vector3(18, 0.85, 10), Vector3(3.2, 0.1, 1.2), "frame")
	for x in [17.0, 18.0, 19.0]:
		_box(_geometry, Vector3(x, 0.5, 10.615), Vector3(0.75, 0.48, 0.025), "trim")
		_box(_geometry, Vector3(x, 0.63, 10.65), Vector3(0.3, 0.04, 0.05), "metal")
	# Shelving has an accessible middle deck at y=1.0 and a clear approach from -Z.
	for y in [0.08, 0.96, 2.04]:
		_box(_geometry, Vector3(22.5, y, 24.7), Vector3(2.4, 0.08, 1.1), "frame", true)
	for x in [21.35, 23.65]:
		for z in [24.2, 25.2]:
			_box(_geometry, Vector3(x, 1.05, z), Vector3(0.07, 2.1, 0.07), "metal", true)
	_box(_geometry, Vector3(21.8, 2.28, 24.7), Vector3(0.65, 0.4, 0.6), "trim")
	_box(_geometry, Vector3(22.8, 2.23, 24.7), Vector3(0.75, 0.3, 0.6), "shop")
	_build_yard_workbench()
	_box(_geometry, Vector3(14.68, 1.2, 15), Vector3(0.6, 0.4, 0.3), "frame", true)
	_box(_geometry, Vector3(15, 1.2, 15), Vector3(0.04, 0.16, 0.1), "shop")


func _build_yard_workbench() -> void:
	# Top y=.9; footprint x26.1..27.9/z19.95..21.05 leaves the resident's
	# (27,0,19.3) approach and all previous yard paths clear. The centre box slot
	# stays empty above the top: x26.675..27.325/z20.31..20.69.
	_box(_geometry, Vector3(27, 0.85, 20.5), Vector3(1.8, 0.1, 1.1), "shop", true)
	for x in [26.25, 27.75]:
		for z in [20.1, 20.9]:
			_box(_geometry, Vector3(x, 0.4, z), Vector3(0.09, 0.8, 0.09), "metal", true)
	for z in [20.1, 20.9]:
		_box(_geometry, Vector3(27, 0.23, z), Vector3(1.5, 0.08, 0.06), "frame", true)
	_box(_geometry, Vector3(27, 0.19, 20.5), Vector3(1.5, 0.06, 0.74), "frame", true)
	# A worn board to the left and a shallow parts tray to the right are static
	# visual props, not extra copies of the unique interactable toolbox.
	_box(_geometry, Vector3(26.365, 0.9175, 20.48), Vector3(0.43, 0.035, 0.78), "bark")
	for x in [26.22, 26.34, 26.49]:
		_box(_geometry, Vector3(x, 0.936, 20.48), Vector3(0.006, 0.002, 0.69), "trim")
	var tray := Node3D.new()
	tray.name = "YardPartsTray"
	tray.position = Vector3(27.62, 0.9, 20.55)
	_geometry.add_child(tray)
	_box(tray, Vector3(0, 0.018, 0), Vector3(0.42, 0.036, 0.55), "frame")
	for x in [-0.20, 0.20]:
		_box(tray, Vector3(x, 0.056, 0), Vector3(0.02, 0.04, 0.55), "metal")
	for z in [-0.265, 0.265]:
		_box(tray, Vector3(0, 0.056, z), Vector3(0.38, 0.04, 0.02), "metal")
	_build_wrench(tray, Vector3(-0.09, 0.053, -0.02), 0.14)
	_build_screwdriver(tray, Vector3(0.085, 0.057, 0.025), -0.12)
	for x in [-0.08, 0.0, 0.08]:
		_box(tray, Vector3(x, 0.05, 0.20), Vector3(0.04, 0.028, 0.04), "metal")


func _build_lamp() -> void:
	_box(_geometry, Vector3(19.1, 2.88, 17.5), Vector3(1.8, 0.12, 0.3), "frame")
	_lamp_material = StandardMaterial3D.new()
	_lamp_material.albedo_color = Color("e9e8db")
	_lamp_material.roughness = 0.5
	_lamp_material.emission = Color("fff5df")
	var diffuser := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.65, 0.04, 0.24)
	diffuser.mesh = mesh
	diffuser.material_override = _lamp_material
	diffuser.position = Vector3(19.1, 2.8, 17.5)
	_geometry.add_child(diffuser)
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(19.1, 2.55, 17.5)
	_lamp.omni_range = 11.0
	_lamp.light_energy = 1.3
	_lamp.light_color = Color("fff6e6")
	_lamp.shadow_enabled = true
	_geometry.add_child(_lamp)


func _build_toolbox() -> void:
	_toolbox = Node3D.new()
	_toolbox.name = "SurfaceToolbox"
	_geometry.add_child(_toolbox)
	# Closed envelope remains TOOLBOX_SIZE; the base and four walls leave a real
	# cavity. All parts are visual, so an open lid never changes placement rules.
	_box(_toolbox, Vector3(0, 0.02, 0), Vector3(0.65, 0.04, 0.38), "shop")
	for z in [-0.175, 0.175]:
		_box(_toolbox, Vector3(0, 0.17, z), Vector3(0.65, 0.26, 0.03), "shop")
	for x in [-0.31, 0.31]:
		_box(_toolbox, Vector3(x, 0.17, 0), Vector3(0.03, 0.26, 0.32), "shop")
	for x in [-0.20, 0.20]:
		_box(_toolbox, Vector3(x, 0.30, 0.18), Vector3(0.07, 0.025, 0.02), "metal")
	_toolbox_lid = Node3D.new()
	_toolbox_lid.name = "HingedLid"
	_toolbox_lid.position = Vector3(0, 0.30, 0.19)
	_toolbox.add_child(_toolbox_lid)
	_box(_toolbox_lid, Vector3(0, 0.01, -0.19), Vector3(0.65, 0.02, 0.38), "frame")
	for x in [-0.15, 0.15]:
		_box(_toolbox_lid, Vector3(x, 0.05, -0.19), Vector3(0.035, 0.06, 0.05), "metal")
	_box(_toolbox_lid, Vector3(0, 0.07, -0.19), Vector3(0.33, 0.02, 0.05), "metal")
	_toolbox_tools = Node3D.new()
	_toolbox_tools.name = "VisibleInternalTools"
	_toolbox.add_child(_toolbox_tools)
	# A shallow inner tray raises the tools above the front-wall sightline while
	# keeping every tool below the closed lid. It is a visual insert, not inventory.
	for x in [-0.28, 0.28]:
		_box(_toolbox_tools, Vector3(x, 0.20, 0), Vector3(0.02, 0.04, 0.29), "frame")
	_box(_toolbox_tools, Vector3(0, 0.22, 0), Vector3(0.57, 0.014, 0.30), "rubber")
	_box(_toolbox_tools, Vector3(0, 0.255, 0), Vector3(0.018, 0.05, 0.29), "frame")
	_build_wrench(_toolbox_tools, Vector3(-0.15, 0.24, 0), -0.18)
	_build_screwdriver(_toolbox_tools, Vector3(0.13, 0.247, 0), 0.15)
	_toolbox_tools.hide()


func _build_wrench(parent: Node3D, at: Vector3, yaw: float) -> void:
	var tool := Node3D.new()
	tool.position = at
	tool.rotation.y = yaw
	parent.add_child(tool)
	_box(tool, Vector3(0, 0, 0.015), Vector3(0.028, 0.018, 0.22), "metal")
	_box(tool, Vector3(0, 0, -0.095), Vector3(0.075, 0.026, 0.025), "frame")
	for x in [-0.029, 0.029]:
		_box(tool, Vector3(x, 0, -0.122), Vector3(0.017, 0.026, 0.055), "frame")


func _build_screwdriver(parent: Node3D, at: Vector3, yaw: float) -> void:
	var tool := Node3D.new()
	tool.position = at
	tool.rotation.y = yaw
	parent.add_child(tool)
	_box(tool, Vector3(0, 0, 0.07), Vector3(0.055, 0.04, 0.10), "shop")
	_box(tool, Vector3(0, 0, -0.05), Vector3(0.014, 0.014, 0.14), "metal")
	_box(tool, Vector3(0, 0, -0.126), Vector3(0.024, 0.008, 0.025), "frame")


func _box(parent: Node3D, p: Vector3, size: Vector3, material: String, solid: bool = false) -> void:
	var piece: Node3D = StaticBody3D.new() if solid else Node3D.new()
	piece.position = p
	parent.add_child(piece)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = _materials.get(material) as Material
	piece.add_child(visual)
	if solid:
		var body := piece as StaticBody3D
		body.collision_layer = 1
		body.collision_mask = 2
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
