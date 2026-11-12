extends Node3D
## Carpenter's winch, weight linkage, parking fork and jointed windsock.

const DRUM := Vector3(-15.4, 0.94, -8.65)
const HANDLE := Vector3(-15.4, 0.92, -7.82)
const GUIDE := Vector3(-15.4, 1.52, -9.10)
const REST := Vector3(-15.4, 1.72, -9.36)
const POLE := Vector3(-17.5, 0, -6.2)
const SAFE_FEET := Vector3(-15.4, 0.04, -5.80)
const CASE_CENTER := Vector3(-15.4, 0.60, -8.65)
const CASE_SIZE := Vector3(1.42, 1.20, 1.18)
const POLE_HEIGHT := 1.65
const POLE_RADIUS := 0.065

const WOOD := Color("9f7047")
const LIGHT_WOOD := Color("c8995d")
const IRON := Color("46504e")
const BRASS := Color("daaa55")
const CORD := Color("edcf92")

var wheel := Node3D.new()
var pawl := Node3D.new()
var treadle := Node3D.new()
var wind_head := Node3D.new()
var cloth: Array[Node3D] = []
var _materials: Dictionary = {}

func _ready() -> void:
	# Broad cheeks and a low storage box form a compact player/camera obstacle.
	_solid_box(CASE_CENTER, CASE_SIZE)
	box(self, DRUM + Vector3(0,-0.69,0), Vector3(1.42,0.50,1.18), WOOD)
	for side in [-1.0, 1.0]:
		box(self, DRUM + Vector3(0, -0.27, side * 0.45), Vector3(1.36,1.05,0.15), LIGHT_WOOD)
	wheel.position = DRUM
	add_child(wheel)
	var barrel := _cylinder(wheel, Vector3.ZERO, 0.30, 0.70, CORD)
	barrel.rotation.x = PI / 2.0
	for z in [-0.35, 0.35]:
		_cylinder(wheel, Vector3(0,0,z), 0.40, 0.09, WOOD).rotation.x = PI / 2.0
	# Keep the ratchet, crank and grip on the operator's side of the cheek.
	_cylinder(wheel, Vector3(0,0,0.56), 0.25, 0.07, IRON).rotation.x = PI / 2.0
	for i in range(10):
		var angle := i * TAU / 10.0
		var tooth := box(wheel, Vector3(cos(angle)*0.26,sin(angle)*0.26,0.56), Vector3(0.115,0.09,0.09), BRASS)
		tooth.rotation.z = angle + 0.35
	box(wheel, Vector3(0.15,0,0.64), Vector3(0.36,0.065,0.065), IRON)
	_cylinder(wheel, Vector3(0.30,0,0.76), 0.055, 0.21, WOOD).rotation.x = PI / 2.0
	pawl.position = DRUM + Vector3(0.47,0.29,0.56)
	add_child(pawl)
	box(pawl, Vector3(-0.15,0,0), Vector3(0.35,0.082,0.11), IRON)
	_cylinder(pawl, Vector3.ZERO, 0.062, 0.13, BRASS).rotation.x = PI/2.0

	treadle.position = Vector3(-13.12,0.083,-8.0)
	add_child(treadle)
	box(treadle, Vector3(0.66,0,0), Vector3(1.37,0.046,0.57), LIGHT_WOOD)
	box(treadle, Vector3(0.14,0.006,0), Vector3(0.08,0.048,0.59), BRASS)
	_rod(self, Vector3(-13.12,0.10,-8), DRUM + Vector3(0.56,-0.65,0.56), 0.027, IRON)
	_rod(self, DRUM + Vector3(0.56,-0.65,0.56), pawl.position, 0.027, IRON)

	# Split parking fork below the parked swallow, with an eye for the line.
	for x in [-0.134, 0.134]:
		_rod(self, GUIDE + Vector3(0,-0.44,0), REST + Vector3(x,-0.398,-0.055), 0.044, WOOD)
	_rod(self, DRUM+Vector3(0,0.30,-0.24), GUIDE, 0.018, CORD)
	var eye := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.052
	ring.outer_radius = 0.083
	eye.mesh = ring
	eye.position = GUIDE
	eye.material_override = material(BRASS)
	add_child(eye)

	var mast := _cylinder(self, POLE + Vector3.UP*POLE_HEIGHT*0.5, POLE_RADIUS, POLE_HEIGHT, WOOD)
	var body := StaticBody3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = POLE_RADIUS
	shape.height = POLE_HEIGHT
	_collider(mast, body, shape)
	wind_head.position = POLE + Vector3.UP*(POLE_HEIGHT - 0.05)
	add_child(wind_head)
	var parent := wind_head
	for i in range(3):
		var joint := Node3D.new()
		if i > 0:
			joint.position.z = 0.40
		parent.add_child(joint)
		cloth.append(joint)
		_ribbon(joint, 0.22-i*0.055, 0.165-i*0.055 if i < 2 else 0.0, Color("bd502f") if i != 1 else Color("f5df9d"))
		parent = joint

