extends SceneTree
## GAME-WEB-CHAR-006 r1: future-only headless checks (authored, NOT_RUN).
## This is source, not executed evidence.

const Model = preload("res://profile_flow_model_candidate.gd")
const FlowScene = preload("res://profile_flow_candidate.tscn")
const Degraded = preload("res://profile_degraded_candidate.gd")
const Contract = preload("res://profile_contract_candidate.gd")
const Loader = preload("res://placeholder_fixture_loader_candidate.gd")
const PageSamples = preload("res://synthetic_page_factory_candidate.gd")
const DemoScene = preload("res://flow_demo.tscn")

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _check(name: String, received: Variant, expected: Variant) -> void:
    _checks += 1
    if received != expected:
        _failures.append("%s: expected=%s actual=%s" % [
            name, str(expected), str(received)
        ])


func _make_profile(index: int) -> Dictionary:
    return {
        "schema_version": 1,
        "profile_id": "synthetic-%02d" % index,
        "display_name": "占位条目 %02d" % index,
        "subtitle": "测试用合成名称",
        "summary": "第一段：只为排版与分页。\r\n第二段：" + "syntheticA1".repeat(60),
        "status_label": "非正史",
        "tags": ["合成", "占位"],
        "sections": [
            {"section_id": "first", "heading": "合成片段",
                "items": [{"label": "字段甲", "value": "合成值"}]},
            {"section_id": "last", "heading": "尾部片段",
                "items": [{"label": "长字段", "value": "xY12".repeat(130)}]}
        ]
    }


func _profiles(how_many: int) -> Array:
    var result: Array = []
    for i in range(how_many):
        result.append(_make_profile(i))
    return result


