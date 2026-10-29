extends SceneTree
## GAME-WEB-MODULE-CHAR-002 r1: future-only additional tests. NOT_RUN.
## All assertions are proposals; no executed acceptance is claimed.

const PanelScene = preload("res://character_profile_panel.tscn")
const PreviewScene = preload("res://preview_candidate.tscn")
const FixtureLoader = preload("res://placeholder_fixture_loader_candidate.gd")

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _check(label: String, actual: Variant, expected: Variant) -> void:
    checks += 1
    if actual != expected:
        failures.append("%s: actual=%s expected=%s" % [label, str(actual), str(expected)])


func _sample(identifier: String = "placeholder-one") -> Dictionary:
    return {
        "schema_version": 1,
        "profile_id": identifier,
        "display_name": "合成占位 A",
        "subtitle": "",
        "summary": "占位摘要",
        "status_label": "",
        "tags": ["合成标签"],
        "sections": [
            {
                "section_id": "section-a",
                "heading": "测试章节",
                "items": [{"label": "字段", "value": "合成测试值"}]
            }
        ]
    }


func _has_property(target: Object, property_name: String) -> bool:
    for prop in target.get_property_list():
        if str(prop.get("name", "")) == property_name:
            return true
    return false


func _run() -> void:
    _check("non-string fixture rejected", FixtureLoader.parse_text(null)["ok"], false)
    _check("empty fixture rejected", FixtureLoader.parse_text("")["ok"], false)
    _check("whitespace fixture rejected", FixtureLoader.parse_text("   ")["ok"], false)
    _check("malformed fixture rejected", FixtureLoader.parse_text("[invalid")["ok"], false)
    _check("object root rejected", FixtureLoader.parse_text("{}")["ok"], false)
    _check("scalar root rejected", FixtureLoader.parse_text("true")["ok"], false)
    _check("empty array rejected", FixtureLoader.parse_text("[]")["ok"], false)
    _check("non-profile item rejected", FixtureLoader.parse_text("[null]")["ok"], false)
    _check("oversized byte payload rejected",
        FixtureLoader.parse_text("x".repeat(FixtureLoader.MAX_FIXTURE_BYTES + 1))["ok"], false)

    var valid: Array = [_sample("placeholder-one"), _sample("placeholder-two")]
    var accepted: Dictionary = FixtureLoader.parse_text(JSON.stringify(valid))
    _check("valid synthetic list accepted", accepted["ok"], true)
    if accepted["ok"]:
        _check("accepted all items", accepted["data"].size(), 2)
        var copy: Dictionary = accepted["data"][0]
        copy["display_name"] = "changed"
        _check("other fixture isolated",
            accepted["data"][1]["display_name"], "合成占位 A")

    var duplicate: Array = [_sample("same-id"), _sample("same-id")]
    var dupe_result: Dictionary = FixtureLoader.parse_text(JSON.stringify(duplicate))
    _check("duplicate identity rejected", dupe_result["ok"], false)
    _check("duplicate result has no partial data", dupe_result["data"].size(), 0)

    var malformed_end: Array = [_sample(), {"profile_id": "incomplete"}]
    var atomic: Dictionary = FixtureLoader.parse_text(JSON.stringify(malformed_end))
    _check("invalid final record rejects entire batch", atomic["ok"], false)
    _check("invalid batch returns no accepted prefix", atomic["data"].size(), 0)

    var too_many: Array = []
    for i in range(FixtureLoader.MAX_RECORDS + 1):
        too_many.append(_sample("item-%d" % i))
    _check("fixture count limited",
        FixtureLoader.parse_text(JSON.stringify(too_many))["ok"], false)

    var panel = PanelScene.instantiate()
    root.add_child(panel)
    var scrolling: ScrollContainer = panel.get_node("Layout/Scroll")
    _check("scroll is keyboard focusable", scrolling.focus_mode, Control.FOCUS_ALL)
    _check("scroll follows focused children", scrolling.follow_focus, true)
    _check("scroll horizontal disabled",
        scrolling.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
    _check("scroll has keyboard input handler", scrolling.has_method("_gui_input"), true)
    _check("help text visible when a profile exists before injection",
        panel.get_node("Layout/HelpLabel").visible, false)

    var long_profile := _sample()
    long_profile["summary"] = "长段摘要".repeat(200)
    _check("bounded long synthetic summary accepted", panel.set_profile(long_profile), true)
    _check("summary sits inside the scroll content",
        panel.get_node("Layout/Scroll/Content/Header/SummaryLabel").text,
        long_profile["summary"])
    _check("reading help becomes visible",
        panel.get_node("Layout/HelpLabel").visible, true)
    _check("scroll tooltip describes keys",
        scrolling.tooltip_text.contains("PageDown"), true)
    if _has_property(scrolling, "accessibility_name"):
        _check("native reader label (if available)",
            scrolling.get("accessibility_name"), "人物资料阅读区域")

    panel.clear_profile()
    _check("empty state on clear", panel.get_node("Layout/EmptyState").visible, true)
    _check("scroll hidden when empty", scrolling.visible, false)
    _check("hint hidden when empty",
        panel.get_node("Layout/HelpLabel").visible, false)

    var preview = PreviewScene.instantiate()
    root.add_child(preview)
    var picker: OptionButton = preview.get_node("Layout/Toolbar/Choice")
    var clear_button: Button = preview.get_node("Layout/Toolbar/Clear")
    var reload_button: Button = preview.get_node("Layout/Toolbar/Reload")
    _check("preview initial data available", picker.item_count, 2)
    _check("picker enabled for valid fixture", picker.disabled, false)
    _check("clear enabled for selected profile", clear_button.disabled, false)
    _check("reload available", reload_button.disabled, false)
    _check("keyboard picker focus enabled", picker.focus_mode, Control.FOCUS_ALL)
    _check("keyboard clear focus enabled", clear_button.focus_mode, Control.FOCUS_ALL)
    _check("keyboard reload focus enabled", reload_button.focus_mode, Control.FOCUS_ALL)
    _check("picker next focus is clear",
        picker.focus_next, picker.get_path_to(clear_button))
    _check("clear next focus is reload",
        clear_button.focus_next, clear_button.get_path_to(reload_button))

    preview._on_clear()
    _check("clear disables clear button", clear_button.disabled, true)
    _check("clear removes current profile", preview.get_node("Layout/Panel").profile_copy(), {})
    preview._on_chosen(-1)
    _check("bad selection does not repopulate", preview.get_node("Layout/Panel").profile_copy(), {})
    preview._on_reload()
    _check("explicit reload restores picker choices", picker.item_count, 2)
    _check("explicit reload restores placeholder", preview.get_node("Layout/Panel").profile_copy()["profile_id"], "placeholder-a")

    preview.free()
    panel.free()
    _finish()


func _finish() -> void:
    if failures.is_empty():
        print("PASS GAME-WEB-MODULE-CHAR-002 r1 (%d assertions)" % checks)
        quit(0)
        return
    for failure in failures:
        printerr("FAIL " + failure)
    printerr("FAIL GAME-WEB-MODULE-CHAR-002 r1 (%d/%d failed)" %
        [failures.size(), checks])
    quit(1)
