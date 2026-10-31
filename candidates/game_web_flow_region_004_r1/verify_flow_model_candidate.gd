extends SceneTree
## FUTURE ONLY: headless logic contract. DO NOT RUN in authoring task.
## Exact source revision and native viewport screenshots require later QA.
const FlowModel = preload("res://flow_model_candidate.gd")
var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_verify")


func expect(condition: bool, reason: String) -> void:
    if not condition:
        failures.append(reason)


func _verify() -> void:
    var source: String = FileAccess.get_file_as_string("res://synthetic_targets.json")
    var parsed: Variant = JSON.parse_string(source)
    if not parsed is Dictionary:
        push_error("Fixture parsing failed")
        quit(1)
        return
    if parsed.get("schema_version", "") != "synthetic-targets-v1":
        push_error("Fixture schema not recognized")
        quit(1)
        return

    var model = FlowModel.new()
    var catalog: Array = parsed.get("targets", [])
    expect(not model.is_loaded(), "initial state unloaded")
    expect(not model.load_targets([]), "empty list fails closed")
    expect(model.load_targets(catalog), "valid synthetic fixture loaded")
    expect(model.is_loaded(), "loaded flag true")
    expect(model.all_targets().size() == 3, "three explicit synthetic targets")

    var before_invalid: Dictionary = model.snapshot()
    expect(not model.load_targets([
        {"id":"placeholder_a","label":"A","x":0,"z":0},
        {"id":"placeholder_a","label":"Duplicate","x":1,"z":0}
    ]), "duplicate ID rejected atomically")
    expect(model.snapshot() == before_invalid, "invalid reload retains state")
    expect(not model.load_targets([
        {"id":"private_real_person","label":"invalid","x":0,"z":0}
    ]), "non-placeholder ID disallowed")

    var response: Dictionary = model.move_player(Vector2(0, 3))
    expect(response.get("ok", false), "far movement accepted")
    expect(model.nearby_ids().is_empty(), "far start has no targets")
    expect(model.prompt_entries().is_empty(), "far start has no prompt entries")

    response = model.move_player(Vector2(-1.2, 1.5))
    expect(model.nearby_ids().size() == 1, "enter A only")
    expect(model.nearby_ids().has(&"placeholder_a"), "A is eligible")
    expect(response["entered"].size() == 1, "one enter transition")
    expect(model.selected_id() == &"placeholder_a", "selection defaults to A")

    response = model.move_player(Vector2(-1.2, 1.7))
    expect(model.nearby_ids().has(&"placeholder_a"), "hysteresis retains A")
    expect(response["left"].is_empty(), "no early departure at 1.7")

    response = model.move_player(Vector2(-1.2, 1.9))
    expect(model.nearby_ids().is_empty(), "A leaves past 1.85")
    expect(response["left"].has(&"placeholder_a"), "A leave transition")
    expect(model.selected_id() == &"", "selected clears on leaving all")

    response = model.move_player(Vector2(-0.6, 0))
    expect(response.get("ok", false), "between A/B accepted")
    expect(model.nearby_ids().size() == 2, "A and B eligible")
    expect(model.nearby_ids()[0] == &"placeholder_a", "tied sort by ID")
    expect(model.nearby_ids()[1] == &"placeholder_b", "tied order B")
    expect(model.prompt_entries().size() == 2, "two prompt entries")

    expect(model.mark_selected(&"placeholder_b"), "choose B")
    expect(not model.mark_selected(&"placeholder_c"), "out-of-range C rejected")
    expect(model.selected_id() == &"placeholder_b", "stale selection does not change")
    var denied: Dictionary = model.confirm(&"placeholder_a")
    expect(not denied["ok"], "reject confirming unselected A")
    expect(model.snapshot()["confirm_count"] == 0, "rejected confirm no mutation")
    var confirmed: Dictionary = model.confirm(&"placeholder_b")
    expect(confirmed.get("ok", false), "confirm selected B")
    expect(confirmed["target_id"] == &"placeholder_b", "correct confirmed ID")
    expect(model.snapshot()["confirm_count"] == 1, "one confirmation")

    expect(model.dismiss_prompt(), "manual dismiss")
    expect(model.is_dismissed(), "dismiss state")
    var hidden_reply: Dictionary = model.confirm(&"placeholder_b")
    expect(not hidden_reply.get("ok", false), "dismiss blocks confirmation")
    expect(model.reopen_prompt(), "explicit reopen")
    expect(not model.is_dismissed(), "reopened state")

    response = model.move_player(Vector2(0.0, 3.1))
    expect(response.get("ok", false), "leave movement accepted")
    # Leave clears proximity and manual suppression. Exit/reentry is deterministic.
    expect(model.nearby_ids().is_empty(), "far move clears nearby")
    expect(not model.is_dismissed(), "far move clears dismissal")

    # Same model, 10 complete cycles. No load or file I/O per cycle.
    for i in range(10):
        response = model.move_player(Vector2(-1.2, 0.0))
        expect(response.get("ok", false), "round %d approach" % i)
        expect(model.nearby_ids().has(&"placeholder_a"), "round %d A nearby" % i)
        expect(model.mark_selected(&"placeholder_a"), "round %d select A" % i)
        confirmed = model.confirm(&"placeholder_a")
        expect(confirmed.get("ok", false), "round %d confirm" % i)
        response = model.move_player(Vector2(0.0, 3.1))
        expect(model.nearby_ids().is_empty(), "round %d leave" % i)
    expect(model.snapshot()["confirm_count"] == 11, "exact 11 confirmations")
    expect(model.snapshot()["last_confirmed"] == &"placeholder_a",
        "last confirmation is synthetic A")

    if failures.is_empty():
        print("PASS GAME-WEB-FLOW-REGION-004 r1 (future model checks)")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)
