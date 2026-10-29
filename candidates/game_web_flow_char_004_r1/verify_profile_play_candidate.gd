extends SceneTree
## GAME-WEB-PLAY-CHAR-005 r1: author-provided future-only checks, NOT_RUN.
## A future verifier must record the engine's real outcome and exit status.

const Model = preload("res://profile_flow_model_candidate.gd")
const FlowScene = preload("res://profile_flow_candidate.tscn")
const DemoScene = preload("res://flow_demo.tscn")
const FixtureLoader = preload("res://placeholder_fixture_loader_candidate.gd")
const TextLayout = preload("res://profile_text_layout_candidate.gd")
const PanelFactory = preload("res://preview_panel_resource_candidate.gd")

var _checks: int = 0
var _failures: Array[String] = []
var _routes: Array[String] = []
var _rejections: int = 0
var _exits: int = 0


func _initialize() -> void:
    call_deferred("_run")


func _expect(label: String, received: Variant, expected: Variant) -> void:
    _checks += 1
    if received != expected:
        _failures.append("%s got=%s expected=%s" % [
            label, str(received), str(expected)
        ])


func _sample(identity: String) -> Dictionary:
    return {
        "schema_version": 1, "profile_id": identity,
        "display_name": "合成占位-" + identity,
        "subtitle": "A synthetic subtitle",
        "summary": "第一段。\r\n第二段：" + "LongText0123456789".repeat(35),
        "status_label": "纯占位",
        "tags": ["合成", "演示"],
        "sections": [
            {"section_id": "a", "heading": "合成章节",
             "items": [{"label": "字段", "value": "Test " + "qW09".repeat(65)}]}
        ]
    }


func _record_route(name: String, identity: String) -> void:
    _routes.append(name + ":" + identity)


func _record_rejected(_reason: String) -> void:
    _rejections += 1


func _record_exit() -> void:
    _exits += 1


