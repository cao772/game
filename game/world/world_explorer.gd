extends Node3D
## Regional exploration slice; source only, no engine/runtime acceptance yet.

const Shore = preload("res://runtime/shore_water.gd")
const State = preload("res://runtime/world_state.gd")
const Store = preload("res://runtime/world_save_store.gd")
const Player = preload("res://world/world_player.gd")
const Landscape = preload("res://world/world_landscape.gd")
const Schedule = preload("res://runtime/resident_schedule.gd")
const Resident = preload("res://world/world_resident.gd")
const ResidentPanel = preload("res://ui/resident_panel.gd")
const MERCHANT = preload("res://art/resident_merchant/merchant.glb")
const COURIER = preload("res://art/resident_courier/courier.glb")
@export_file("*.json") var atlas_path := "res://content/world_atlas.json"
@export_file("*.tscn") var story_scene := "res://scenes/explorer_dispatch.tscn"
@export_file("*.json") var resident_routes_path := "res://content/resident_routes.json"
@export_file("*.json") var resident_lines_path := "res://content/resident_lines.json"
@export_file("*.tscn") var modern_scene := "res://scenes/modern_street.tscn"

var _state := State.new()
var _store := Store.new()
var _schedule := Schedule.new()
var _player: Player
var _landscape: Landscape
var _low := false
var _story_button: Button
var _modern_button: Button
var _wait_button: Button
var _wait_dialog: ConfirmationDialog
var _quoted_day := 0
var _quoted_minute := 0
var _shore_message := ""
var _region: Node3D
var _props: Node3D
var _held: Node3D
var _sun: DirectionalLight3D
var _title: Label
var _time: Label
var _hint: Label
var _notice: Label
var _map: PanelContainer
var _map_text: Label
var _confirm: ConfirmationDialog
var _targets: Array[Dictionary] = []
var _nearest: Dictionary = {}
var _projection: Dictionary = {}
var _elapsed := 0.0
var _ready_ok := false
enum SlotAccess { PROTECTED, EMPTY, VALID }
var _slot_access := SlotAccess.PROTECTED
var _landmark_names: Dictionary = {}
var _resident_nodes: Dictionary = {}
var _resident_views: Dictionary = {}
var _chat: ResidentPanel
var _chat_id := ""
var _follow_id := ""
var _guide: Label
var _stop_follow_button: Button

func _ready() -> void:
	_build_ui()
	var file := FileAccess.open(atlas_path, FileAccess.READ)
	if file == null or file.get_length() > 1048576:
		_notice.text = "地图资料无法读取。"
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		_notice.text = "地图资料格式错误。"
		return
	var configured: Dictionary = _state.configure(data)
	if not configured["ok"]:
		_notice.text = "地图初始化失败：" + configured["code"]
		return
	var routes: Variant = _read_optional_json(resident_routes_path)
	var lines: Variant = _read_optional_json(resident_lines_path)
	if not routes is Dictionary or not lines is Dictionary:
		_notice.text = "居民路线或交谈资料无法读取。"
		return
	configured = _schedule.configure(data, routes)
	if not configured["ok"]:
		_notice.text = "居民路线无法准备：" + configured["code"]
		return
	var resident_ids: Array = []
	for resident in data["npcs"]:
		resident_ids.append(resident["id"])
	configured = _chat.configure(lines, resident_ids)
	if not configured["ok"]:
		_notice.text = "居民交谈资料无法准备：" + configured["code"]
		return
	for landmark in data["landmarks"]:
		_landmark_names[landmark["id"]] = landmark["label"]
	_player = Player.new()
	add_child(_player)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-48, -35, 0)
	_sun.shadow_enabled = true
	add_child(_sun)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("709eae")
	atmosphere.sky_horizon_color = Color("e5d9b5")
	sky.sky_material = atmosphere
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d2dcdf")
	environment.ambient_light_energy = 0.6
	world.environment = environment
	add_child(world)
	_ready_ok = true
	var record: Dictionary = _store.read_latest("world_free")
	if record.get("ok", false) and record.get("payload") is Dictionary:
		var restored: Dictionary = _state.restore(record["payload"])
		_set_slot_access(SlotAccess.VALID if restored["ok"] else SlotAccess.PROTECTED)
		_notice.text = "已恢复街外的上次保存。" if restored["ok"] else "存档未应用：" + restored["code"]
		if restored["ok"] and record.get("code") == "RECOVERED_OLDER_RECORD":
			_notice.text += " 较新记录损坏，已回到有效的第 %d 份。" % int(record.generation)
	elif record.get("code") == "NO_SAVES":
		_set_slot_access(SlotAccess.EMPTY)
	else:
		_set_slot_access(SlotAccess.PROTECTED)
		_notice.text = "未能恢复旧档：" + str(record.get("code"))
	if _slot_access == SlotAccess.PROTECTED:
		_notice.text += " 可在现场查看；旧进度受保护，修复档案后按 F9 重读。"
	_show_region()
	_notice.text += _shore_message

