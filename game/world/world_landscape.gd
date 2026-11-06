extends Node3D
## Bounded, procedural scenery. The caller owns actors, interactions and lighting.
## Walking surfaces use layer 1; the caller's character uses layer 2 / mask 1.

const ROAD_WIDTH: float = 4.2
const LOOKOUT_HEIGHT: float = 2.4
const RAMP_RUN: float = 8.0
const RAMP_WIDTH: float = 4.0

var _generated: Node3D
var _rotor: Node3D
var _materials: Dictionary = {}


func build(region_id: String) -> void:
	# Detach first so rebuilding does not leave old collision bodies in the world.
	_rotor = null
	if is_instance_valid(_generated):
		remove_child(_generated)
		_generated.queue_free()
	_generated = Node3D.new()
	_generated.name = "RegionScenery"
	add_child(_generated)
	match region_id:
		"RIDGE":
			_ground(Color("77915c"), Color("a9ad8a"))
			_triangle_paths(Vector2(0, 28), Vector2(28, -5), Color("c7b58c"))
			_build_ridge()
		"SHORE":
			_ground(Color("a2b0a4"), Color("778a89"))
			_triangle_paths(Vector2(-28, 6), Vector2(0, -28), Color("cdd0b7"))
			_build_shore()
		_:
			_ground(Color("aaad8c"), Color("c0b79b"))
			_triangle_paths(Vector2(0, -28), Vector2(28, 6), Color("e0caa1"))
			_build_yard()


func _process(delta: float) -> void:
	if is_instance_valid(_rotor):
		_rotor.rotate_z(delta * 0.32)


func _ground(ground_color: Color, wall_color: Color) -> void:
	var ground := _group("GroundAndBoundary")
	# The floor's top is exactly y=0, including the full [-32,32] square.
	_box(ground, Vector3(0, -0.25, 0), Vector3(64, 0.5, 64), ground_color, true)
	# Inner faces are at +/-31.5. All exit triggers are at +/-28, inside the walls.
	_box(ground, Vector3(-31.75, 0.525, 0), Vector3(0.5, 1.05, 64), wall_color, true)
	_box(ground, Vector3(31.75, 0.525, 0), Vector3(0.5, 1.05, 64), wall_color, true)
	_box(ground, Vector3(0, 0.525, -31.75), Vector3(63, 1.05, 0.5), wall_color, true)
	_box(ground, Vector3(0, 0.525, 31.75), Vector3(63, 1.05, 0.5), wall_color, true)


func _triangle_paths(first: Vector2, second: Vector2, color: Color) -> void:
	var center := Vector2(0, 8)
	_road(center, first, ROAD_WIDTH, color)
	_road(first, second, ROAD_WIDTH, color)
	_road(second, center, ROAD_WIDTH, color)
	# Flat, collision-free paint never adds a curb at an arrival point.
	_box(_generated, Vector3(0, 0.008, 8), Vector3(6, 0.016, 6), color)


func _build_yard() -> void:
	var houses := _group("LowHouses")
	_house(houses, Vector2(-19, -17), Vector2(9, 8), 3.5, Color("e3d3ad"), Color("ab6249"))
	_house(houses, Vector2(-19, 8), Vector2(8, 9), 3.1, Color("d2c4a1"), Color("717f83"))
	_house(houses, Vector2(-14, 24), Vector2(11, 6), 3.2, Color("d9cbb2"), Color("a66f50"))
	_house(houses, Vector2(18, 23), Vector2(8, 6), 3.4, Color("e0c8a2"), Color("78868c"))
	_house(houses, Vector2(21, -21), Vector2(8, 7), 3.6, Color("cccfaf"), Color("a96650"))
	# Gaps between the west houses provide views through to the central lanes.
	_road(Vector2(-26, -4), Vector2(-4, -4), 2.5, Color("e0caa1"))
	_road(Vector2(-25, 16), Vector2(0, 16), 2.5, Color("e0caa1"))
	_road(Vector2(0, 16), Vector2(0, 8), 2.5, Color("e0caa1"))
	_build_well(Vector3(-9, 0, 2))
	_build_sign(Vector3(8, 0, -6))
	_build_stall(Vector3(8, 0, 0))
	var trees := _group("CourtyardTrees")
	_tree(trees, Vector2(-26, 23), 0.9)
	_tree(trees, Vector2(26, 23), 0.85)
	_tree(trees, Vector2(-27, -25), 0.8)
	# Fixed seating stays clear of both crate anchors at (+/-6,7).
	_bench(_generated, Vector3(-9, 0, 11), 0.0)
	_bench(_generated, Vector3(13, 0, 14), PI * 0.5)


