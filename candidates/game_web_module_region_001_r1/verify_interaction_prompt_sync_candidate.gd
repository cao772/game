extends SceneTree
## GAME-WEB-CONTINUE-REGION-003 r1: future Godot 4 headless QA fixture.
## Authored only. NOT_RUN. No native focus/GUI pass can be inferred here.

const Catalog = preload("res://placeholder_catalog_candidate.gd")
var _failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_check_candidate")


func _expect(condition: bool, reason: String) -> void:
    if not condition:
        _failures.append(reason)


func _check_candidate() -> void:
    var packed: PackedScene = load("res://interaction_prompt_candidate.tscn")
    if packed == null:
        push_error("Cannot load independent prompt scene")
        quit(1)
        return

    var host := Control.new()
    root.add_child(host)
    var host_button := Button.new()
    host_button.focus_mode = Control.FOCUS_ALL
    host.add_child(host_button)
    var prompt = packed.instantiate()
    host.add_child(prompt)
    await process_frame

    var snapshots: Array[Dictionary] = []
    var selected: Array[StringName] = []
    var requested: Array[StringName] = []
    var list_counts: Array[int] = []
    var visibilities: Array[bool] = []

    prompt.prompt_state_changed.connect(func(state: Dictionary):
        snapshots.append(state.duplicate(true))
    )
    prompt.placeholder_changed.connect(func(id: StringName):
        selected.append(id)
    )
    prompt.interaction_requested.connect(func(id: StringName):
        requested.append(id)
    )
    prompt.target_list_changed.connect(func(count: int):
        list_counts.append(count)
    )
    prompt.prompt_visibility_changed.connect(func(shown: bool):
        visibilities.append(shown)
    )

    var fixture: Dictionary = Catalog.load_catalog()
    _expect(fixture.get("ok", false), "load bundled public JSON fixture")
    if not fixture.get("ok", false):
        host.queue_free()
        quit(1)
        return

    var initial: Array = Catalog.get_set(fixture, "initial")
    var reordered: Array = Catalog.get_set(fixture, "reordered")
    var reduced: Array = Catalog.get_set(fixture, "reduced")
    var alternate: Array = Catalog.get_set(fixture, "alternate")

    _expect(initial.size() == 3, "three initial placeholder records")
    _expect(reordered.size() == 3, "three reordered records")
    _expect(reduced.size() == 1, "one reduced record")
    _expect(alternate.size() == 2, "two alternative records")

    _expect(not prompt.is_prompt_shown(), "initially hidden")
    _expect(prompt.state_snapshot()["target_count"] == 0, "empty initial state")
    _expect(not prompt.synchronize_targets(initial), "cannot sync while hidden")
    _expect(prompt.show_for_targets(initial, 1), "show B first")
    await process_frame

    _expect(prompt.active_target_id() == &"placeholder_b", "initial B")
    _expect(prompt.active_target_index() == 1, "B index 1")
    _expect(prompt.state_snapshot()["target_ids"].size() == 3, "snapshot IDs")
    _expect(visibilities.size() == 1 and visibilities[0], "one show event")
    _expect(snapshots.size() == 1, "one coalesced show snapshot")
    var first_revision: int = prompt.state_snapshot()["revision"]
    _expect(first_revision > 0, "revision starts after real changes")

    _expect(prompt.synchronize_targets(reordered), "reorder accepted")
    await process_frame
    _expect(prompt.active_target_id() == &"placeholder_b", "retain ID on reorder")
    _expect(prompt.active_target_index() == 2, "reordered B index 2")
    _expect(selected.size() == 1, "no duplicate selection change on reorder")
    _expect(requested.is_empty(), "reordering does not request interaction")
    _expect(prompt.state_snapshot()["revision"] > first_revision, "revision advanced")
    _expect(list_counts.size() == 2, "new list event on reorder")

    # Invalid updates are atomic, even with a previously displayed target.
    var unchanged: Dictionary = prompt.state_snapshot()
    var invalid: Array = [
        {"id": "placeholder_a", "label": "A"},
        {"id": "placeholder_a", "label": "duplicate"}
    ]
    _expect(not prompt.synchronize_targets(invalid), "duplicate ID rejected")
    _expect(not prompt.synchronize_targets([]), "empty sync rejected")
    await process_frame
    _expect(prompt.state_snapshot() == unchanged, "invalid sync retains full state")
    _expect(requested.is_empty(), "invalid update emits no request")

    _expect(prompt.synchronize_targets(reduced), "remove selected B")
    await process_frame
    _expect(prompt.active_target_id() == &"placeholder_a", "clamp to A")
    _expect(prompt.active_target_index() == 0, "fallback index 0")
    _expect(prompt.target_count() == 1, "single target count")
    _expect(not prompt.get_node("Padding/Content/Navigation").visible,
        "hidden nav after reduction")
    _expect(selected.size() == 2, "selected A change emitted")

    _expect(prompt.synchronize_targets(alternate, &"placeholder_e"),
        "preferred E selected when available")
    await process_frame
    _expect(prompt.active_target_id() == &"placeholder_e", "preferred ID E")
    _expect(prompt.active_target_index() == 1, "preferred index 1")
    _expect(prompt.target_count() == 2, "alternate count")
    _expect(prompt.get_node("Padding/Content/Navigation").visible,
        "navigation restored after expansion")
    _expect(not prompt.request_interaction(true), "blocked request stays blocked")
    _expect(prompt.request_interaction(false), "injected request E")
    await process_frame
    _expect(requested.size() == 1, "one valid request")
    if requested.size() == 1:
        _expect(requested[0] == &"placeholder_e", "request uses current E")

    # Style and target synchronization must not reset one another.
    var selected_before_style: StringName = prompt.active_target_id()
    var requests_before_style: int = prompt.request_count()
    var old_revision: int = prompt.state_snapshot()["revision"]
    _expect(prompt.apply_style_preset(&"high_contrast"), "preset accepted")
    await process_frame
    _expect(prompt.active_target_id() == selected_before_style,
        "style preserves selected target")
    _expect(prompt.request_count() == requests_before_style,
        "style does not dispatch action")
    _expect(prompt.state_snapshot()["revision"] > old_revision,
        "style appears in coalesced state")
    var style_before_invalid: Dictionary = prompt.style_snapshot()
    _expect(not prompt.apply_style({"font_size": 4}),
        "invalid style rejected")
    await process_frame
    _expect(prompt.style_snapshot() == style_before_invalid,
        "invalid style is atomic")

    # Headless contract verifies focus-state structure, NOT native keyboard.
    var role: StringName = prompt.focus_state()["role"]
    _expect(role in [&"none", &"previous", &"next", &"action", &"dismiss"],
        "focus role uses documented enum")
    _expect(prompt.state_snapshot()["focus_role"] == role,
        "focus role agrees with state snapshot")

    _expect(prompt.hide_prompt(), "hide")
    await process_frame
    _expect(prompt.active_target_id() == &"", "hide clears ID")
    _expect(prompt.target_count() == 0, "hide clears count")
    _expect(prompt.state_snapshot()["target_ids"].is_empty(),
        "hide clears snapshot IDs")
    _expect(prompt.state_snapshot()["focus_role"] == &"none",
        "hide clears focus role")
    _expect(visibilities.size() == 2 and not visibilities[1],
        "exactly one hide transition")

    # Ten cycles with source-replaced list must not retain previous selection.
    for i in range(10):
        _expect(prompt.show_for_targets(initial, i % 3),
            "round %d show" % i)
        _expect(prompt.synchronize_targets(reordered),
            "round %d re-order" % i)
        _expect(prompt.request_interaction(false),
            "round %d request" % i)
        _expect(prompt.hide_prompt(), "round %d hide" % i)
        _expect(prompt.active_target_id() == &"",
            "round %d stale ID cleared" % i)
    await process_frame
    _expect(requested.size() == 11, "eleven total valid requests")
    _expect(prompt.request_count() == 11, "request counter remains in sync")

    host.queue_free()
    await process_frame
    if _failures.is_empty():
        print("PASS GAME-WEB-CONTINUE-REGION-003 r1 (future contract only)")
        quit(0)
    else:
        for failure in _failures:
            push_error("FAIL: " + failure)
        quit(1)
