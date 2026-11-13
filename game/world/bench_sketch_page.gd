extends Node3D
## Pencil strokes on the visitor's private page, in notebook-local X/Z metres.

const STROKES := {
	"rim": [
		[Vector2(-0.14, 0.024), Vector2(0.079, 0.055)],
		[Vector2(0.079, 0.055), Vector2(0.139, -0.018)],
		[Vector2(-0.14, 0.024), Vector2(-0.08, -0.05)],
		[Vector2(-0.08, -0.05), Vector2(0.139, -0.018)],
	],
	"gap": [
		[Vector2(-0.108, -0.067), Vector2(0.112, -0.054)],
		[Vector2(-0.092, -0.066), Vector2(-0.107, 0.076)],
		[Vector2(-0.059, -0.064), Vector2(-0.073, 0.074)],
		[Vector2(0.069, -0.057), Vector2(0.058, 0.068)],
		[Vector2(0.101, -0.055), Vector2(0.09, 0.067)],
	],
}
var _drawings: Dictionary = {}


func _ready() -> void:
	var graphite := StandardMaterial3D.new()
	graphite.albedo_color = Color("473f37")
	var nib := BoxMesh.new()
	nib.size = Vector3(1, 0.002, 0.018)
	for subject in STROKES:
		var drawing := Node3D.new()
		add_child(drawing)
		_drawings[subject] = drawing
		for stroke in STROKES[subject]:
			var start: Vector2 = stroke[0]
			var end: Vector2 = stroke[1]
			var mark := MeshInstance3D.new()
			mark.mesh = nib
			mark.material_override = graphite
			mark.rotation.y = -(end - start).angle()
			drawing.add_child(mark)
		drawing.hide()


func draw_to(subject: String, seconds: float) -> Vector3:
	var drawing: Node3D = _drawings[subject]
	for group in _drawings.values():
		group.visible = group == drawing
	var strokes: Array = STROKES[subject]
	# Thirty seconds at the subject, with the finished page held for the last four.
	var progress := clampf(seconds / 26.0, 0.0, 1.0) * strokes.size()
	var tip: Vector2 = strokes[0][0]
	for index in range(strokes.size()):
		var from: Vector2 = strokes[index][0]
		var to: Vector2 = strokes[index][1]
		var fraction := clampf(progress - index, 0.0, 1.0)
		var mark := drawing.get_child(index) as MeshInstance3D
		mark.visible = fraction > 0.0
		if mark.visible:
			tip = from.lerp(to, fraction)
			var center := (from + tip) * 0.5
			mark.position = Vector3(center.x, 0.032, center.y)
			mark.scale.x = from.distance_to(tip)
	return Vector3(tip.x, 0.033, tip.y)
