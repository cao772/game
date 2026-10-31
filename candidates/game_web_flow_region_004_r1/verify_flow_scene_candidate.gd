extends SceneTree
## FUTURE ONLY: contract test for the isolated scene/prompt integration.
## NOT_RUN. Headless checks do not prove native focus or visual rendering.

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)


func _verify() -> void:
    var packed: PackedScene = load("res://main.tscn")
    if packed == null:
        push_error("Standalone scene unavailable")
        quit(1)
        return
    var scene = packed.instantiate()
    root.add_child(scene)
    await process_frame

    var prompt = scene.get("_prompt")
    check(prompt != null, "PR #10 prompt instantiated")
    if prompt == null:
        scene.queue_free()
        quit(1)
        return

    var signals: Array[StringName] = []
    prompt.interaction_requested.connect(func(id: StringName):
        signals.append(id)
    )

    var start: Dictionary = scene.flow_snapshot()
    check(start["loaded"], "standalone catalog loaded")
    check(start["nearby_ids"].is_empty(), "initial position out of range")
    check(not start["prompt_shown"], "prompt hidden initially")

    check(scene.set_demo_position(Vector2(-0.6, 0.0)), "move between targets")
    var nearby: Dictionary = scene.flow_snapshot()
    check(nearby["nearby_ids"].size() == 2, "two nearby placeholders")
    check(nearby["prompt_shown"], "prompt automatically visible")
    check(prompt.target_count() == 2, "prompt synced two entries")
    check(prompt.active_target_id() == nearby["selected_id"], "selection synced")

    check(prompt.cycle_target(1), "switch target with prompt")
    var chosen: StringName = prompt.active_target_id()
    check(scene.flow_snapshot()["selected_id"] == chosen, "selection signal to model")
    check(prompt.request_interaction(false), "injected future confirm request")
    check(signals.size() == 1, "one prompt signal")
    check(scene.flow_snapshot()["confirm_count"] == 1, "one model confirmation")
    check(scene.flow_snapshot()["last_confirmed"] == chosen, "correct confirmed ID")

    check(scene.set_demo_position(Vector2(0.0, 3.1)), "walk out")
    var far: Dictionary = scene.flow_snapshot()
    check(not far["prompt_shown"], "prompt hides on leaving")
    check(far["nearby_ids"].is_empty(), "nearby selection cleared")

    check(scene.set_demo_position(Vector2(-1.2, 0.0)), "reenter")
    check(scene.flow_snapshot()["prompt_shown"], "prompt reappears")
    prompt.hide_prompt()
    check(scene.flow_snapshot()["dismissed"], "manual hide suppresses prompt")
    check(scene.set_demo_position(Vector2(-1.0, 0.0)), "stay within range")
    check(not scene.flow_snapshot()["prompt_shown"], "manual hide persists nearby")
    scene._reopen()
    check(scene.flow_snapshot()["prompt_shown"], "explicit reopen")
    check(not scene.flow_snapshot()["dismissed"], "suppression cleared")

    scene._reset_demo()
    var reset: Dictionary = scene.flow_snapshot()
    check(reset["loaded"], "catalog preserved after reset")
    check(reset["confirm_count"] == 0, "local confirm counter reset")
    check(reset["nearby_ids"].is_empty(), "no nearby after reset")
    check(not reset["prompt_shown"], "prompt hidden after reset")

    scene.queue_free()
    await process_frame
    if failures.is_empty():
        print("PASS GAME-WEB-FLOW-REGION-004 r1 (future scene contract)")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)