func _build_ridge() -> void:
	_build_lookout()
	_road(Vector2(0, 8), Vector2(-8, -3), 3.6, Color("c7b58c"))
	_build_bridge(Vector3(14, 0, 1.5))
	_build_windmill(Vector3(-23, 0, 17))
	var trees := _group("RidgeTrees")
	for point in [Vector2(-24, -23), Vector2(-21, -2), Vector2(-16, 25), Vector2(21, 22), Vector2(22, -23)]:
		_tree(trees, point, 1.0)
	_bench(_generated, Vector3(-14, 0, 4), -PI * 0.5)
	var horizon := _group("DistantMountains")
	# Horizon geometry is outside the boundary and deliberately has no collision.
	_cone(horizon, Vector3(-36, 7, -48), 16.0, 18.0, Color("768c82"))
	_cone(horizon, Vector3(-7, 10, -58), 19.0, 25.0, Color("8da59b"))
	_cone(horizon, Vector3(29, 6, -51), 17.0, 18.0, Color("6d837c"))
	_cone(horizon, Vector3(-56, 5, 1), 19.0, 17.0, Color("91a595"))


func _build_shore() -> void:
	var waterfront := _group("Waterfront")
	# The water starts at x=32.3, entirely beyond the x=31.5 inner barrier.
	_box(waterfront, Vector3(64.3, -0.28, 0), Vector3(64, 0.12, 112), Color("528e9b"))
	for index in range(7):
		_box(waterfront, Vector3(36.0 + index * 7.0, -0.211, -15.0 + index * 4.0), Vector3(3.7, 0.012, 0.1), Color("80b2b8"))
	# Flush boards share the underlying floor collision; there are no raised steps.
	_box(waterfront, Vector3(23, 0.009, 4), Vector3(14, 0.018, 53), Color("a69270"))
	_box(waterfront, Vector3(12, 0.01, 11), Vector3(12, 0.02, 5), Color("b59e75"))
	for index in range(22):
		_box(waterfront, Vector3(23, 0.021, -21.5 + index * 2.4), Vector3(13.7, 0.008, 0.045), Color("81745b"))
	for index in range(11):
		var z: float = -20.0 + index * 4.7
		_box(waterfront, Vector3(30.3, 0.65, z), Vector3(0.2, 1.3, 0.2), Color("777b69"), true)
	_box(waterfront, Vector3(30.3, 1.02, 3.5), Vector3(0.15, 0.15, 47.5), Color("b6ae8c"), true)
	# Mooring posts are beside the deck, away from the interaction point (12,11).
	for point in [Vector2(18, 15), Vector2(26, 15), Vector2(26, 7)]:
		_cylinder(waterfront, Vector3(point.x, 0.45, point.y), 0.27, 0.9, Color("7e6f56"), true)
	_build_old_wall()
	_build_tide_stone(Vector3(4, 0, -13))
	_road(Vector2(0, 8), Vector2(12, 11), 3.6, Color("cdd0b7"))
	_road(Vector2(0, -13), Vector2(4, -13), 2.6, Color("cdd0b7"))
	_house(_generated, Vector2(-22, 22), Vector2(8, 7), 3.1, Color("d2d7bd"), Color("73848c"))
	_bench(_generated, Vector3(23, 0, 23), PI * 0.5)
	_bench(_generated, Vector3(-14, 0, 0), PI * 0.5)
	var shelter := _group("FerryShelter")
	_box(shelter, Vector3(23, 2.9, -15), Vector3(7, 0.2, 6), Color("718e91"))
	for offset in [Vector2(-3.2, -2.5), Vector2(3.2, -2.5), Vector2(-3.2, 2.5), Vector2(3.2, 2.5)]:
		_box(shelter, Vector3(23 + offset.x, 1.4, -15 + offset.y), Vector3(0.18, 2.8, 0.18), Color("686e61"), true)


