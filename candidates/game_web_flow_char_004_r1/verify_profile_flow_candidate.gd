extends SceneTree
## GAME-WEB-FLOW-CHAR-004 r1 future-only acceptance code. NOT_RUN.
## No test was executed when this source was authored/submitted.

const Model = preload("res://profile_flow_model_candidate.gd")
const Contract = preload("res://profile_contract_candidate.gd")
const Loader = preload("res://placeholder_fixture_loader_candidate.gd")
const Flow = preload("res://profile_flow_candidate.tscn")
const ShellAdapter = preload("res://shell_profile_adapter_candidate.gd")

var failures: Array[String] = []
var assertions: int = 0
var routed: Array[String] = []
var exits: int = 0


func _initialize() -> void:
    call_deferred("_run")


func _assert_case(label: String, actual: Variant, expected: Variant) -> void:
    assertions += 1
    if actual != expected:
        failures.append("%s | actual=%s expected=%s" % [
            label, str(actual), str(expected)
        ])


func _fixture(identity: String, label_value: String = "占位 A") -> Dictionary:
    return {
        "schema_version": 1,
        "profile_id": identity,
        "display_name": label_value,
        "subtitle": "纯合成测试",
        "summary": "一段合成占位描述。",
        "status_label": "待校验",
        "tags": ["合成", "示例"],
        "sections": [{
            "section_id": "a",
            "heading": "资料片段",
            "items": [{"label": "字段", "value": "合成值"}]
        }]
    }


func _on_route(name: String, identity: String) -> void:
    routed.append(name + ":" + identity)


func _on_exit() -> void:
    exits += 1


func _run() -> void:
    var model = Model.new()
    _assert_case("start list", model.route(), "list")
    _assert_case("start empty", model.count(), 0)
    _assert_case("invalid scalar rejected", model.replace_profiles(null)["ok"], false)
    var a := _fixture("synthetic-a")
    var b := _fixture("synthetic-b", "占位 B")
    _assert_case("valid collection accepted", model.replace_profiles([a, b])["ok"], true)
    _assert_case("two records", model.count(), 2)
    a["display_name"] = "caller edited"
    _assert_case("copy protects source", model.visible_summaries()[0]["display_name"], "占位 A")

    var invalid: Array = [_fixture("synthetic-a"), {"bad": "record"}]
    _assert_case("invalid batch rejected", model.replace_profiles(invalid)["ok"], false)
    _assert_case("invalid batch leaves old records", model.count(), 2)
    _assert_case("duplicate IDs rejected",
        model.replace_profiles([_fixture("x"), _fixture("x")])["ok"], false)
    _assert_case("duplicate rejection preserves existing", model.count(), 2)

    _assert_case("unknown profile refused", model.open_detail("unknown"), false)
    _assert_case("valid id opens", model.open_detail("synthetic-a"), true)
    _assert_case("detail route", model.route(), "detail")
    var returned: Dictionary = model.selected_profile_copy()
    returned["display_name"] = "mutated getter"
    _assert_case("getter copy isolated", model.selected_profile_copy()["display_name"], "占位 A")
    _assert_case("back accepted", model.back_to_list(), true)
    _assert_case("back route", model.route(), "list")
    _assert_case("extra back refused", model.back_to_list(), false)

    _assert_case("query accepted", model.set_query("占位 b"), true)
    _assert_case("case-insensitive filter", model.visible_summaries().size(), 1)
    _assert_case("hidden id not openable", model.open_detail("synthetic-a"), false)
    _assert_case("matching id opens", model.open_detail("synthetic-b"), true)
    _assert_case("search changed resets detail", model.set_query("合成"), true)
    _assert_case("route resets to list", model.route(), "list")
    _assert_case("too-long query rejected",
        model.set_query("x".repeat(Model.MAX_QUERY_CHARS + 1)), false)
    _assert_case("query unchanged on rejection", model.query(), "合成")
    _assert_case("empty replacement accepted", model.replace_profiles([])["ok"], true)
    _assert_case("zero-profile list", model.visible_summaries().size(), 0)

    var raw := Loader.read_known_fixture()
    _assert_case("PR14 pinned fixture readable", raw["ok"], true)
    if raw["ok"]:
        _assert_case("three synthetic fixtures", raw["data"].size(), 3)
    _assert_case("malformed JSON rejected", Loader.parse_text("not json")["ok"], false)

    var adapter = ShellAdapter.new()
    var sample: Dictionary = adapter.preview()
    _assert_case("shell synthetic preview OK", sample.get("ok"), true)
    _assert_case("shell title bounded", str(sample.get("title", "")).length() <= 100, true)
    _assert_case("shell body bounded", str(sample.get("body", "")).length() <= 1800, true)
    var action: Dictionary = adapter.preview_action("sample_request")
    _assert_case("shell simulated request", action.get("simulated"), true)
    _assert_case("shell accepts sample", action.get("ok"), true)
    _assert_case("shell rejects other requests",
        adapter.preview_action("open_detail")["ok"], false)

    var view = Flow.instantiate()
    root.add_child(view)
    view.route_changed.connect(_on_route)
    view.exit_requested.connect(_on_exit)
    _assert_case("empty view list", view.route_copy()["route"], "list")
    _assert_case("flow input accepted", view.set_profiles([_fixture("synthetic-a"), _fixture("synthetic-b", "占位 B")]), true)
    _assert_case("list rows", view.visible_rows_copy().size(), 2)
    _assert_case("row widgets created",
        view.get_node("Layout/Body/ListSide/ListScroll/Rows").get_child_count(), 2)

    _assert_case("open detail", view.open_profile("synthetic-b"), true)
    _assert_case("selected id", view.route_copy()["selected_id"], "synthetic-b")
    _assert_case("details contain exact data", view.current_profile_copy()["display_name"], "占位 B")
    _assert_case("detail component attached",
        view.get_node_or_null("Layout/Body/DetailSide/DetailHost/DetailPanel") != null, true)
    _assert_case("back button enabled",
        view.get_node("Layout/Header/BackButton").disabled, false)
    view.get_node("Layout/Header/BackButton").pressed.emit()
    _assert_case("back returns list", view.route_copy()["route"], "list")
    _assert_case("invalid id no mutation", view.open_profile("missing"), false)
    _assert_case("list stays", view.route_copy()["route"], "list")

    _assert_case("open again", view.open_profile("synthetic-a"), true)
    view._on_query_changed("占位 B")
    _assert_case("filter returns list", view.route_copy()["route"], "list")
    _assert_case("filtered rows visible", view.visible_rows_copy().size(), 1)
    _assert_case("filtered list regenerated",
        view.get_node("Layout/Body/ListSide/ListScroll/Rows").get_child_count(), 1)
    _assert_case("switch rejected with invalid batch",
        view.set_profiles([_fixture("x"), _fixture("x")]), false)
    _assert_case("invalid injection keeps valid set", view.route_copy()["total"], 2)

    view.get_node("Layout/Header/ExitButton").pressed.emit()
    _assert_case("exit emits once", exits, 1)
    _assert_case("exit signal does not exit SceneTree", view.is_inside_tree(), true)
    _assert_case("route signals emitted", routed.size() >= 3, true)
    view.free()

    _finish()


func _finish() -> void:
    if failures.is_empty():
        print("PASS GAME-WEB-FLOW-CHAR-004 r1 (%d checks)" % assertions)
        quit(0)
        return
    for failure in failures:
        printerr("FAIL " + failure)
    printerr("FAIL GAME-WEB-FLOW-CHAR-004 r1 (%d/%d failed)" % [
        failures.size(), assertions
    ])
    quit(1)
