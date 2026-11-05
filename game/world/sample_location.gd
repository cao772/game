extends Node3D
## One persistent scene owner. Synthetic content only; source-authored, NOT_RUN.
const Application = preload("res://runtime/quest_application.gd")
const Player = preload("res://world/sample_player.gd")
const Observation = preload("res://world/quest_observation_area.gd")
const Dialogue = preload("res://ui/quest_dialogue_panel.gd")
const CounterActor = preload("res://world/counter_actor.gd")
const Counter = preload("res://scenes/dispatch_counter.tscn")
const Parcel = preload("res://scenes/sample_parcel.tscn")

# Variants can change performance copy without changing quest facts or save data.
@export_file("*.json") var definition_path := "res://content/synthetic_delivery.json"
@export_file("*.json") var presentation_path := "res://content/synthetic_presentation.json"
@export var clerk_name := "签收员"
@export_multiline var early_greeting := "东西从入口领。我给你留了桌上这块空地方。"
@export var receipt_messages: Dictionary = {}
@export var terminal_notes: Dictionary = {}

const SPAWN := Vector3(0, 1, 5)

var _application: Application = Application.new()
var _player: Player
var _camera: Camera3D
var _overview: Transform3D
var _receipt_line: Label
var _dialogue: Dialogue
var _dialogue_box: VBoxContainer
var _journal: Label
var _hint: Label
var _notice: Label
var _generation: SpinBox
var _confirm: ConfirmationDialog
var _pending: String = ""
var _pending_revision: int = 0
var _pending_generation: int = 0
var _stations: Array[Dictionary] = []
var _target: int = -1
var _opened: bool = false
var _ready_ok: bool = false
var _actor: CounterActor
var _carried: Node3D
var _received: Node3D
var _recipient_index: int
var _recipient_label: Label3D
var _mode_button: Button

func _ready() -> void:
	_build_world()
	_build_ui()
	var definition: Variant = _read_json(definition_path)
	var presentation: Variant = _read_json(presentation_path)
	if typeof(definition) != TYPE_DICTIONARY or typeof(presentation) != TYPE_DICTIONARY:
		_notice.text = "任务资料无法读取。请检查安装文件。"
		_player.controls_enabled = false
		return
	var result: Dictionary = _application.configure(definition, presentation)
	_ready_ok = result.get("ok", false)
	if not _ready_ok:
		_notice.text = "任务初始化失败：" + str(result.get("code", "UNKNOWN"))
		_player.controls_enabled = false
		return
	_dialogue.bind_application(_application)
	_refresh()

func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 1048576:
		return null
	return JSON.parse_string(file.get_as_text())

func _build_world() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(24, 1, 20), Color("263b45"), true)
	_box(Vector3(-12, 1, 0), Vector3(0.5, 3, 20), Color("526874"), true)
	_box(Vector3(12, 1, 0), Vector3(0.5, 3, 20), Color("526874"), true)
	_box(Vector3(0, 1, -10), Vector3(24, 3, 0.5), Color("526874"), true)
	_box(Vector3(0, 1, 10), Vector3(24, 3, 0.5), Color("526874"), true)
	_player = Player.new()
	_player.position = SPAWN
	_player.collision_layer = 2
	_player.collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	shape.shape = capsule
	_player.add_child(shape)
	var mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.35
	capsule_mesh.height = 1.6
	mesh.mesh = capsule_mesh
	mesh.material_override = _material(Color("f4cc78"))
	_player.add_child(mesh)
	add_child(_player)
	_carried = Parcel.instantiate() as Node3D
	_carried.name = "CarriedParcel"
	_carried.position = Vector3(0.34, -0.08, 0.12)
	_carried.visible = false
	_player.add_child(_carried)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.position = Vector3(0, 23, 18)
	_camera.look_at(Vector3.ZERO)
	_camera.current = true
	_overview = _camera.transform
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, -25, 0)
	light.light_energy = 1.4
	add_child(light)
	_station("领取与路线选择", Vector3(0, 0, 3), "")
	_station("查看左侧路线", Vector3(-7, 0, 0), "LOOK_AT_ROUTE_A")
	_station("查看右侧路线", Vector3(7, 0, 0), "LOOK_AT_ROUTE_B")
	_station("询问协助者", Vector3(-5, 0, -5), "SPEAK_TO_HELPER")
	var counter := Counter.instantiate() as Node3D
	counter.position = Vector3(0, 0, -7)
	add_child(counter)
	_actor = CounterActor.new()
	counter.get_node("ActorAnchor").add_child(_actor)
	_received = Parcel.instantiate() as Node3D
	_received.visible = false
	counter.get_node("ParcelAnchor").add_child(_received)
	_recipient_label = _sign(clerk_name)
	counter.get_node("SignAnchor").add_child(_recipient_label)
	_recipient_index = _stations.size()
	_register_station("与" + clerk_name + "交谈", counter.position + Vector3(0, 0, 0.45), "")

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material