func _run() -> void:
    var model = Model.new()
    var entries: Array = []
    for index in range(Model.MAX_PROFILES):
        entries.append(_sample("item-%02d" % index))
    _expect("24 bounded records accepted", model.replace_profiles(entries)["ok"], true)
    _expect("24 count correct", model.count(), Model.MAX_PROFILES)
    entries.append(_sample("overflow"))
    _expect("25 records rejected", model.replace_profiles(entries)["ok"], false)
    _expect("failed load retains 24", model.count(), Model.MAX_PROFILES)
    _expect("full summaries in list data",
        model.visible_summaries()[0]["summary"].length() > 100, true)
    _expect("search matching tags", model.set_query("演示"), true)
    _expect("tag filter returns all 24", model.visible_summaries().size(), 24)
    _expect("select existing profile", model.open_detail("item-12"), true)
    _expect("route detail", model.route(), "detail")
    _expect("change filter accepted", model.set_query("item-01"), true)
    _expect("filter change returns list", model.route(), "list")
    _expect("filtered list contains one record", model.visible_summaries().size(), 1)
    _expect("filtered-out detail refused", model.open_detail("item-12"), false)
    _expect("clear filter", model.set_query(""), true)
    _expect("empty replace", model.replace_profiles([])["ok"], true)
    _expect("empty list state", model.count(), 0)

    var fixture: Dictionary = FixtureLoader.read_known_fixture()
    _expect("fixed synthetic fixture readable", fixture["ok"], true)
    if fixture["ok"]:
        _expect("three official synthetic samples", fixture["data"].size(), 3)
        _expect("long placeholder has sections",
            fixture["data"][2]["sections"].size() >= 3, true)
    _expect("invalid UTF8 fails closed",
        FixtureLoader.parse_bytes(PackedByteArray([255, 254]))["ok"], false)
    _expect("null PackedScene rejected",
        PanelFactory.instantiate_panel(null)["ok"], false)
    _expect("not a PackedScene rejected",
        PanelFactory.instantiate_panel(Resource.new())["ok"], false)
    _expect("literal markup stays a plain value",
        TextLayout.visible_text("[b]文字[/b]"), "[b]文字[/b]")

    var view = FlowScene.instantiate()
    view.route_changed.connect(_record_route)
    view.collection_rejected.connect(_record_rejected)
    view.exit_requested.connect(_record_exit)
    root.add_child(view)
    _expect("starts on list", view.route_copy()["route"], "list")
    _expect("header wraps controls",
        view.get_node("Layout/Header") is HFlowContainer, true)
    _expect("reload control exists",
        view.get_node("Layout/Header/ReloadSamplesButton") is Button, true)
    _expect("breadcrumb identifies list",
        view.get_node("Layout/Breadcrumb").text.contains("列表"), true)
    _expect("fixed synthetic load accepted", view.load_placeholder_profiles(), true)
    _expect("three list buttons/rows",
        view.get_node("Layout/Body/ListSide/ListScroll/Rows").get_child_count(), 3)
    _expect("public rows carry summary preview source",
        view.visible_rows_copy()[2].has("summary"), true)
    _expect("long fixture opens", view.open_profile("placeholder-long-c"), true)
    _expect("detail ID correct",
        view.current_profile_copy()["profile_id"], "placeholder-long-c")
    _expect("breadcrumb identifies detail",
        view.get_node("Layout/Breadcrumb").text.contains("详情"), true)
    _expect("back now enabled",
        view.get_node("Layout/Header/BackButton").disabled, false)
    _expect("detail panel attached",
        view.get_node_or_null("Layout/Body/DetailSide/DetailHost/DetailPanel") != null,
        true)
    _expect("detail panel visible",
        view.get_node("Layout/Body/DetailSide/DetailHost").visible, true)
    _expect("selected source preserved, full summary",
        view.current_profile_copy()["summary"].length() > 400, true)

    _expect("back works", view.go_back(), true)
    _expect("returns to list", view.route_copy()["route"], "list")
    _expect("breadcrumb returns to list",
        view.get_node("Layout/Breadcrumb").text.contains("列表"), true)
    _expect("origin row restored in row dictionary",
        view.get_node_or_null(
            "Layout/Body/ListSide/ListScroll/Rows/row_placeholder-long-c"
        ) != null, true)
    _expect("second Back is no-op", view.go_back(), false)
    _expect("unknown detail refuses", view.open_profile("missing"), false)

    var previous_total: int = view.route_copy()["total"]
    _expect("invalid duplicate set rejected",
        view.set_profiles([_sample("a"), _sample("a")]), false)
    _expect("invalid set retains all rows",
        view.route_copy()["total"], previous_total)
    _expect("rejection signal emitted", _rejections >= 1, true)

    _expect("query literal", view.get_node("Layout/Search") is LineEdit, true)
    view._on_query_changed("占位条目 B")
    _expect("filter selects one", view.visible_rows_copy().size(), 1)
    _expect("query reset after reload",
        view.load_placeholder_profiles(), true)
    _expect("filter reset", view.route_copy()["query"], "")

    view.size = Vector2(400, 300)
    view._on_resized()
    _expect("compact list visible",
        view.get_node("Layout/Body/ListSide").visible, true)
    _expect("compact detail hidden",
        view.get_node("Layout/Body/DetailSide").visible, false)
    _expect("open on narrow", view.open_profile("placeholder-a"), true)
    _expect("narrow detail visible",
        view.get_node("Layout/Body/DetailSide").visible, true)
    _expect("narrow search hidden",
        view.get_node("Layout/Search").visible, false)
    _expect("narrow back", view.go_back(), true)
    _expect("narrow search restored",
        view.get_node("Layout/Search").visible, true)
    view.size = Vector2(1060, 720)
    view._on_resized()
    _expect("wide list visible",
        view.get_node("Layout/Body/ListSide").visible, true)
    _expect("wide detail visible",
        view.get_node("Layout/Body/DetailSide").visible, true)

    view._on_retry()
    _expect("retry while list is a harmless no-op",
        view.route_copy()["route"], "list")
    view.get_node("Layout/Header/ExitButton").pressed.emit()
    _expect("exit signal once", _exits, 1)
    _expect("exit does not free component", view.is_inside_tree(), true)
    _expect("route signals present", _routes.size() >= 4, true)

    var demo = DemoScene.instantiate()
    root.add_child(demo)
    _expect("demo toolbar retry exists",
        demo.get_node("Toolbar/RetryFlow") is Button, true)
    _expect("demo flow dynamic mount",
        demo.get_node_or_null("Host/Flow") != null, true)
    _expect("demo flow mounted once", demo.get_node("Host").get_child_count(), 2)
    _expect("demo flow reload is explicit", demo.reload_flow(), true)
    _expect("demo flow reload no double nodes",
        demo.get_node("Host").get_child_count(), 2)
    demo._on_exit_requested()
    _expect("demo exit is informational",
        demo.get_node("ExitNotice").visible, true)
    demo.free()

    view.free()
    _finish()


func _finish() -> void:
    if _failures.is_empty():
        print("PASS GAME-WEB-PLAY-CHAR-005 r1 (%d checks)" % _checks)
        quit(0)
        return
    for failure in _failures:
        printerr("FAIL " + failure)
    printerr("FAIL GAME-WEB-PLAY-CHAR-005 r1 (%d/%d)" % [
        _failures.size(), _checks
    ])
    quit(1)
