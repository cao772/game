extends SceneTree
## GAME-WEB-PLAY-REGION-005 r1 future-only scene contract.
## Headless does NOT establish native 3D picking, focus or visual quality.
## NOT_RUN.
var _failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_verify")


func _check(ok: bool, case_id: String) -> void:
    if not ok:
        _failures.append(case_id)


func _verify() -> void:
    var prefab: PackedScene = load("res://main.tscn")
    if prefab == null:
        push_error("Independent scene could not load")
        quit(1)
        return
    var demo = prefab.instantiate()
    root.add_child(demo)
    await process_frame

    var prompt = demo.get("_prompt")
    _check(prompt != null, "S001 prompt instantiated")
    if prompt == null:
        demo.queue_free()
        quit(1)
        return

    var start: Dictionary = demo.flow_snapshot()
    _check(start.get("loaded", false), "S002 synthetic model loaded")
    _check(start.get("feedback_history", []).is_empty(),
        "S003 feedback starts empty")

    _check(demo.set_demo_position(Vector2(-0.6, 0.0)),
        "S004 overlap reachable")
    var prox: Dictionary = demo.flow_snapshot()
    _check(prox["nearby_ids"].size() == 2, "S005 two nearby")
    _check(prox["prompt_shown"], "S006 prompt visible")
    _check(demo.select_marker_at(Vector2(0.0, 0.0)),
        "S007 click virtual B ground position")
    _check(demo.flow_snapshot()["selected_id"] == &"placeholder_b",
        "S008 model selected B")
    _check(prompt.active_target_id() == &"placeholder_b",
        "S009 prompt selected B")
    _check(demo.select_marker_at(Vector2(1.2, 0.0)),
        "S010 out-of-range C click handled as refusal")
    _check(demo.flow_snapshot()["selected_id"] == &"placeholder_b",
        "S011 rejected C does not steal selection")
    _check(demo.flow_snapshot()["confirm_count"] == 0,
        "S012 clicks do not auto-confirm")

    _check(prompt.request_interaction(false), "S013 injected confirm B")
    var once: Dictionary = demo.flow_snapshot()
    _check(once["confirm_count"] == 1, "S014 one confirmation")
    _check(once["last_confirmed"] == &"placeholder_b",
        "S015 confirmation target B")
    _check(once["feedback_history"].size() > 0,
        "S016 feedback history recorded")

    _check(demo.set_demo_position(Vector2(0.0, 3.1)), "S017 leave")
    var far: Dictionary = demo.flow_snapshot()
    _check(not far["prompt_shown"], "S018 prompt hides")
    _check(far["nearby_ids"].is_empty(), "S019 no nearby")
    _check(not demo.select_marker_at(Vector2(80, 80)),
        "S020 non-marker click ignored")

    _check(demo.set_demo_position(Vector2(-1.2, 0.0)),
        "S021 reapproach A")
    prompt.hide_prompt()
    _check(demo.flow_snapshot()["dismissed"], "S022 manual hide latched")
    _check(demo.select_marker_at(Vector2(-1.2, 0.0)),
        "S023 hidden A click reports refusal")
    _check(not demo.flow_snapshot()["prompt_shown"],
        "S024 refusal does not reopen")
    demo._reopen()
    _check(demo.flow_snapshot()["prompt_shown"], "S025 explicit reopen")
    demo._reset_demo()
    var reset: Dictionary = demo.flow_snapshot()
    _check(reset["confirm_count"] == 0, "S026 reset count")
    _check(not reset["prompt_shown"], "S027 reset hides prompt")
    _check(reset["feedback_history"].size() == 1,
        "S028 reset starts new bounded journal")
    _check(reset["feedback_history"][0]["kind"] == "reset",
        "S029 reset feedback kind")

    demo.queue_free()
    await process_frame
    if _failures.is_empty():
        print("PASS GAME-WEB-PLAY-REGION-005 r1 (future scene checks)")
        quit(0)
    else:
        for failure in _failures:
            push_error("FAIL: " + failure)
        quit(1)
