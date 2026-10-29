extends SceneTree
## GAME-WEB-MODULE-REGION-002 r1 — FUTURE checks only (NOT_RUN).
## Headless checks cannot establish native keyboard focus or visual accessibility.

var _errors: Array[String] = []


func _initialize() -> void:
    call_deferred("_verify")


func _expect(ok: bool, name: String) -> void:
    if not ok:
        _errors.append(name)


func _verify() -> void:
    var packed: PackedScene = load("res://interaction_prompt_candidate.tscn")
    if packed == null:
        push_error("Prompt scene cannot load")
        quit(1)
        return

    var host := Control.new()
    root.add_child(host)
    var origin := Button.new()
    origin.focus_mode = Control.FOCUS_ALL
    host.add_child(origin)
    var prompt = packed.instantiate()
    host.add_child(prompt)
    await process_frame

    var actual: Array[StringName] = []
    var placeholders: Array[StringName] = []
    var focus_roles: Array[StringName] = []
    var visibility: Array[bool] = []
    prompt.interaction_requested.connect(func(id): actual.append(id))
    prompt.placeholder_changed.connect(func(id): placeholders.append(id))
    prompt.focus_state_changed.connect(func(role): focus_roles.append(role))
    prompt.prompt_visibility_changed.connect(func(shown): visibility.append(shown))

    var specs: Array = [
        {"id": &"placeholder_a", "label": "占位 A", "action_caption": "确认 A"},
        {"id": &"placeholder_b", "label": "占位 B", "action_caption": "确认 B"},
        {"id": &"placeholder_c", "label": "占位 C", "action_caption": "确认 C"}
    ]

    _expect(not prompt.show_for_targets([], 0), "empty list rejected")
    _expect(not prompt.show_for_targets(specs, 3), "out-of-range index rejected")
    _expect(not prompt.show_for_targets([
        {"id": &"a", "label": "A"},
        {"id": &"a", "label": "Duplicate"}
    ]), "duplicate ID rejected")
    _expect(not prompt.show_for_targets([{"id": &"x", "label": ""}]),
        "blank label rejected")
    _expect(not prompt.is_prompt_shown(), "invalid input leaves prompt hidden")
    _expect(prompt.show_for_targets(specs, 1), "three-target list accepted")
    _expect(prompt.target_count() == 3, "target count")
    _expect(prompt.active_target_index() == 1, "initial index B")
    _expect(prompt.active_target_id() == &"placeholder_b", "target B")
    _expect(prompt.get_node("Padding/Content/Navigation").visible, "nav visible")
    _expect(prompt.get_node("Padding/Content/ActionButton").text == "确认 B",
        "B caption shown")
    _expect(visibility.size() == 1 and visibility[0], "one show transition")

    _expect(prompt.cycle_target(1), "next target")
    _expect(prompt.active_target_id() == &"placeholder_c", "next is C")
    _expect(prompt.cycle_target(1), "wrap forward")
    _expect(prompt.active_target_id() == &"placeholder_a", "forward wraps to A")
    _expect(prompt.cycle_target(-1), "wrap backward")
    _expect(prompt.active_target_id() == &"placeholder_c", "backward wraps to C")
    _expect(not prompt.cycle_target(2), "invalid direction rejected")
    _expect(not prompt.select_target(7), "invalid index rejected")
    _expect(prompt.active_target_id() == &"placeholder_c",
        "rejections keep active C")

    var before_style: Dictionary = prompt.style_snapshot()
    _expect(not prompt.apply_style({"font_size": 5}), "invalid font rejected")
    _expect(not prompt.apply_style({"unexpected": 5}), "unknown key rejected")
    _expect(prompt.style_snapshot() == before_style, "style rejects atomically")
    _expect(prompt.apply_style({"padding": 22, "font_size": 20}),
        "valid partial style")
    _expect(prompt.style_snapshot()["padding"] == 22, "padding set")
    _expect(prompt.style_snapshot()["font_size"] == 20, "font set")
    _expect(prompt.apply_style_preset(&"high_contrast"), "contrast preset")
    _expect(prompt.style_snapshot()["font_size"] == 18, "contrast font size")
    _expect(not prompt.apply_style_preset(&"not_a_preset"), "unknown preset")
    _expect(prompt.apply_style_preset(&"default"), "default preset")
    _expect(prompt.style_snapshot() == before_style, "default reset")

    # Focus state reports the actual viewport focus owner; in headless mode
    # only contract shape can be asserted, not hardware focus success.
    var focus_data: Dictionary = prompt.focus_state()
    _expect(focus_data.has("role") and focus_data.has("shown"), "focus state keys")
    _expect(focus_data["target_count"] == 3, "focus state target count")
    _expect(focus_data["role"] in [
        &"none", &"previous", &"next", &"action", &"dismiss"
    ], "focus state role enum")

    _expect(not prompt.request_interaction(true), "blocked interaction")
    _expect(prompt.request_interaction(false), "allowed injected interaction")
    _expect(actual.size() == 1, "one action signal")
    if actual.size() == 1:
        _expect(actual[0] == &"placeholder_c", "action sends selected target")
    _expect(prompt.request_count() == 1, "one request counter increment")

    _expect(prompt.hide_prompt(), "hide succeeds")
    _expect(prompt.target_count() == 0, "hide clears list")
    _expect(prompt.active_target_index() == -1, "hide clears index")
    _expect(prompt.active_target_id() == &"", "hide clears ID")
    _expect(prompt.focus_state()["role"] == &"none", "hide clears focus role")
    _expect(not prompt.request_interaction(false), "hidden action blocked")
    _expect(visibility.size() == 2 and not visibility[1], "one hide transition")

    _expect(prompt.show_for_target(&"legacy_a", "旧入口占位"),
        "legacy show_for_target")
    _expect(prompt.target_count() == 1, "legacy single-target")
    _expect(not prompt.get_node("Padding/Content/Navigation").visible,
        "single target hides navigation")
    _expect(not prompt.cycle_target(1), "cannot cycle one target")
    _expect(prompt.request_interaction(false), "legacy injected action")
    _expect(actual.size() == 2, "legacy one action")
    if actual.size() == 2:
        _expect(actual[1] == &"legacy_a", "legacy request has correct ID")

    _expect(prompt.hide_prompt(), "legacy hide")
    for i in range(10):
        _expect(prompt.show_for_targets(specs, i % specs.size()),
            "cycle %d show" % i)
        _expect(prompt.cycle_target(1), "cycle %d switch" % i)
        _expect(prompt.request_interaction(false), "cycle %d request" % i)
        _expect(prompt.hide_prompt(), "cycle %d hide" % i)
        _expect(prompt.active_target_id() == &"", "cycle %d clear" % i)

    _expect(prompt.request_count() == 12, "total 12 accepted requests")
    _expect(actual.size() == 12, "total 12 emitted signals")

    prompt.show_for_targets(specs)
    paused = true
    _expect(not prompt.request_interaction(false), "pause blocks override")
    paused = false
    prompt.hide_prompt()

    host.queue_free()
    await process_frame
    if _errors.is_empty():
        print("PASS GAME-WEB-MODULE-REGION-002 r1 (future headless checks)")
        quit(0)
    else:
        for item in _errors:
            push_error("FAIL: " + item)
        quit(1)
