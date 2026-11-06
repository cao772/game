extends Node3D
## Shared drying terrace, authored game geometry rather than a surveyed building.
## Coordinates match modern_street's origin; the scene owns sitting and standing.

const DECK_Y: float = 3.0
const SEAT_FEET := Vector3(30, 3, 10.8)
const SEAT_TARGET := Vector3(30, 3.75, 10)
const STAND_POINTS := [Vector3(30, 3, 9.45), Vector3(29, 3, 9.45), Vector3(31, 3, 9.45)]

var _geometry: Node3D
var _materials: Dictionary = {}


func setup(materials: Dictionary, font: Font) -> void:
	if is_instance_valid(_geometry):
		remove_child(_geometry)
		_geometry.queue_free()
	_materials = materials
	_geometry = Node3D.new()
	_geometry.name = "SharedTerraceGeometry"
	add_child(_geometry)
	_build_decks()
	_build_routes()
	_build_guards()
	_build_seat()
	_build_drying_frame()
	if font != null:
		var sign := Label3D.new()
		sign.text = "共享晒台"
		sign.font = font
		sign.font_size = 40
		sign.pixel_size = 0.006
		sign.outline_size = 0
		sign.modulate = Color("eeeeDF")
		sign.position = Vector3(38.3, 1.4, 3.2)
		sign.rotation.y = PI * 0.5
		_geometry.add_child(sign)


func targets() -> Array[Dictionary]:
	var standing: Array[Vector3] = []
	for point in STAND_POINTS:
		standing.append(to_global(point))
	# The target is in clear air in FRONT of the bench. No seat-body ray exception
	# is needed. All seat frames remain ordinary world collision.
	return [{"id": "terrace_seat", "label": "晒台长椅", "position": to_global(SEAT_TARGET),
		"feet": to_global(SEAT_FEET), "yaw": global_rotation.y, "stand_candidates": standing}]


func _build_decks() -> void:
	# Main slab x28..36/z6..13. Its underside is y2.75, or y2.60 at beams.
	_deck(Vector2(28, 6), Vector2(36, 13), DECK_Y)
	_deck(Vector2(36, 11), Vector2(38.2, 13), DECK_Y)
	_deck(Vector2(40, 9), Vector2(45, 11), 1.5)
	_deck(Vector2(32, -1), Vector2(42, 1), DECK_Y)
	_deck(Vector2(32, 1), Vector2(34, 6), DECK_Y)
	# Supports are outside the whole rear-lane strip x26.5..31.5, not merely
	# outside its centreline. The existing x25 resident route is untouched.
	for x in [32.2, 35.7]:
		for z in [6.3, 12.7]:
			_box(Vector3(x, 1.375, z), Vector3(0.22, 2.75, 0.22), "metal", true)
	for z in [6.3, 12.7]:
		_box(Vector3(32, 2.675, z), Vector3(8, 0.15, 0.2), "metal", true)
	for p in [Vector2(33.8, 3), Vector2(33.8, 5.6), Vector2(36, -0.4), Vector2(41, -0.4)]:
		_box(Vector3(p.x, 1.375, p.y), Vector3(0.18, 2.75, 0.18), "metal", true)
	for x in [40.2, 44.8]:
		_box(Vector3(x, 0.625, 10.7), Vector3(0.18, 1.25, 0.18), "metal", true)


func _build_routes() -> void:
	# Stair appearance with ONE continuous collision ramp. Top end vertices share
	# the landing edge exactly: (37.2,0,3) -> (37.2,3,11), atan(3/8)=20.556deg.
	_ramp(37.2, 2.0, 3, 0, 11, 3, false)
	for index in range(20):
		# Visual treads sample the ramp midpoint; maximum visual mismatch is 0.075m.
		var height: float = (float(index) + 0.5) * 0.15
		_box(Vector3(37.2, height - 0.075, 3.2 + index * 0.4), Vector3(2, 0.15, 0.4), "concrete")
	# Gentle switchback: 7.125deg up leg A, a level 2m turning landing, then
	# 10.620deg up leg B. It joins the north deck entry via a level upper bridge.
	_ramp(44, 2, -3, 0, 9, 1.5, true)
	_ramp(41, 2, 9, 1.5, 1, 3, true)


func _build_guards() -> void:
	# Rails have continuous solid collision, despite the visually open metal bars.
	# Platform north leaves x32..34 open; east leaves z11..13 open.
	_guard(Vector3(28, 3, 6), Vector3(32, 3, 6))
	_guard(Vector3(34, 3, 6), Vector3(36, 3, 6))
	_guard(Vector3(28, 3, 6), Vector3(28, 3, 13))
	_guard(Vector3(28, 3, 13), Vector3(38.2, 3, 13))
	_guard(Vector3(36, 3, 6), Vector3(36, 3, 11))
	_guard(Vector3(38.2, 3, 11), Vector3(38.2, 3, 13))
	_guard(Vector3(36.2, 0, 3), Vector3(36.2, 3, 11))
	_guard(Vector3(38.2, 0, 3), Vector3(38.2, 3, 11))
	# Lower ramp, switchback platform and upper ramp. Only the top/bottom ends
	# are open; no transverse collision crosses a route's entry.
	_guard(Vector3(43, 0, -3), Vector3(43, 1.5, 9))
	_guard(Vector3(45, 0, -3), Vector3(45, 1.5, 9))
	_guard(Vector3(40, 1.5, 9), Vector3(40, 3, 1))
	_guard(Vector3(42, 1.5, 9), Vector3(42, 3, 1))
	_guard(Vector3(40, 1.5, 11), Vector3(45, 1.5, 11))
	_guard(Vector3(40, 1.5, 9), Vector3(40, 1.5, 11))
	_guard(Vector3(45, 1.5, 9), Vector3(45, 1.5, 11))
	_guard(Vector3(42, 1.5, 9), Vector3(43, 1.5, 9))
	# Upper bridge and north platform approach. The two 2m openings at z=1
	# connect the arriving ramp at x40..42 and the walkway at x32..34.
	_guard(Vector3(32, 3, -1), Vector3(42, 3, -1))
	_guard(Vector3(42, 3, -1), Vector3(42, 3, 1))
	_guard(Vector3(34, 3, 1), Vector3(40, 3, 1))
	_guard(Vector3(32, 3, -1), Vector3(32, 3, 6))
	_guard(Vector3(34, 3, 1), Vector3(34, 3, 6))


