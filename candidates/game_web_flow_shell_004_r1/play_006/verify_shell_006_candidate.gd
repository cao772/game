extends SceneTree
## GAME-WEB-SHELL-006 r1 — authored future-only verifier.
## Explicit author rule: DO NOT RUN. Status stays NOT_RUN for every case.

const EventModel = preload("res://play_005/event_preview_model.gd")
const Bridge = preload("res://play_006/target_event_bridge_candidate.gd")
const Play = preload("res://play_005/play_entry.tscn")
const MAP_PATH := "res://play_006/synthetic_target_event_map.json"
const REGION_PATH := "res://play_005/vendor/region/synthetic_targets.json"

var failures: Array[String] = []
var synthetic_routes: int = 0


func _initialize() -> void:
    call_deferred("_verify")


func _check(condition: bool, case_id: String) -> void:
    if not condition:
        failures.append(case_id)


func _on_region(_id: StringName) -> void:
    synthetic_routes += 1


func _read_dictionary(path: String) -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) == TYPE_DICTIONARY:
        return parsed
    return {}


func _follow_target(app: Variant, id: String, position: Vector2) -> bool:
    var region: Variant = app.get("_region")
    if region == null or not is_instance_valid(region):
        return false
    if not region.has_method("set_demo_position") \
            or not region.has_method("_on_prompt_confirmed"):
        return false
    if not bool(region.call("set_demo_position", position)):
        return false
    region.call("_on_prompt_confirmed", StringName(id))
    var before: Dictionary = region.call("flow_snapshot")
    if str(before.get("last_confirmed", "")) != id:
        return false
    app.call("_follow_region", false)
    return app.active_module() == "event"


