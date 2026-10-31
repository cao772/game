extends SceneTree
## GAME-WEB-REGION-006 r1: FUTURE scene-wiring contract test only.
## NOT_RUN. Direct internal stepping is only a deterministic logic seam.
## It does NOT prove real OS focus, pointer routing, timing, or GUI quality.

var _errors: Array[String] = []


func _initialize() -> void:
    call_deferred("_verify")


func _expect(ok: bool, case_id: String) -> void:
    if not ok:
        _errors.append(case_id)


func _verify() -> void:
    var scene_file: PackedScene = load("res://main.tscn")
    if scene_file == null:
        push_error("Standalone region trial scene could not be loaded")
        quit(1)
        return
    var demo = scene_file.instantiate()
    root.add_child(demo)
    await process_frame

    var model = demo.get("_model")
    var navigator = demo.get("_navigation")
    var guard = demo.get("_focus_guard")
    var prompt = demo.get("_prompt")
    _expect(model != null, "S601 model present")
    _expect(navigator != null, "S602 navigation present")
    _expect(guard != null, "S603 focus policy present")
    _expect(prompt != null, "S604 prompt present")
    if model == null or navigator == null or guard == null or prompt == null:
        demo.queue_free()
        quit(1)
        return

    _expect(demo.flow_snapshot()["navigation"]["mode"] == &"idle",
        "S605 trial navigation initially idle")
    _expect(not demo.flow_snapshot()["prompt_shown"],
        "S606 prompt hidden when far")

    # Headless testing directly seeds the in-memory navigation model.
    # UI-triggered start_navigation requires real native window focus
    # and must be checked later as a desktop/manual case.
    _expect(navigator.start_to_target(
        &"placeholder_a", model.all_targets(), model.player_position()
    ), "S607 pure trial navigation accepts A")
    demo._on_window_unfocused()
    _expect(demo.flow_snapshot()["navigation"]["mode"] == &"paused",
        "S608 simulated focus-loss pauses active route")
    _expect(demo.flow_snapshot()["focus_recovery"]["require_key_release"],
        "S609 key release guard armed")
    _expect(not navigator.advance(model.player_position(), 0.1).get("ok", false),
        "S610 paused route cannot advance")

    demo._on_window_returned()
    await process_frame
    _expect(demo.flow_snapshot()["navigation"]["mode"] == &"paused",
        "S611 simulated focus return must not auto-resume")

    # Direct stepping intentionally bypasses native-window input
    # to validate only deterministic scene coordination, NOT OS focus.
    _expect(navigator.resume_after_focus_return(true),
        "S612 explicit pure model resume")
    var reached: bool = false
    for i in range(80):
        demo._advance_navigation(0.1)
        if navigator.state()["mode"] == &"arrived":
            reached = true
            break
    _expect(reached, "S613 A approach arrives within finite steps")
    var arrived: Dictionary = demo.flow_snapshot()
    _expect(arrived["nearby_ids"].has(&"placeholder_a"),
        "S614 A is eligible after arrival")
    _expect(arrived["selected_id"] == &"placeholder_a",
        "S615 stable goal ID selected after arrival")
    _expect(arrived["prompt_shown"], "S616 prompt opens on arrival")
    _expect(arrived["prompt_target"] == &"placeholder_a",
        "S617 prompt and model IDs agree")
    _expect(arrived["confirm_count"] == 0,
        "S618 navigation never auto-confirms")

    _expect(demo.set_demo_position(Vector2(0, 3.1)),
        "S619 independent leave accepted")
    _expect(not demo.flow_snapshot()["prompt_shown"],
        "S620 leaving hides prompt")
    demo._reset_demo()
    var reset: Dictionary = demo.flow_snapshot()
    _expect(reset["navigation"]["mode"] == &"idle",
        "S621 reset clears navigation")
    _expect(not reset["focus_recovery"]["require_key_release"],
        "S622 reset clears key-release guard")
    _expect(reset["confirm_count"] == 0,
        "S623 reset clears confirmation count")
    _expect(reset["feedback_history"].size() == 1,
        "S624 reset yields exactly one journal entry")

    demo.queue_free()
    await process_frame
    if _errors.is_empty():
        print("PASS GAME-WEB-REGION-006 r1 future scene contracts")
        quit(0)
    else:
        for item in _errors:
            push_error("FAIL: " + item)
        quit(1)
