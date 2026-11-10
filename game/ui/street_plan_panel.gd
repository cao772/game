extends CenterContainer
const Book = preload("res://runtime/street_plan_book.gd")
signal requested(action: String, argument: String, revision: int)
var _list: VBoxContainer
var _scroll: ScrollContainer

const ART := {
	"lamp":preload("res://art/street_plans/lamp.svg"),
	"seat":preload("res://art/street_plans/seat.svg"),
	"guide":preload("res://art/street_plans/guide.svg"),
}


func _ready() -> void:
	hide()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","top","right","bottom"]:
		margin.add_theme_constant_override("margin_"+side,16)
	panel.add_child(margin)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	margin.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation",8)
	_scroll.add_child(_list)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	_scroll.custom_minimum_size = Vector2(clampf(size.x-60,140,570),clampf(size.y-70,100,540))


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide()


func show_book(book: Book, origin: String, notice: String = "") -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	show()
	var title := _text("街坊图样板" if origin == "board" else str(Book.PLACES[origin])+" · 现场簿")
	title.add_theme_font_size_override("font_size",24)
	if not notice.is_empty():
		_text(notice).modulate = Color("ffdda6")
	if not book.problem.is_empty() or book.data.is_empty():
		_text(book.problem)
		_button("重新读取建设簿","retry","",book.generation)
		if book.problem.contains("SAVE_DIRECTORY_LIMIT"):
			_button("整理建设旧记录（保留最近32份）","archive","",book.generation)
	else:
		_contents(book, origin, notice.begins_with("新图样"))
	var close := Button.new()
	close.text = "收起 · Esc"
	close.pressed.connect(hide)
	_list.add_child(close)
	title.focus_mode = Control.FOCUS_ALL
	title.grab_focus()
	_scroll.scroll_vertical = 0


func _contents(book: Book, origin: String, reveal: bool) -> void:
	var d := book.data
	var rest := PackedStringArray()
	_text("我的图样 · %d/3" % d.owned.size())
	var cards := HFlowContainer.new()
	_list.add_child(cards)
	for id in Book.CARDS:
		var owned: bool = d.owned.has(id)
		_card(cards,id,owned,reveal and owned and d.owned.back()==id)
		if not owned:
			rest.append(Book.NAMES[id])
	if reveal:
		_button("查看图册与建设进度","browse",origin,book.generation)
		return
	_text("首张在主街板前免费领。再勘察两个不同地块，各得一次免费领取；可先勘察存次数。图样永久复用。")
	_text("待用次数 %d　·　勘察 %d/2" % [book.credits(),d.surveyed.size()])
	if rest.is_empty():
		_text("图样已集齐。")
	else:
		_text("剩余 %s，各 1/%d，每次必得新图样。" % ["、".join(rest),rest.size()])
		if book.credits()>0 and (origin=="board" or not d.owned.is_empty()):
			_button("免费抽一张图样","draw",origin,book.generation)
		elif d.owned.is_empty():
			_text("已登记的次数会保留。首张请到主街图样板领取。")
	_list.add_child(HSeparator.new())
	for site in Book.PLACES:
		var status := "已勘察" if d.surveyed.has(site) else ("可勘察" if d.surveyed.size()<2 else "勘察名额已满")
		if d.built.has(site):
			status = "已建"+str(Book.NAMES[d.built[site]])
		_text("%s · %s　%s" % [Book.PLACES[site],status,Book.DIRECTIONS[site]])
	if d.offer != "":
		_text("当前机会 · " + str(Book.PLACES[d.offer]))
		var uses: Array = Book.ALLOWED[d.offer]
		for card in uses:
			_text("%s · %s%s" % [Book.NAMES[card],Book.USE[card],"（尚未收藏）" if not d.owned.has(card) else ""])
			if origin=="board" and d.accepted=="" and d.owned.has(card):
				_button("承接："+str(Book.NAMES[card]),"accept",card,book.generation)
		if d.accepted != "":
			_text("已选%s。到%s对着地块按 E 施工。每处只能建一件。" % [Book.NAMES[d.accepted],Book.PLACES[d.offer]])
		if origin=="board":
			_button("放弃这处机会","skip","",book.generation)
	elif d.built.size()==3:
		_text("三处均已建成，可前往使用。")
	elif origin=="board":
		var sites := book.available_sites()
		_text("机会从可用图样匹配的空地中等概率选出。跳过后，如有其他合格地，下次优先换地。")
		if not sites.is_empty():
			var names := PackedStringArray()
			for site in sites:
				names.append(Book.PLACES[site])
			_text("本次候选：%s，各 1/%d。" % ["、".join(names),sites.size()])
			_button("领取建设机会","offer","",book.generation)
		else:
			_text("再集一张图样，解锁相配的场地。")
	else:
		_text("回主街板前查看或承接建设机会。")


func _card(row: Control, id: String, owned: bool, fresh: bool) -> void:
	var ink := Color("f5db9f") if owned else Color("afb8b5")
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("344f49") if owned else Color("303a3a")
	style.border_color = Color("ecc67c") if fresh else Color("66746d")
	style.set_border_width_all(3 if fresh else 1)
	style.set_corner_radius_all(5)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
		style.set_content_margin(side,6.0)
	frame.add_theme_stylebox_override("panel",style)
	row.add_child(frame)
	var column := VBoxContainer.new()
	frame.add_child(column)
	var art := TextureRect.new()
	art.texture = ART[id]
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(148,88)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not owned:
		art.modulate = Color(0.65,0.65,0.65,0.75)
	column.add_child(art)
	var title := Label.new()
	title.text = str(Book.NAMES[id]) + (" · 新" if fresh else (" · 已藏" if owned else " · 待领"))
	title.modulate = ink
	column.add_child(title)
	var places := PackedStringArray()
	for site in Book.PLACES:
		if Book.ALLOWED[site].has(id):
			places.append(Book.PLACES[site])
	var detail := Label.new()
	detail.custom_minimum_size.x = 148
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.text = str(Book.USE[id]) + "\n" + " / ".join(places)
	detail.add_theme_font_size_override("font_size",14)
	column.add_child(detail)


func _text(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(label)
	return label


func _button(caption: String, action: String, argument: String, revision: int) -> void:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(func(): requested.emit(action,argument,revision))
	_list.add_child(button)
