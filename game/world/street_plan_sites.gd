extends Node3D
const Book = preload("res://runtime/street_plan_book.gd")
const BOARD := Vector3(-4.8, 0, 18)
const SITES := {"cross":Vector3(-8,0,3), "south":Vector3(-32,0,18), "north":Vector3(-27,0,-12)}
const LANDMARKS := ["图样板", "阅览室前廊", "洗择棚东口"]
const DESTINATIONS := [BOARD, Vector3(-12,0,18.8), Vector3(-32,0,11.9)]
var _labels: Dictionary = {}
var _installations: Dictionary = {}
var _kinds: Dictionary = {}
var _lights: Dictionary = {}
var _bulbs: Dictionary = {}
var _font: Font
var _guide := -1


func setup(font: Font) -> void:
	_font = font
	var board := _fixture(BOARD, Vector3(1.8,1.3,0.18), Vector3(0,0.75,0), Color("345d58"))
	_label(board, Vector3(0,1.66,0), "街坊图样板")
	for site in SITES:
		var fixture := _fixture(SITES[site], Vector3(1.35,0.78,0.16), Vector3(0,0.39,0.57), Color("766854"))
		_labels[site] = _label(fixture, Vector3(0,1.15,0.44), Book.PLACES[site])


func refresh(book: Book) -> void:
	var built: Dictionary = book.data.get("built",{})
	for site in SITES:
		var kind: String = built.get(site,"")
		if kind != _kinds.get(site,""):
			if _installations.has(site):
				var old: Node3D = _installations[site]
				remove_child(old)
				old.queue_free()
				_installations.erase(site)
				_lights.erase(site)
				_bulbs.erase(site)
			_kinds[site] = kind
			if not kind.is_empty():
				_install(site, kind)
		var caption: String = Book.PLACES[site]
		if not kind.is_empty():
			caption += " · " + str(Book.NAMES[kind])
		elif book.data.get("offer","") == site and book.data.get("accepted","") != "":
			caption += " · 待建" + str(Book.NAMES[book.data.accepted])
		else:
			caption += " · 勘察点"
		(_labels[site] as Label3D).text = caption


func targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"id":"plan_board","label":"街坊图样板","position":BOARD+Vector3.UP*1.53}]
	for site in SITES:
		var at: Vector3 = SITES[site]
		var kind: String = _kinds.get(site,"")
		result.append({"id":"plot_"+str(site),"site":site,"kind":kind,"position":at+Vector3(0,0.94,0),
			"label":str(Book.PLACES[site])+"歇脚凳" if kind=="seat" else str(Book.PLACES[site]),
			"feet":at,"yaw":0.0,"stand_candidates":[at+Vector3(0,0,-1.3),at+Vector3(0.85,0,-1.15),at+Vector3(-0.85,0,-1.15)]})
	return result


func caption(site: String, book: Book) -> String:
	match str(_kinds.get(site,"")):
		"seat": return "坐在" + str(Book.PLACES[site]) + "歇脚凳上"
		"guide": return "选择下一处步行地标"
		"lamp": return "熄灭街灯" if (_lights[site] as OmniLight3D).visible else "点亮街灯"
	if not book.data.is_empty() and book.data.offer == site and book.data.accepted != "":
		return "建造" + str(Book.NAMES[book.data.accepted])
	return "查看地块与勘察登记"


func use_fixture(site: String) -> String:
	if _kinds.get(site) == "lamp":
		var light := _lights[site] as OmniLight3D
		light.visible = not light.visible
		var material := _bulbs[site] as StandardMaterial3D
		material.emission_enabled = light.visible
		material.albedo_color = Color("ffe3a6") if light.visible else Color("706f66")
		return "街灯已亮。" if light.visible else "街灯已熄。"
	_guide += 1
	if _guide >= LANDMARKS.size():
		_guide = -1
	return "结束指路。" if _guide < 0 else "开始指路 · " + str(LANDMARKS[_guide])


func guide_text(feet: Vector3) -> String:
	if _guide < 0:
		return ""
	var offset: Vector3 = DESTINATIONS[_guide] - feet
	var bearing := Vector2(offset.x,offset.z)
	if bearing.length() < 2.0:
		return "已到达 · " + str(LANDMARKS[_guide])
	var compass := ["东","东南","南","西南","西","西北","北","东北"]
	var octant := posmod(roundi(bearing.angle() / (PI / 4)),8)
	return "步行指路 · %s在%s侧，直线约%d米" % [LANDMARKS[_guide],compass[octant],roundi(bearing.length())]


func occupied(site: String, feet: Vector3) -> bool:
	var offset: Vector3 = feet - SITES[site]
	return absf(offset.x)<1.20 and absf(offset.z)<0.94 and offset.y<2.65 and offset.y + 1.75 > 0.0


func _fixture(at: Vector3, size: Vector3, center: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	add_child(body)
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 2 | 4
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position = center
	body.add_child(collider)
	_box(body,center,size,color)
	return body


func _install(site: String, kind: String) -> void:
	var item := Node3D.new()
	add_child(item)
	item.position = SITES[site]
	_installations[site] = item
	match kind:
		"seat":
			_box(item,Vector3(0,0.46,0.03),Vector3(1.55,0.11,0.62),Color("b79167"))
			for x in [-0.58,0.58]:
				_box(item,Vector3(x,0.22,0.08),Vector3(0.10,0.44,0.42),Color("555f5b"))
		"lamp":
			_box(item,Vector3(0,1.13,0.53),Vector3(0.10,2.26,0.10),Color("344c48"))
			var bulb := _box(item,Vector3(0,2.26,0.49),Vector3(0.54,0.26,0.49),Color("706f66"))
			var material := bulb.material_override as StandardMaterial3D
			material.emission = Color("ffce88")
			_bulbs[site] = material
			var light := OmniLight3D.new()
			item.add_child(light)
			light.position = Vector3(0,2.14,0.23)
			light.omni_range = 7.5
			light.light_color = Color("ffdca7")
			light.light_energy = 1.6
			light.hide()
			_lights[site] = light
		"guide":
			_box(item,Vector3(0,1.0,0.54),Vector3(0.12,2,0.12),Color("53655c"))
			_box(item,Vector3(0,1.78,0.5),Vector3(1.18,0.46,0.11),Color("34675f"))
			_label(item,Vector3(0,1.81,0.39),"步行指南")


func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	piece.material_override = material
	parent.add_child(piece)
	piece.position = at
	return piece


func _label(parent: Node3D, at: Vector3, text: String) -> Label3D:
	var label := Label3D.new()
	label.font = _font
	label.font_size = 36
	label.pixel_size = 0.004
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	label.position = at
	return label