func _verify() -> void:
    # 01–19: fixed mapping and strict schema, no actual game side effects.
    var model: Variant = EventModel.new()
    var bridge: Variant = Bridge.new()
    var loaded: Dictionary = model.load_fixtures()
    _check(bool(loaded.get("ok", false)), "M01")
    _check(not bridge.resolve({
        "loaded": true, "confirm_count": 1, "last_confirmed": &"placeholder_a"
    }).get("ok", false), "M02")
    _check(not model.start_at("EVENT_NONEXISTENT"), "M03")
    _check(model.has_event("EVENT_START"), "M04")
    _check(model.has_event("EVENT_NEXT"), "M05")
    _check(model.has_event("EVENT_END"), "M06")
    var map_doc: Dictionary = _read_dictionary(MAP_PATH)
    var targets: Dictionary = _read_dictionary(REGION_PATH)
    _check(not map_doc.is_empty() and not targets.is_empty(), "M07")
    var checked: Dictionary = bridge.validate_document(map_doc, targets, model)
    _check(bool(checked.get("ok", false)), "M08")
    var ready: Dictionary = bridge.prepare(model)
    _check(bool(ready.get("ok", false)), "M09")
    _check(int(bridge.status().get("count", 0)) == 3, "M10")
    for item in [
        ["placeholder_a", "EVENT_START", "M11"],
        ["placeholder_b", "EVENT_NEXT", "M12"],
        ["placeholder_c", "EVENT_END", "M13"]
    ]:
        var result: Dictionary = bridge.resolve({
            "loaded": true, "confirm_count": 1,
            "last_confirmed": StringName(item[0])
        })
        _check(bool(result.get("ok", false)) \
            and str(result.get("event_id", "")) == item[1], item[2])
    _check(not bridge.resolve({"loaded": false, "confirm_count": 1,
        "last_confirmed": &"placeholder_a"}).get("ok", false), "M14")
    _check(not bridge.resolve({"loaded": true, "confirm_count": 0,
        "last_confirmed": &"placeholder_a"}).get("ok", false), "M15")
    _check(not bridge.resolve({"loaded": true, "confirm_count": 1,
        "last_confirmed": &"unknown"}).get("ok", false), "M16")
    _check(not bridge.resolve({"loaded": true, "confirm_count": "1",
        "last_confirmed": &"placeholder_a"}).get("ok", false), "M17")
    _check(not bridge.resolve({"loaded": true, "confirm_count": 1,
        "last_confirmed": null}).get("ok", false), "M18")
    _check(not bridge.resolve([]).get("ok", false), "M19")

    # 20–30: malformed mapping documents are rejected atomically.
    var bad_version: Dictionary = map_doc.duplicate(true)
    bad_version["schema_version"] = "unapproved-version"
    _check(not bridge.validate_document(bad_version, targets, model)["ok"], "M20")
    var bad_approval: Dictionary = map_doc.duplicate(true)
    bad_approval["candidate_only"] = false
    _check(not bridge.validate_document(bad_approval, targets, model)["ok"], "M21")
    var bad_event: Dictionary = map_doc.duplicate(true)
    bad_event["entries"][0]["event_id"] = "EVENT_FAKE"
    _check(not bridge.validate_document(bad_event, targets, model)["ok"], "M22")
    var bad_target: Dictionary = map_doc.duplicate(true)
    bad_target["entries"][0]["target_id"] = "placeholder_unknown"
    _check(not bridge.validate_document(bad_target, targets, model)["ok"], "M23")
    var duplicated: Dictionary = map_doc.duplicate(true)
    duplicated["entries"].append(duplicated["entries"][0].duplicate(true))
    _check(not bridge.validate_document(duplicated, targets, model)["ok"], "M24")
    var bad_reason: Dictionary = map_doc.duplicate(true)
    bad_reason["entries"][0]["reason"] = ""
    _check(not bridge.validate_document(bad_reason, targets, model)["ok"], "M25")
    var unexpected: Dictionary = map_doc.duplicate(true)
    unexpected["entries"][0]["extra"] = "injected"
    _check(not bridge.validate_document(unexpected, targets, model)["ok"], "M26")
    var bad_catalog: Dictionary = targets.duplicate(true)
    bad_catalog["schema_version"] = "wrong"
    _check(not bridge.validate_document(map_doc, bad_catalog, model)["ok"], "M27")
    _check(bridge.status()["ready"], "M28")
    _check(model.start_at("EVENT_NEXT"), "M29")
    _check(model.state()["event_id"] == "EVENT_NEXT", "M30")
    _check(not model.start_at("EVENT_UNLISTED"), "M31")
    _check(model.state()["event_id"] == "EVENT_NEXT", "M32")
    _check(model.start_at("EVENT_END"), "M33")
    _check(model.state()["trace"].is_empty(), "M34")
    bridge.clear()
    _check(not bridge.resolve({"loaded": true, "confirm_count": 1,
        "last_confirmed": &"placeholder_a"}).get("ok", false), "M35")

    # 36–56: actual pinned region flow and navigation, future-only.
    var app: Variant = Play.instantiate()
    root.add_child(app)
    app.synthetic_region_confirmation.connect(_on_region)
    _check(app.active_module() == "", "N01")
    _check(app.open_module("region"), "N02")
    app.call("_follow_region", false)
    _check(app.active_module() == "region", "N03")
    _check(synthetic_routes == 0, "N04")
    var first: bool = _follow_target(app, "placeholder_a", Vector2(-1.2, 0.0))
    _check(first, "N05")
    _check(app.event_state()["event_id"] == "EVENT_START", "N06")
    _check(app.navigation_snapshot()["mapped_context"].get("target_id", "") \
        == "placeholder_a", "N07")
    _check(synthetic_routes == 1, "N08")
    _check(app.return_previous(), "N09")
    _check(app.active_module() == "region", "N10")
    _check(app.navigation_snapshot()["mapped_context"].is_empty(), "N11")
    var second: bool = _follow_target(app, "placeholder_b", Vector2(0.0, 0.0))
    _check(second, "N12")
    _check(app.event_state()["event_id"] == "EVENT_NEXT", "N13")
    _check(app.event_state()["checker_status"] == "NOT_RUN", "N14")
    _check(app.open_module("saves"), "N15")
    _check(app.return_previous(), "N16")
    _check(app.active_module() == "event", "N17")
    _check(app.event_state()["event_id"] == "EVENT_NEXT", "N18")
    _check(app.return_previous(), "N19")
    _check(app.active_module() == "region", "N20")
    var third: bool = _follow_target(app, "placeholder_c", Vector2(1.2, 0.0))
    _check(third, "N21")
    _check(app.event_state()["event_id"] == "EVENT_END", "N22")
    app.return_menu()
    _check(app.active_module() == "", "N23")
    _check(app.navigation_snapshot()["history"].is_empty(), "N24")
    _check(app.navigation_snapshot()["mapped_context"].is_empty(), "N25")
    _check(str(app.last_region_confirmation()).is_empty(), "N26")
    _check(not app.open_module("unknown"), "N27")
    _check(app.open_module("event"), "N28")
    _check(app.event_state()["event_id"] == "EVENT_START", "N29")
    _check(not app.return_previous(), "N30")
    _check(app.active_module() == "", "N31")
    _check(app.open_module("region"), "N32")
    app.call("_follow_region", true)
    _check(app.active_module() == "region", "N33")
    _check(synthetic_routes == 3, "N34")
    app.return_menu()
    app.queue_free()

    if failures.is_empty():
        print("PASS GAME-WEB-SHELL-006 r1")
        quit(0)
        return
    for item in failures:
        push_error("FAIL " + item)
    quit(1)