func pose(payout: float, weighted: bool, phase: float, yaw: float) -> void:
	wheel.rotation.z = payout * TAU * 5.0
	pawl.rotation.z = 0.39 if weighted else -0.57
	treadle.rotation.z = 0.0 if weighted else 0.15
	wind_head.rotation.y = yaw
	for i in range(cloth.size()):
		cloth[i].rotation.x = 0.055 + 0.105*sin(phase*2.3-i*0.8)
		cloth[i].rotation.y = 0.07*sin(phase*2.8-i*0.65)

static func blocks_feet(feet: Vector3) -> bool:
	# Horizontal distance to each solid and vertical distance to the player's
	# capsule axis, so a legal foot touching the cabinet lid or edge can restore.
	var delta := (feet - CASE_CENTER).abs() - CASE_SIZE*0.5
	var dx := maxf(delta.x, 0.0)
	var dz := maxf(delta.z, 0.0)
	var gap := maxf(0, maxf(feet.y+0.32-CASE_SIZE.y, -(feet.y+1.33)))
	if dx*dx + dz*dz + gap*gap < 0.32*0.32 - 0.00001:
		return true
	var radial := maxf(0, Vector2(feet.x-POLE.x,feet.z-POLE.z).length()-POLE_RADIUS)
	gap = maxf(0, maxf(feet.y+0.32-POLE_HEIGHT, -(feet.y+1.33)))
	return radial*radial + gap*gap < 0.32*0.32 - 0.00001

func _ribbon(parent: Node3D, height: float, tip_height: float, color: Color) -> void:
	var mesh := ImmediateMesh.new()
	var finish := material(color)
	finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, finish)
	for point in [Vector3(0,height/2,0), Vector3(0,-height/2,0), Vector3(0,tip_height/2,0.4), Vector3(0,-tip_height/2,0.4)]:
		mesh.surface_set_normal(Vector3.RIGHT)
		mesh.surface_add_vertex(point)
	mesh.surface_end()
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	parent.add_child(piece)

func _solid_box(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var shape := BoxShape3D.new()
	shape.size = size
	_collider(self, body, shape)

func _collider(parent: Node3D, body: StaticBody3D, shape: Shape3D) -> void:
	body.collision_layer = 1
	body.collision_mask = 2
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)

func material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var finish := StandardMaterial3D.new()
		finish.albedo_color = color
		finish.roughness = 0.84
		_materials[color] = finish
	return _materials[color]

func box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.position = at
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	return node

func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 16
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var node := MeshInstance3D.new()
	node.position = at
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	return node

func _rod(parent: Node3D, start: Vector3, end: Vector3, radius: float, color: Color) -> void:
	var rod := _cylinder(parent, (start+end)*0.5, radius, start.distance_to(end), color)
	rod.quaternion = Quaternion(Vector3.UP, (end-start).normalized())
