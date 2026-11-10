extends "res://runtime/save_store.gd"
## Single-writer construction ledger. Each command is proposed on a deep copy.
const SLOT := "street_plans"
const CARDS := ["lamp", "seat", "guide"]
const NAMES := {"lamp":"街灯", "seat":"歇脚凳", "guide":"指路牌"}
const USE := {"lamp":"点亮或熄灭街角灯", "seat":"坐下看街景，随时起身", "guide":"切换地标，沿距离提示步行"}
const PLACES := {"cross":"横街口", "south":"后巷南口", "north":"北巷"}
const DIRECTIONS := {"cross":"沿主街向北，到东西横街西口", "south":"出阅览室后门，沿后巷向北到洗择棚东南侧", "north":"沿横街向西，沿楼后巷向北走"}
const ALLOWED := {"cross":["lamp","guide"], "south":["seat","lamp"], "north":["guide","seat"]}
const ORDERS := [
	["lamp","seat","guide"], ["lamp","guide","seat"], ["seat","lamp","guide"],
	["seat","guide","lamp"], ["guide","lamp","seat"], ["guide","seat","lamp"],
]
const MODULUS := 2147483647
var data: Dictionary = {}
var generation := 0
var problem := ""


func _root_component() -> String:
	return "street_construction_v1"


func _valid_slot(slot: String) -> bool:
	return slot == SLOT


func load_book() -> void:
	var record := read_latest(SLOT)
	if record.get("code") == "NO_SAVES" and generation == 0:
		problem = ""
		return
	if record.get("code") != "LOADED" or not _valid(record.get("payload")):
		problem = "建设簿读取失败，保留现场。检查存储后可重读。"
		return
	if int(record.generation) < generation:
		problem = "建设记录早于当前现场，请检查存储后重读。"
		return
	data = record.payload.duplicate(true)
	generation = int(record.generation)
	problem = ""


func start_book() -> void:
	if not data.is_empty() or not problem.is_empty():
		return
	var order := _seed_below(6)
	var stream := _seed_below(MODULUS - 1)
	if order < 0 or stream < 0:
		problem = "暂时无法初始化图样簿，请重试。"
		return
	_commit({"version":1, "order":order, "stream":stream+1, "owned":[], "surveyed":[], "offer":"",
		"accepted":"", "skipped":"", "built":{}})


func _seed_below(count: int) -> int:
	var limit := 4294967296 - (4294967296 % count)
	while true:
		var bytes := Crypto.new().generate_random_bytes(4)
		if bytes.size() != 4:
			return -1
		var value := bytes.decode_u32(0)
		if value < limit:
			return value % count
	return -1


func _integer(value: Variant, lo: int, hi: int) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value)) and value >= lo and value <= hi and value == floor(value)


func _valid(v: Variant) -> bool:
	if not v is Dictionary or v.size() != 9 or not v.has_all(["version","order","stream","owned","surveyed","offer","accepted","skipped","built"]):
		return false
	if not _integer(v.version, 1, 1) or not _integer(v.order, 0, 5) or not _integer(v.stream, 1, MODULUS - 1):
		return false
	if not v.owned is Array or v.owned.size() > 3 or not v.built is Dictionary:
		return false
	if not v.surveyed is Array or v.surveyed.size() > 2 or v.owned.size() > 1 + v.surveyed.size():
		return false
	for i in range(v.surveyed.size()):
		if not PLACES.has(v.surveyed[i]) or v.surveyed.find(v.surveyed[i]) != i:
			return false
	for i in range(v.owned.size()):
		if v.owned[i] != ORDERS[int(v.order)][i]:
			return false
	for place in v.built:
		if v.surveyed.size() < 2 and not v.surveyed.has(place):
			return false
		if not PLACES.has(place) or not v.owned.has(v.built[place]) or not ALLOWED[place].has(v.built[place]):
			return false
	for place in [v.offer, v.skipped]:
		if not place is String or (place != "" and (not PLACES.has(place) or v.built.has(place))):
			return false
	if not v.accepted is String or (v.offer != "" and v.skipped != ""):
		return false
	if v.offer != "" or v.skipped != "":
		var location: String = v.offer if v.offer != "" else v.skipped
		if not v.owned.any(func(card): return ALLOWED[location].has(card)):
			return false
	return v.accepted == "" or (v.offer != "" and v.owned.has(v.accepted) and ALLOWED[v.offer].has(v.accepted))


