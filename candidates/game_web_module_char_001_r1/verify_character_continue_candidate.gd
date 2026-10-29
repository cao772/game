extends SceneTree
## GAME-WEB-CONTINUE-CHAR-003 r1 — future headless acceptance only. NOT_RUN.

const PanelScene = preload("res://character_profile_panel.tscn")
const PreviewScene = preload("res://preview_candidate.tscn")
const FixtureLoader = preload("res://placeholder_fixture_loader_candidate.gd")
const PanelFactory = preload("res://preview_panel_resource_candidate.gd")
const TextLayout = preload("res://profile_text_layout_candidate.gd")
const KeyScroll = preload("res://profile_scroll_navigation.gd")

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
    call_deferred("_run")


func _check(label: String, actual: Variant, expected: Variant) -> void:
    checks += 1
    if actual != expected:
        failures.append("%s actual=%s expected=%s" % [
            label, str(actual), str(expected)
        ])


func _key(keycode_value: int) -> InputEventKey:
    var result := InputEventKey.new()
    result.keycode = keycode_value
    result.pressed = true
    result.echo = false
    return result


func _profile() -> Dictionary:
    return {
        "schema_version": 1,
        "profile_id": "example-long",
        "display_name": "仅占位",
        "subtitle": "长文本阅读",
        "summary": "第一段。\r\n第二段：" + "Synthetic0123".repeat(30),
        "status_label": "占位",
        "tags": ["合成"],
        "sections": [
            {"section_id": "section-one", "heading": "第一节",
             "items": [{"label": "字段一", "value": "占位值 " + "aB09".repeat(60)}]},
            {"section_id": "section-two", "heading": "第二节",
             "items": [{"label": "字段二", "value": "第二个合成值"}]}
        ]
    }


