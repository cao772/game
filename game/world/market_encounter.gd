extends Node3D
## The current session owns progress; the scene only projects the active stop.
const Actor = preload("res://world/counter_actor.gd")
const MERCHANT: PackedScene = preload("res://art/market_actor/merchant.glb")
const ANCHORS := {"stall": "StallActor", "bench": "BenchActor", "rack": "RackActor"}
const STOPS := {"OFFER": "stall", "FIND_TAG": "bench", "GET_TOOL": "rack", "RETURN_TOOL": "bench", "REPLACED": "stall", "RETURNED": "stall"}
const DIRECTIONS := {"OFFER": "和东南角的摊主商量", "FIND_TAG": "去西南角修理台查签", "GET_TOOL": "去柜台东侧寄放架取扳手", "RETURN_TOOL": "带扳手回西南角修理台", "REPLACED": "回摊可看现货价签", "RETURNED": "回摊可看共用工具簿"}

var copy: Dictionary
var _actor: Actor
var _body: StaticBody3D
@onready var _rack_tool: Transform3D = $OldTool.transform

func _ready() -> void:
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.30
	capsule.height = 1.65
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.825
	_body.add_child(shape)
	_actor = Actor.new()
	_actor.model_scene = MERCHANT
	_body.add_child(_actor)
	add_child(_body)
	_body.position = ($StallActor as Marker3D).position

func configure(data: Dictionary, definition: Dictionary) -> bool:
	if not _lines_present(data, ["name", "title", "intro"]):
		return false
	for key in ["lines", "actions", "clues", "handoffs", "receipts", "extras"]:
		if not (data.get(key) is Dictionary):
			return false
	if not _lines_present(data["clues"], ["bench", "rack"]):
		return false
	if not _lines_present(data["handoffs"], ["TRACE", "READ_TAG", "PICK_UP"]):
		return false
	if not (definition.get("nodes") is Dictionary):
		return false
	var nodes: Dictionary = definition["nodes"]
	if nodes.size() != STOPS.size() or not nodes.has_all(STOPS.keys()) or not _lines_present(data["lines"], nodes.keys()):
		return false
	for node in nodes.values():
		if not (node is Dictionary) or not (node.get("actions") is Array):
			return false
		for option in node["actions"]:
			if not (option is Dictionary) or not _lines_present(data["actions"], [option.get("id")]):
				return false
	for outcome in ["REPLACED", "RETURNED"]:
		if not _lines_present(data["receipts"], [outcome]) or not (data["extras"].get(outcome) is Dictionary):
			return false
		if not _lines_present(data["extras"][outcome], ["label", "text"]):
			return false
	copy = data
	return true

func _lines_present(data: Dictionary, keys: Array) -> bool:
	for key in keys:
		if not (data.get(key) is String) or str(data[key]).strip_edges().is_empty():
			return false
	return true

func current_stop(view: Dictionary) -> String:
	return STOPS.get(view["node"], "stall")

func objective(view: Dictionary) -> String:
	if not view["started"]:
		return "可选：去东南角逛旧货摊。"
	return str(copy["title"]) + " · " + str(DIRECTIONS[view["node"]])

func line(stop: String, view: Dictionary) -> String:
	if stop != current_stop(view):
		if stop == "stall":
			return "摊前挂着歇业牌。" + str(DIRECTIONS[view["node"]]) + "。"
		if stop == "rack" and view["node"] in ["RETURN_TOOL", "RETURNED"]:
			return "旧扳手原来搁着的地方空了。"
		return copy["clues"][stop]
	var speech: String = copy["lines"][view["node"]] if view["started"] else copy["intro"]
	return str(copy["name"]) + "：" + speech

func focus_at(stop: String) -> Vector3:
	var anchor := get_node(str(ANCHORS[stop])) as Marker3D
	return anchor.global_position + Vector3(0, 1.16, 0.4)

func detail_at(key: String) -> Vector3:
	if key == "READ_TAG":
		return ($RepairBench/BorrowSlips as Node3D).global_position + Vector3.UP * 0.025
	var display: Node3D = $NewStock if key == "REPLACED" else $SharedTools
	return display.global_position + Vector3.UP * 0.14

func project(view: Dictionary, hold_at: String = "") -> void:
	var stage: String = view["node"]
	var closed := stage in ["FIND_TAG", "GET_TOOL", "RETURN_TOOL"]
	$OpenStock.visible = not closed
	$ClosedSign.visible = closed
	$NewStock.visible = stage == "REPLACED"
	$SharedTools.visible = stage == "RETURNED"
	var at := current_stop(view) if hold_at.is_empty() else hold_at
	_body.position = (get_node(str(ANCHORS[at])) as Marker3D).position
	$OldTool.visible = stage != "RETURNED"
	if stage == "RETURN_TOOL":
		var belt := Transform3D(Basis(Vector3.FORWARD, 1.24).scaled(Vector3.ONE * 0.72), Vector3(0.34, 0.97, 0.12))
		$OldTool.transform = _body.transform * belt
	else:
		$OldTool.transform = _rack_tool

func gesture() -> void:
	_actor.acknowledge(true)
