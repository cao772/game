extends Node3D
## Independent modern street study. Metres, feet at y=0, no legacy world state.

const Walker = preload("res://world/urban_walkthrough_player.gd")
@export_file("*.tscn") var return_scene_path: String = "res://scenes/world_explorer.tscn"

var _walker: Walker
var _hint: Label
var _last_error: String = ""
var _materials: Dictionary = {}
var _batches: Dictionary = {}
var _font: SystemFont


func _ready() -> void:
	_prepare_materials()
	_build_ground()
	for side in [-1.0, 1.0]:
		for z in [-17.5, 17.5]:
			_build_block(side, z)
	_build_street_details()
	_flush_batches()
	_build_lighting()
	_walker = Walker.new()
	_walker.position = Vector3(0, 0, 20)
	_walker.recover_pos = Vector3(0, 0.1, 20)
	add_child(_walker)
	_build_ui()


func _process(_delta: float) -> void:
	if _hint != null and _walker != null:
		_hint.text = "WASD 行走 · Shift 跑步 · 空格 跳跃 · V 切视角  |  " + _walker.mode_label()
		_hint.text += "\n按住右键环视 · 松开 / Esc 释放"
		if not _last_error.is_empty():
			_hint.text += "\n" + _last_error


func _prepare_materials() -> void:
	_materials["concrete"] = _pbr("concrete", Color("c5c5bf"), 1.0)
	_materials["asphalt"] = _pbr("asphalt", Color("555652"), 3.0)
	_materials["paving"] = _pbr("paving", Color("a6a69c"), 1.8)
	for pair in [["trim", "9b9e98"], ["frame", "b9bcb5"], ["glass", "45565a"], ["metal", "636963"], ["paint", "ddd8bc"], ["shop", "63756e"], ["soil", "60584b"], ["leaf", "5a6c4f"], ["bark", "777062"], ["rubber", "30332f"], ["car", "c5c9c7"]]:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(pair[1])
		material.roughness = 0.82
		if pair[0] == "glass":
			material.roughness = 0.3
			material.metallic = 0.15
		_materials[pair[0]] = material
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "PingFang SC", "sans-serif"])


