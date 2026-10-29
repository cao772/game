extends SceneTree
## Future headless logic checks. This file is deliberately NOT_RUN.
## Execute only after owner/Codex authorizes verification.
## Native mouse, focus/keyboard hardware and screenshots require separate GUI checks.

var _errors: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_checks")


func _check(condition: bool, description: String) -> void:
    if not condition:
        _errors.append(description)


func _run_checks() -> void:
    var prefab: PackedScene = load("res://interaction_prompt_candidate.tscn")
    if prefab == null:
        push_error("Could not load independent prompt scene")
        quit(1)
        return

    var host := Control.new()
    root.add_child(host)

    var origin := Button.new()
    origin.name = "OriginFocus"
    host.add_child(origin)

    var prompt = prefab.instantiate()
    host.add_child(prompt)
    await process_frame

    var action_button: Button = prompt.get_node("Padding/Content/ActionButton")
    var dismiss_button: Button = prompt.get_node("Padding/Content/DismissButton")
    var messages: Array[StringName] = []
    var transitions: Array[bool] = []

    prompt.interaction_requested.connect(func(target_id):
        messages.append(target_id)
    )
    prompt.prompt_visibility_changed.connect(func(shown):
        transitions.append(shown)
    )

    _check(not prompt.is_prompt_shown(), "initially hidden")
    _check(not prompt.request_interaction(false), "hidden request blocked")
    _check(not prompt.show_for_target(&"", "A"), "empty ID rejected")
    _check(not prompt.show_for_target(&"a", ""), "empty display rejected")
    _check(not prompt.show_for_target(&"a", "A", ""), "empty caption rejected")
    _check(not prompt.is_prompt_shown(), "invalid input cannot show prompt")

    _check(prompt.show_for_target(&"placeholder_a", "占位目标 A"),
        "show valid placeholder")
    _check(prompt.is_prompt_shown(), "visible with target")
    _check(prompt.active_target_id() == &"placeholder_a", "active ID A")
    _check(action_button.focus_mode == Control.FOCUS_ALL, "action focusable")
    _check(dismiss_button.focus_mode == Control.FOCUS_ALL, "dismiss focusable")
    _check(not action_button.focus_next.is_empty(), "Tab neighbor set")
    _check(not dismiss_button.focus_previous.is_empty(), "reverse Tab set")

    _check(not prompt.request_interaction(true), "blocked window gate")
    _check(messages.size() == 0, "blocked gate emits nothing")
    _check(prompt.request_interaction(false), "injected allowed request")
    _check(messages.size() == 1, "one request signal")
    if messages.size() == 1:
        _check(messages[0] == &"placeholder_a", "request target A")

    _check(prompt.show_for_target(&"placeholder_b", "占位目标 B", "确认"),
        "switch target without hide")
    _check(prompt.active_target_id() == &"placeholder_b", "active ID B")
    _check(prompt.request_interaction(false), "B request")
    _check(messages.size() == 2, "exactly two signals")
    if messages.size() == 2:
        _check(messages[1] == &"placeholder_b", "request target B")

    _check(prompt.hide_prompt(), "hide visible prompt")
    _check(not prompt.is_prompt_shown(), "hidden after hide")
    _check(prompt.active_target_id() == &"", "no active ID after hide")
    _check(not prompt.hide_prompt(), "second hide is no-op")
    _check(not prompt.request_interaction(false), "request blocked after hide")

    # Repeated show/hide without state leakage or duplicate signals.
    for i in range(10):
        _check(prompt.show_for_target(&"placeholder_a", "占位目标 A"),
            "cycle %d show" % i)
        _check(prompt.request_interaction(false), "cycle %d action" % i)
        _check(prompt.hide_prompt(), "cycle %d hide" % i)
        _check(not prompt.is_prompt_shown(), "cycle %d clears" % i)

    _check(prompt.request_count() == 12, "12 accepted requests total")
    _check(messages.size() == 12, "12 emitted requests total")
    _check(transitions.size() == 22, "11 shows plus 11 hides")
    paused = true
    _check(not prompt.request_interaction(false), "paused tree blocks")
    paused = false

    host.queue_free()
    await process_frame

    if _errors.is_empty():
        print("PASS GAME-WEB-MODULE-REGION-001 r1 (headless contract checks)")
        quit(0)
    else:
        for item in _errors:
            push_error("FAIL: " + item)
        quit(1)
