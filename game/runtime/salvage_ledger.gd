extends "res://runtime/save_store.gd"
## One confirmed record covers the active batch and all installed fittings.
const SLOT := "street_salvage"
const MATERIAL_NAMES := {"wood": "木条", "iron": "带孔角铁"}
const FIXTURES := {"book": "阅览书托", "drain": "沥盆架"}
const DESTINATIONS := {"book": "阅览室东南墙的书托", "drain": "洗择棚东侧的沥盆架"}
var data: Dictionary = {}
var generation := 0
var problem := ""


func _root_component() -> String:
	return "street_salvage_v1"


func _valid_slot(slot: String) -> bool:
	return slot == SLOT


func is_built(fixture: String) -> bool:
	return data.get("installed", []).has(fixture)


func active_material() -> String:
	if data.is_empty() or data.stage == "spent":
		return ""
	if data.installed.is_empty():
		return data.first
	return "wood" if data.first == "iron" else "iron"


func direct_fixture() -> String:
	return "book" if active_material() == "wood" else "drain"


func has_adapter() -> bool:
	return data.get("stage", "") == "fitted"


func fits(fixture: String) -> bool:
	return FIXTURES.has(fixture) and not active_material().is_empty() and (fixture == direct_fixture() or has_adapter())


func _valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 4 or not value.has_all(["version","first","installed","stage"]):
		return false
	if typeof(value.version) not in [TYPE_INT, TYPE_FLOAT] or value.version != 1:
		return false
	if not MATERIAL_NAMES.has(value.first) or not value.installed is Array or value.installed.size() > 2:
		return false
	for i in range(value.installed.size()):
		var fixture: Variant = value.installed[i]
		if not FIXTURES.has(fixture) or value.installed.find(fixture) != i:
			return false
	if value.stage == "spent":
		return not value.installed.is_empty()
	return value.stage in ["raw","fitted"] and value.installed.size() < 2


func _successor(next: Dictionary) -> bool:
	if data.is_empty():
		return true
	if next.first != data.first or next.installed.slice(0, data.installed.size()) != data.installed:
		return false
	if next.installed.size() == data.installed.size():
		var stages := ["spent","raw","fitted"]
		return stages.find(next.stage) >= stages.find(data.stage)
	return true


func reload_ledger() -> void:
	var head := read_latest(SLOT)
	if generation == 0 and head.get("code") == "NO_SAVES":
		problem = ""
		return
	if head.get("code") != "LOADED" or not _valid(head.get("payload")):
		problem = "旧料登记未能确认，保留现场。到主街东侧料架按 E 重读。"
		return
	var next: Dictionary = head.payload
	var newer: int = int(head.generation)
	if newer < generation or (newer == generation and not _json_equal(data, next)) or not _successor(next):
		problem = "旧料登记与现场不符，保留现状。请回料架重读。"
		return
	data = next.duplicate(true)
	generation = newer
	problem = ""


func act(action: String, revision: int) -> String:
	if not problem.is_empty():
		return problem
	if revision != generation:
		return "旧料登记已更新，请查看当前批次。"
	var next := data.duplicate(true)
	var notice := ""
	match action:
		"register":
			if is_built("book") and is_built("drain"):
				return "两批都已用完。书托和盆架可到现场使用。"
			if not active_material().is_empty():
				return summary()
			if next.is_empty():
				var roll := Crypto.new().generate_random_bytes(1)
				if roll.size() != 1:
					return "暂未开批，请重新登记。"
				next = {"version":1, "first":"wood" if (int(roll[0]) % 2) == 0 else "iron", "installed":[], "stage":"raw"}
			else:
				next.stage = "raw"
		"fit":
			if active_material().is_empty():
				return summary()
			if has_adapter():
				return summary()
			next.stage = "fitted"
			notice = "工坊已配好转接件，本批仍留在料架。"
		"book", "drain":
			if is_built(action):
				return "这处已经装好。"
			if not fits(action):
				return "请先到料架登记。" if active_material().is_empty() else "本批需先在东侧维修工坊的台面右端加装转接件。"
			next.installed.append(action)
			next.stage = "spent"
			notice = str(FIXTURES[action]) + "已装好，本批已领用。"
		_:
			return "未知旧料操作。"
	# Never reveal a roll, change a prop, or consume stock on a speculative write.
	var head := read_latest(SLOT)
	var current := head.get("code") == "NO_SAVES" if generation == 0 else head.get("code") == "LOADED" and head.get("generation") == generation and _json_equal(data, head.get("payload"))
	if not current or not _valid(next):
		problem = "旧料记录已变化或不可读，保留现场。请回料架按 E 重读。"
		return problem
	var receipt := write_record(SLOT, next)
	if not receipt.get("ok",false):
		problem = "旧料写入未确认（%s），请回料架按 E 重读。" % receipt.get("code","IO")
		return problem
	data = next
	generation = int(receipt.generation)
	return summary() if notice.is_empty() else notice + "\n" + summary()


func summary() -> String:
	var material := active_material()
	if material.is_empty():
		if is_built("book") and is_built("drain"):
			return "两处均已装好。"
		return "到主街东侧旧料架登记下一批。" if not data.is_empty() else "主街东侧料架可登记首批。"
	var direct := direct_fixture()
	var other := "drain" if direct == "book" else "book"
	var batch := "首批" if data.installed.is_empty() else "第二批"
	var stock := batch + str(MATERIAL_NAMES[material]) + " · "
	if has_adapter():
		var choices := PackedStringArray()
		for fixture in FIXTURES:
			if not is_built(fixture):
				choices.append(DESTINATIONS[fixture])
		return stock + "已配转接件，可到现场安装：" + " / ".join(choices)
	if is_built(direct):
		return stock + "直装处已完工，到东侧维修工坊配转接件可装" + str(DESTINATIONS[other]) + "。"
	if is_built(other):
		return stock + "可直接去装" + str(DESTINATIONS[direct]) + "。"
	return stock + "可直装" + str(DESTINATIONS[direct]) + "，或先去东侧工坊配件，再装" + str(DESTINATIONS[other]) + "。"
