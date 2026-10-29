extends SceneTree
## Future-only legacy r1 checks, path-adjusted for r2 scroll layout. NOT_RUN.

const PanelScene = preload("res://character_profile_panel.tscn")
const Contract = preload("res://profile_contract_candidate.gd")

var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(label: String, actual: Variant, expected: Variant) -> void:
    checks += 1
    if actual != expected:
        failures.append("%s: actual=%s expected=%s" % [label, str(actual), str(expected)])

func _sample(identity: String = "placeholder-one") -> Dictionary:
    return {
        "schema_version": 1,
        "profile_id": identity,
        "display_name": "占位姓名",
        "subtitle": "占位副标题",
        "summary": "占位摘要",
        "status_label": "待注入",
        "tags": ["标签甲", "标签乙"],
        "sections": [
            {
                "section_id": "alpha",
                "heading": "占位章节",
                "items": [
                    {"label": "占位字段", "value": "[b]仅是普通文本[/b]"},
                    {"label": "第二字段", "value": "第二占位值"}
                ]
            }
        ]
    }

func _contains_exact_label(node: Node, expected: String) -> bool:
    for child in node.find_children("*", "Label", true, false):
        if child.text == expected:
            return true
    return false

func _run() -> void:
    var panel = PanelScene.instantiate()
    root.add_child(panel)
    _check("initially empty", panel.profile_copy(), {})
    _check("empty label visible", panel.get_node("Layout/EmptyState").visible, true)
    _check("no sections initially", panel.get_node("Layout/Scroll/Content/Sections").get_child_count(), 0)

    _check("null rejected", Contract.validate(null)["ok"], false)
    _check("array rejected", Contract.validate([])["ok"], false)
    var missing := _sample()
    missing.erase("summary")
    _check("missing key rejected", Contract.validate(missing)["ok"], false)
    var extra := _sample()
    extra["unknown"] = "not accepted"
    _check("extra key rejected", Contract.validate(extra)["ok"], false)

    for bad_version in [true, 2, 1.5]:
        var wrong := _sample()
        wrong["schema_version"] = bad_version
        _check("invalid schema version", Contract.validate(wrong)["ok"], false)

    _check("invalid id rejected", Contract.validate(_sample("bad/id"))["ok"], false)
    var blank_name := _sample()
    blank_name["display_name"] = "  "
    _check("blank name rejected", Contract.validate(blank_name)["ok"], false)
    var long_summary := _sample()
    long_summary["summary"] = "长".repeat(1201)
    _check("oversize summary rejected", Contract.validate(long_summary)["ok"], false)
    var many_tags := _sample()
    many_tags["tags"] = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
    _check("tag count bounded", Contract.validate(many_tags)["ok"], false)
    var duplicate_tags := _sample()
    duplicate_tags["tags"] = ["重复", "重复"]
    _check("duplicate tags rejected", Contract.validate(duplicate_tags)["ok"], false)
    var malformed_items := _sample()
    malformed_items["sections"][0]["items"] = [{"label": "only"}]
    _check("malformed item rejected", Contract.validate(malformed_items)["ok"], false)
    var duplicate_sections := _sample()
    duplicate_sections["sections"].append(duplicate_sections["sections"][0].duplicate(true))
    _check("duplicate section id rejected", Contract.validate(duplicate_sections)["ok"], false)
    var unsafe_section := _sample()
    unsafe_section["sections"][0]["section_id"] = "../escape"
    _check("unsafe section id rejected", Contract.validate(unsafe_section)["ok"], false)
    var long_value := _sample()
    long_value["sections"][0]["items"][0]["value"] = "长".repeat(601)
    _check("oversize value rejected", Contract.validate(long_value)["ok"], false)
    var null_text := _sample()
    null_text["display_name"] = "bad\u0000text"
    _check("null char rejected", Contract.validate(null_text)["ok"], false)

    var raw := _sample()
    _check("valid data accepted", panel.set_profile(raw), true)
    _check("name rendered", panel.get_node("Layout/Scroll/Content/Header/NameLabel").text, "占位姓名")
    _check("one section rendered", panel.get_node("Layout/Scroll/Content/Sections").get_child_count(), 1)
    _check("named section exists", panel.get_node_or_null("Layout/Scroll/Content/Sections/section_alpha") != null, true)
    _check("literal markup remains text", _contains_exact_label(panel, "[b]仅是普通文本[/b]"), true)
    _check("two tags", panel.get_node("Layout/Scroll/Content/Header/Tags").get_child_count(), 2)

    raw["display_name"] = "mutated"
    raw["sections"][0]["items"][0]["value"] = "mutated"
    _check("caller dictionary copied", panel.profile_copy()["display_name"], "占位姓名")
    _check("nested input copied", panel.profile_copy()["sections"][0]["items"][0]["value"], "[b]仅是普通文本[/b]")
    var copy = panel.profile_copy()
    copy["sections"][0]["items"][0]["value"] = "changed"
    _check("getter returns deep copy", panel.profile_copy()["sections"][0]["items"][0]["value"], "[b]仅是普通文本[/b]")

    var invalid := _sample()
    invalid["sections"] = "invalid"
    _check("bad replacement rejected", panel.set_profile(invalid), false)
    _check("last valid data retained", panel.profile_copy()["profile_id"], "placeholder-one")
    _check("last UI retained", panel.get_node("Layout/Scroll/Content/Header/NameLabel").text, "占位姓名")
    _check("rejection reason exists", panel.last_error().is_empty(), false)

    var without_sections := _sample("placeholder-two")
    without_sections["subtitle"] = ""
    without_sections["summary"] = ""
    without_sections["status_label"] = ""
    without_sections["tags"] = []
    without_sections["sections"] = []
    _check("empty sections accepted", panel.set_profile(without_sections), true)
    _check("old section removed", panel.get_node_or_null("Layout/Scroll/Content/Sections/section_alpha") == null, true)
    _check("section placeholder shown", _contains_exact_label(panel, "暂无展示章节"), true)
    _check("subtitle hidden", panel.get_node("Layout/Scroll/Content/Header/SubtitleLabel").visible, false)
    _check("tags removed", panel.get_node("Layout/Scroll/Content/Header/Tags").get_child_count(), 0)

    var zero_items := _sample("placeholder-three")
    zero_items["sections"][0]["items"] = []
    _check("zero-item section accepted", panel.set_profile(zero_items), true)
    _check("zero-item hint visible", _contains_exact_label(panel, "暂无条目"), true)

    panel.clear_profile()
    _check("clear removes data", panel.profile_copy(), {})
    _check("clear restores empty state", panel.get_node("Layout/EmptyState").visible, true)
    _check("clear removes cards", panel.get_node("Layout/Scroll/Content/Sections").get_child_count(), 0)

    var detached = PanelScene.instantiate()
    _check("inject before ready", detached.set_profile(_sample("placeholder-early")), true)
    root.add_child(detached)
    _check("pre-ready injection rendered", detached.get_node("Layout/Scroll/Content/Header/NameLabel").text, "占位姓名")
    detached.free()
    panel.free()
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("PASS GAME-WEB-MODULE-CHAR-001 r1 (%d assertions)" % checks)
        quit(0)
    else:
        for failure in failures:
            printerr("FAIL " + failure)
        printerr("FAIL GAME-WEB-MODULE-CHAR-001 r1 (%d/%d failed)" % [failures.size(), checks])
        quit(1)
