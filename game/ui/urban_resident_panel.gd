extends PanelContainer
## Optional plain-text conversation. The street owns proximity and modal pause.
## Replies use the copies captured at open; this panel never changes world state.

signal closed

const RESIDENT_ID := "workshop_resident"
const PHASES := ["bench", "shelf", "yard"]
const BLOCKERS := ["", "gate", "player", "obstacle"]
const CONFIG_FIELDS := [
	"schema_version", "resident_id", "display_name", "greetings",
	"destination_names", "route_replies", "toolbox_replies", "lamp_replies", "small_talk"
]
const STATUS_FIELDS := ["id", "activity", "goal", "moving", "blocked", "phase"]
const VIEW_FIELDS := [
	"schema_version", "front_open", "back_open", "lamp_on", "toolbox_anchor"
]
const ROUTE_FIELDS := [
	"moving", "planned", "gate_wait", "front_detour", "back_open", "gate_clear",
	"player", "obstacle"
]

var _copy: Dictionary = {}
var _status: Dictionary = {}
var _view: Dictionary = {}
var _is_open := false
var _talk_index := 0
var _name_label: Label
var _activity_label: Label
var _reply_label: Label
var _scroll: ScrollContainer
var _first_button: Button


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = true
	margin.add_child(_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	_scroll.add_child(column)
	_name_label = _label(column, 24)
	_activity_label = _label(column, 16)
	_reply_label = _label(column, 18)
	column.add_child(HSeparator.new())
	_first_button = _button(column, "接下来去哪？", _answer_route)
	_button(column, "工具箱这样放行吗？", _answer_toolbox)
	_button(column, "聊聊这里", _answer_small_talk)
	_button(column, "这盏灯呢？", _answer_lamp)
	_button(column, "告辞 · Esc", close_panel)
	get_viewport().size_changed.connect(_fit_viewport)
	_fit_viewport()


func configure(data: Dictionary) -> Dictionary:
	if _is_open:
		return {"ok": false, "code": "CONVERSATION_OPEN"}
	if not _exact_keys(data, CONFIG_FIELDS) or not _version_one(data["schema_version"]):
		return {"ok": false, "code": "INVALID_RESIDENT_CONFIG"}
	if typeof(data["resident_id"]) != TYPE_STRING or data["resident_id"] != RESIDENT_ID:
		return {"ok": false, "code": "INVALID_RESIDENT_ID"}
	if not _valid_text(data["display_name"], 40, false):
		return {"ok": false, "code": "INVALID_RESIDENT_NAME"}
	if not _text_map(data["greetings"], ["idle", "moving", "gate", "player", "obstacle"], 240):
		return {"ok": false, "code": "INVALID_GREETINGS"}
	if not _text_map(data["destination_names"], PHASES, 24):
		return {"ok": false, "code": "INVALID_DESTINATIONS"}
	if not _text_map(data["route_replies"], ROUTE_FIELDS, 240):
		return {"ok": false, "code": "INVALID_ROUTE_REPLIES"}
	if not _text_map(data["toolbox_replies"], ["bench", "shelf", "yard", "carried"], 240):
		return {"ok": false, "code": "INVALID_TOOLBOX_REPLIES"}
	if not _text_map(data["lamp_replies"], ["on", "off"], 240):
		return {"ok": false, "code": "INVALID_LAMP_REPLIES"}
	if typeof(data["small_talk"]) != TYPE_ARRAY or data["small_talk"].size() != 3:
		return {"ok": false, "code": "INVALID_SMALL_TALK"}
	for line in data["small_talk"]:
		if not _valid_text(line, 240):
			return {"ok": false, "code": "INVALID_SMALL_TALK"}
	# Validate everything before replacing an earlier, usable configuration.
	_copy = data.duplicate(true)
	_copy["schema_version"] = 1
	_talk_index = 0
	return {"ok": true, "code": "RESIDENT_LINES_READY"}


func open_resident(status: Dictionary, view: Dictionary) -> bool:
	if not is_inside_tree() or not is_node_ready() or _is_open or _copy.is_empty():
		return false
	if not _valid_status(status) or not _valid_view(view):
		return false
	_status = status.duplicate(true)
	_view = view.duplicate(true)
	_name_label.text = _copy["display_name"]
	_activity_label.text = "当前：" + str(_status["activity"])
	if _status["phase"] == "bench" and not _status["moving"] and not _view["lamp_on"] and _status["blocked"] == "":
		_activity_label.text = "当前：在工作台边歇一会儿，灯关着，暂不检修"
	var greeting_key: String = _status["blocked"]
	if greeting_key.is_empty():
		greeting_key = "moving" if _status["moving"] else "idle"
	_reply_label.text = _copy["greetings"][greeting_key]
	if not _view["lamp_on"]:
		_reply_label.text += "\n\n" + str(_copy["lamp_replies"]["off"])
	_scroll.scroll_vertical = 0
	_is_open = true
	_fit_viewport()
	show()
	_first_button.grab_focus()
	return true


func close_panel() -> void:
	if not _is_open:
		return
	_is_open = false
	if is_inside_tree():
		var focus_owner: Control = get_viewport().gui_get_focus_owner()
		if focus_owner != null and (focus_owner == self or is_ancestor_of(focus_owner)):
			focus_owner.release_focus()
	hide()
	_status.clear()
	_view.clear()
	closed.emit()


func _input(event: InputEvent) -> void:
	if _is_open and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close_panel()


func _answer_route() -> void:
	if not _is_open:
		return
	var lines: Dictionary = _copy["route_replies"]
	var blocked: String = _status["blocked"]
	var destination: String = _copy["destination_names"][_status["goal"]]
	var reply: String = "想去" + destination + "。"
	if blocked == "gate":
		if not _view["front_open"] and not _view["back_open"]:
			reply += str(lines["gate_wait"])
		elif _view["front_open"] and _view["back_open"]:
			reply += str(lines["gate_clear"])
		elif not _view["back_open"] and _view["front_open"]:
			reply += str(lines["front_detour"])
		else:
			reply += str(lines["back_open"])
	elif blocked == "player" or blocked == "obstacle":
		reply += str(lines[blocked])
	else:
		reply += str(lines["moving"] if _status["moving"] else lines["planned"])
	_show_reply(reply)


func _answer_toolbox() -> void:
	if not _is_open:
		return
	var reply: String = _copy["toolbox_replies"][_view["toolbox_anchor"]]
	if not _view["lamp_on"]:
		reply += "\n\n" + str(_copy["lamp_replies"]["off"])
	_show_reply(reply)


func _answer_small_talk() -> void:
	if not _is_open:
		return
	_show_reply(_copy["small_talk"][_talk_index])
	_talk_index = (_talk_index + 1) % 3


func _answer_lamp() -> void:
	if _is_open:
		_show_reply(_copy["lamp_replies"]["on" if _view["lamp_on"] else "off"])


func _show_reply(text: String) -> void:
	_reply_label.text = text
	# Long copy stays readable on smaller viewports; all buttons remain scrollable.
	_scroll.scroll_vertical = 0


func _fit_viewport() -> void:
	var available: Vector2 = get_viewport_rect().size - Vector2(24, 24)
	var panel_size := Vector2(minf(680.0, maxf(1.0, available.x)), minf(620.0, maxf(1.0, available.y)))
	offset_left = -panel_size.x * 0.5
	offset_right = panel_size.x * 0.5
	offset_top = -panel_size.y * 0.5
	offset_bottom = panel_size.y * 0.5


func _label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.clip_text = true
	button.custom_minimum_size.y = 40
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _valid_status(status: Dictionary) -> bool:
	if not _exact_keys(status, STATUS_FIELDS):
		return false
	if typeof(status["id"]) != TYPE_STRING or status["id"] != RESIDENT_ID:
		return false
	if not _valid_text(status["activity"], 96, false) or typeof(status["moving"]) != TYPE_BOOL:
		return false
	for field in ["goal", "phase"]:
		if typeof(status[field]) != TYPE_STRING or not PHASES.has(status[field]):
			return false
	return typeof(status["blocked"]) == TYPE_STRING and BLOCKERS.has(status["blocked"])


func _valid_view(view: Dictionary) -> bool:
	if not _exact_keys(view, VIEW_FIELDS) or not _version_one(view["schema_version"]):
		return false
	for field in ["front_open", "back_open", "lamp_on"]:
		if typeof(view[field]) != TYPE_BOOL:
			return false
	return typeof(view["toolbox_anchor"]) == TYPE_STRING and ["bench", "shelf", "yard", "carried"].has(view["toolbox_anchor"])


func _text_map(value: Variant, fields: Array, limit: int) -> bool:
	if not _exact_keys(value, fields):
		return false
	for field in fields:
		if not _valid_text(value[field], limit):
			return false
	return true


func _exact_keys(value: Variant, fields: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != fields.size():
		return false
	for key in value:
		if typeof(key) != TYPE_STRING or not fields.has(key):
			return false
	return true


func _valid_text(value: Variant, limit: int, multiline: bool = true) -> bool:
	if typeof(value) != TYPE_STRING or value.length() > limit or value.strip_edges().is_empty():
		return false
	for index in range(value.length()):
		var code: int = value.unicode_at(index)
		if code == 127 or (code < 32 and not (multiline and code == 10)):
			return false
	return true


func _version_one(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return value == 1
	if typeof(value) == TYPE_FLOAT:
		return is_finite(value) and value == 1.0
	return false