func _read_optional_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 1048576:
		return null
	return JSON.parse_string(file.get_as_text())

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(290, 0)
	canvas.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_title = _label(box, "正在展开地图", 22)
	_time = _label(box, "", 16)
	_hint = _label(box, "", 17)
	_guide = _label(box, "", 15)
	_guide.hide()
	_stop_follow_button = _button(box, "不再同行", _stop_follow)
	_stop_follow_button.hide()
	_notice = _label(box, "随处走走。路牌通往山脊与湖岸，木台上的箱子可以搬走。", 15)
	_label(box, "WASD 行走 · Shift 跑步 · 空格跳跃\n右键拖动 / ← → 转镜头 · 滚轮缩放\nE 互动 · Q 转木箱 · M 地图", 14)
	_button(box, "地图与发现 · M", _toggle_map)
	_button(box, "歇一小时", _rest)
	_wait_button = _button(box, "在岸上候水", _offer_wait)
	_wait_button.hide()
	_button(box, "保存 · F5", _save)
	_button(box, "恢复最新保存 · F9", _request_load)
	_button(box, "整理较早存档（保留最近32份）", _archive)
	_story_button = _button(box, "去登记区", _open_story)
	_modern_button = _button(box, "去现代街区", _open_modern)
	_map = PanelContainer.new()
	_map.position = Vector2(335, 28)
	_map.custom_minimum_size = Vector2(650, 0)
	canvas.add_child(_map)
	var map_box := VBoxContainer.new()
	_map.add_child(map_box)
	_map_text = _label(map_box, "", 18)
	_map_text.custom_minimum_size.x = 620
	_button(map_box, "收起地图", _toggle_map)
	_map.hide()
	_confirm = ConfirmationDialog.new()
	_confirm.title = "恢复世界"
	_confirm.dialog_text = "用最近保存替换当前地点、时段和物件摆放？尚未保存的变化会丢失。\n读档会回到保存时的整分钟，并结束当前交谈和同行提示。"
	_confirm.confirmed.connect(_load)
	canvas.add_child(_confirm)
	_wait_dialog = ConfirmationDialog.new()
	_wait_dialog.title = "在干岸候水"
	_wait_dialog.get_ok_button().text = "留在岸上等候"
	_wait_dialog.get_cancel_button().text = "现在就走"
	_wait_dialog.confirmed.connect(_accept_wait)
	canvas.add_child(_wait_dialog)
	_chat = ResidentPanel.new()
	canvas.add_child(_chat)
	_chat.closed.connect(_close_chat)
	_chat.directions_requested.connect(_resident_directions)
	_chat.follow_requested.connect(_follow_resident)
	_chat.departure_requested.connect(_wait_for_departure)

