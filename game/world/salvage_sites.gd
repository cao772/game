extends Node3D
## Fixed street locations. The mounts reserve the same collision envelope on every visit.
const Ledger = preload("res://runtime/salvage_ledger.gd")
const RACK := Vector3(7.90, 1.00, 19.90)
const JIG := Vector3(19.10, 1.08, 10.40)
const BOOK := Vector3(-15.00, 0.80, 24.65)
const DRAIN := Vector3(-31.25, 0.72, 8.45)
const BOOK_AIM := BOOK + Vector3(0, 0.18, 0)
const DRAIN_AIM := DRAIN + Vector3(0, 0.32, 0)
var _rack_card: Label3D
var _jig_jaw: MeshInstance3D
var _jig_card: Label3D
var _lots: Dictionary = {}
var _adapters: Node3D
var _finished: Dictionary = {}
var _markers: Dictionary = {}
var _font: Font
var _materials: Dictionary


func setup(materials: Dictionary, font: Font) -> void:
	_font = font
	_materials = materials.duplicate()
	for pair in [["slats","ba8557"], ["angle","566970"], ["adapter","b78749"]]:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(pair[1])
		mat.metallic = 0.45 if pair[0] != "slats" else 0.0
		_materials[pair[0]] = mat
	_build_rack()
	# The vise sits on the existing shop counter, clear of the toolbox.
	_box(self,JIG + Vector3(0,-0.15,0),Vector3(0.54,0.06,0.34),"angle")
	_box(self,JIG + Vector3(-0.19,-0.06,0),Vector3(0.09,0.16,0.3),"adapter")
	_jig_jaw = _box(self,JIG + Vector3(0.19,-0.06,0),Vector3(0.09,0.16,0.3),"adapter")
	_jig_card = _sign(self,JIG + Vector3(0,0.37,0),"旧料转接夹具")
	_build_mount("book", BOOK)
	_build_mount("drain", DRAIN)


func _build_rack() -> void:
	var shelf := Node3D.new()
	add_child(shelf)
	shelf.position = Vector3(RACK.x,0,RACK.z)
	_solid(shelf,Vector3(0,0.39,0),Vector3(0.86,0.78,1.70))
	for x in [-0.35,0.35]:
		for z in [-0.73,0.73]:
			_box(shelf,Vector3(x,0.36,z),Vector3(0.1,0.72,0.1),"frame")
	for y in [0.2,0.74]:
		_box(shelf,Vector3(0,y,0),Vector3(0.86,0.08,1.70),"shop")
	_rack_card = _sign(shelf,Vector3(0,1.38,0),"")
	var slats := Node3D.new()
	shelf.add_child(slats)
	for i in range(3):
		_box(slats,Vector3(-0.23 + i * 0.2,0.83,(i-1)*0.06),Vector3(0.15,0.10,1.21),"slats")
	_lots["wood"] = slats
	var angle := Node3D.new()
	shelf.add_child(angle)
	# Two flanges with open rectangular holes between successive crosspieces.
	_box(angle,Vector3(0.02,0.80,0),Vector3(0.30,0.04,1.30),"angle")
	for y in [0.84,0.98]:
		_box(angle,Vector3(0.15,y,0),Vector3(0.045,0.05,1.30),"angle")
	for i in range(6):
		_box(angle,Vector3(0.15,0.91,-0.60+i*0.24),Vector3(0.045,0.10,0.10),"angle")
	_lots["iron"] = angle
	_adapters = Node3D.new()
	shelf.add_child(_adapters)
	for z in [-0.32,0.32]:
		_box(_adapters,Vector3(-0.08,0.0225,z),Vector3(0.55,0.045,0.085),"adapter")


func _build_mount(id: String, at: Vector3) -> void:
	var mount := Node3D.new()
	add_child(mount)
	mount.position = Vector3(at.x,0,at.z)
	_solid(mount,Vector3(0,at.y*0.5,0),Vector3(0.94,at.y,0.66))
	# Existing masonry cheeks stand either side of an empty fitting bay.
	for x in [-0.42,0.42]:
		_box(mount,Vector3(x,at.y*0.5,0),Vector3(0.10,at.y,0.66),"concrete")
	_box(mount,Vector3(0,0.09,0),Vector3(0.90,0.18,0.60),"concrete")
	_markers[id] = _sign(mount,Vector3(0,at.y+0.49,-0.30),"书托安装位" if id == "book" else "沥盆架安装位")
	var item := Node3D.new()
	mount.add_child(item)
	item.position.y = at.y
	if id == "book":
		item.rotation.y = PI
	_finished[id] = item


