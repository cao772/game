extends Control
## The artwork occupies the whole [-32,32] square. The rim is drawn outside the data.
signal picked(key: String)
const PAPERS := {
	"YARD": preload("res://art/field_atlas/yard.png"),
	"RIDGE": preload("res://art/field_atlas/ridge.png"),
	"shore_low": preload("res://art/field_atlas/shore_low.png"),
	"shore_normal": preload("res://art/field_atlas/shore_normal.png")
}
const INK := Color("#2c332e")
const PARCHMENT := Color("#ffefca")
const PLAYER := Color("#18777e")
const PIN := Color("#b13228")
var paper: Texture2D
var rows: Array[Dictionary] = []
var pin := ""
var selection := ""
var here := false
var feet := Vector2.ZERO
var heading := 0.0

func _rect() -> Rect2:
	var side := minf(size.x,size.y)
	return Rect2((size-Vector2.ONE*side)*0.5, Vector2.ONE*side)

func _pixel(xz: Vector2) -> Vector2:
	var area := _rect()
	return area.position + (xz + Vector2.ONE*32.0)/64.0*area.size

func _draw() -> void:
	if paper == null:
		return
	draw_texture_rect(paper,_rect(),false)
	for row in rows:
		if row.held:
			continue
		var at := _pixel(row.xz)
		draw_circle(at,8,INK)
		match row.kind:
			"route":
				draw_colored_polygon(PackedVector2Array([at+Vector2(0,-7),at+Vector2(6,0),at+Vector2(0,7),at+Vector2(-6,0)]),PARCHMENT)
			"crate":
				draw_rect(Rect2(at-Vector2.ONE*5,Vector2.ONE*10),Color("#e6ad54"))
			"site":
				draw_circle(at,5,Color("#c4e4b1"))
	for row in rows:
		if row.held:
			continue
		var at := _pixel(row.xz)
		if row.key == selection:
			draw_arc(at,11,0,TAU,32,INK,2,true)
		if row.key == pin:
			draw_arc(at,14,0,TAU,32,PARCHMENT,5,true)
			draw_arc(at,14,0,TAU,32,PIN,3,true)
	if here:
		var at := _pixel(feet)
		var nose := Vector2(-sin(heading),-cos(heading))
		var wing := nose.orthogonal()
		var triangle := PackedVector2Array([at+nose*12,at-nose*7+wing*7,at-nose*4,at-nose*7-wing*7])
		draw_colored_polygon(triangle,PLAYER)
		triangle.append(triangle[0])
		draw_polyline(triangle,Color.WHITE,2,true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var nearest := ""
		var distance := 15.0
		for row in rows:
			if row.held:
				continue
			var d: float = event.position.distance_to(_pixel(row.xz))
			if d < distance:
				nearest = row.key
				distance = d
		if not nearest.is_empty():
			picked.emit(nearest)
		accept_event()