func _build_lookout() -> void:
	var lookout := _group("AccessibleLookout")
	var wood := Color("a48d62")
	_box(lookout, Vector3(-8, LOOKOUT_HEIGHT * 0.5, -14), Vector3(6, LOOKOUT_HEIGHT, 6), Color("7d8870"), true)
	_box(lookout, Vector3(-8, LOOKOUT_HEIGHT + 0.006, -14), Vector3(6, 0.012, 6), wood)
	# A continuous tilted slab: top endpoints are exactly (y=0,z=-3) and
	# (y=2.4,z=-11). atan(2.4/8)=16.699 degrees, below the requested 24.
	var angle: float = atan(LOOKOUT_HEIGHT / RAMP_RUN)
	var normal := Vector3(0, cos(angle), sin(angle))
	var thickness: float = 0.26
	var ramp_center := Vector3(-8, LOOKOUT_HEIGHT * 0.5, -7) - normal * thickness * 0.5
	var ramp_length: float = sqrt(RAMP_RUN * RAMP_RUN + LOOKOUT_HEIGHT * LOOKOUT_HEIGHT)
	_box(lookout, ramp_center, Vector3(RAMP_WIDTH, thickness, ramp_length), wood, true, Vector3(angle, 0, 0))
	# Side rails follow the ramp. Nothing crosses either end of the walking strip.
	for x in [-10.12, -5.88]:
		_box(lookout, Vector3(x, 2.15, -7), Vector3(0.12, 0.14, ramp_length), Color("dfcba0"), true, Vector3(angle, 0, 0))
		for index in range(3):
			var progress: float = float(index) * 0.5
			_box(lookout, Vector3(x, LOOKOUT_HEIGHT * progress + 0.5, -3.0 - RAMP_RUN * progress), Vector3(0.14, 1.0, 0.14), Color("82745b"), true)
	_box(lookout, Vector3(-11.1, 2.95, -14), Vector3(0.2, 1.1, 6.2), Color("c9ba93"), true)
	_box(lookout, Vector3(-4.9, 2.95, -14), Vector3(0.2, 1.1, 6.2), Color("c9ba93"), true)
	_box(lookout, Vector3(-8, 2.95, -17.1), Vector3(6.4, 1.1, 0.2), Color("c9ba93"), true)
	_box(lookout, Vector3(-10.65, 2.95, -10.95), Vector3(0.7, 1.1, 0.2), Color("c9ba93"), true)
	_box(lookout, Vector3(-5.35, 2.95, -10.95), Vector3(0.7, 1.1, 0.2), Color("c9ba93"), true)


func _build_bridge(center: Vector3) -> void:
	var bridge := _group("DryGullyBridge")
	bridge.position = center
	bridge.rotation.y = atan2(28.0, -13.0)
	# A dark inset and a flat timber surface suggest a shallow dry gully.
	# Its long axis follows the center-to-east route instead of cutting across it.
	_box(bridge, Vector3(0, 0.011, 0), Vector3(8, 0.014, 3), Color("7f856c"))
	_box(bridge, Vector3(0, 0.021, 0), Vector3(3.8, 0.016, 9), Color("b7a47d"))
	for index in range(9):
		_box(bridge, Vector3(0, 0.034, -4 + index), Vector3(3.65, 0.006, 0.045), Color("7e755f"))
	for x in [-2.1, 2.1]:
		_box(bridge, Vector3(x, 0.8, 0), Vector3(0.12, 0.14, 9), Color("c5b48c"), true)
		for z in [-4.3, 0.0, 4.3]:
			_box(bridge, Vector3(x, 0.48, z), Vector3(0.16, 0.96, 0.16), Color("81735a"), true)


func _build_windmill(center: Vector3) -> void:
	var mill := _group("MeadowWindmill")
	_cylinder(mill, center + Vector3(0, 2.35, 0), 1.25, 4.7, Color("ded9ba"), true)
	_cone(mill, center + Vector3(0, 5.1, 0), 1.7, 1.8, Color("916652"))
	_rotor = Node3D.new()
	_rotor.name = "WindRotor"
	_rotor.position = center + Vector3(0, 4.4, 1.5)
	mill.add_child(_rotor)
	_cylinder(_rotor, Vector3.ZERO, 0.28, 0.42, Color("645e50"), false, Vector3(PI * 0.5, 0, 0))
	for index in range(4):
		var blade := Node3D.new()
		blade.rotation.z = float(index) * PI * 0.5
		_rotor.add_child(blade)
		_box(blade, Vector3(0, 1.65, 0), Vector3(0.18, 3.3, 0.12), Color("76674f"))
		_box(blade, Vector3(0.32, 2.0, 0.015), Vector3(0.7, 2.0, 0.06), Color("e8d8a7"))