func _box(at: Vector3, size: Vector3, color: Color, solid: bool) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var geometry := BoxMesh.new()
	geometry.size = size
	mesh.mesh = geometry
	mesh.material_override = _material(color)
	mesh.position = at
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		mesh.add_child(body)
	return mesh

func _station(caption: String, at: Vector3, observation: String) -> void:
	_box(at + Vector3(0, 0.35, 0), Vector3(1, 0.7, 1), Color("75adc0"), true)
	var label := _sign(caption)
	label.position = at + Vector3(0, 2, 0)
	add_child(label)
	_register_station(caption, at, observation)

func _sign(caption: String) -> Label3D:
	var label := Label3D.new()
	label.text = caption
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	return label

func _register_station(caption: String, at: Vector3, observation: String) -> void:
	var area := Observation.new()
	area.interaction_id = observation
	area.collision_layer = 0
	area.collision_mask = 2
	area.position = at + Vector3(0, 1, 0)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.2
	shape.shape = sphere
	area.add_child(shape)
	add_child(area)
	_stations.append({"caption": caption, "area": area})

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(350, 0)
	canvas.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(374, 740)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	_journal = _label(column, "")
	_label(column, "WASD 移动 · E 交互 · Esc 关闭对话\n在蓝色路标附近查看线索；到亮灯的柜台交件。")
	_hint = _label(column, "")
	_notice = _label(column, "任务进度需手动保存；位置不保存。")
	_button(column, "保存当前模式", _save)
	_button(column, "恢复最新存档…", _request.bind("load"))
	_mode_button = _button(column, "进入章节重玩…", _request.bind("mode"))
	_button(column, "归档较早存档…", _request.bind("archive"))
	_label(column, "按归档代号恢复（仅当前模式）")
	_generation = SpinBox.new()
	_generation.min_value = 1
	_generation.max_value = 2147483647
	_generation.step = 1
	column.add_child(_generation)
	_button(column, "恢复指定归档…", _request.bind("restore"))
	_dialogue_box = VBoxContainer.new()
	column.add_child(_dialogue_box)
	_dialogue = Dialogue.new()
	_dialogue_box.add_child(_dialogue)
	_receipt_line = _label(_dialogue_box, "")
	_receipt_line.hide()
	_dialogue.command_finished.connect(_after_choice)
	_button(_dialogue_box, "结束交谈", _close_dialogue)
	_dialogue_box.hide()
	_confirm = ConfirmationDialog.new()
	_confirm.title = "确认存档操作"
	_confirm.confirmed.connect(_execute_pending)
	_confirm.canceled.connect(_cancel_pending)
	canvas.add_child(_confirm)

func _label(parent: Node, caption: String) -> Label:
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 350
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _physics_process(_delta: float) -> void:
	if not _ready_ok:
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	_player.controls_enabled = not _opened and not _confirm.visible and not (focus is LineEdit)
	_target = -1
	var distance: float = INF
	for index in range(_stations.size()):
		var area: Observation = _stations[index]["area"]
		var candidate: float = area.global_position.distance_squared_to(_player.global_position)
		if area.overlaps_body(_player) and candidate < distance:
			distance = candidate
			_target = index
	_hint.text = "靠近路标或亮灯的柜台。" if _target < 0 else "E · " + str(_stations[_target]["caption"])

func _unhandled_key_input(event: InputEvent) -> void:
	if not _ready_ok or _confirm.visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		_close_dialogue()
	elif event.physical_keycode == KEY_E and not _opened and _target >= 0:
		_interact()

func _interact() -> void:
	var view: Dictionary = _application.present()
	var area: Observation = _stations[_target]["area"]
	if not area.overlaps_body(_player):
		return
	if not area.interaction_id.is_empty():
		var result: Dictionary = area.interact(_player, _application, view["revision"])
		_report(result, "已记下这条线索。回领取点选择行动。")
		_refresh()
		return
	var needs_recipient: bool = view["node"] == "ARRIVE" or view["terminal"]
	if (_target == _recipient_index) != needs_recipient:
		_notice.text = "请到收件处交付。" if needs_recipient else clerk_name + "：" + early_greeting
		return
	if _target == _recipient_index:
		_camera.position = Vector3(3.2, 2.8, -3.4)
		_camera.look_at(Vector3(-0.2, 1.1, -7.65))
		if view["terminal"]:
			_actor.acknowledge(false)
	_opened = true
	_player.velocity = Vector3.ZERO
	_player.controls_enabled = false
	_dialogue.refresh()
	_dialogue_box.show()

