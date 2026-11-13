extends RefCounted
## Fixed shore calendar and footprint. Derived entirely from the existing world day.

const WEST := 2.0
const EAST := 16.0
const NORTH := -9.0
const SOUTH := 5.0
const RUN := 3.0
const DEPTH := 0.65
const GUTTER := 14.0
const GUTTER_DROP := 0.40
const WAIT_AT := Vector3(6.5, 0, -14.8)
const WAIT_RADIUS := 2.25
const NORTH_LANDING := Vector3(10, 0.04, -11)
const SOUTH_LANDING := Vector3(12, 0.04, 7)

static func is_low(day: int) -> bool:
	# Each pair contains both levels. A fixed integer mix chooses their order.
	var pair := (day - 1) >> 1
	var order := ((pair * 1103515245 + 12345) >> 16) & 1
	return ((day - 1) & 1) == order

static func next_change(day: int, minute: int, last_day: int) -> int:
	for offset in [1, 2]:
		var next_day: int = day + offset
		if next_day <= last_day and is_low(next_day) != is_low(day):
			return offset * 1440 - minute
	return 0

static func water_name(low: bool) -> String:
	return "低水" if low else "平水"

static func bed_height(z: float) -> float:
	return -DEPTH * clampf(minf(z - NORTH, SOUTH - z) / RUN, 0.0, 1.0)

static func safe_feet(feet: Vector3, low: bool) -> Vector3:
	# Include the capsule radius and physics skin at each side of the flood barrier.
	if feet.x < WEST - 0.33 or feet.x > EAST + 0.33 or feet.z < NORTH - 0.33 or feet.z > SOUTH + 0.33:
		return feet
	if not low:
		# A legal save leaning against the barrier must restore in place.
		var dx := maxf(maxf(WEST - feet.x, feet.x - EAST), 0.0)
		var dz := maxf(maxf(NORTH - feet.z, feet.z - SOUTH), 0.0)
		if dx * dx + dz * dz >= 0.32 * 0.32:
			return feet
		return NORTH_LANDING if feet.distance_squared_to(NORTH_LANDING) <= feet.distance_squared_to(SOUTH_LANDING) else SOUTH_LANDING
	var ground := bed_height(feet.z)
	if feet.z > NORTH + RUN and feet.z < SOUTH - RUN:
		ground -= GUTTER_DROP * clampf((feet.x - GUTTER) / (EAST - GUTTER), 0.0, 1.0)
	# The round foot may graze a bank without entering it. Test the actual
	# capsule segment against the dry floor box, including its top and underside.
	var side_distance := maxf(0.0, minf(feet.x - WEST, EAST - feet.x))
	var vertical_gap := maxf(0.0, maxf(feet.y + 0.32, -1.1 - (feet.y + 1.65 - 0.32)))
	if side_distance * side_distance + vertical_gap * vertical_gap < 0.32 * 0.32 and feet.y < 0.0:
		ground = 0.0
	if feet.y < ground - 0.015:
		return Vector3(feet.x, ground + 0.04, feet.z)
	return feet
