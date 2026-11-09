extends Node3D
## Independent modern street study. Metres, feet at y=0, no legacy world state.

const Walker = preload("res://world/urban_walkthrough_player.gd")
const Workshop = preload("res://world/urban_workshop.gd")
const UrbanState = preload("res://runtime/urban_state.gd")
const UrbanStore = preload("res://runtime/urban_save_store.gd")
const Resident = preload("res://world/urban_resident.gd")
const ResidentPanel = preload("res://ui/urban_resident_panel.gd")
const Terrace = preload("res://world/urban_terrace.gd")
const ReadingRoom = preload("res://world/urban_reading_room.gd")
const ReadingVisitor = preload("res://world/urban_reading_visitor.gd")
const CupVisitor = preload("res://world/urban_cup_visitor.gd")
const WashShelter = preload("res://world/urban_wash_shelter.gd")
@export_file("*.tscn") var return_scene_path: String = "res://scenes/world_explorer.tscn"
@export_file("*.json") var resident_lines_path: String = "res://content/urban_resident_lines.json"
@export_file("*.json") var visitor_lines_path: String = "res://content/reading_visitor_lines.json"

@export var cup_visitor_name := "带布包的来客"
@export var cup_keep_line := "这对杯碟我想自己留着。"

var _walker: Walker
var _hint: Label
var _last_error: String = ""
var _materials: Dictionary = {}
var _batches: Dictionary = {}
var _font: SystemFont
var _workshop: Workshop
var _urban := UrbanState.new()
var _store := UrbanStore.new()
var _held: Node3D
var _action: Label
var _load_confirm: ConfirmationDialog
var _leave_confirm: ConfirmationDialog
var _nearest: Dictionary = {}
var _interact_queued := false
var _reading_action: String = ""
var _persistence_ready := false
var _dirty := false
var _resident: Resident
var _resident_panel: ResidentPanel
var _resident_copy_ready := false
var _toolbar: Array[Button] = []
var _terrace: Terrace
var _reading_room: ReadingRoom
var _reading_visitor: ReadingVisitor
var _cup_visitor: CupVisitor
var _wash_shelter: WashShelter
var _seat_label: String = "长椅"
var _seated_forward := Vector3.FORWARD


func _ready() -> void:
	_prepare_materials()
	_build_ground()
	for side in [-1.0, 1.0]:
		for z in [-17.5, 17.5]:
			_build_block(side, z)
	_build_street_details()
	_flush_batches()
	_build_lighting()
	_workshop = Workshop.new()
	add_child(_workshop)
	_workshop.setup(_materials, _font)
	_terrace = Terrace.new()
	add_child(_terrace)
	_terrace.setup(_materials, _font)
	_reading_room = ReadingRoom.new()
	add_child(_reading_room)
	_reading_room.setup(_materials, _font)
	_wash_shelter = WashShelter.new()
	add_child(_wash_shelter)
	_wash_shelter.setup(_materials, _font)
	_walker = Walker.new()
	_walker.position = Vector3(0, 0, 20)
	_walker.recover_pos = Vector3(0, 0.1, 20)
	add_child(_walker)
	# Residents use their own layer. Existing street/world geometry is unchanged.
	_walker.collision_mask |= 4
	_resident = Resident.new()
	add_child(_resident)
	_reading_visitor = ReadingVisitor.new()
	add_child(_reading_visitor)
	_cup_visitor = CupVisitor.new()
	_cup_visitor.display_name = cup_visitor_name
	_cup_visitor.keep_line = cup_keep_line
	add_child(_cup_visitor)
	var visitor_file := FileAccess.open(visitor_lines_path, FileAccess.READ)
	if visitor_file != null:
		var copy: Variant = JSON.parse_string(visitor_file.get_as_text())
		visitor_file.close()
		if copy is Dictionary:
			_reading_visitor.configure(copy)
	_build_ui()
	_build_held()
	_restore_latest(true)