func _install(id: String, material: String) -> void:
	var item: Node3D = _finished[id]
	var finish := "slats" if material == "wood" else "angle"
	if id == "book":
		for i in range(4):
			_box(item,Vector3(0,-0.035,-0.20+i*0.14),Vector3(0.84,0.07,0.138),finish)
		_box(item,Vector3(0,0.05,-0.285),Vector3(0.84,0.13,0.045),finish)
	else:
		for x in [-0.22,0.22]:
			_box(item,Vector3(x,-0.045,0),Vector3(0.10,0.09,0.62),finish)
		for z in [-0.25,0.25]:
			_box(item,Vector3(0,-0.11,z),Vector3(0.87,0.05,0.07),"angle")
	for x in [-0.39,0.39]:
		_box(item,Vector3(x,-0.03,0),Vector3(0.07,0.065,0.46),"adapter")
	(_markers[id] as Label3D).text = Ledger.FIXTURES[id]


func refresh(book: Ledger) -> void:
	var material := book.active_material()
	for kind in _lots:
		(_lots[kind] as Node3D).visible = material == kind
	_adapters.visible = book.has_adapter()
	_adapters.position.y = 0.88 if material == "wood" else 1.005
	_jig_jaw.position.x = JIG.x + (-0.05 if book.has_adapter() else 0.19)
	_jig_card.text = "已压合 · 本批可现场安装" if book.has_adapter() else "旧料转接夹具"
	var batch := "空架 · E 登记首批"
	if not material.is_empty():
		var route := PackedStringArray()
		for fixture in Ledger.FIXTURES:
			if not book.is_built(fixture):
				var place := "阅览室书托" if fixture == "book" else "洗择棚盆架"
				route.append(place if book.fits(fixture) else "经工坊 → " + place)
		batch = str(Ledger.MATERIAL_NAMES[material]) + (" · 已配转接件" if book.has_adapter() else "") + "\n" + " / ".join(route)
	elif not book.data.is_empty():
		batch = "两批已领用" if book.data.installed.size() == 2 else "空架 · E 登记第二批"
	_rack_card.text = "街坊旧料架\n" + (batch if book.problem.is_empty() else "登记待重读")
	for i in range(book.data.get("installed",[]).size()):
		var id: String = book.data.installed[i]
		if (_finished[id] as Node3D).get_child_count() == 0:
			var first: String = book.data.first
			var kind := first if i == 0 else ("iron" if first == "wood" else "wood")
			_install(id,kind)


func targets(book: Ledger) -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		{"id":"salvage_register","action":"register","position":RACK},
		{"id":"salvage_fit","action":"fit","position":JIG},
	]
	for id in Ledger.FIXTURES:
		if not book.is_built(id):
			result.append({"id":"install_"+str(id),"action":id,"position":BOOK_AIM if id == "book" else DRAIN_AIM})
	for target in result:
		target["salvage_generation"] = book.generation
	return result


func caption(action: String, book: Ledger) -> String:
	if not book.problem.is_empty():
		return "在料架重读旧料登记" if action == "register" else book.problem
	match action:
		"register":
			if not book.active_material().is_empty():
				return "查看本批 · " + book.summary()
			if book.is_built("book") and book.is_built("drain"):
				return "查看旧料架 · 两处已建成"
			return "登记首批旧料（木条或带孔角铁，各半）" if book.data.is_empty() else "登记第二批旧料"
		"fit":
			if book.active_material().is_empty() or book.has_adapter():
				return book.summary()
			return "用夹具给" + str(Ledger.MATERIAL_NAMES[book.active_material()]) + "配转接件"
	if book.fits(action):
		return "领用本批，安装" + str(Ledger.FIXTURES[action])
	return str(Ledger.FIXTURES[action]) + "安装位 · " + book.summary()


func occupied(action: String, feet: Vector3) -> bool:
	var at := BOOK if action == "book" else DRAIN
	return absf(feet.x-at.x) < 0.81 and absf(feet.z-at.z) < 0.67 and feet.y < at.y+0.35 and feet.y+1.75 > 0


func _sign(parent: Node3D, at: Vector3, words: String) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.font = _font
	label.font_size = 34
	label.pixel_size = 0.0035
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	label.position = at
	return label


func _solid(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 2 | 4


func _box(parent: Node3D, at: Vector3, size: Vector3, finish: String) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	piece.mesh = mesh
	piece.material_override = _materials[finish]
	parent.add_child(piece)
	piece.position = at
	return piece
