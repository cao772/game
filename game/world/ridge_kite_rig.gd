extends Node3D
## The box pad belongs to WorldState. Only the brief hand flight is visit-local.
const Frame = preload("res://world/ridge_kite_frame.gd")
const SWALLOW = preload("res://art/ridge_kite/swallow.glb")
const PAD_ID := "ridge_lookout_pad"
const HANDLE_REACH := 1.80
const LET_GO := 2.30
const SHORT := 0.36
const WIND_NAMES := ["西", "北", "东", "南"]
const WIND_ANGLES := [-PI/2.0, -PI, PI/2.0, 0.0]
const LINE_SEGMENTS := 8

var _frame := Frame.new()
var _kite: Node3D
var _line: Array[MeshInstance3D] = []
var _initialized := false
var _manual := false
var _weighted := false
var _day := 0
var _wind := 0
var _yaw := 0.0
var _face_yaw := 0.0
var _phase := 0.0
var _payout := 0.0

func _ready() -> void:
	add_child(_frame)
	_kite = SWALLOW.instantiate() as Node3D
	add_child(_kite)
	var cord := CylinderMesh.new()
	cord.radial_segments = 6
	cord.rings = 0
	cord.top_radius = 0.020
	cord.bottom_radius = 0.020
	cord.height = 1.0
	for i in range(LINE_SEGMENTS):
		var piece := MeshInstance3D.new()
		piece.mesh = cord
		piece.material_override = _frame.material(Frame.CORD)
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(piece)
		_line.append(piece)

func sync_pad(occupied_by: String, day: int) -> void:
	var pressed := not occupied_by.is_empty()
	if pressed != _weighted:
		_manual = false
	_weighted = pressed
	_set_day(day)
	if not _initialized:
		_initialized = true
		_payout = 1.0 if pressed else 0.0
		_yaw = WIND_ANGLES[_wind]
		_face_yaw = wrapf(_yaw + PI, -PI, PI) if pressed else 0.0
		_draw()

# Unrank one of 24 permutations from the four-day group. The first group
# introduces each direction in a known order; returning uses only the world day.
func _set_day(day: int) -> void:
	if day == _day:
		return
	_day = day
	var group := (day - 1) >> 2
	var mixed := group
	for pass_index in range(2):
		mixed = ((mixed ^ (mixed >> 16)) * 73244475) & 0x7fffffff
	var rank := (mixed ^ (mixed >> 16)) % 24
	var choices := [0, 1, 2, 3]
	var slot := (day - 1) % 4
	for i in range(slot + 1):
		var count := choices.size()
		_wind = choices.pop_at(rank % count)
		@warning_ignore("integer_division")
		rank = rank / count

func handle_radius() -> float:
	return LET_GO if _manual else HANDLE_REACH

func is_weighted() -> bool:
	return _weighted

func _approach_angle(angle: float, target: float, step: float) -> float:
	return wrapf(angle + clampf(wrapf(target-angle, -PI, PI), -step, step), -PI, PI)

func update_active(delta: float, day: int, feet: Vector3, hands_full: bool) -> void:
	if not _initialized:
		return
	_set_day(day)
	if hands_full or feet.distance_to(Frame.HANDLE) > LET_GO:
		_manual = false
	var goal := 1.0 if _weighted else (SHORT if _manual else 0.0)
	var rate := 0.22 if goal > _payout else 0.31
	_payout = move_toward(_payout, goal, delta * rate)
	_yaw = _approach_angle(_yaw, WIND_ANGLES[_wind], 1.30 * delta)
	# The bridle is on the printed face (+Z). Turn it toward the winch
	# so the final span pulls the bridle without passing through the sail.
	var parking := goal == 0.0 and _payout < 0.16
	var toward_winch := wrapf(_yaw + PI, -PI, PI)
	# Lift the forked tail above the cheeks before turning out of its rack.
	var face_goal := 0.0 if parking or _payout <= 0.055 else toward_winch
	_face_yaw = _approach_angle(_face_yaw, face_goal, (12.0 if parking else 7.8) * delta)
	_phase = fmod(_phase + delta, TAU * 100.0)
	_draw()

func handle_label() -> String:
	var turning := absf(wrapf(WIND_ANGLES[_wind] - _yaw, -PI, PI)) > 0.015
	var wind := ("风带正转向" if turning else "风吹向") + str(WIND_NAMES[_wind])
	if _weighted:
		return "查看长线棘轮 · " + wind
	if _manual:
		return "卷回短线 · " + wind
	return "摇柄试放短线 · " + wind

func use_handle(feet: Vector3, hands_full: bool) -> String:
	if hands_full or feet.distance_to(Frame.HANDLE) > handle_radius():
		return ""
	if _weighted:
		return "木箱压住踏板，棘爪已扣住长线。可以登望台看鸢，取走木座上的箱子便会收线。"
	_manual = not _manual
	if _manual:
		return "短线放出。再按 E 可卷回；走离手柄会自动收线。想登台看长线，可用木箱压住旁边的踏板。"
	return "松开手柄，卷筒正在把短线收回。"

func _draw() -> void:
	var p := _payout
	var direction := Vector3(sin(_yaw), 0.0, cos(_yaw))
	var sideways := Vector3(direction.z, 0, -direction.x)
	var airborne := smoothstep(0.0, SHORT, p)
	var reach := 10.0 * p * smoothstep(0.0, 0.12, p)
	var height := 6.0*p + 2.34*p*(1.0-p)
	var tip := Frame.REST + direction*reach + Vector3.UP*height
	tip += airborne * (sideways*0.16*sin(_phase*1.6) + Vector3.UP*0.10*sin(_phase*2.1))
	_kite.position = tip
	# While the kite swings through the vertical above the eye, dip the
	# bridle toward the actual incoming span, even midway through a yaw turn.
	var pull := ((Frame.GUIDE-tip)/float(LINE_SEGMENTS) + Vector3.DOWN*0.34*p*sin(PI/LINE_SEGMENTS)).normalized()
	var front := Vector3(sin(_face_yaw),0,cos(_face_yaw))
	var pitch := maxf(deg_to_rad(20.0)*airborne, atan2(-pull.dot(front), -pull.y) + deg_to_rad(18.0))
	_kite.rotation = Vector3(pitch, _face_yaw, 0.09*airborne*sin(_phase*1.6))
	_frame.pose(p, _weighted, _phase, _yaw)
	var last := Frame.GUIDE
	for i in range(LINE_SEGMENTS):
		var t := float(i+1) / float(LINE_SEGMENTS)
		var point := Frame.GUIDE.lerp(tip, t)
		point.y -= 0.34*p * sin(PI*t)
		var span := point-last
		var orientation := Basis(Quaternion(Vector3.UP, span.normalized()))
		orientation.y *= span.length()
		_line[i].transform = Transform3D(orientation, (last+point)*0.5)
		last = point