func _process(_delta: float) -> void:
	if _hint != null and _walker != null:
		_hint.text = "WASD 行走 · Shift 跑步 · 空格 跳跃 · V 切视角  |  " + _walker.mode_label()
		_hint.text += "\n按住右键环视 · 松开 / Esc 释放"
		if _walker.is_seated():
			_hint.text = _seat_label + " · E 起身 · V 切视角  |  " + _walker.mode_label()
			_hint.text += "\n按住右键看周围 · 松开 / Esc 释放 · 工坊住户继续自己的活动"
		if not _last_error.is_empty():
			_hint.text += "\n" + _last_error
		var view: Dictionary = _urban.view()
		if _walker.is_seated():
			_action.text = "E：离开" + _seat_label + " · 起身位置被挡时会留在座位上"
		else:
			_action.text = "E：" + _target_caption(_nearest, view) if not _nearest.is_empty() else "阅览室后巷有洗择棚 · 东侧工坊通后院与晒台"
		if _reading_room.is_carrying():
			_action.text += " · 手持书盘 · F 翻页"
		elif not _nearest.is_empty() and _reading_room.has_tray(str(_nearest["id"])):
			if _walker.is_seated():
				_action.text += " · F 翻页"
			elif _wash_shelter.is_carrying() or view["toolbox_anchor"] == "carried":
				_action.text += " · F 翻页 · 先放好手中物品再拿书盘"
			else:
				_action.text += " · R 拿起书盘"
		if _wash_shelter.is_carrying():
			_action.text += " · 手持公共盆"
		if not _nearest.is_empty() and WashShelter.ANCHORS.has(str(_nearest["id"])):
			if _wash_shelter.is_carrying():
				_action.text += " · R 放盆"
			elif _wash_shelter.has_basin(str(_nearest["id"])):
				_action.text += " · 先放好手中物品再拿盆" if _reading_room.is_carrying() or view["toolbox_anchor"] == "carried" else " · R 拿盆"
		if _wash_shelter.is_carrying() or (not _nearest.is_empty() and WashShelter.ANCHORS.has(str(_nearest["id"]))):
			_action.text += "\n" + _wash_shelter.summary()
		_action.text += " · 手持工具箱" if view["toolbox_anchor"] == "carried" else ""
		_action.text += " · 尚未保存" if _dirty else ""
		if is_instance_valid(_resident):
			_action.text += "\n工坊住户：" + str(_resident.status()["activity"])
		if is_instance_valid(_reading_visitor):
			var visitor_status: Dictionary = _reading_visitor.status()
			_action.text += "\n" + str(visitor_status["name"]) + "：" + str(visitor_status["activity"])
		_sync_held()


func _physics_process(delta: float) -> void:
	var enabled: bool = _walker != null and _walker.interaction_allowed()
	if is_instance_valid(_resident):
		_resident.advance(delta, _urban.view(), enabled)
		_workshop.present_activity(_resident.status() if enabled else {})
	if is_instance_valid(_reading_visitor):
		_reading_visitor.advance(delta, _reading_room.visitor_view(), enabled)
	_cup_visitor.advance(delta, enabled)
	_wash_shelter.advance(delta, enabled)
	if not enabled:
		_interact_queued = false
		_reading_action = ""
		_nearest.clear()
		return
	_nearest = _find_target()
	var reading_action: String = _reading_action
	_reading_action = ""
	if _interact_queued:
		_interact_queued = false
		_reading_action = ""
		_interact(delta)
	elif reading_action == "move":
		if _wash_shelter.is_carrying() or (not _nearest.is_empty() and WashShelter.ANCHORS.has(str(_nearest["id"]))):
			_move_wash_basin(delta)
		else:
			_move_reading_tray(delta)
	elif reading_action == "read":
		_read_page()
	_reading_visitor.refresh_reading(_reading_room.visitor_view())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		_interact_queued = false
		_reading_action = ""
		if is_instance_valid(_resident):
			_resident.suspend_activity()
		if is_instance_valid(_reading_visitor):
			_reading_visitor.suspend_activity()
		if is_instance_valid(_cup_visitor):
			_cup_visitor.suspend_activity()
		if is_instance_valid(_wash_shelter):
			_wash_shelter.suspend_activity()
		if is_instance_valid(_workshop):
			_workshop.present_activity({})