func _build_seat() -> void:
	# Seat top y=3.52 matches the seated proxy's hip offset +0.52. The seat is
	# visual ONLY, giving the controller a clear r0.3/h1.35 seating capsule.
	_box(Vector3(30, 3.48, 10.9), Vector3(1.8, 0.08, 0.54), "shop")
	# Back front face z=11.23 is 0.43m behind the seat root. Side frame inner
	# faces are at x29.14/30.86, well outside the radius plus 0.03m margin.
	# Top y3.94 leaves 0.26m below the seated eye y4.20 for the camera sweep.
	_box(Vector3(30, 3.72, 11.28), Vector3(1.8, 0.44, 0.1), "shop", true)
	for x in [29.1, 30.9]:
		_box(Vector3(x, 3.72, 10.95), Vector3(0.08, 0.08, 0.65), "metal", true)
		for z in [10.65, 11.05]:
			_box(Vector3(x, 3.25, z), Vector3(0.08, 0.5, 0.08), "metal", true)


func _build_drying_frame() -> void:
	for z in [7.4, 9.6]:
		_box(Vector3(34.7, 3.9, z), Vector3(0.07, 1.8, 0.07), "metal", true)
	_box(Vector3(34.7, 4.8, 8.5), Vector3(0.07, 0.07, 2.3), "frame")
	_box(Vector3(34.7, 4.43, 8.1), Vector3(0.025, 0.7, 0.65), "frame")


func _deck(low: Vector2, high: Vector2, top: float) -> void:
	var center := (low + high) * 0.5
	_box(Vector3(center.x, top - 0.125, center.y), Vector3(high.x - low.x, 0.25, high.y - low.y), "concrete", true)


func _ramp(x: float, width: float, start_z: float, start_y: float, end_z: float, end_y: float, visible_surface: bool) -> void:
	# Explicit world-space top corners avoid the vertical lip of an uncorrected
	# tilted BoxShape. A thin convex prism joins the two landing heights exactly.
	var points := PackedVector3Array([
		Vector3(x - width * 0.5, start_y, start_z), Vector3(x + width * 0.5, start_y, start_z),
		Vector3(x - width * 0.5, end_y, end_z), Vector3(x + width * 0.5, end_y, end_z),
		Vector3(x - width * 0.5, start_y - 0.18, start_z), Vector3(x + width * 0.5, start_y - 0.18, start_z),
		Vector3(x - width * 0.5, end_y - 0.18, end_z), Vector3(x + width * 0.5, end_y - 0.18, end_z),
	])
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 6
	_geometry.add_child(body)
	var collider := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	collider.shape = hull
	body.add_child(collider)
	if not visible_surface:
		return
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var center := Vector3(x, (start_y + end_y) * 0.5 - 0.09, (start_z + end_z) * 0.5)
	for face in [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]:
		var normal := (points[face[1]] - points[face[0]]).cross(points[face[2]] - points[face[0]]).normalized()
		var midpoint := (points[face[0]] + points[face[1]] + points[face[2]] + points[face[3]]) * 0.25
		if normal.dot(midpoint - center) < 0:
			normal = -normal
		var offset := vertices.size()
		for corner in face:
			vertices.append(points[corner])
			normals.append(normal)
		indices.append_array(PackedInt32Array([offset, offset + 1, offset + 2, offset, offset + 2, offset + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := (_materials["concrete"] as StandardMaterial3D).duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = material
	body.add_child(visual)


func _guard(from: Vector3, to: Vector3) -> void:
	var direction := (to - from).normalized()
	var right := Vector3.UP.cross(direction).normalized()
	var normal := direction.cross(right).normalized()
	var basis := Basis(right, normal, direction)
	var length := from.distance_to(to)
	var center := (from + to) * 0.5
	# Full panel collider prevents squeezing between the visual uprights.
	_box(center + Vector3.UP * 0.54, Vector3(0.1, 1.08, length), "metal", true, false, basis)
	_box(center + Vector3.UP * 1.04, Vector3(0.075, 0.075, length), "metal", false, true, basis)
	_box(center + Vector3.UP * 0.52, Vector3(0.055, 0.055, length), "frame", false, true, basis)
	var count: int = maxi(1, int(ceil(length / 1.5)))
	for index in range(count + 1):
		var foot := from.lerp(to, float(index) / float(count))
		_box(foot + Vector3.UP * 0.52, Vector3(0.07, 1.04, 0.07), "metal")


func _box(p: Vector3, size: Vector3, material: String, solid: bool = false, visible_mesh: bool = true, basis: Basis = Basis.IDENTITY) -> void:
	var piece: Node3D = StaticBody3D.new() if solid else Node3D.new()
	piece.transform = Transform3D(basis, p)
	_geometry.add_child(piece)
	if visible_mesh:
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh
		visual.material_override = _materials.get(material) as Material
		piece.add_child(visual)
	if solid:
		var body := piece as StaticBody3D
		body.collision_layer = 1
		body.collision_mask = 6
		var collider := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		collider.shape = box
		body.add_child(collider)
