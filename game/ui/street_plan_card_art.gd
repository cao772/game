extends Control

const SEAL := preload("res://art/street_plans/ink-seal-strip.png")
const CELL := Vector2(80, 56)
const LAST_FRAME := 9
const FPS := 20.0

var _illustration: Texture2D
var _frame := -1
var _elapsed := 0.0


func _init(illustration: Texture2D, owned: bool, fresh: bool) -> void:
	_illustration = illustration
	if owned:
		_frame = 0 if fresh else LAST_FRAME
	custom_minimum_size = Vector2(148, 88)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(queue_redraw)
	visibility_changed.connect(_on_visibility_changed)
	set_process(_frame == 0)


func _on_visibility_changed() -> void:
	if not is_visible_in_tree() and is_processing():
		_frame = LAST_FRAME
		set_process(false)
		queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	var next_frame := mini(int(_elapsed * FPS), LAST_FRAME)
	if next_frame != _frame:
		_frame = next_frame
		queue_redraw()
	if _frame == LAST_FRAME:
		set_process(false)


func _draw() -> void:
	var native := _illustration.get_size()
	var fitted := native * minf(size.x / native.x, size.y / native.y)
	var corner := (size - fitted) * 0.5
	draw_texture_rect(_illustration, Rect2(corner, fitted), false)
	if _frame < 0:
		return
	# Anchor to the fitted illustration, including when the cell has letterboxing.
	var scale_factor := fitted.y / 88.0
	var stamp := Rect2(corner + Vector2(3, 2) * scale_factor, Vector2(40, 28) * scale_factor)
	var source := Rect2(Vector2(_frame * CELL.x, 0), CELL)
	draw_texture_rect_region(SEAL, stamp, source)