func _close_dialogue() -> void:
	_opened = false
	_camera.transform = _overview
	_receipt_line.hide()
	_dialogue.show()
	_dialogue_box.hide()

func _after_choice(result: Dictionary) -> void:
	# A successful choice at this counter is the handover; restoring a snapshot
	# calls _refresh directly and must never replay that one-shot.
	var view := _application.present()
	var just_delivered: bool = result.get("ok", false) and _opened and view.get("terminal", false)
	var feedback := "行动已记录；完成后记得保存。"
	if just_delivered:
		_actor.acknowledge(true)
		feedback = clerk_name + "：" + str(receipt_messages.get(view["node"], "对上了。包裹我留下，这一栏我来签。"))
		# Hold the counter view until dismissed, so the player can see the gesture
		# and read the response. The next explicit visit gets the terminal dialogue.
		_receipt_line.text = feedback
		_dialogue.hide()
		_receipt_line.show()
		_report(result, "已签收；任务进度可保存。")
	else:
		_report(result, feedback)
		_close_dialogue()
	_refresh()

func _refresh() -> void:
	var view: Dictionary = _application.present()
	var objectives := {"": "前往领取点开始任务", "PREPARE": "领取物品", "PLAN": "探索路线或寻找协助，再回领取点决定", "REST": "回领取点重新规划", "ARRIVE": "走到收件处交付"}
	var entry := str(terminal_notes.get(view["node"], "已签收")) if view["terminal"] else "收件处"
	_journal.text = ("自由模式" if view["mode"] == "free" else "章节重玩") + "\n" + (entry + "，可保存并回访" if view["terminal"] else str(objectives.get(view["node"], "前往领取点开始任务")))
	_mode_button.text = "进入章节重玩…" if view["mode"] == "free" else "返回自由模式…"
	_carried.visible = view["node"] in ["PLAN", "REST", "ARRIVE"]
	_received.visible = view["terminal"]
	_recipient_label.text = clerk_name + " · " + entry
	_dialogue.refresh()

func _save() -> void:
	if _ready_ok and not _confirm.visible:
		_report(_application.save(_application.present()["revision"]), "当前任务进度已保存。")

func _request(command: String) -> void:
	if not _ready_ok or _confirm.visible:
		return
	_close_dialogue()
	_pending = command
	_pending_revision = _application.present()["revision"]
	_pending_generation = int(_generation.value)
	_confirm.dialog_text = "恢复会替换当前模式未保存的任务进度，并将角色放回入口。是否继续？"
	if command == "mode":
		_confirm.dialog_text = "先保存当前模式，再切换。进入章节会开始新的重玩；可随后恢复章节存档。是否继续？"
	elif command == "archive":
		_confirm.dialog_text = "保留最近 32 份有效活动档，将更早有效档移入归档；不删除文件。是否继续？"
	_confirm.popup_centered(Vector2i(520, 180))
	_player.controls_enabled = false
	_player.velocity = Vector3.ZERO

func _cancel_pending() -> void:
	_pending = ""

func _execute_pending() -> void:
	var result: Dictionary
	var command: String = _pending
	_pending = ""
	match command:
		"load": result = _application.load_latest(_pending_revision)
		"restore": result = _application.load_archived(_pending_generation, _pending_revision)
		"archive": result = _application.archive_saves(_pending_revision)
		"mode":
			if _application.present()["mode"] == "free":
				result = _application.enter_chapter(_pending_revision)
			else:
				result = _application.leave_chapter(_pending_revision)
		_: return
	if result.get("ok", false) and command != "archive":
		_target = -1
		_actor.reset_pose()
		_player.position = SPAWN
		_player.velocity = Vector3.ZERO
	_report(result, "操作完成。")
	_refresh()

func _report(result: Dictionary, success: String) -> void:
	_notice.text = success if result.get("ok", false) else "操作未完成；请保留当前进度。"
	if result.has("generation"):
		_notice.text += " 存档代号：" + str(result["generation"])
	if result.has("moved"):
		var generations: Array = []
		for receipt in result["moved"]:
			generations.append(receipt["generation"])
		_notice.text += " 已归档代号：" + str(generations)
	if not result.get("ok", false):
		_notice.text += "\n诊断：" + str(result.get("code", "UNKNOWN"))
		if result.has("cause"):
			_notice.text += " / " + str(result["cause"].get("code", "UNKNOWN"))
	if not result.get("skipped", []).is_empty():
		_notice.text += "\n已跳过不可用存档，请保留旧文件供检查。"

	if not result.get("diagnostics", []).is_empty():
		_notice.text += "\n归档含警告；部分文件可能仍在活动目录，请保留文件。"