func _run() -> void:
    _check("non-string rejected", FixtureLoader.parse_text(null)["ok"], false)
    _check("invalid UTF8 rejected",
        FixtureLoader.parse_bytes(PackedByteArray([255, 254]))["ok"], false)
    _check("empty bytes rejected",
        FixtureLoader.parse_bytes(PackedByteArray())["ok"], false)
    _check("BOM rejected",
        FixtureLoader.parse_bytes(PackedByteArray([239, 187, 191, 91, 93]))["ok"], false)
    var oversized := PackedByteArray()
    oversized.resize(FixtureLoader.MAX_FIXTURE_BYTES + 1)
    _check("oversized byte fixture rejected",
        FixtureLoader.parse_bytes(oversized)["ok"], false)

    var fixture: Dictionary = FixtureLoader.read_known_fixture()
    _check("fixed synthetic resource can be parsed", fixture["ok"], true)
    if fixture["ok"]:
        _check("three public placeholders", fixture["data"].size(), 3)
        _check("last fixture is only synthetic", fixture["data"][2]["profile_id"], "placeholder-long-c")

    var repeated_id: Array = [_profile(), _profile()]
    var duplicates := FixtureLoader.parse_text(JSON.stringify(repeated_id))
    _check("duplicate profile IDs fail atomically", duplicates["ok"], false)
    _check("atomic failure returns zero profiles", duplicates["data"].size(), 0)

    _check("missing panel resource rejected by factory",
        PanelFactory.instantiate_panel(null)["ok"], false)
    _check("wrong resource class rejected by factory",
        PanelFactory.instantiate_panel(Resource.new())["ok"], false)

    _check("line endings normalized",
        TextLayout.visible_text("A\r\nB\rC\tD"), "A\nB\nC    D")
    _check("word-smart mode for ordinary text",
        TextLayout.wrap_mode("short words"),
        TextServer.AUTOWRAP_WORD_SMART)
    _check("character mode for long unbroken text",
        TextLayout.wrap_mode("abcd".repeat(15)),
        TextServer.AUTOWRAP_ARBITRARY)

    var scroll_down := KeyScroll.scroll_decision(_key(KEY_DOWN), true, 0, 500, 180)
    _check("Down accepted with focus", scroll_down["handled"], true)
    _check("Down advances 64 pixels", scroll_down["position"], 64)
    _check("unfocused reading does not consume",
        KeyScroll.scroll_decision(_key(KEY_DOWN), false, 0, 500, 180)["handled"], false)
    _check("Down at end not trapped",
        KeyScroll.scroll_decision(_key(KEY_DOWN), true, 500, 500, 180)["handled"], false)
    _check("Up at top not trapped",
        KeyScroll.scroll_decision(_key(KEY_UP), true, 0, 500, 180)["handled"], false)
    _check("PageDown advances",
        KeyScroll.scroll_decision(_key(KEY_PAGEDOWN), true, 0, 500, 200)["position"], 160)
    _check("Home returns to top",
        KeyScroll.scroll_decision(_key(KEY_HOME), true, 200, 500, 180)["position"], 0)
    _check("End reaches limit",
        KeyScroll.scroll_decision(_key(KEY_END), true, 200, 500, 180)["position"], 500)
    var modified := _key(KEY_DOWN)
    modified.shift_pressed = true
    _check("Shift-modified scroll ignored",
        KeyScroll.scroll_decision(modified, true, 0, 500, 180)["handled"], false)
    var echo_key := _key(KEY_DOWN)
    echo_key.echo = true
    _check("auto-repeat ignored",
        KeyScroll.scroll_decision(echo_key, true, 0, 500, 180)["handled"], false)
    _check("unrelated key ignored",
        KeyScroll.scroll_decision(_key(KEY_ENTER), true, 0, 500, 180)["handled"], false)

    var panel = PanelScene.instantiate()
    root.add_child(panel)
    _check("empty panel has no navigation",
        panel.get_node("Layout/SectionNav").visible, false)
    var record := _profile()
    _check("valid long text accepted", panel.set_profile(record), true)
    _check("raw stored data preserved",
        panel.profile_copy()["summary"], record["summary"])
    _check("CRLF rendered as normal paragraphs",
        panel.get_node("Layout/Scroll/Content/Header/SummaryLabel").text,
        TextLayout.visible_text(record["summary"]))
    _check("long continuous run uses character wrapping",
        panel.get_node("Layout/Scroll/Content/Header/SummaryLabel").autowrap_mode,
        TextServer.AUTOWRAP_ARBITRARY)
    _check("non-truncated summary length",
        panel.get_node("Layout/Scroll/Content/Header/SummaryLabel").text.length(),
        TextLayout.visible_text(record["summary"]).length())
    _check("nav visible with two sections",
        panel.get_node("Layout/SectionNav").visible, true)
    _check("two navigable sections", panel.section_count(), 2)
    _check("section chooser count",
        panel.get_node("Layout/SectionNav/SectionChoice").item_count, 2)
    _check("section jump enabled",
        panel.get_node("Layout/SectionNav/SectionJump").disabled, false)
    _check("single vertical reader focus enabled",
        panel.get_node("Layout/Scroll").focus_mode, Control.FOCUS_ALL)
    panel.clear_profile()
    _check("clear hides navigation",
        panel.get_node("Layout/SectionNav").visible, false)
    _check("clear removes section handles", panel.section_count(), 0)

    var preview = PreviewScene.instantiate()
    root.add_child(preview)
    _check("preview fixture has three records",
        preview.get_node("Layout/Toolbar/Choice").item_count, 3)
    _check("initial placeholder selected",
        preview.preview_profile_copy()["profile_id"], "placeholder-a")
    preview._on_chosen(2)
    _check("long fixture reachable from preview",
        preview.preview_profile_copy()["profile_id"], "placeholder-long-c")
    _check("full-panel resource is dynamically inserted",
        preview.get_node_or_null("Layout/PanelHost/CharacterProfilePanel") != null, true)
    _check("fallback hidden on available panel",
        preview.get_node("Layout/PanelHost/Fallback").visible, false)
    preview._on_clear()
    _check("clear drops preview content", preview.preview_profile_copy(), {})
    preview._on_reload()
    _check("reload is deterministic",
        preview.preview_profile_copy()["profile_id"], "placeholder-a")

    preview.free()
    panel.free()
    _finish()


func _finish() -> void:
    if failures.is_empty():
        print("PASS GAME-WEB-CONTINUE-CHAR-003 r1 (%d assertions)" % checks)
        quit(0)
    else:
        for failure in failures:
            printerr("FAIL " + failure)
        printerr("FAIL GAME-WEB-CONTINUE-CHAR-003 r1 (%d/%d failed)" % [
            failures.size(), checks
        ])
        quit(1)
