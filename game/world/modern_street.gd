extends Node3D
## Independent modern street study. Metres, feet at y=0, no legacy world state.

const Walker = preload("res://world/urban_walkthrough_player.gd")
const Workshop = preload("res://world/urban_workshop.gd")
const UrbanState = preload("res://runtime/urban_state.gd")
const UrbanStore = preload("res://runtime/urban_save_store.gd")
@export_file("*.tscn") var return_scene_path: String = "res://scenes/world_explorer.tscn"

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
var _persistence_ready := false
var _dirty := false


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
	_walker = Walker.new()
	_walker.position = Vector3(0, 0, 20)
	_walker.recover_pos = Vector3(0, 0.1, 20)
	add_child(_walker)
	_build_ui()
	_build_held()
	_restore_latest(true)


func _process(_delta: float) -> void:
	if _hint != null and _walker != null:
		_hint.text = "WASD 行走 · Shift 跑步 · 空格 跳跃 · V 切视角  |  " + _walker.mode_label()
		_hint.text += "\n按住右键环视 · 松开 / Esc 释放"
		if not _last_error.is_empty():
			_hint.text += "\n" + _last_error
		var view: Dictionary = _urban.view()
		_action.text = "E：" + _target_caption(_nearest, view) if not _nearest.is_empty() else "沿东侧廊檐找到维修工坊 · 靠近并看向门、开关或工具箱"
		_action.text += " · 手持工具箱" if view["toolbox_anchor"] == "carried" else ""
		_action.text += " · 尚未保存" if _dirty else ""
		_sync_held()


func _physics_process(delta: float) -> void:
	if _walker == null or not _walker.interaction_allowed():
		_interact_queued = false
		_nearest.clear()
		return
	_nearest = _find_target()
	if _interact_queued:
		_interact_queued = false
		_interact(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _walker == null or not _walker.interaction_allowed():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E:
				_interact_queued = true
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
	var enterable: bool = side > 0 and center_z > 0
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
	_load_confirm.dialog_text = "恢复最近保存的门、照明与工具箱位置，并回到街上起点？当前未保存改动会被替换。"
	_load_confirm.confirmed.connect(_restore_latest.bind(false))
	_load_confirm.visibility_changed.connect(_update_modal_controls)
	canvas.add_child(_load_confirm)
	_leave_confirm = ConfirmationDialog.new()
	_leave_confirm.title = "不保存返回"
	_leave_confirm.dialog_text = "离开现代街区并放弃本次未保存的布置？原有存档保留。"
	_leave_confirm.confirmed.connect(_leave_without_save)
	_leave_confirm.visibility_changed.connect(_update_modal_controls)
	canvas.add_child(_leave_confirm)


func _ui_button(parent: Node, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", _font)
	button.pressed.connect(action)
	parent.add_child(button)


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
	_leave_confirm.popup_centered()


func _request_restore() -> void:
	_walker.release_pointer()
	_interact_queued = false
	_load_confirm.popup_centered()


func _update_modal_controls() -> void:
	if _load_confirm != null and _leave_confirm != null:
		_walker.controls_enabled = not (_load_confirm.visible or _leave_confirm.visible)
		if not _walker.controls_enabled:
			_interact_queued = false
			_nearest.clear()


func _save_urban() -> bool:
	if not _persistence_ready:
		_last_error = "旧街区存档尚未成功读取，暂不写入。可重试恢复，或不保存返回。"
		return false
	var saved: Dictionary = _store.write_record("urban_free", _urban.snapshot())
	if saved.get("ok", false):
		_dirty = false
		_last_error = "已保存门、照明和工具箱；下次从街上起点进入。"
	else:
		_last_error = "保存失败：%s。当前布置仍保留，可整理旧档后重试。" % saved.get("code", "UNKNOWN")
	return saved.get("ok", false)


func _restore_latest(initial: bool) -> void:
	var record: Dictionary = _store.read_latest("urban_free")
	if record.get("code") == "NO_SAVES":
		if initial:
			_persistence_ready = true
			_last_error = "东侧维修工坊已开放；门、灯和工具箱都可使用。"
		else:
			_last_error = "还没有现代街区存档；当前布置保留。"
			_last_error += "可以先保存。" if _persistence_ready else "之前的读取问题尚未解决，写入仍暂停；可不保存返回。"
	elif record.get("ok", false) and record.get("payload") is Dictionary:
		var restored: Dictionary = _urban.restore(record["payload"])
		if restored["ok"]:
			_persistence_ready = true
			_dirty = false
			_walker.reset_pose(Vector3(0, 0.1, 20))
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
	_workshop.apply_view(view)
	_sync_held()
	_held.visible = view["toolbox_anchor"] == "carried"
	_nearest.clear()
	_interact_queued = false


func _find_target() -> Dictionary:
	var eye: Vector3 = _walker.global_position + Vector3.UP * Walker.EYE_HEIGHT
	var forward: Vector3 = -_walker.interaction_camera().global_basis.z
	var view: Dictionary = _urban.view()
	var best: Dictionary = {}
	var best_score := -INF
	for target in _workshop.targets():
		var id: String = target["id"]
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
		var ray := PhysicsRayQueryParameters3D.create(eye, target["position"], 1)
		ray.hit_from_inside = true
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and not _workshop.is_gate_collider(id, hit.get("collider")):
			continue
		var score := facing * 3.0 - distance
		if score > best_score:
			best_score = score
			best = target
	return best


func _target_caption(target: Dictionary, view: Dictionary) -> String:
	var id: String = target["id"]
	match id:
		"front_gate", "back_gate":
			var opened: bool = view["front_open" if id == "front_gate" else "back_open"]
			return ("关闭" if opened else "打开") + target["label"]
		"lamp_switch":
			return "关灯" if view["lamp_on"] else "开灯"
		_:
			return "放到" + target["label"] if view["toolbox_anchor"] == "carried" else "拿起工具箱"


func _interact(delta: float) -> void:
	if _nearest.is_empty():
		return
	var id: String = _nearest["id"]
	var view: Dictionary = _urban.view()
	var result: Dictionary
	if id == "front_gate" or id == "back_gate":
		var opened: bool = view["front_open" if id == "front_gate" else "back_open"]
		if opened and (_workshop.gate_occupied(id, _walker.global_position) or _workshop.gate_occupied(id, _walker.global_position + _walker.velocity * delta)):
			_last_error = "先离开门洞，再关卷帘门。"
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
		result = _urban.place_toolbox(id)
	else:
		result = _urban.take_toolbox()
	if result["ok"]:
		_last_error = _target_caption(_nearest, view) + "，已完成。"
		_dirty = true
		_apply_urban_view()
	else:
		_last_error = "暂时无法操作：" + result["code"]


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
	var forward: Vector3 = -_walker.interaction_camera().global_basis.z
	forward.y = 0
	forward = forward.normalized()
	_held.position = _walker.position + Vector3.UP * 1.12 + forward * 0.8
	_held.rotation.y = atan2(-forward.x, -forward.z)


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