func credits() -> int:
	return 0 if data.is_empty() else 1 + data.surveyed.size() - data.owned.size()


func available_sites() -> Array:
	var choices := []
	if data.is_empty():
		return choices
	for site in PLACES:
		if data.built.has(site):
			continue
		for card in data.owned:
			if ALLOWED[site].has(card):
				choices.append(site)
				break
	if choices.size() > 1:
		choices.erase(data.skipped)
	return choices


func act(action: String, argument: String, expected_generation: int) -> String:
	if not problem.is_empty():
		return problem
	if data.is_empty() or expected_generation != generation:
		return "建设簿已更新，请按当前选项操作。"
	var next := data.duplicate(true)
	var message := ""
	match action:
		"survey":
			if not PLACES.has(argument):
				return "没有这个建设地块。"
			if next.surveyed.has(argument):
				return "这处已勘察，登记仍有效。"
			if next.surveyed.size() >= 2:
				return "两处勘察已齐。"
			next.surveyed.append(argument)
			message = "已登记%s · 获得一次免费抽图样。" % PLACES[argument]
		"draw":
			if next.owned.size() >= CARDS.size():
				return "三张图样已经集齐。"
			if credits() <= 0:
				return "先到一处还没登记的地块勘察。"
			if argument != "board" and (not PLACES.has(argument) or next.owned.is_empty()):
				return "首张请到主街图样板领取。"
			var card: String = ORDERS[int(next.order)][next.owned.size()]
			next.owned.append(card)
			message = "新图样 · %s　%s" % [NAMES[card], USE[card]]
		"offer":
			var choices := available_sites()
			if next.offer != "" or choices.is_empty():
				return "当前没有新机会。"
			var count := choices.size()
			# 2,147,483,646 is divisible by every possible pool size (1, 2, 3).
			# The pending roll was committed before this request. An independent
			# fresh value for the following offer commits with today's result.
			var following := _seed_below(MODULUS - 1)
			if following < 0:
				return "暂时无法准备下一次机会，本次尚未领取。"
			next.offer = choices[(int(next.stream) - 1) % count]
			next.stream = following + 1
			next.skipped = ""
			message = "收到建设机会 · " + str(PLACES[next.offer])
		"accept":
			if next.offer == "" or next.accepted != "" or not next.owned.has(argument) or not ALLOWED[next.offer].has(argument):
				return "这张图样当前无法承接。"
			next.accepted = argument
			message = "已承接 · 到%s瞄准地块标记按 E 建造。" % PLACES[next.offer]
		"skip":
			if next.offer == "":
				return "没有待处理的机会。"
			next.skipped = next.offer
			next.offer = ""
			next.accepted = ""
			message = "已放弃本次机会，可再领一份。"
		"build":
			if argument == "" or argument != next.offer or next.accepted == "" or next.built.has(argument):
				return "先到主街图样板承接这里的建设。"
			if next.surveyed.size() < 2 and not next.surveyed.has(argument):
				next.surveyed.append(argument)
			next.built[argument] = next.accepted
			message = "%s的%s已建成，可就地使用。" % [PLACES[argument], NAMES[next.accepted]]
			next.offer = ""
			next.accepted = ""
			next.skipped = ""
		_:
			return "未知建设动作。"
	if not _commit(next):
		return problem
	return message


func _commit(next: Dictionary) -> bool:
	if not _valid(next):
		problem = "建设状态校验失败，请重读。"
		return false
	var head := read_latest(SLOT)
	var current := head.get("code") == "NO_SAVES" if generation == 0 else head.get("code") == "LOADED" and head.get("generation") == generation and _json_equal(data, head.get("payload"))
	if not current:
		problem = "建设记录已变化或无法读取。请先重读。"
		return false
	var receipt := write_record(SLOT, next)
	if not receipt.get("ok", false):
		# A failed promotion readback may already be durable. Block further
		# writes until an explicit reload resolves the actual committed head.
		problem = "建设写入未确认（%s），请先重读建设簿。" % receipt.get("code","IO")
		return false
	data = next
	generation = int(receipt.generation)
	problem = ""
	return true