func _unhandled_input(event: InputEvent) -> void:
	if _walker == null or not _walker.interaction_allowed():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E:
				_interact_queued = true
			KEY_R:
				_reading_action = "move"
			KEY_F:
				_reading_action = "read"
			KEY_F5:
				_save_urban()
			KEY_F9:
				_request_restore()
			_:
				return
		get_viewport().set_input_as_handled()


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
	var enterable: bool = center_z > 0 # Workshop east; reading passage west.
	if not enterable:
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
		if enterable:
			continue
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
	var column := VBoxContainer.new()
	column.position = Vector2(18, 16)
	column.add_theme_constant_override("separation", 8)
	canvas.add_child(column)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	column.add_child(bar)
	_ui_button(bar, "保存并返回街外", _return_to_world)
	_ui_button(bar, "保存 · F5", _save_urban)
	_ui_button(bar, "恢复 · F9", _request_restore)
	_ui_button(bar, "整理旧存档", _archive_urban)
	_ui_button(bar, "不保存返回", _request_leave)
	_hint = Label.new()
	_hint.add_theme_font_override("font", _font)
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color("f0f0e8"))
	_hint.add_theme_color_override("font_shadow_color", Color("222823"))
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_hint)
	_action = Label.new()
	_action.add_theme_font_override("font", _font)
	_action.add_theme_font_size_override("font_size", 18)
	_action.add_theme_color_override("font_color", Color("ffe5a1"))
	_action.add_theme_color_override("font_shadow_color", Color("222823"))
	_action.add_theme_constant_override("shadow_offset_x", 1)
	_action.add_theme_constant_override("shadow_offset_y", 1)
	_action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_action)
	_load_confirm = ConfirmationDialog.new()
	_load_confirm.title = "恢复现代街区"
	_load_confirm.dialog_text = "恢复最近保存的工坊门、工作灯与工具箱位置，并回到街上起点？当前未保存改动会被替换；书盘回阅览台，阅览灯和书页回到初始状态；阅览来客从前廊重新来访；公共盆回水槽，水、菜、龙头和滴水复位。"
	_load_confirm.confirmed.connect(_restore_latest.bind(false))
	_load_confirm.visibility_changed.connect(_update_modal_controls)
	canvas.add_child(_load_confirm)
	_leave_confirm = ConfirmationDialog.new()
	_leave_confirm.title = "不保存返回"
	_leave_confirm.dialog_text = "离开现代街区并放弃本次未保存的布置？原有存档保留；公共书盘回阅览台，公共盆回水槽且水菜复位，下次进入时来客重新来访。"
	_leave_confirm.confirmed.connect(_leave_without_save)
	_leave_confirm.visibility_changed.connect(_update_modal_controls)
	canvas.add_child(_leave_confirm)
	_resident_panel = ResidentPanel.new()
	var conversation_theme := Theme.new()
	conversation_theme.default_font = _font
	_resident_panel.theme = conversation_theme
	canvas.add_child(_resident_panel)
	_resident_panel.closed.connect(_update_modal_controls)
	_resident_panel.visibility_changed.connect(_update_modal_controls)
	var file := FileAccess.open(resident_lines_path, FileAccess.READ)
	if file != null:
		var data: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if data is Dictionary:
			_resident_copy_ready = _resident_panel.configure(data).get("ok", false)
	if not _resident_copy_ready:
		push_warning("Workshop resident copy unavailable; walking and workshop interactions remain available.")


