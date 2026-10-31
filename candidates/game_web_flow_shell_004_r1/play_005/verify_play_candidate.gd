extends SceneTree
## Future ONLY. GAME-WEB-PLAY-SHELL-005 r1; all tests NOT_RUN.
## Explicit exit codes and finite assertions if later authorized.
const Preview = preload("res://play_005/event_preview_model.gd")
const Scene = preload("res://play_005/play_entry.tscn")
var _failed: Array[String] = []

func _check(value: bool, id: String) -> void:
    if not value:
        _failed.append(id)

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var events = Preview.new()
    var load_result: Dictionary = events.load_fixtures()
    _check(load_result.get("ok", false), "P01")
    _check(events.state()["event_id"] == "EVENT_START", "P02")
    _check(events.state()["choices"].size() == 3, "P03")
    _check(not events.choose("UNKNOWN")["ok"], "P04")
    _check(events.state()["event_id"] == "EVENT_START", "P05")
    _check(events.choose("ACTION_TO_NEXT")["ok"], "P06")
    _check(events.state()["event_id"] == "EVENT_NEXT", "P07")
    _check(events.choose("ACTION_FINISH")["ok"], "P08")
    _check(events.state()["event_id"] == "EVENT_END", "P09")
    _check(events.choose("ACTION_COMPLETE")["ok"], "P10")
    _check(events.state()["terminal"], "P11")
    _check(not events.choose("ACTION_END")["ok"], "P12")
    _check(events.reset(), "P13")
    _check(events.choose("@ignore")["ok"], "P14")
    _check(events.state()["event_id"] == "EVENT_END", "P15")
    _check(events.state()["checker_status"] == "NOT_RUN", "P16")
    var app = Scene.instantiate()
    root.add_child(app)
    _check(app.active_module() == "", "P17")
    _check(not app.open_module("unregistered"), "P18")
    _check(app.open_module("event"), "P19")
    _check(app.active_module() == "event", "P20")
    _check(app.event_state()["event_id"] == "EVENT_START", "P21")
    _check(app.open_module("saves"), "P22")
    _check(app.active_module() == "saves", "P23")
    _check(app.get_node_or_null("Play005Screen") != null, "P24")
    app.return_menu()
    _check(app.active_module() == "", "P25")
    _check(app.open_module("characters"), "P26")
    _check(app.active_module() == "characters", "P27")
    _check(app.open_module("input_19"), "P28")
    _check(app.active_module() == "input_19", "P29")
    app.call("_input_preview")
    app.call("_input_apply")
    app.call("_input_reset")
    _check(app.open_module("region"), "P30")
    _check(app.active_module() == "region", "P31")
    app.call("_follow_region")
    _check(app.active_module() == "region", "P32")
    app.return_menu()
    _check(app.active_module() == "", "P33")
    app.queue_free()
    if _failed.is_empty():
        print("PASS GAME-WEB-PLAY-SHELL-005 r1")
        quit(0)
    for id in _failed:
        push_error("FAIL " + id)
    quit(1)
