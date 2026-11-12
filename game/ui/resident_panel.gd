extends PanelContainer
## Optional, plain-text conversation. No quest/relationship mutations.

signal closed
signal directions_requested(resident_id: String)
signal follow_requested(resident_id: String)
signal departure_requested(resident_id: String)

var _lines: Dictionary = {}
var _resident_id := ""
var _name: Label
var _text: Label
var _topics: VBoxContainer
var _departure_button: Button

func _ready() -> void:
	position = Vector2(335, 185)
	custom_minimum_size.x = 620
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	_name = _label(column, 24)
	_text = _label(column, 18)
	_topics = VBoxContainer.new()
	column.add_child(_topics)
	_button(column, "接下来去哪？", _request_directions)
	_button(column, "我跟你走一段", _request_follow)
	_departure_button = _button(column, "等到出发", _request_departure)
	_button(column, "告辞 · Esc", func() -> void: closed.emit())
	hide()

func configure(data: Dictionary, resident_ids: Array) -> Dictionary:
	if not _lines.is_empty():
		return {"ok": false, "code": "ALREADY_CONFIGURED"}
	if data.size() != 2 or not data.has_all(["schema", "residents"]) or not (typeof(data["schema"]) in [TYPE_INT, TYPE_FLOAT]) or data["schema"] != 1:
		return {"ok": false, "code": "INVALID_RESIDENT_LINES"}
	if not data["residents"] is Dictionary or data["residents"].size() != resident_ids.size():
		return {"ok": false, "code": "RESIDENT_LINES_MISMATCH"}
	for id in resident_ids:
		var entry: Variant = data["residents"].get(id)
		if not entry is Dictionary or entry.size() != 3 or not entry.has_all(["idle_greeting", "moving_greeting", "topics"]):
			return {"ok": false, "code": "INVALID_RESIDENT_COPY"}
		if not _valid_text(entry["idle_greeting"]) or not _valid_text(entry["moving_greeting"]):
			return {"ok": false, "code": "INVALID_RESIDENT_GREETING"}
		if not entry["topics"] is Array or entry["topics"].size() < 1 or entry["topics"].size() > 4:
			return {"ok": false, "code": "INVALID_RESIDENT_TOPICS"}
		for topic in entry["topics"]:
			if not topic is Dictionary or topic.size() != 2 or not topic.has_all(["prompt", "reply"]):
				return {"ok": false, "code": "INVALID_RESIDENT_TOPIC"}
			if not _valid_text(topic["prompt"]) or not _valid_text(topic["reply"]):
				return {"ok": false, "code": "INVALID_RESIDENT_TOPIC_TEXT"}
	_lines = data["residents"].duplicate(true)
	return {"ok": true, "code": "RESIDENT_LINES_READY"}

func open_resident(resident: Dictionary) -> bool:
	if not _lines.has(resident["id"]):
		return false
	_resident_id = resident["id"]
	_name.text = resident["label"]
	var copy: Dictionary = _lines[_resident_id]
	_text.text = resident["activity"] + "。\n\n" + str(copy["moving_greeting"] if resident["moving"] else copy["idle_greeting"])
	for node in _topics.get_children():
		_topics.remove_child(node)
		node.queue_free()
	for topic in copy["topics"]:
		_button(_topics, topic["prompt"], _show_reply.bind(str(topic["reply"])))
	var dock_reply := ""
	match resident.get("delivery_phase", ""):
		"out":
			dock_reply = "数着是两道，还得去桩边看看斜口朝哪边。光看条数，拿反了也看不出来。"
		"check":
			dock_reply = "你从侧面看。我把两块签举到一块儿，两道斜口都往同一边走。就是这根桩。"
		"back":
			dock_reply = "对上了。我回西岸等船；你要找这个收货点，就认那两道斜口。"
	if not dock_reply.is_empty():
		_button(_topics, "这块木签怎么认？", _show_reply.bind(dock_reply))
	_departure_button.visible = not resident["moving"]
	_departure_button.text = "等到出发，一起走（约 %d 分钟）" % int(ceil(float(resident.get("departure_in_minutes", 0))))
	show()
	return true

func show_directions(text: String) -> void:
	if visible:
		_text.text = text

func close_panel() -> void:
	hide()
	_resident_id = ""

func _request_directions() -> void:
	if visible:
		directions_requested.emit(_resident_id)

func _request_follow() -> void:
	if visible:
		follow_requested.emit(_resident_id)

func _request_departure() -> void:
	if visible and _departure_button.visible:
		departure_requested.emit(_resident_id)

func _show_reply(text: String) -> void:
	if visible:
		_text.text = text

func _label(parent: Node, size: int) -> Label:
	var label := Label.new()
	label.custom_minimum_size.x = 600
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _valid_text(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 512