func _ui_button(parent: Node, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", _font)
	button.pressed.connect(action)
	parent.add_child(button)
	_toolbar.append(button)


func _return_to_world() -> void:
	if not _save_urban():
		return
	_leave_without_save()


func _leave_without_save() -> void:
	_walker.release_pointer()
	var result := get_tree().change_scene_to_file(return_scene_path)
	if result != OK:
		_last_error = "暂时无法返回，请稍后再试。"


func _request_leave() -> void:
	_walker.release_pointer()
	_interact_queued = false
	_reading_action = ""
	_leave_confirm.popup_centered()


func _request_restore() -> void:
	_walker.release_pointer()
	_interact_queued = false
	_reading_action = ""
	_load_confirm.popup_centered()


func _update_modal_controls() -> void:
	if _load_confirm != null and _leave_confirm != null:
		var talking: bool = is_instance_valid(_resident_panel) and _resident_panel.visible
		var modal: bool = _load_confirm.visible or _leave_confirm.visible or talking
		_walker.controls_enabled = not modal
		for button in _toolbar:
			button.disabled = modal
		if is_instance_valid(_resident):
			_resident.set_conversing(talking)
		if not _walker.controls_enabled:
			_resident.suspend_activity()
			_cup_visitor.suspend_activity()
			_reading_visitor.suspend_activity()
			_wash_shelter.suspend_activity()
			_workshop.present_activity({})
			_walker.release_pointer()
			_interact_queued = false
			_reading_action = ""
			_nearest.clear()


func _save_urban() -> bool:
	if not _persistence_ready:
		_last_error = "旧街区存档尚未成功读取，暂不写入。可重试恢复，或不保存返回。"
		return false
	var saved: Dictionary = _store.write_record("urban_free", _urban.snapshot())
	if saved.get("ok", false):
		_dirty = false
		_last_error = "已保存工坊门、工作灯和工具箱；书盘、阅览灯、书页、来客与洗择棚状态只保留到离场或成功恢复。"
	else:
		_last_error = "保存失败：%s。当前布置仍保留，可整理旧档后重试。" % saved.get("code", "UNKNOWN")
	return saved.get("ok", false)


func _restore_latest(initial: bool) -> void:
	var record: Dictionary = _store.read_latest("urban_free")
	if record.get("code") == "NO_SAVES":
		if initial:
			_persistence_ready = true
			_last_error = "西侧阅览室与东侧工坊已开放，可以从主街穿到后巷。"
		else:
			_last_error = "还没有现代街区存档；当前布置保留。"
			_last_error += "可以先保存。" if _persistence_ready else "之前的读取问题尚未解决，写入仍暂停；可不保存返回。"
	elif record.get("ok", false) and record.get("payload") is Dictionary:
		var restored: Dictionary = _urban.restore(record["payload"])
		if restored["ok"]:
			_persistence_ready = true
			_dirty = false
			_walker.reset_pose(Vector3(0, 0.1, 20))
			# Resident motion is scene-local, not part of the five-field layout save.
			# Reset before restored shutters can become solid around an old pose.
			_resident.reset_routine()
			# Clear scene-local held objects before projecting the restored toolbox.
			_wash_shelter.reset_visit()
			_reading_room.reset_visit()
			_cup_visitor.reset_visit()
			_reading_visitor.reset_visit()
			_last_error = "已恢复街区布置，回到街上起点。"
			if record.get("code") == "RECOVERED_OLDER_RECORD" or not record.get("skipped", []).is_empty():
				_last_error += " 最近记录不可用，采用了较早的有效存档。"
		else:
			_persistence_ready = false
			_last_error = "旧档格式未通过校验，保留当前布置且暂停写入：" + restored["code"]
	else:
		_persistence_ready = false
		_last_error = "存档未读取，保留当前布置且暂停写入：%s。可重试恢复或不保存返回。" % record.get("code", "UNKNOWN")
	_apply_urban_view()


func _archive_urban() -> void:
	var result: Dictionary = _store.archive_older("urban_free", 32)
	_last_error = "已归档 %d 份，保留最近32份；原记录仍保留。%s" % [result.get("moved", []).size(), result.get("code", "UNKNOWN")]


func _apply_urban_view() -> void:
	var view: Dictionary = _urban.view()
	# Input and restore callbacks must refresh work without advancing time or
	# clearing an in-flight route. Use this same layout for the visible box.
	_resident.refresh_work_view(view)
	_workshop.apply_view(view)
	_workshop.present_activity(_resident.status() if _walker.interaction_allowed() else {})
	_sync_held()
	_held.visible = view["toolbox_anchor"] == "carried"
	_nearest.clear()
	_interact_queued = false
	_reading_action = ""


func _find_target() -> Dictionary:
	var eye_height: float = Walker.SEATED_EYE_HEIGHT if _walker.is_seated() else Walker.EYE_HEIGHT
	var eye: Vector3 = _walker.global_position + Vector3.UP * eye_height
	var forward: Vector3 = -_walker.interaction_camera().global_transform.basis.z
	var view: Dictionary = _urban.view()
	var best: Dictionary = {}
	var best_score := -INF
	var candidates: Array[Dictionary] = _workshop.targets()
	candidates.append(_cup_visitor.interaction_target())
	candidates.append(_reading_visitor.interaction_target())
	candidates.append_array(_terrace.targets())
	candidates.append_array(_reading_room.targets())
	candidates.append_array(_wash_shelter.targets())
	if _resident_copy_ready:
		candidates.append(_resident.interaction_target())
	for target in candidates:
		var id: String = target["id"]
		if _walker.is_seated() and not _reading_room.has_tray(id):
			continue
		if Workshop.ANCHORS.has(id) and view["toolbox_anchor"] != "carried" and view["toolbox_anchor"] != id:
			continue
		var offset: Vector3 = target["position"] - eye
		var distance := offset.length()
		if distance > 2.6 or distance < 0.2:
			continue
		var facing := forward.dot(offset / distance)
		if facing < 0.45:
			continue
		# A gate may occlude its own handle from inside; accept only that exact body.
		var ray := PhysicsRayQueryParameters3D.create(eye, target["position"], 1 | 4)
		ray.hit_from_inside = true
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		var own_resident: bool = (id == "workshop_resident" and hit.get("collider") == _resident) or (id == "reading_visitor" and hit.get("collider") == _reading_visitor) or (id == "cup_visitor" and hit.get("collider") == _cup_visitor)
		if not hit.is_empty() and not own_resident and not _workshop.is_gate_collider(id, hit.get("collider")):
			continue
		var score := facing * 3.0 - distance
		if score > best_score:
			best_score = score
			best = target
	return best


func _target_caption(target: Dictionary, view: Dictionary) -> String:
	var id: String = target["id"]
	if ReadingRoom.TRAY_ANCHORS.has(id):
		return _reading_room.caption(id)
	if WashShelter.ANCHORS.has(id):
		return _wash_shelter.caption(id)
	match id:
		"reading_lamp", "reading_seat":
			return _reading_room.caption(id)
		"terrace_seat":
			return "坐在晒台长椅上"
		"workshop_resident":
			return "和工坊住户聊聊"
		"reading_visitor", "cup_visitor":
			return "看看" + str(target["label"]) + "在忙什么"
		"front_gate", "back_gate":
			var opened: bool = view["front_open" if id == "front_gate" else "back_open"]
			return ("关闭" if opened else "打开") + target["label"]
		"lamp_switch":
			return "关灯" if view["lamp_on"] else "开灯"
		_:
			return "放到" + target["label"] if view["toolbox_anchor"] == "carried" else "拿起工具箱"


func _interact(delta: float) -> void:
	if _walker.is_seated():
		var stood: Dictionary = _walker.stand_up()
		_last_error = "已起身，可以继续探索。" if stood.get("ok", false) else "起身位置暂时被挡住了；仍留在座位上，稍后再试。"
		_nearest.clear()
		_interact_queued = false
		_reading_action = ""
		return
	if _nearest.is_empty():
		return
	var id: String = _nearest["id"]
	var view: Dictionary = _urban.view()
	var result: Dictionary
	if id == "terrace_seat" or id == "reading_seat":
		var stand_candidates: Array[Vector3] = []
		for point in _nearest["stand_candidates"]:
			stand_candidates.append(point)
		var seated: Dictionary = _walker.seat_at(_nearest["feet"], float(_nearest["yaw"]), stand_candidates)
		if seated.get("ok", false):
			_seat_label = _nearest["label"]
			_seated_forward = Basis(Vector3.UP, float(_nearest["yaw"])) * Vector3.FORWARD
		_last_error = "坐下了。可以环视街区，按 E 随时尝试起身。" if seated.get("ok", false) else "先走到长椅前的空位，站稳后再坐下。"
		_nearest.clear()
		_interact_queued = false
		_reading_action = ""
		return
	elif WashShelter.ANCHORS.has(id):
		_last_error = _wash_shelter.use_station(id)
		_nearest.clear()
		return
	elif ReadingRoom.TRAY_ANCHORS.has(id):
		if _reading_room.is_carrying():
			_move_reading_tray(delta)
		else:
			_read_page()
		return
	elif id == "reading_lamp":
		_last_error = _reading_room.toggle_lamp()
		_nearest.clear()
		_interact_queued = false
		_reading_action = ""
		return
	elif id == "cup_visitor":
		_last_error = _cup_visitor.describe(_wash_shelter.is_carrying())
		return
	elif id == "reading_visitor":
		# A passing remark, not a modal conversation or timer reset.
		_last_error = _reading_visitor.describe()
		return
	elif id == "workshop_resident":
		_walker.release_pointer()
		if not _resident_panel.open_resident(_resident.status(), view):
			_last_error = "暂时无法交谈，可以继续探索。"
		_update_modal_controls()
		return
	elif id == "front_gate" or id == "back_gate":
		var opened: bool = view["front_open" if id == "front_gate" else "back_open"]
		if opened and (_workshop.gate_occupied(id, _walker.global_position) or _workshop.gate_occupied(id, _walker.global_position + _walker.velocity * delta)):
			_last_error = "先离开门洞，再关卷帘门。"
			return
		if opened and (_workshop.gate_occupied(id, _resident.global_position) or _workshop.gate_occupied(id, _resident.possible_next_position(delta))):
			_last_error = "工坊住户正在通过，等他离开门洞再关门。"
			return
		result = _urban.toggle_gate(id)
	elif id == "lamp_switch":
		result = _urban.toggle_lamp()
	elif view["toolbox_anchor"] == "carried":
		var base: Vector3 = Workshop.ANCHORS[id]
		var p := _walker.global_position
		if absf(p.x - base.x) < 0.7 and absf(p.z - base.z) < 0.55 and p.y < base.y + 0.48 and p.y + 1.75 > base.y:
			_last_error = "先让开放置位置，再放下工具箱。"
			return
		var resident_pos: Vector3 = _resident.global_position
		if absf(resident_pos.x - base.x) < 0.7 and absf(resident_pos.z - base.z) < 0.55 and resident_pos.y < base.y + 0.48 and resident_pos.y + 1.75 > base.y:
			_last_error = "工坊住户还在这个位置，稍等他让开再放。"
			return
		result = _urban.place_toolbox(id)
	else:
		if _wash_shelter.is_carrying():
			_last_error = "手里已有公共盆，请先放回洗择棚任一台面。"
			return
		if _reading_room.is_carrying():
			_last_error = "手里已有书盘，请先放到阅览台、座旁低台或前廊窄台。"
			return
		result = _urban.take_toolbox()
	if result["ok"]:
		_last_error = _target_caption(_nearest, view) + "，已完成。"
		_dirty = true
		_apply_urban_view()
	else:
		_last_error = "暂时无法操作：" + result["code"]


func _read_page() -> void:
	# Owned hand content needs no remote target. Surface reading always uses the
	# same physics-frame range, facing and occlusion result, including seated eyes.
	if _reading_room.is_carrying() or (not _nearest.is_empty() and _reading_room.has_tray(str(_nearest["id"]))):
		_last_error = _reading_room.turn_page()
	else:
		_last_error = "先走近并看向书盘，或把它拿在手里再翻页。"


func _move_reading_tray(delta: float) -> void:
	if _walker.is_seated():
		_last_error = "坐着可以按 F 翻页；请先按 E 起身，再拿放书盘。"
		return
	if _nearest.is_empty() or not ReadingRoom.TRAY_ANCHORS.has(str(_nearest["id"])):
		_last_error = "看向阅览台、座旁低台或前廊窄台的书盘位置，再按 R。"
		return
	var id: String = _nearest["id"]
	if not _reading_room.is_carrying():
		if _wash_shelter.is_carrying():
			_last_error = "手里已有公共盆，请先放回洗择棚，再拿书盘。"
			return
		var toolbox_carried: bool = _urban.view()["toolbox_anchor"] == "carried"
		if not _reading_room.take_tray(id, toolbox_carried):
			_last_error = "手里已有工具箱，请先放回工坊或院台。" if toolbox_carried else "这里没有可拿的书盘。"
			return
		_sync_held()
		_last_error = "拿起了公共书盘；F 翻页，看向另一处台面按 E 或 R 放下。"
	else:
		for feet in [_walker.global_position, _walker.global_position + _walker.velocity * delta, _resident.global_position, _resident.possible_next_position(delta), _reading_visitor.global_position, _reading_visitor.possible_next_position(delta), _cup_visitor.global_position, _cup_visitor.possible_next_position(delta)]:
			if _reading_room.placement_occupied(id, feet):
				_last_error = "放置位置有人，等让开后再放。"
				return
		if not _reading_room.place_tray(id):
			return
		_last_error = "已放到" + str(ReadingRoom.TRAY_LABELS[id]) + "；书页保留，可就近翻阅。"
	_nearest.clear()
	_interact_queued = false
	_reading_action = ""


func _move_wash_basin(delta: float) -> void:
	if _walker.is_seated():
		_last_error = "请先按 E 起身，再拿放公共盆。"
		return
	if _nearest.is_empty() or not WashShelter.ANCHORS.has(str(_nearest["id"])):
		_last_error = "看向洗择棚的接水槽、择洗台或沥水台，再按 R 拿放盆。"
		return
	var id: String = _nearest["id"]
	if not _wash_shelter.is_carrying():
		var occupied: bool = _reading_room.is_carrying() or _urban.view()["toolbox_anchor"] == "carried"
		if not _wash_shelter.take_basin(id, occupied):
			_last_error = "手里已有物品，请先归位，再拿公共盆。" if occupied else "这里没有公共盆，可以先把盆带过来。"
			return
		_sync_held()
		_last_error = "拿起公共盆；水和菜随盆移动。看向洗择棚台面按 R 放下。"
	else:
		for feet in [_walker.global_position, _walker.global_position + _walker.velocity * delta, _resident.global_position, _resident.possible_next_position(delta), _reading_visitor.global_position, _reading_visitor.possible_next_position(delta), _cup_visitor.global_position, _cup_visitor.possible_next_position(delta)]:
			if _wash_shelter.placement_occupied(id, feet):
				_last_error = "放置位置有人，稍等让开后再放盆。"
				return
		if not _wash_shelter.place_basin(id):
			return
		_last_error = "公共盆已放到" + str(WashShelter.LABELS[id]) + "。按 E 使用台面。"
	_nearest.clear()
	_interact_queued = false
	_reading_action = ""


func _build_held() -> void:
	_held = Node3D.new()
	add_child(_held)
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Workshop.TOOLBOX_SIZE
	box.mesh = mesh
	box.material_override = _materials["shop"]
	_held.add_child(box)
	_held.hide()


func _sync_held() -> void:
	var forward: Vector3 = _seated_forward if _walker.is_seated() else -_walker.interaction_camera().global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	var held_height: float = 0.78 if _walker.is_seated() else 1.12
	var held_distance: float = 0.6 if _walker.is_seated() else 0.8
	_held.position = _walker.position + Vector3.UP * held_height + forward * held_distance
	_held.rotation.y = atan2(-forward.x, -forward.z)
	_reading_room.present_carried(_held.global_position, _held.global_rotation.y)
	_wash_shelter.present_carried(_held.global_position, _held.global_rotation.y)


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