func _run() -> void:
    var model = Model.new()
    _check("zero count", model.count(), 0)
    _check("empty page count minimum one", model.page_count(), 1)
    _check("empty page summaries", model.page_summaries().size(), 0)
    _check("empty pager cannot go forward", model.set_page(1), false)
    _check("empty pager cannot go back", model.set_page(-1), false)

    _check("14 synthetic records accepted", model.replace_profiles(_profiles(14))["ok"], true)
    _check("page size six", Model.PAGE_SIZE, 6)
    _check("14 records => three pages", model.page_count(), 3)
    _check("first page six records", model.page_summaries().size(), 6)
    _check("first item 00", model.page_summaries()[0]["profile_id"], "synthetic-00")
    _check("page initially one", model.page_state()["page_number"], 1)
    _check("previous disabled at first", model.page_state()["has_previous"], false)
    _check("next enabled at first", model.page_state()["has_next"], true)
    _check("negative page rejected", model.set_page(-1), false)
    _check("high page rejected", model.set_page(3), false)
    _check("move to second", model.set_page(1), true)
    _check("second page starts 06", model.page_summaries()[0]["profile_id"], "synthetic-06")
    _check("second page last 11", model.page_summaries()[5]["profile_id"], "synthetic-11")
    _check("third page accessible", model.set_page(2), true)
    _check("third page two entries", model.page_summaries().size(), 2)
    _check("third page begins 12", model.page_summaries()[0]["profile_id"], "synthetic-12")
    _check("third page next disabled", model.page_state()["has_next"], false)
    _check("selected 07 repositions page", model.open_detail("synthetic-07"), true)
    _check("selected item page index", model.page_index(), 1)
    _check("detail route", model.route(), "detail")
    _check("back retains original page", model.back_to_list(), true)
    _check("page index retained", model.page_index(), 1)
    _check("new search resets page", model.set_query("item-with-no-match"), true)
    _check("search resets page one", model.page_index(), 0)
    _check("zero results one empty page", model.page_count(), 1)
    _check("no results means no page cards", model.page_summaries().size(), 0)
    _check("clear search", model.set_query(""), true)
    _check("full collection restored", model.filtered_count(), 14)
    _check("filter by display", model.set_query("条目 13"), true)
    _check("one filtered entry", model.filtered_count(), 1)
    _check("filtered page has 13", model.page_summaries()[0]["profile_id"], "synthetic-13")
    _check("replace resets page", model.replace_profiles(_profiles(6))["ok"], true)
    _check("exact one page", model.page_count(), 1)
    _check("only six rows", model.page_summaries().size(), 6)
    _check("replacing with bad batch rejected",
        model.replace_profiles([_make_profile(0), {"broken": true}])["ok"], false)
    _check("invalid batch keeps six", model.count(), 6)

    var generated: Array[Dictionary] = PageSamples.build(14)
    _check("fourteen synthetic demo records", generated.size(), 14)
    _check("generated records conform to pinned contract", Contract.validate(generated[13])["ok"], true)
    _check("over-limit generator does not emit extras", PageSamples.build(25).is_empty(), true)

    var stub: Dictionary = Degraded.stub_profile()
    _check("fallback schema valid", Contract.validate(stub)["ok"], true)
    _check("synthetic fallback fixed ID", stub["profile_id"], Degraded.PROFILE_ID)
    _check("fallback contains no novel facts", stub["display_name"].contains("占位"), true)
    var full: String = Degraded.full_text(_make_profile(3))
    _check("full detail includes final section", full.contains("尾部片段"), true)
    _check("full detail includes long value", full.contains("xY12".repeat(130)), true)
    _check("full detail includes line breaks", full.contains("\r\n"), true)
    _check("empty fallback is clear", Degraded.full_text({}).contains("未选择"), true)

    var flow = FlowScene.instantiate()
    root.add_child(flow)
    _check("flow scene mounts", flow.is_inside_tree(), true)
    _check("new page controls exist",
        flow.get_node("Layout/Body/ListSide/Pagination/NextPageButton") is Button, true)
    _check("new fallback scroll exists",
        flow.get_node("Layout/Body/DetailSide/FallbackScroll") is ScrollContainer, true)
    _check("inject 14 via real validator", flow.set_profiles(_profiles(14)), true)
    _check("UI shows first six rows",
        flow.get_node("Layout/Body/ListSide/ListScroll/Rows").get_child_count(), 6)
    _check("first page previous disabled",
        flow.get_node("Layout/Body/ListSide/Pagination/PreviousPageButton").disabled, true)
    _check("first page next enabled",
        flow.get_node("Layout/Body/ListSide/Pagination/NextPageButton").disabled, false)
    _check("page two via UI handler", flow._change_page(1), true)
    _check("flow page becomes second", flow.route_copy()["page"]["page_number"], 2)
    _check("page two has six", flow.current_page_rows_copy().size(), 6)
    _check("page two starts 06", flow.current_page_rows_copy()[0]["profile_id"], "synthetic-06")
    _check("select 08 from second page", flow.open_profile("synthetic-08"), true)
    _check("detail ID", flow.current_profile_copy()["profile_id"], "synthetic-08")
    _check("Back from detail", flow.go_back(), true)
    _check("Back page restored", flow.route_copy()["page"]["page_number"], 2)
    _check("Back list contains origin",
        flow.get_node_or_null("Layout/Body/ListSide/ListScroll/Rows/row_synthetic-08") != null, true)
    _check("invalid page refused", flow.set_page_number(99), false)
    _check("last page selected", flow.set_page_number(3), true)
    _check("last page UI has two", flow.current_page_rows_copy().size(), 2)
    _check("last page next disabled",
        flow.get_node("Layout/Body/ListSide/Pagination/NextPageButton").disabled, true)

    _check("empty injection accepted", flow.set_profiles([]), true)
    _check("fixture fault simulated returns false",
        flow.apply_placeholder_result({"ok": false, "error": "合成模拟丢失"}), false)
    _check("one built-in degraded record", flow.route_copy()["total"], 1)
    _check("explicit fallback flag", flow.route_copy()["fixture_degraded"], true)
    _check("only built-in synthetic ID",
        flow.current_page_rows_copy()[0]["profile_id"], Degraded.PROFILE_ID)
    _check("second failure preserves fallback",
        flow.apply_placeholder_result({"ok": false, "error": "再次缺失"}), false)
    _check("fallback stays synthetic", flow.route_copy()["fixture_degraded"], true)
    _check("recover with strictly synthetic injected source",
        flow.apply_placeholder_result({"ok": true, "data": _profiles(3)}), true)
    _check("recovered data count", flow.route_copy()["total"], 3)
    _check("fallback flag resets on recovery", flow.route_copy()["fixture_degraded"], false)
    _check("open first recovered detail", flow.open_profile("synthetic-00"), true)
    flow._show_degraded_detail(flow.current_profile_copy(), "模拟场景缺失")
    _check("simulated degraded detail flagged", flow.route_copy()["detail_degraded"], true)
    _check("degraded full text available",
        flow.get_node("Layout/Body/DetailSide/FallbackScroll/FullText").text.contains("尾部片段"), true)
    _check("retry visible during degradation",
        flow.get_node("Layout/Body/DetailSide/RetryButton").visible, true)
    _check("back from degraded detail", flow.go_back(), true)
    _check("Back still reaches list", flow.route_copy()["route"], "list")
    flow.free()

    var demo = DemoScene.instantiate()
    root.add_child(demo)
    _check("demo synthetic page button exists",
        demo.get_node("Toolbar/PageSamplesButton") is Button, true)
    _check("demo fixed Flow has loaded",
        demo.get_node_or_null("Host/Flow") != null, true)
    demo._on_page_samples()
    var mounted = demo.get_node_or_null("Host/Flow")
    if mounted != null:
        _check("explicit demo pagination generator loads",
            mounted.route_copy()["total"], 14)
        _check("demo pages three",
            mounted.route_copy()["page"]["page_count"], 3)
    demo.free()
    _finish()


func _finish() -> void:
    if _failures.is_empty():
        print("PASS GAME-WEB-CHAR-006 r1 (%d planned checks)" % _checks)
        quit(0)
        return
    for problem in _failures:
        printerr("FAIL " + problem)
    printerr("FAIL GAME-WEB-CHAR-006 r1 (%d/%d)" % [
        _failures.size(), _checks
    ])
    quit(1)
