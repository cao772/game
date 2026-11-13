extends RefCounted
## The courier's short evening trip uses the existing world clock, shore bed and pier.
const Shore = preload("res://runtime/shore_water.gd")

const DEPART := 1030 # 17:10
const CHECK_MINUTES := 3
const LOW_WALK_MINUTES := 8
const DRY_WALK_MINUTES := 10
const LAST_RETURN := DEPART + 2 * DRY_WALK_MINUTES + CHECK_MINUTES
const POST := Vector3(26, 0, 7)
const CHECK_FEET := Vector3(26, 0, 6.05)
const SIGN_FACE := Vector3(26, 0.72, 6.72)

static func timetable(station: Dictionary, low: bool) -> Array:
	var outward_minutes := LOW_WALK_MINUTES if low else DRY_WALK_MINUTES
	var arrive := DEPART + outward_minutes
	var leave := arrive + CHECK_MINUTES
	var finish := leave + outward_minutes
	var path: Array = [station.points[0].duplicate(), [-9,0,-11], [2,0,-11], [8,0,-12.25]]
	if low:
		for z in [Shore.NORTH, Shore.NORTH + Shore.RUN, Shore.SOUTH - Shore.RUN, Shore.SOUTH]:
			path.append([10, Shore.bed_height(z), z])
		path.append([11,0,6])
		path.append([17.8,0,6])
	else:
		path.append([17.8,0,-12.25])
		path.append([17.8,0,6])
	path.append([CHECK_FEET.x, CHECK_FEET.y, CHECK_FEET.z])
	var back := path.duplicate(true)
	back.reverse()
	var before := station.duplicate(true)
	before.end = DEPART
	var after := station.duplicate(true)
	after.start = finish
	var via := "经湾底石带" if low else "沿东侧干栈板"
	return [
		before,
		_leg(DEPART, arrive, path, via + "去东桩对货签", "东栈桥双斜纹桩", "out"),
		_leg(arrive, leave, [path.back().duplicate()], "举起手中木签，核对桩上两道斜纹", "东栈桥双斜纹桩", "check"),
		_leg(leave, finish, back, "核过货签，" + via + "回岸等船", "西岸等船处", "back"),
		after
	]

static func _leg(start: int, end: int, points: Array, activity: String, stop: String, phase: String) -> Dictionary:
	return {
		"start": start, "end": end, "region": "SHORE", "points": points,
		"heading": 0.0, "activity": activity, "destination": "SHORE", "next_route": "",
		"stop_label": stop, "delivery_phase": phase
	}