func _label(parent: Node, caption: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 274
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _set_slot_access(access: SlotAccess) -> void:
	_slot_access = access
	var exit_note := "（不保存街外进度）" if access == SlotAccess.PROTECTED else "（先保存街外进度）"
	_story_button.text = "去登记区" + exit_note
	_modern_button.text = "去现代街区" + exit_note

func _show_region() -> void:
	_close_chat()
	_clear_residents()
	if _region != null:
		remove_child(_region)
		_region.queue_free()
	_projection = _state.view()
	_region = Node3D.new()
	add_child(_region)
	_landscape = Landscape.new()
	_region.add_child(_landscape)
	_low = Shore.is_low(int(_projection["state"]["clock"]["day"]))
	var player_state: Dictionary = _projection["state"]["player"]
	_player.position = _vector(player_state["position"])
	_player.velocity = Vector3.ZERO
	_player.recovery_position = _vector(_projection["current_region"]["spawn"])
	_player.set_heading(float(player_state["heading"]))
	_shore_message = ""
	if _at_shore():
		_secure_shore_feet(_low)
	_landscape.build(_projection["current_region"]["id"],_low)
	_props = null
	_elapsed = 0.0
	_refresh_props()
	_update_residents(false)

func _refresh_props() -> void:
	_projection = _state.view()
	if _props != null:
		_region.remove_child(_props)
		_props.queue_free()
	_props = Node3D.new()
	_region.add_child(_props)
	_targets.clear()
	if _at_shore():
		if _low:
			_target("inspect_eye", "shore_mooring_eye", "俯看旧缆眼", Vector3(12.85,-0.4,0.8), 1.65,
				"孔底留着一弯泥。东侧的铁边磨得发亮，顺着绳槽望去，正对旧栈桥的系船桩。")
		for z in [Shore.NORTH-0.7,Shore.SOUTH+0.7]:
			_sign(("低水 · 可带箱穿湾" if _low else "平水 · 湾口已淹") + "\n干路沿东侧栈桥", Vector3(13.7,1.55,z), Color("e5e3bb"))
		_sign("候水石坪",Shore.WAIT_AT+Vector3.UP*0.95,Color("deceab"))
	for route in _projection["routes"]:
		var at := _vector(route["exit"])
		_sign(route["label"], at + Vector3(0, 1.9, 0), Color("ffe5a1"))
		_target("route", route["id"], route["label"], at, 4.0)
	for item in _projection["anchors"]:
		var at := _vector(item["position"])
		_box(_props, at + Vector3(0, 0.025, 0), Vector3(1.7, 0.05, 1.7), Color("c5b17c"), false)
		if item["occupied_by"] == "":
			_target("place", item["id"], "放到" + item["label"], at, 3.0)
	for item in _projection["objects"]:
		var object := _crate(item["id"], true)
		_props.add_child(object)
		object.position = _vector(item["position"])
		object.rotation.y = int(item["quarter_turns"]) * PI / 2.0
		_target("take", item["id"], "拿起" + item["label"], object.position, 3.0)
	for item in _projection["landmarks"]:
		var at := _vector(item["position"])
		_sign(item["label"] + (" · 已记录" if item["visited"] else ""), at + Vector3(0, 2.4, 0), Color("f5edcc"))
		_target("discover", item["id"], "看看" + item["label"], at, float(item["radius"]), item["description"])
	if _held != null:
		remove_child(_held)
		_held.queue_free()
		_held = null
	var carried: String = _projection["state"]["carried"]
	if not carried.is_empty():
		_held = _crate(carried, false)
		add_child(_held)
		_sync_held()
	_refresh_hud()
	_nearest = {}

func _crate(id: String, solid: bool) -> Node3D:
	var root := Node3D.new()
	_box(root, Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.9), Color("be935d") if id == "crate_a" else Color("8c7963"), solid)
	_box(root, Vector3(0, 0.46, 0), Vector3(0.15, 0.94, 0.94), Color("e3c292") if id == "crate_a" else Color("438896"), false)
	# An off-center seal makes the quarter-turn placement observable.
	_box(root, Vector3(0.22, 0.7, 0.46), Vector3(0.23, 0.16, 0.02), Color("eee1af"), false)
	return root

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color, solid: bool) -> void:
	var mesh := MeshInstance3D.new()
	var geometry := BoxMesh.new()
	geometry.size = size
	mesh.mesh = geometry
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		mesh.add_child(body)