func _pbr(stem: String, fallback: Color, metres: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = fallback
	material.roughness = 0.9
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / metres
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for suffix in ["diffuse", "roughness", "normal"]:
		var path := "res://art/urban_materials/%s_%s.jpg" % [stem, suffix]
		if not ResourceLoader.exists(path):
			continue
		var texture := load(path) as Texture2D
		if texture == null:
			continue
		match suffix:
			"diffuse":
				material.albedo_texture = texture
				material.albedo_color = Color.WHITE
			"roughness":
				material.roughness_texture = texture
			"normal":
				material.normal_enabled = true
				material.normal_texture = texture
				material.normal_scale = 0.65
	return material


func _build_ground() -> void:
	# Flat shared-grade paving avoids steps that a walking controller cannot climb.
	_box(Vector3(0, -0.2, 0), Vector3(96, 0.4, 64), "paving", true)
	_box(Vector3(0, 0.004, 0), Vector3(7, 0.008, 64), "asphalt")
	_box(Vector3(0, 0.005, 0), Vector3(96, 0.01, 10), "asphalt")
	# Two 3.25m travel lanes, plus 0.25m drainage margins on each side.
	for z in [-28.0, -22.0, -16.0, -10.0, 10.0, 16.0, 22.0, 28.0]:
		_batch("lane_dash", Vector3(0.1, 0.012, 3), "paint", Vector3(0, 0.015, z))
	for side in [-1.0, 1.0]:
		for z in [-19.0, 19.0]:
			_batch("drain", Vector3(0.16, 0.015, 26), "metal", Vector3(side * 3.4, 0.012, z))
		# Rear lanes and end connections make a complete loop around each block.
		_box(Vector3(side * 29, 0.003, 0), Vector3(5, 0.006, 60), "paving")
		_box(Vector3(side * 47.75, 0.65, 0), Vector3(0.5, 1.3, 64), "concrete", true)
		for z in [-31.75, 31.75]:
			_box(Vector3(side * 26, 0.65, z), Vector3(43.5, 1.3, 0.5), "concrete", true)
	# The study's street continues visually beyond a visible, low closure rail.
	for z in [-31.6, 31.6]:
		_box(Vector3(0, 0.7, z), Vector3(7.8, 0.18, 0.18), "paint", true)
		for x in [-3.7, 3.7]:
			_box(Vector3(x, 0.4, z), Vector3(0.14, 0.8, 0.14), "metal", true)


func _build_block(side: float, center_z: float) -> void:
	# Four 13 x 21m blocks, frontage x=+/-11, six storeys at 3m each.
	_box(Vector3(side * 17.5, 10.5, center_z), Vector3(13, 15, 21), "concrete", true)
	# Recessed ground floor creates an actually walkable 3.2m covered frontage.
	_box(Vector3(side * 19.1, 1.5, center_z), Vector3(9.8, 3, 21), "concrete", true)
	_box(Vector3(side * 17.5, 18.14, center_z), Vector3(13.25, 0.28, 21.25), "trim")
	var yaw: float = -side * PI * 0.5
	for floor_index in range(1, 6):
		_batch("floor_band", Vector3(13.08, 0.09, 21.08), "trim", Vector3(side * 17.5, floor_index * 3.0, center_z))
		for bay in range(5):
			var z: float = center_z - 8.4 + bay * 4.2
			var origin := Vector3(side * 10.96, floor_index * 3.0 + 1.5, z)
			_facade_part("window_glass", Vector3(1.55, 1.4, 0.045), "glass", origin, yaw, Vector3.ZERO)
			for x in [-0.8, 0.0, 0.8]:
				_facade_part("window_vertical", Vector3(0.055, 1.5, 0.1), "frame", origin, yaw, Vector3(x, 0, 0.045))
			for y in [-0.73, 0.73]:
				_facade_part("window_horizontal", Vector3(1.65, 0.055, 0.1), "frame", origin, yaw, Vector3(0, y, 0.045))
			_facade_part("window_sill", Vector3(1.8, 0.1, 0.24), "trim", origin, yaw, Vector3(0, -0.8, 0.04))
			_facade_part("ac_case", Vector3(0.75, 0.5, 0.34), "frame", origin, yaw, Vector3(1.35, -0.45, 0.2))
			_facade_part("ac_grille", Vector3(0.61, 0.33, 0.02), "metal", origin, yaw, Vector3(1.35, -0.45, 0.38))
			if floor_index <= 2:
				for x in [-0.6, -0.3, 0.0, 0.3, 0.6]:
					_facade_part("security_bar", Vector3(0.025, 1.4, 0.035), "metal", origin, yaw, Vector3(x, 0, 0.19))
			if bay % 2 == 1 and floor_index % 2 == 1:
				_facade_part("balcony_slab", Vector3(2.35, 0.12, 0.9), "concrete", origin, yaw, Vector3(0, -1.4, 0.42))
				_facade_part("balcony_rail", Vector3(2.35, 0.07, 0.07), "metal", origin, yaw, Vector3(0, -0.4, 0.84))
				for x in [-1.1, -0.55, 0.0, 0.55, 1.1]:
					_facade_part("balcony_upright", Vector3(0.035, 1.0, 0.035), "metal", origin, yaw, Vector3(x, -0.9, 0.84))
	for bay in range(6):
		_box(Vector3(side * 11.25, 1.5, center_z - 10.3 + bay * 4.12), Vector3(0.42, 3, 0.42), "concrete", true)
	for bay in range(5):
		var z: float = center_z - 8.4 + bay * 4.2
		var origin := Vector3(side * 14.15, 0, z)
		_facade_part("shop_window", Vector3(2.25, 2.2, 0.05), "glass", origin, yaw, Vector3(-0.6, 1.1, 0))
		_facade_part("shop_door", Vector3(1.0, 2.2, 0.07), "frame", origin, yaw, Vector3(1.15, 1.1, 0.02))
		_facade_part("shop_door_glass", Vector3(0.82, 1.9, 0.025), "glass", origin, yaw, Vector3(1.15, 1.15, 0.07))
		_facade_part("shop_handle", Vector3(0.035, 0.38, 0.09), "metal", origin, yaw, Vector3(0.85, 1.05, 0.12))
		_facade_part("shop_sign", Vector3(3.8, 0.48, 0.12), "shop", origin, yaw, Vector3(0, 2.6, 0.08))
		var names := ["便利店", "家常面馆", "修车配钥匙", "理发", "社区服务"]
		_sign(names[(bay + (1 if side > 0 else 0)) % names.size()], origin + Basis(Vector3.UP, yaw) * Vector3(0, 2.6, 0.155), yaw)
	for z in [center_z - 10.0, center_z + 10.0]:
		_batch("rain_pipe", Vector3(0.09, 17.8, 0.09), "frame", Vector3(side * 10.88, 9, z))


func _build_street_details() -> void:
	for side in [-1.0, 1.0]:
		for z in [-24.0, -12.0, 12.0, 24.0]:
			_tree(Vector3(side * 5.4, 0, z))
			_box(Vector3(side * 7.5, 1.8, z + 2), Vector3(0.09, 3.6, 0.09), "metal", true)
			_batch("street_lamp", Vector3(0.5, 0.12, 0.8), "frame", Vector3(side * 7.5, 3.6, z + 2))
		for z in [-21.0, 19.0]:
			_vehicle(Vector3(side * 36, 0, z), side * 0.1)
		# Bicycle / scooter parking sits beside the rear path, not across it.
		for index in range(4):
			var p := Vector3(side * 33, 0, -5.4 + index * 1.15)
			_batch("cycle_rail", Vector3(0.05, 0.8, 0.05), "metal", p + Vector3(0, 0.4, 0))
			_batch("scooter_body", Vector3(0.38, 0.52, 1.3), "shop", p + Vector3(0.7 * side, 0.55, 0))
			_batch("scooter_seat", Vector3(0.43, 0.12, 0.65), "rubber", p + Vector3(0.7 * side, 0.89, -0.2))
			for dz in [-0.53, 0.53]:
				_batch("scooter_wheel", Vector3(0.15, 0.4, 0.4), "rubber", p + Vector3(0.7 * side, 0.22, dz))
		_box(Vector3(side * 33.35, 0.5, -3.65), Vector3(1.5, 1, 4.6), "metal", true, false)
		for z in [-26.0, 25.0]:
			_box(Vector3(side * 42, 0.48, z), Vector3(2.2, 0.16, 0.65), "trim", true)
			for dx in [-0.75, 0.75]:
				_batch("bench_leg", Vector3(0.12, 0.4, 0.5), "metal", Vector3(side * 42 + dx, 0.2, z))


func _tree(p: Vector3) -> void:
	_box(p + Vector3(0, 0.06, 0), Vector3(1.75, 0.12, 1.75), "trim", true)
	_box(p + Vector3(0, 0.125, 0), Vector3(1.5, 0.01, 1.5), "soil")
	_box(p + Vector3(0, 1.6, 0), Vector3(0.23, 3.2, 0.23), "bark", true)
	var canopy := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.7
	sphere.height = 3.4
	sphere.radial_segments = 16
	sphere.rings = 8
	canopy.mesh = sphere
	canopy.position = p + Vector3(0.3, 4.0, 0)
	canopy.scale = Vector3(1, 0.85, 1.1)
	canopy.material_override = _materials["leaf"]
	add_child(canopy)


func _vehicle(p: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	_batch("car_body", Vector3(1.8, 0.65, 4.25), "car", p + Vector3(0, 0.62, 0), basis)
	_batch("car_cabin", Vector3(1.6, 0.65, 2.25), "glass", p + basis * Vector3(0, 1.26, -0.2), basis)
	_batch("car_roof", Vector3(1.63, 0.08, 2.28), "car", p + basis * Vector3(0, 1.62, -0.2), basis)
	for x in [-0.88, 0.88]:
		for z in [-1.35, 1.35]:
			_batch("car_wheel", Vector3(0.18, 0.58, 0.58), "rubber", p + basis * Vector3(x, 0.32, z), basis)
	_box(p + Vector3(0, 0.78, 0), Vector3(2.25, 1.56, 4.5), "metal", true, false)


func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 1.15
	sun.light_color = Color("fff5e7")
	sun.shadow_enabled = true
	add_child(sun)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("819db4")
	atmosphere.sky_horizon_color = Color("c9d0ce")
	atmosphere.ground_horizon_color = Color("b5bbb6")
	sky.sky_material = atmosphere
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c7d1d4")
	environment.ambient_light_energy = 0.45
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var bar := HBoxContainer.new()
	bar.position = Vector2(18, 16)
	bar.add_theme_constant_override("separation", 16)
	canvas.add_child(bar)
	var back := Button.new()
	back.text = "返回街外"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_override("font", _font)
	back.pressed.connect(_return_to_world)
	bar.add_child(back)
	_hint = Label.new()
	_hint.add_theme_font_override("font", _font)
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color("f0f0e8"))
	_hint.add_theme_color_override("font_shadow_color", Color("222823"))
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_hint)


