extends SceneTree
## GAME-WEB-REGION-006 r1: FUTURE pure navigation and focus-policy checks.
## Authored only. NOT_RUN. Does not assert native keyboard/window focus.

const Navigation = preload("res://navigation_candidate.gd")
const FocusRecovery = preload("res://focus_recovery_candidate.gd")

var _errors: Array[String] = []


func _initialize() -> void:
    call_deferred("_verify")


func _expect(ok: bool, case_id: String) -> void:
    if not ok:
        _errors.append(case_id)


func _verify() -> void:
    var nav = Navigation.new()
    var focus = FocusRecovery.new()
    var raw: Variant = JSON.parse_string(
        FileAccess.get_file_as_string("res://synthetic_targets.json")
    )
    if not raw is Dictionary:
        push_error("Expected public fixture document was not available")
        quit(1)
        return
    var records: Array = raw.get("targets", [])
    var catalog: Array[Dictionary] = []
    for item in records:
        if not item is Dictionary:
            push_error("Fixture item not a dictionary")
            quit(1)
            return
        catalog.append({
            "id": StringName(str(item.get("id", ""))),
            "position": Vector2(float(item.get("x", 0)), float(item.get("z", 0)))
        })

    _expect(nav.state()["mode"] == &"idle", "N001 initial idle")
    _expect(not nav.start_to_target(&"other", catalog, Vector2.ZERO),
        "N002 unknown target rejected")
    _expect(not nav.start_to_target(&"placeholder_a", catalog, Vector2.INF),
        "N003 invalid start rejected")

    var from := Vector2(0, 3)
    _expect(nav.start_to_target(&"placeholder_a", catalog, from),
        "N004 valid A starts")
    _expect(nav.state()["target_id"] == &"placeholder_a", "N005 target A stored")
    _expect(nav.is_moving(), "N006 mode moving")
    _expect(not nav.advance(from, -0.1).get("ok", false),
        "N007 negative step rejected")
    var tick: Dictionary = nav.advance(from, 15.0)
    _expect(tick.get("ok", false), "N008 huge time capped")
    _expect((tick["position"] as Vector2).distance_to(from) <= 0.201,
        "N009 capped movement per step")

    _expect(nav.pause_for_focus_loss(), "N010 loss pauses navigation")
    _expect(nav.is_paused(), "N011 paused flag")
    _expect(not nav.advance(tick["position"], 0.1).get("ok", false),
        "N012 paused navigation does not advance")
    _expect(not nav.resume_after_focus_return(false),
        "N013 no implicit resume")
    _expect(nav.resume_after_focus_return(true), "N014 explicit resume")
    _expect(nav.is_moving(), "N015 resumes only after authorization")

    var point: Vector2 = tick["position"]
    var arrived: bool = false
    for i in range(90):
        tick = nav.advance(point, 0.1)
        _expect(tick.get("ok", false), "N016 step %d accepted" % i)
        if not tick.get("ok", false):
            break
        point = tick["position"]
        if tick["arrived"]:
            arrived = true
            break
    _expect(arrived, "N017 arrives within finite steps")
    _expect(nav.state()["mode"] == &"arrived", "N018 arrived state")
    _expect(point.distance_to(Vector2(-1.2, 0)) <= 1.201,
        "N019 stops within candidate entry radius")
    _expect(not nav.advance(point, 0.1).get("ok", false),
        "N020 arrived prevents repeated advancement")
    _expect(not nav.cancel(), "N021 cannot cancel completed navigation")

    nav.reset()
    _expect(nav.state()["mode"] == &"idle", "N022 reset idle")
    _expect(nav.start_to_target(&"placeholder_b", catalog, Vector2(0, 3)),
        "N023 starts B")
    _expect(nav.cancel("manual override"), "N024 manual cancellation")
    _expect(nav.state()["mode"] == &"cancelled", "N025 cancelled state")
    _expect(not nav.resume_after_focus_return(true),
        "N026 cancellation cannot be resumed")

    focus.capture_window_loss(&"action", &"placeholder_b", true)
    _expect(focus.snapshot()["pending_restore"], "K001 focus claim pending")
    _expect(focus.snapshot()["require_key_release"],
        "K002 key-release gate armed")
    _expect(not focus.consume_key_release_gate(true),
        "K003 inactive never permits keys")
    var inactive_claim: Dictionary = focus.claim_focus(
        true, &"placeholder_b", false
    )
    _expect(not inactive_claim.get("restore", false),
        "K004 inactive cannot reclaim")
    focus.mark_window_returned()
    _expect(not focus.consume_key_release_gate(false),
        "K005 key held after return blocked")
    _expect(focus.consume_key_release_gate(true),
        "K006 released keys unblock")
    var claim: Dictionary = focus.claim_focus(true, &"placeholder_b", false)
    _expect(claim.get("restore", false), "K007 matching focus reclaimed")
    _expect(claim.get("role", &"none") == &"action",
        "K008 original role preserved")
    var repeated_claim: Dictionary = focus.claim_focus(
        true, &"placeholder_b", false
    )
    _expect(not repeated_claim.get("restore", false),
        "K009 single-use claim")

    focus.capture_window_loss(&"next", &"placeholder_b", true)
    focus.mark_window_returned()
    claim = focus.claim_focus(true, &"placeholder_a", false)
    _expect(not claim.get("restore", false), "K010 changed ID blocks restore")

    focus.capture_window_loss(&"dismiss", &"placeholder_a", true)
    focus.mark_window_returned()
    claim = focus.claim_focus(true, &"placeholder_a", true)
    _expect(not claim.get("restore", false), "K011 host focus not stolen")

    focus.capture_window_loss(&"none", &"placeholder_a", true)
    focus.mark_window_returned()
    _expect(not focus.snapshot()["pending_restore"],
        "K012 world focus not captured")
    focus.reset()
    _expect(not focus.snapshot()["require_key_release"],
        "K013 reset clears release gate")
    _expect(not focus.snapshot()["window_inactive"],
        "K014 reset clears window inactive")

    if _errors.is_empty():
        print("PASS GAME-WEB-REGION-006 r1 future pure contracts")
        quit(0)
    else:
        for failed in _errors:
            push_error("FAIL: " + failed)
        quit(1)