func _build_well(center: Vector3) -> void:
	var well := _group("CoveredStoneWell")
	_cylinder(well, center + Vector3(0, 0.4, 0), 1.25, 0.8, Color("b7b8a2"), true)
	_cylinder(well, center + Vector3(0, 0.815, 0), 0.95, 0.03, Color("5e766d"))
	for x in [-1.1, 1.1]:
		_box(well, center + Vector3(x, 1.4, 0), Vector3(0.16, 2.8, 0.16), Color("8b7556"), true)
	_box(well, center + Vector3(0, 2.78, 0), Vector3(2.6, 0.18, 0.22), Color("8b7556"))
	_box(well, center + Vector3(0, 1.8, 0), Vector3(0.04, 1.8, 0.04), Color("d1bc8c"))


func _build_sign(center: Vector3) -> void:
	var signpost := _group("CrossroadsSign")
	_box(signpost, center + Vector3(0, 1.15, 0), Vector3(0.18, 2.3, 0.18), Color("796b51"), true)
	_box(signpost, center + Vector3(0, 1.95, 0), Vector3(1.5, 0.32, 0.12), Color("c2b675"))
	_box(signpost, center + Vector3(0.15, 1.5, 0), Vector3(1.5, 0.32, 0.12), Color("789a9e"), false, Vector3(0, 0.35, 0))


func _build_stall(center: Vector3) -> void:
	var stall := _group("MarketAwning")
	# The merchant's anchor (8,-3) and its 1.2m radius remain in front of the table.
	_box(stall, center + Vector3(0, 0.85, 0), Vector3(4, 0.16, 1.0), Color("a4895f"), true)
	for x in [-1.7, 1.7]:
		_box(stall, center + Vector3(x, 0.4, 0), Vector3(0.18, 0.8, 0.7), Color("857254"), true)
	for x in [-3.0, 3.0]:
		_box(stall, center + Vector3(x, 1.4, -1), Vector3(0.16, 2.8, 0.16), Color("817158"), true)
	for index in range(6):
		var stripe_color: Color = Color("b96f4d") if index % 2 == 0 else Color("ead8ad")
		_box(stall, center + Vector3(-2.5 + index, 2.8, -1), Vector3(1, 0.13, 4.2), stripe_color)


func _build_old_wall() -> void:
	var wall := _group("OldShoreWall")
	_box(wall, Vector3(-20, 1.25, -18), Vector3(16, 2.5, 0.8), Color("c1c6b0"), true)
	_box(wall, Vector3(-3.9, 0.85, -18), Vector3(1.8, 1.7, 0.8), Color("b2bba5"), true)
	_box(wall, Vector3(-20, 2.57, -18), Vector3(16.3, 0.14, 1.0), Color("80958c"))
	_box(wall, Vector3(-3.9, 1.77, -18), Vector3(2.0, 0.14, 1.0), Color("80958c"))
	# The diagonal main road crosses the 7.2m opening at x=-8.24.
	_road(Vector2(-8, -24), Vector2(-8, -12), 2.6, Color("cdd0b7"))


func _build_tide_stone(center: Vector3) -> void:
	var stone := _group("WaterLevelStone")
	_box(stone, center + Vector3(0, 0.9, 0), Vector3(0.7, 1.8, 0.55), Color("808e84"), true)
	for index in range(5):
		_box(stone, center + Vector3(0.08, 0.3 + index * 0.28, 0.282), Vector3(0.38, 0.035, 0.018), Color("dedfc5"))


