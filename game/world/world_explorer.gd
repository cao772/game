extends Node3D
## Regional exploration slice; source only, no engine/runtime acceptance yet.

const State = preload("res://runtime/world_state.gd")
const Store = preload("res://runtime/world_save_store.gd")
const Player = preload("res://world/world_player.gd")
const Landscape = preload("res://world/world_landscape.gd")
const Actor = preload("res://world/counter_actor.gd")
const MERCHANT = preload("res://art/market_actor/merchant.glb")
const COURIER = preload("res://art/records_actor/clerk.glb")
@export_file("*.json") var atlas_path := "res://content/world_atlas.json"
@export_file("*.tscn") var story_scene := "res://scenes/explorer_dispatch.tscn"

var _state := State.new()
var _store := Store.new()
var _player: Player
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
var _landmark_names: Dictionary = {}

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
		_notice.text = "已恢复街外的上次保存。" if restored["ok"] else "存档未应用：" + restored["code"]
	elif record.get("code") != "NO_SAVES":
		_notice.text = "未能恢复旧档，当前为新起点：" + str(record.get("code"))
	_show_region()

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
	_notice = _label(box, "随处走走。路牌通往山脊与湖岸，木台上的箱子可以搬走。", 15)
	_label(box, "WASD 行走 · Shift 跑步 · 空格跳跃\n右键拖动 / ← → 转镜头 · 滚轮缩放\nE 互动 · Q 转木箱 · M 地图", 14)
	_button(box, "地图与发现 · M", _toggle_map)
	_button(box, "歇一小时", _rest)
	_button(box, "保存 · F5", _save)
	_button(box, "恢复最新保存 · F9", _request_load)
	_button(box, "整理较早存档（保留最近32份）", _archive)
	_button(box, "去登记区（先保存街外进度）", _open_story)
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
	_confirm.dialog_text = "用最近保存替换当前地点、时段和物件摆放？尚未保存的变化会丢失。"
	_confirm.confirmed.connect(_load)
	canvas.add_child(_confirm)

func _label(parent: Node, caption: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 274
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)

func _show_region() -> void:
	if _region != null:
		remove_child(_region)
		_region.queue_free()
	_projection = _state.view()
	_region = Node3D.new()
	add_child(_region)
	var landscape := Landscape.new()
	_region.add_child(landscape)
	landscape.build(_projection["current_region"]["id"])
	var player_state: Dictionary = _projection["state"]["player"]
	_player.position = _vector(player_state["position"])
	_player.velocity = Vector3.ZERO
	_player.recovery_position = _vector(_projection["current_region"]["spawn"])
	_player.set_heading(float(player_state["heading"]))
	_props = null
	_refresh_props()
	_elapsed = 0.0

func _refresh_props() -> void:
	_projection = _state.view()
	if _props != null:
		_region.remove_child(_props)
		_props.queue_free()
	_props = Node3D.new()
	_region.add_child(_props)
	_targets.clear()
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
	for npc in _projection["npcs"]:
		var actor := Actor.new()
		actor.model_scene = MERCHANT if npc["id"] == "merchant" else COURIER
		actor.position = _vector(npc["position"])
		actor.rotation.y = float(npc["heading"])
		_props.add_child(actor)
		_sign(npc["label"], actor.position + Vector3(0, 2.15, 0), Color("d5efdf"))
		_target("npc", npc["id"], "招呼" + npc["label"], actor.position, 3.0, npc["activity"])
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
	_player.controls_enabled = not _map.visible and not _confirm.visible
	if not get_window().has_focus() or not _player.controls_enabled:
		return
	_elapsed += delta
	if _elapsed >= 5.0:
		_elapsed -= 5.0
		var previous: Array = _projection["npcs"]
		_state.advance_minutes(1)
		_projection = _state.view()
		if previous != _projection["npcs"]:
			_refresh_props()
		else:
			_refresh_hud()
	_nearest = {}
	var nearest_distance := INF
	var carrying: bool = _projection["state"]["carried"] != ""
	for target in _targets:
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
	if not _ready_ok or not event is InputEventKey or not event.pressed or event.echo or _confirm.visible:
		return
	match event.physical_keycode:
		KEY_M:
			_toggle_map()
		KEY_F5:
			_save()
		KEY_F9:
			_request_load()
		KEY_Q:
			if not _map.visible:
				var result: Dictionary = _state.rotate_carried()
				if result["ok"]:
					_refresh_props()
		KEY_E:
			if not _map.visible:
				_interact()
		KEY_ESCAPE:
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
		"route":
			result = _state.travel(target["id"])
		"take":
			result = _state.take_object(target["id"])
		"place":
			result = _state.place_object(target["id"])
		"discover":
			result = _state.discover(target["id"])
		"npc":
			_notice.text = target["label"].trim_prefix("招呼") + " · " + target["detail"]
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

func _rest() -> void:
	if not _ready_ok:
		return
	var result: Dictionary = _state.advance_minutes(60)
	if result["ok"]:
		_refresh_props()
		_elapsed = 0.0
		_notice.text = "歇了一小时。可以去别处看看熟人的去向。"
	else:
		_notice.text = "未能休息：" + result["code"]

func _save() -> bool:
	if not _ready_ok or not _capture_player():
		return false
	var result: Dictionary = _store.write_record("world_free", _state.snapshot())
	_notice.text = "世界已保存，代号 %s。" % result.get("generation", "") if result["ok"] else "保存失败：" + result["code"]
	return result["ok"]

func _request_load() -> void:
	if _ready_ok:
		_player.release_pointer()
		_confirm.popup_centered()

func _load() -> void:
	var record: Dictionary = _store.read_latest("world_free")
	if not record["ok"] or not record.get("payload") is Dictionary:
		_notice.text = "未能读档：" + str(record.get("code"))
		return
	var result: Dictionary = _state.restore(record["payload"])
	if result["ok"]:
		_show_region()
	_notice.text = "已恢复地点、时段、发现和木箱摆放。" if result["ok"] else "旧档未应用：" + result["code"]

func _archive() -> void:
	if not _ready_ok:
		return
	var result: Dictionary = _store.archive_older("world_free", 32)
	_notice.text = "已归档 %d 份；较早文件仍保留。%s" % [result.get("moved", []).size(), result["code"]]

func _open_story() -> void:
	if not _save():
		return
	_player.release_pointer()
	var error := get_tree().change_scene_to_file(story_scene)
	if error != OK:
		_notice.text = "登记区暂时无法进入：%s" % error

func _toggle_map() -> void:
	if not _ready_ok:
		return
	_map.visible = not _map.visible
	_player.release_pointer()
	_refresh_hud()

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

func _vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
