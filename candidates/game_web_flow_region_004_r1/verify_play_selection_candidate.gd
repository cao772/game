extends SceneTree
## GAME-WEB-PLAY-REGION-005 r1 future-only pure selection/feedback checks.
## NOT_RUN. No assertions are claimed to have passed.
const FlowModel = preload("res://flow_model_candidate.gd")
const Picker = preload("res://target_picker_candidate.gd")
const Journal = preload("res://feedback_journal_candidate.gd")
var _failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_verify")


func _check(ok: bool, case_id: String) -> void:
    if not ok:
        _failures.append(case_id)


func _verify() -> void:
    var model = FlowModel.new()
    var raw: Variant = JSON.parse_string(
        FileAccess.get_file_as_string("res://synthetic_targets.json")
    )
    _check(raw is Dictionary, "P001 fixture dictionary")
    if not raw is Dictionary:
        quit(1)
        return
    _check(model.load_targets(raw.get("targets", [])), "P002 fixture load")
    var targets: Array[Dictionary] = model.all_targets()
    var no_nearby: Array[StringName] = []

    var hit: Dictionary = Picker.choose_at(
        Vector2(-1.2, 0.0), targets, no_nearby
    )
    _check(hit.get("hit", false), "P003 cube A hit")
    _check(hit.get("target_id", &"") == &"placeholder_a", "P004 ID A")
    _check(not hit.get("eligible", true), "P005 A not eligible far away")
    _check(not Picker.choose_at(Vector2(99, 99), targets, no_nearby).get(
        "hit", false
    ), "P006 unrelated floor click")
    _check(not Picker.choose_at(Vector2.INF, targets, no_nearby).get(
        "hit", false
    ), "P007 nonfinite point")
    _check(not Picker.choose_at(Vector2.ZERO, targets, no_nearby, -1.0).get(
        "hit", false
    ), "P008 invalid selection radius")

    _check(model.move_player(Vector2(-0.6, 0)).get("ok", false),
        "P009 approach A/B")
    var eligible: Array[StringName] = model.nearby_ids()
    _check(eligible.has(&"placeholder_a") and eligible.has(&"placeholder_b"),
        "P010 two eligible targets")
    hit = Picker.choose_at(Vector2(0, 0), targets, eligible)
    _check(hit.get("target_id", &"") == &"placeholder_b", "P011 choose B")
    _check(hit.get("eligible", false), "P012 B eligible")
    _check(model.mark_selected(hit["target_id"]), "P013 select B")
    _check(model.selected_id() == &"placeholder_b", "P014 ID B synchronized")

    var journal = Journal.new()
    _check(not journal.append("unknown", "unsafe kind"), "P015 reject kind")
    _check(not journal.append("success", ""), "P016 reject blank")
    _check(not journal.append("success", "test", &"person_name"),
        "P017 reject non-placeholder ID")
    _check(journal.append("selection", "已选 B", &"placeholder_b"),
        "P018 selection feedback")
    var result: Dictionary = model.confirm(&"placeholder_b")
    _check(result.get("ok", false), "P019 confirm B")
    _check(journal.append("success", str(result["feedback"]),
        &"placeholder_b"), "P020 confirmation feedback")
    _check(journal.count() == 2, "P021 two journal entries")
    _check(journal.last_entry().get("kind", "") == "success",
        "P022 journal last kind")

    for i in range(15):
        _check(journal.append("info", "bounded %d" % i),
            "P023 bounded append %d" % i)
    _check(journal.count() == 12, "P024 bounded capacity")
    _check(journal.entries()[0]["sequence"] == 6,
        "P025 chronological sequence after rolling")
    _check(journal.lines_for_display(4).split("\n").size() == 4,
        "P026 four display lines")
    var snapshot: Array[Dictionary] = journal.entries()
    snapshot.clear()
    _check(journal.count() == 12, "P027 exported copy cannot mutate journal")
    journal.clear()
    _check(journal.count() == 0 and journal.last_entry().is_empty(),
        "P028 clear journal")
    _check(journal.append("reset", "reset"), "P029 append after clear")
    _check(journal.last_entry()["sequence"] == 1,
        "P030 sequence restarts after clear")

    if _failures.is_empty():
        print("PASS GAME-WEB-PLAY-REGION-005 r1 (future pure checks)")
        quit(0)
    else:
        for failure in _failures:
            push_error("FAIL: " + failure)
        quit(1)
