extends Node3D
## The trays display the active quest outcome. Looking at one is local to a visit.
const Actor = preload("res://world/counter_actor.gd")
const CLERK: PackedScene = preload("res://art/records_actor/clerk.glb")

var _copy: Dictionary
var _row: Dictionary = {}
var _examined := false
var _unlisted_receipt := false
var _actor: Actor

func _ready() -> void:
	_actor = Actor.new()
	_actor.model_scene = CLERK
	$ArchivistAnchor.add_child(_actor)

func configure(copy: Dictionary) -> bool:
	if not _has_lines(copy, ["name", "before"]) or not (copy.get("outcomes") is Dictionary):
		return false
	for row in copy["outcomes"].values():
		if not (row is Dictionary) or not _has_lines(row, ["shelf", "greeting", "examined", "filed", "pending"]):
			return false
		if row["shelf"] not in ["filed", "pending"]:
			return false
	_copy = copy
	return true

func _has_lines(record: Dictionary, keys: Array) -> bool:
	for key in keys:
		if not (record.get(key) is String) or str(record[key]).strip_edges().is_empty():
			return false
	return true

func show_outcome(view: Dictionary) -> void:
	var next: Dictionary = _copy["outcomes"].get(view["node"], {}) if view["terminal"] else {}
	if next != _row:
		_examined = false
	_row = next
	_unlisted_receipt = view["terminal"] and _row.is_empty()
	$FiledTray/Record.visible = _row.get("shelf", "") == "filed"
	$PendingTray/Record.visible = _row.get("shelf", "") == "pending"

func begin_visit() -> void:
	_examined = false
	_actor.reset_pose()

func clerk_name() -> String:
	return _copy["name"]

func talk() -> String:
	_actor.acknowledge(true)
	if _row.is_empty():
		if _unlisted_receipt:
			return "柜台已经签收了。这两盘里还没有对应的底联。"
		return _copy["before"]
	return _row["examined"] if _examined else _row["greeting"]

func inspect(tray: String) -> String:
	if _row.is_empty():
		return "盘上没有这趟交件的记录。"
	if tray == _row["shelf"]:
		_examined = true
	return _row[tray]
