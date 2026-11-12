extends Node3D
## The matching two-cut marks are readable from either side of the courier's tally.

func _ready() -> void:
	_piece(Vector3.ZERO, Vector3(0.32, 0.20, 0.036), Color("deb775"))
	for x in [-0.065, 0.065]:
		var stripe := _piece(Vector3(x, 0, 0), Vector3(0.03, 0.168, 0.040), Color("4b4336"))
		stripe.rotation.z = -0.36

func _piece(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var board := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	board.mesh = shape
	var finish := StandardMaterial3D.new()
	finish.albedo_color = color
	finish.roughness = 0.86
	board.material_override = finish
	board.position = at
	add_child(board)
	return board
