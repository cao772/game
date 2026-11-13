extends ColorRect
## A modal, event-driven field notebook. Only the region sheet and its index change.
signal closed
signal marked(key: String)
const Sheet = preload("res://ui/field_map_sheet.gd")
const PAPER := Color("#f6f0df")
const INK := Color("#233c38")
const ACCENT := Color("#8d3e2d")
var _margin := MarginContainer.new()
var _sheet := Sheet.new()
var _layout := BoxContainer.new()
var _rail := VBoxContainer.new()
var _list := VBoxContainer.new()
var _tabs := HFlowContainer.new()
var _scroll := ScrollContainer.new()
var _button_theme := Theme.new()
var _status: Label
var _region_label: Label
var _detail: Label
var _marked: Label
var _set_button: Button
var _clear: Button
var _regions: Dictionary
var _rows: Array[Dictionary] = []
var _buttons: Dictionary = {}
var _region := ""
var _current := ""
var _pin := ""
var _low := false

func _ready() -> void:
	hide()
	color = PAPER
	var colors := {"normal":"e9e4d4","hover":"dce5d9","pressed":"c8d9ca","hover_pressed":"bed4c5","disabled":"f0ecdf","focus":"00000000"}
	for style_name in colors:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(colors[style_name])
		style.set_corner_radius_all(4)
		style.content_margin_left = 10
		style.content_margin_right = 10
		if style_name == "focus":
			style.set_border_width_all(2)
			style.border_color = Color("#217770")
		_button_theme.set_stylebox(style_name,"Button",style)
	for name_key in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
		_button_theme.set_color(name_key,"Button",INK)
	_button_theme.set_color("font_disabled_color","Button",Color("#716d61"))
	theme = _button_theme
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	for side in ["left","right","top","bottom"]:
		_margin.add_theme_constant_override("margin_"+side,12)
	var stack := VBoxContainer.new()
	_margin.add_child(stack)
	stack.add_theme_constant_override("separation",8)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var title := _label(header,"行旅手图",25)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header,"收图  M",_close)
	_status = _label(stack,"",15)
	stack.add_child(_tabs)
	stack.add_child(_scroll)
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_layout)
	_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layout.add_theme_constant_override("separation",14)
	_layout.add_child(_sheet)
	_sheet.picked.connect(_select)
	_sheet.mouse_filter = Control.MOUSE_FILTER_PASS
	_sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layout.add_child(_rail)
	_rail.add_theme_constant_override("separation",6)
	_region_label = _label(_rail,"",20)
	_label(_rail,"◆ 路口　■ 木箱　● 发现\n上北下南 · 青箭头是你的位置与视向。\n黑圈为预览，红圈为目的地。",14)
	_rail.add_child(_list)
	_detail = _label(_rail,"",16)
	_set_button = _button(_rail,"设为目的地",_set_pin)
	_marked = _label(_rail,"",16)
	_marked.add_theme_color_override("font_color",ACCENT)
	_clear = _button(_rail,"清除目的地",_clear_pin)
	_label(_rail,"到地标前按 E 记录发现。木箱可随身跨区，靠近空木台按 E 放下。遇到居民可交谈、同行或自行改道。",14)
	resized.connect(_fit)
	get_viewport().size_changed.connect(_fit)

func _fit() -> void:
	if not visible:
		return
	# canvas_items stretching can leave 1280 logical units in a 480px window.
	# Compensate on this non-container parent, keeping buttons and type readable.
	var to_window := get_viewport().get_final_transform() * get_global_transform_with_canvas()
	var density := to_window.x.length()
	var zoom := 1.0 / clampf(density,0.20,1.0)
	_margin.scale = Vector2.ONE * zoom
	_margin.size = size / zoom
	var narrow := _margin.size.x < 720
	_layout.vertical = narrow
	var width := maxf(96,_margin.size.x-52)
	_rail.custom_minimum_size.x = 0 if narrow else clampf(width*0.34,230,350)
	var available := width if narrow else width-_rail.custom_minimum_size.x-14
	_sheet.custom_minimum_size.y = minf(available, maxf(160,_margin.size.y*(0.53 if narrow else 0.73)))
	_sheet.queue_redraw()

func _label(parent: Control, caption: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color",INK)
	label.add_theme_font_size_override("font_size",font_size)
	parent.add_child(label)
	return label

func _button(parent: Control, caption: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = caption
	btn.pressed.connect(action)
	btn.custom_minimum_size.y = 32
	parent.add_child(btn)
	return btn

func open(regions: Dictionary, entries: Array[Dictionary], current: String, feet: Vector3, yaw: float,
		low: bool, clock_text: String, pin: String) -> void:
	_regions = regions
	_rows = entries
	_current = current
	_pin = pin
	_low = low
	_sheet.feet = Vector2(feet.x,feet.z)
	_sheet.heading = yaw
	_status.text = "所在 · %s　%s　·　已暂停" % [regions[current],clock_text]
	if _tabs.get_child_count() == 0:
		for id in regions:
			var tab := _button(_tabs,regions[id],_browse.bind(id))
			tab.toggle_mode = true
			tab.set_meta("region",id)
	show()
	_fit()
	_browse(current)
	for tab in _tabs.get_children():
		if tab.get_meta("region") == current:
			tab.grab_focus()

func _browse(id: String) -> void:
	_region = id
	for tab in _tabs.get_children():
		tab.set_pressed_no_signal(tab.get_meta("region") == id)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_sheet.rows.clear()
	_sheet.selection = ""
	_sheet.here = id == _current
	var layer := id
	if id == "SHORE":
		layer = "shore_low" if _low else "shore_normal"
	_sheet.paper = Sheet.PAPERS[layer]
	_region_label.text = "图幅 · " + str(_regions[id]) + ((" · 低水" if _low else " · 平水") if id=="SHORE" else "")
	for row in _rows:
		if row.region != id:
			continue
		_sheet.rows.append(row)
		var prefix: String = {"route":"◆","crate":"■","site":"●"}[row.kind]
		var btn := _button(_list,"%s　%s%s" % [prefix,row.name," · 随身" if row.held else ""],_select.bind(row.key))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.clip_text = true
		btn.tooltip_text = row.name
		btn.toggle_mode = true
		_buttons[row.key] = btn
	_select(_pin if _buttons.has(_pin) else "")
	_scroll.scroll_vertical = 0

func _select(key: String) -> void:
	_sheet.selection = key
	_sheet.pin = _pin
	_sheet.queue_redraw()
	_detail.text = "点地图符号或选列表条目。Tab 切换，回车确认。"
	_marked.text = "目的地 · 未标记"
	for row in _rows:
		if row.key == key:
			_detail.text = "%s\n%s" % [row.name,row.detail]
		if row.key == _pin:
			_marked.text = "目的地 · %s / %s" % [row.name,"随身" if row.held else _regions[row.region]]
	for id in _buttons:
		_buttons[id].set_pressed_no_signal(id == key)
	_set_button.disabled = key.is_empty() or key == _pin
	_clear.disabled = _pin.is_empty()

func _set_pin() -> void:
	_pin = _sheet.selection
	marked.emit(_pin)
	_select(_pin)

func _clear_pin() -> void:
	_pin = ""
	marked.emit("")
	_select(_sheet.selection)

func _close() -> void:
	hide()
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	if event.physical_keycode in [KEY_M,KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo:
			_close()
	elif event.physical_keycode in [KEY_E,KEY_Q,KEY_F5,KEY_F9]:
		get_viewport().set_input_as_handled()