func _sign(text: String, at: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.modulate = color
	label.font_size = 34
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_props.add_child(label)

func _target(kind: String, id: String, label: String, at: Vector3, radius: float, detail: String = "") -> void:
	_targets.append({"kind": kind, "id": id, "label": label, "position": at, "radius": radius, "detail": detail})

func _physics_process(delta: float) -> void:
	if not _ready_ok:
		return
	_sync_held()
	_player.controls_enabled = not _map.visible and not _confirm.visible and not _wait_dialog.visible and not _chat.visible
	_update_wait_button()
	var paused := not get_window().has_focus() or not _player.controls_enabled
	if not paused:
		_elapsed = minf(_elapsed + delta, 5.1)
		if _elapsed >= 5.0:
			var advanced: Dictionary = _advance_time(1)
			_elapsed = _elapsed - 5.0 if advanced["ok"] else 0.0
			if _shore_message != "":
				_notice.text = _shore_message
			_refresh_hud()
	_update_residents(paused)
	if paused:
		return
	_nearest = {}
	var nearest_distance := INF
	var carrying: bool = _projection["state"]["carried"] != ""
	var candidates: Array[Dictionary] = _targets.duplicate()
	for id in _resident_nodes:
		var actor: Resident = _resident_nodes[id]
		var resident: Dictionary = _resident_views[id]
		candidates.append({"kind": "npc", "id": id, "label": "招呼" + resident["label"], "position": actor.global_position, "radius": 3.0})
	for target in candidates:
		if (target["kind"] == "place" and not carrying) or (target["kind"] == "take" and carrying):
			continue
		var distance := _player.position.distance_to(target["position"])
		if distance <= float(target["radius"]) and distance < nearest_distance:
			nearest_distance = distance
			_nearest = target
	_hint.text = "E · " + str(_nearest["label"]) if not _nearest.is_empty() else "沿路牌探索，或搬一只木箱试试。"
	if carrying:
		_hint.text += "\nQ · 转木箱；空木台可放下"

func _sync_held() -> void:
	if _held == null:
		return
	_held.position = _player.position + Vector3(0, 0.65, 0.95).rotated(Vector3.UP, _player.facing())
	_held.rotation.y = int(_projection["state"]["objects"][_projection["state"]["carried"]]["quarter_turns"]) * PI / 2.0

func _unhandled_key_input(event: InputEvent) -> void:
	if not _ready_ok or not event is InputEventKey or not event.pressed or event.echo or _confirm.visible or _wait_dialog.visible:
		return
	match event.physical_keycode:
		KEY_M:
			_toggle_map()
		KEY_F5:
			_save()
		KEY_F9:
			_request_load()
		KEY_Q:
			if not _map.visible and not _chat.visible:
				var result: Dictionary = _state.rotate_carried()
				if result["ok"]:
					_refresh_props()
		KEY_E:
			if not _map.visible and not _chat.visible:
				_interact()
		KEY_ESCAPE:
			_close_chat()
			_map.hide()
			_player.release_pointer()

func _capture_player() -> bool:
	var p := _player.position
	var result: Dictionary = _state.set_player([p.x, p.y, p.z], _player.heading())
	if not result["ok"]:
		_notice.text = "当前位置暂不能保存或互动：" + result["code"]
	return result["ok"]

func _interact() -> void:
	if _nearest.is_empty() or not _capture_player():
		return
	var target: Dictionary = _nearest.duplicate()
	if _player.position.distance_to(target["position"]) > float(target["radius"]):
		return
	var result: Dictionary
	match target["kind"]:
		"inspect_eye":
			if _at_shore() and _low:
				_notice.text = target["detail"]
			return
		"route":
			result = _state.travel(target["id"])
		"take":
			result = _state.take_object(target["id"])
		"place":
			result = _state.place_object(target["id"])
		"discover":
			result = _state.discover(target["id"])
		"npc":
			_open_chat(target["id"])
			return
		_:
			return
	if not result["ok"]:
		_notice.text = "暂时办不到：" + result["code"]
		return
	if target["kind"] == "route":
		_show_region()
		_notice.text = _projection["current_region"]["description"]
	else:
		_refresh_props()
		_notice.text = target["detail"] if target["kind"] == "discover" else target["label"] + "。这次摆放可随世界保存。"
		if target["id"] == "shore_tide_mark":
			_notice.text += " 石上指片指在低水。桥下格栅露出，带箱也能沿石带穿湾。" if _low else " 石上指片指在平水。湖水浸到桥下格栅上沿，沿东侧木栈桥绕湾。"
			_notice.text += " 石旁浅色石坪可以候到下一次换水。"

func _at_shore() -> bool:
	return _projection["current_region"]["id"] == "SHORE"

func _secure_shore_feet(low: bool) -> void:
	var safe := Shore.safe_feet(_player.position,low)
	if safe != _player.position:
		_player.position = safe
		_player.velocity = Vector3.ZERO
		_state.set_player([safe.x,safe.y,safe.z],_player.heading())
		_shore_message = " 湖岸脚位已移回可落脚处，随身物件一起带到了。"

func _advance_time(minutes: int) -> Dictionary:
	var result: Dictionary = _state.advance_minutes(minutes)
	_shore_message = ""
	if not result["ok"]:
		return result
	_projection = _state.view()
	if _at_shore():
		var low := Shore.is_low(int(_projection["state"]["clock"]["day"]))
		if low != _low:
			_secure_shore_feet(low)
			_low = low
			_landscape.set_shore_level(low)
			_refresh_props()
	return result

func _can_wait() -> bool:
	return _at_shore() and _player.is_on_floor() and _player.position.distance_to(Shore.WAIT_AT) <= Shore.WAIT_RADIUS and not _chat.visible and not _map.visible and not _confirm.visible

func _update_wait_button() -> void:
	_wait_button.visible = _can_wait() and not _wait_dialog.visible
	if not _wait_button.visible:
		return
	var clock: Dictionary = _projection["state"]["clock"]
	var cost := Shore.next_change(int(clock.day),int(clock.minute),State.MAX_DAY)
	_wait_button.disabled = cost == 0
	_wait_button.text = "候到%s · 经过 %d 分钟" % [Shore.water_name(not _low),cost] if cost > 0 else "日历已到尽头 · 可走干岸"

func _offer_wait() -> void:
	if not _can_wait() or _wait_dialog.visible:
		return
	var clock: Dictionary = _projection["state"]["clock"]
	var cost := Shore.next_change(int(clock.day),int(clock.minute),State.MAX_DAY)
	if cost == 0:
		return
	_quoted_day = int(clock.day)
	_quoted_minute = int(clock.minute)
	var next_day := _quoted_day + floori(float(_quoted_minute + cost) / 1440.0)
	_wait_dialog.dialog_text = "留在高岸等 %d 个世界分钟？第 %d 天 00:00 转为%s，居民也会按这段时间前往新的位置。" % [cost,next_day,Shore.water_name(not _low)]
	_player.controls_enabled = false
	_player.release_pointer()
	_wait_dialog.popup_centered()

func _accept_wait() -> void:
	var clock: Dictionary = _projection["state"]["clock"]
	if not _can_wait() or _quoted_day != int(clock.day) or _quoted_minute != int(clock.minute):
		return
	var cost := Shore.next_change(_quoted_day,_quoted_minute,State.MAX_DAY)
	_quoted_day = 0
	if cost <= 0:
		return
	var result := _advance_time(cost)
	if result.ok:
		_elapsed = 0.0
		_clear_residents()
		_update_residents(false)
		_refresh_hud()
		_notice.text = "岸边过了 %d 分钟，如今是%s。" % [cost,Shore.water_name(_low)]

func _rest() -> void:
	if not _ready_ok:
		return
	if _chat.visible:
		_notice.text = "先道别，再找地方休息。"
		return
	var result: Dictionary = _advance_time(60)
	if result["ok"]:
		_elapsed = 0.0
		_clear_residents()
		_refresh_props()
		_update_residents(_map.visible)
		_notice.text = "歇了一小时。可以去别处看看熟人的去向。" + _shore_message
	else:
		_notice.text = "未能休息：" + result["code"]

func _save() -> bool:
	if _slot_access == SlotAccess.PROTECTED:
		_notice.text = "旧世界尚未成功恢复，当前不会保存街外进度。可去其他区域，或修复档案后按 F9 重读。"
		return false
	if not _ready_ok or not _capture_player():
		return false
	var result: Dictionary = _store.write_record("world_free", _state.snapshot())
	if result["ok"]:
		_set_slot_access(SlotAccess.VALID)
	_notice.text = "世界已保存，代号 %s。" % result.get("generation", "") if result["ok"] else "保存失败：" + result["code"]
	return result["ok"]

func _request_load() -> void:
	if _ready_ok:
		_player.release_pointer()
		_confirm.popup_centered()

func _load() -> void:
	var record: Dictionary = _store.read_latest("world_free")
	if not record["ok"] or not record.get("payload") is Dictionary:
		if record.get("code") != "NO_SAVES" or _slot_access != SlotAccess.EMPTY:
			_set_slot_access(SlotAccess.PROTECTED)
		_notice.text = "未能读档：" + str(record.get("code"))
		return
	var result: Dictionary = _state.restore(record["payload"])
	if result["ok"]:
		_set_slot_access(SlotAccess.VALID)
		_stop_follow()
		_show_region()
	else:
		_set_slot_access(SlotAccess.PROTECTED)
	_notice.text = "已恢复地点、时段、发现和木箱摆放。" + _shore_message if result["ok"] else "旧档未应用：" + result["code"]

	if result["ok"] and record.get("code") == "RECOVERED_OLDER_RECORD":
		_notice.text += " 较新记录损坏，已回到有效的第 %d 份。" % int(record.generation)

func _archive() -> void:
	if _slot_access == SlotAccess.PROTECTED:
		_notice.text = "请先恢复旧世界，再整理存档。"
		return
	if not _ready_ok:
		return
	var result: Dictionary = _store.archive_older("world_free", 32)
	_notice.text = "已归档 %d 份；较早文件仍保留。%s" % [result.get("moved", []).size(), result["code"]]

func _open_story() -> void:
	if not _ready_ok or (_slot_access != SlotAccess.PROTECTED and not _save()):
		return
	_close_chat()
	_player.release_pointer()
	var error := get_tree().change_scene_to_file(story_scene)
	if error != OK:
		_notice.text = "登记区暂时无法进入：%s" % error

func _toggle_map() -> void:
	if not _ready_ok:
		return
	_close_chat()
	_map.visible = not _map.visible
	_player.release_pointer()
	_refresh_hud()

func _open_modern() -> void:
	if not _ready_ok or (_slot_access != SlotAccess.PROTECTED and not _save()):
		return
	_close_chat()
	_player.release_pointer()
	var error := get_tree().change_scene_to_file(modern_scene)
	if error != OK:
		_notice.text = "现代街区暂时无法进入：%s" % error

func _refresh_hud() -> void:
	var state: Dictionary = _projection["state"]
	var clock: Dictionary = state["clock"]
	var minute: int = int(clock["minute"])
	_title.text = _projection["current_region"]["label"]
	_time.text = "第 %d 天 · %02d:%02d · 已发现 %d / %d" % [clock["day"], int(minute / 60.0), minute % 60, state["visited"].size(), _landmark_names.size()]
	_sun.light_energy = 0.25 + 0.9 * maxf(0.0, sin((minute - 360) * TAU / 1440.0))
	var route_names: PackedStringArray = []
	for route in _projection["routes"]:
		route_names.append("• " + route["label"] + "（约%d分钟）" % route["travel_minutes"])
	var discovered: PackedStringArray = []
	for id in state["visited"]:
		discovered.append(_landmark_names.get(id, "未命名地点"))
	_map_text.text = "街外路线\n\n登记街区 ↔ 风脊步道 ↔ 湖岸码头 ↔ 登记街区\n\n当前位置：" + _title.text + "\n" + "\n".join(route_names) + "\n\n路口可直接通行。木箱能随身跨区，放到空木台上。\n地图和读档窗口打开时，世界时钟暂停。\n\n发现记录：" + ("、".join(discovered) if not discovered.is_empty() else "还没有。走近地标，按 E 看看。")
	_map_text.text += "\n\n居民也沿道路去工作和休息。走近打招呼，可以问去向或陪走一段；交谈时钟暂停，结束后继续。"
	_map_text.text += "\n同行会提示去向，需要自己走；可以随时取消。读档会结束同行提示。"

func _update_residents(paused: bool) -> void:
	var clock: Dictionary = _projection["state"]["clock"]
	var projected: Dictionary = _schedule.project(int(clock["day"]), float(clock["minute"]) + _elapsed / 5.0)
	if not projected.get("ok", false):
		_notice.text = "居民日程暂不可用：" + str(projected.get("code"))
		return
	_resident_views.clear()
	var wanted: Dictionary = {}
	for resident in projected["residents"]:
		var id: String = resident["id"]
		_resident_views[id] = resident
		if resident["region"] != _projection["current_region"]["id"]:
			continue
		wanted[id] = true
		if not _resident_nodes.has(id):
			var created_actor := Resident.new()
			created_actor.configure(MERCHANT if id == "merchant" else COURIER)
			# Place before entering the physics tree: spawns/restores must not sweep
			# an animatable collider across the region from the origin.
			created_actor.position = _vector(resident["position"])
			created_actor.rotation.y = float(resident["heading"])
			_region.add_child(created_actor)
			_resident_nodes[id] = created_actor
			var nameplate := Label3D.new()
			nameplate.name = "Nameplate"
			nameplate.position.y = 2.15
			nameplate.font_size = 34
			nameplate.pixel_size = 0.008
			nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			nameplate.modulate = Color("d5efdf")
			created_actor.add_child(nameplate)
		var actor: Resident = _resident_nodes[id]
		actor.apply_projection(_vector(resident["position"]), float(resident["heading"]), bool(resident["moving"]) and not paused)
		var plate: Label3D = actor.get_node("Nameplate")
		plate.text = resident["label"] + (" · 同行" if _follow_id == id else "")
	for id in _resident_nodes.keys():
		if not wanted.has(id):
			var retired_actor: Resident = _resident_nodes[id]
			retired_actor.get_parent().remove_child(retired_actor)
			retired_actor.queue_free()
			_resident_nodes.erase(id)
	_refresh_follow()

func _clear_residents() -> void:
	for actor in _resident_nodes.values():
		actor.get_parent().remove_child(actor)
		actor.queue_free()
	_resident_nodes.clear()
	_resident_views.clear()

func _open_chat(id: String) -> void:
	if _chat.visible or not _resident_nodes.has(id) or not _resident_views.has(id):
		return
	var actor: Resident = _resident_nodes[id]
	if _player.global_position.distance_to(actor.global_position) > 3.0:
		_notice.text = "对方已经走远了。靠近再打招呼。"
		return
	if not _chat.open_resident(_resident_views[id]):
		return
	_chat_id = id
	actor.set_conversing(true)
	_map.hide()
	_player.controls_enabled = false
	_player.release_pointer()
	_hint.text = "正在交谈 · Esc 告辞"

func _close_chat() -> void:
	if _resident_nodes.has(_chat_id):
		_resident_nodes[_chat_id].set_conversing(false)
	_chat_id = ""
	if _chat != null:
		_chat.close_panel()

func _resident_directions(id: String) -> void:
	if not _chat.visible or id != _chat_id or not _resident_views.has(id):
		return
	var resident: Dictionary = _resident_views[id]
	var text: String
	if resident["moving"]:
		text = "正往%s去。%s。想一起走的话，跟着我就行。" % [resident["destination"], resident["activity"]]
	else:
		var wait_minutes: int = int(ceil(float(resident.get("departure_in_minutes", 0))))
		text = "现在还在这儿忙，大约 %d 分钟后去%s。你也可以先去别处逛，不用等我。" % [wait_minutes, resident["destination"]]
	_chat.show_directions(text)

func _follow_resident(id: String) -> void:
	if not _chat.visible or id != _chat_id or not _resident_views.has(id):
		return
	_follow_id = id
	_close_chat()
	_refresh_follow()
	_notice.text = "记住了同行人的去向。你可以陪走，也可以随时改道。"

func _wait_for_departure(id: String) -> void:
	if not _chat.visible or id != _chat_id or not _resident_views.has(id):
		return
	var resident: Dictionary = _resident_views[id]
	if resident["moving"]:
		return
	var minutes: int = int(ceil(float(resident["departure_in_minutes"])))
	var advanced: Dictionary = _advance_time(minutes)
	if not advanced["ok"]:
		_notice.text = "暂时不能等待：" + str(advanced["code"])
		return
	_follow_id = id
	_close_chat()
	_elapsed = 0.0
	_clear_residents()
	_refresh_props()
	_update_residents(false)
	_notice.text = "等到了出发的时候。可以陪走，也可以随时改道。" + _shore_message

func _stop_follow() -> void:
	_follow_id = ""
	if _guide != null:
		_guide.hide()
		_stop_follow_button.hide()

func _refresh_follow() -> void:
	if _follow_id.is_empty() or not _resident_views.has(_follow_id):
		return
	var resident: Dictionary = _resident_views[_follow_id]
	var description: String = resident["activity"]
	if _resident_nodes.has(_follow_id):
		var actor: Resident = _resident_nodes[_follow_id]
		description = "%dm · %s" % [int(ceil(_player.global_position.distance_to(actor.global_position))), description]
	else:
		description = "已到另一片区域。"
		for route in _projection["routes"]:
			if route["to"] == resident["region"]:
				description = "已离开这里，可" + route["label"] + "。"
				break
	_guide.text = "同行：" + resident["label"] + "\n" + description
	_guide.show()
	_stop_follow_button.show()

func _vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