func _return_to_world() -> void:
	_walker.release_pointer()
	_last_error = ""
	var result := get_tree().change_scene_to_file(return_scene_path)
	if result != OK:
		_last_error = "暂时无法返回，请稍后再试。"


func _sign(text: String, p: Vector3, yaw: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = _font
	label.font_size = 46
	label.pixel_size = 0.006
	label.outline_size = 0
	label.modulate = Color("e5e2d5")
	label.position = p
	label.rotation.y = yaw
	add_child(label)


func _facade_part(key: String, size: Vector3, material: String, origin: Vector3, yaw: float, offset: Vector3) -> void:
	var basis := Basis(Vector3.UP, yaw)
	_batch(key, size, material, origin + basis * offset, basis)


func _batch(key: String, size: Vector3, material: String, p: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	if not _batches.has(key):
		_batches[key] = {"size": size, "material": material, "poses": []}
	_batches[key]["poses"].append(Transform3D(basis, p))


func _flush_batches() -> void:
	for key in _batches:
		var entry: Dictionary = _batches[key]
		var mesh := BoxMesh.new()
		mesh.size = entry["size"]
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = mesh
		instances.instance_count = entry["poses"].size()
		for index in range(instances.instance_count):
			instances.set_instance_transform(index, entry["poses"][index])
		var node := MultiMeshInstance3D.new()
		node.name = str(key)
		node.multimesh = instances
		node.material_override = _materials[entry["material"]]
		add_child(node)
	_batches.clear()


func _box(p: Vector3, size: Vector3, material: String, solid: bool = false, visible_mesh: bool = true) -> void:
	var piece: Node3D = StaticBody3D.new() if solid else Node3D.new()
	piece.position = p
	add_child(piece)
	if visible_mesh:
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh
		visual.material_override = _materials[material]
		piece.add_child(visual)
	if solid:
		var body := piece as StaticBody3D
		body.collision_layer = 1
		body.collision_mask = 2
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		piece.add_child(collider)