func _house(parent: Node3D, center: Vector2, footprint: Vector2, height: float, wall_color: Color, roof_color: Color) -> void:
	var house := Node3D.new()
	house.position = Vector3(center.x, 0, center.y)
	parent.add_child(house)
	_box(house, Vector3(0, height * 0.5, 0), Vector3(footprint.x, height, footprint.y), wall_color, true)
	var roof_run: float = footprint.x * 0.5 + 0.45
	var roof_rise: float = 1.2
	var roof_angle: float = atan(roof_rise / roof_run)
	var roof_length: float = sqrt(roof_run * roof_run + roof_rise * roof_rise)
	for side in [-1.0, 1.0]:
		_box(house, Vector3(side * roof_run * 0.5, height + roof_rise * 0.5, 0), Vector3(roof_length, 0.18, footprint.y + 0.8), roof_color, false, Vector3(0, 0, -side * roof_angle))
	for x in [-footprint.x * 0.26, footprint.x * 0.26]:
		_box(house, Vector3(x, height * 0.58, footprint.y * 0.5 + 0.02), Vector3(1.0, 0.95, 0.04), Color("667d7b"))
		_box(house, Vector3(x, height * 0.58 - 0.53, footprint.y * 0.5 + 0.08), Vector3(1.18, 0.1, 0.22), Color("b6a486"))


func _tree(parent: Node3D, point: Vector2, scale_factor: float) -> void:
	var tree := Node3D.new()
	tree.position = Vector3(point.x, 0, point.y)
	parent.add_child(tree)
	_cylinder(tree, Vector3(0, 1.0 * scale_factor, 0), 0.28 * scale_factor, 2.0 * scale_factor, Color("7f7557"), true)
	_cone(tree, Vector3(0, 3.2 * scale_factor, 0), 1.8 * scale_factor, 3.8 * scale_factor, Color("567b60"))
	_cone(tree, Vector3(0, 4.2 * scale_factor, 0), 1.25 * scale_factor, 2.5 * scale_factor, Color("799467"))


func _bench(parent: Node3D, center: Vector3, heading: float) -> void:
	var bench := Node3D.new()
	bench.position = center
	bench.rotation.y = heading
	parent.add_child(bench)
	_box(bench, Vector3(0, 0.5, 0), Vector3(2.4, 0.16, 0.65), Color("ad956e"), true)
	for x in [-0.85, 0.85]:
		_box(bench, Vector3(x, 0.22, 0), Vector3(0.18, 0.44, 0.55), Color("787b65"), true)
	_box(bench, Vector3(0, 0.94, 0.28), Vector3(2.4, 0.62, 0.12), Color("ad956e"), true)


func _road(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	var difference := to - from
	var midpoint := (from + to) * 0.5
	_box(_generated, Vector3(midpoint.x, 0.007, midpoint.y), Vector3(width, 0.014, difference.length()), color, false, Vector3(0, atan2(difference.x, difference.y), 0))


func _group(label: String) -> Node3D:
	var group := Node3D.new()
	group.name = label
	_generated.add_child(group)
	return group


func _material(color: Color) -> StandardMaterial3D:
	if _materials.has(color):
		return _materials[color] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	material.metallic_specular = 0.15
	_materials[color] = material
	return material


func _box(parent: Node3D, center: Vector3, size: Vector3, color: Color, solid: bool = false, orientation: Vector3 = Vector3.ZERO) -> Node3D:
	var piece: Node3D = StaticBody3D.new() if solid else Node3D.new()
	piece.position = center
	piece.rotation = orientation
	parent.add_child(piece)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	piece.add_child(mesh)
	if solid:
		var body := piece as StaticBody3D
		body.collision_layer = 1
		body.collision_mask = 2
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
	return piece


func _cylinder(parent: Node3D, center: Vector3, radius: float, height: float, color: Color, solid: bool = false, orientation: Vector3 = Vector3.ZERO) -> void:
	var piece: Node3D = StaticBody3D.new() if solid else Node3D.new()
	piece.position = center
	piece.rotation = orientation
	parent.add_child(piece)
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 12
	mesh.mesh = cylinder
	mesh.material_override = _material(color)
	piece.add_child(mesh)
	if solid:
		var body := piece as StaticBody3D
		body.collision_layer = 1
		body.collision_mask = 2
		var shape := CollisionShape3D.new()
		var cylinder_shape := CylinderShape3D.new()
		cylinder_shape.radius = radius
		cylinder_shape.height = height
		shape.shape = cylinder_shape
		body.add_child(shape)


func _cone(parent: Node3D, center: Vector3, radius: float, height: float, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.position = center
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = height
	cone.radial_segments = 10
	mesh.mesh = cone
	mesh.material_override = _material(color)
	parent.add_child(mesh)
