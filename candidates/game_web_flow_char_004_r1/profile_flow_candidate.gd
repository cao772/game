extends MarginContainer
## GAME-WEB-FLOW-CHAR-004 r1. Isolated Control with synthetic-only entrypoint.
## Does not call the independent shell, shared input router or any save API.

signal route_changed(route_name: String, profile_id: String)
signal exit_requested
signal collection_replaced(record_count: int)
signal collection_rejected(reason: String)

const Model = preload("res://profile_flow_model_candidate.gd")
const FixtureLoader = preload("res://placeholder_fixture_loader_candidate.gd")
const PanelFactory = preload("res://preview_panel_resource_candidate.gd")
const DETAIL_SCENE_PATH := "res://character_profile_panel.tscn"
const COMPACT_BREAKPOINT := 700.0

var _model = Model.new()
var _detail: Control = null
var _rows: Dictionary = {}
var _compact: bool = false
var _busy: bool = false

@onready var _back: Button = $Layout/Header/BackButton
@onready var _exit: Button = $Layout/Header/ExitButton
@onready var _status: Label = $Layout/Status
@onready var _search: LineEdit = $Layout/Search
@onready var _list_side: VBoxContainer = $Layout/Body/ListSide
@onready var _detail_side: VBoxContainer = $Layout/Body/DetailSide
@onready var _list: VBoxContainer = $Layout/Body/ListSide/ListScroll/Rows
@onready var _count: Label = $Layout/Body/ListSide/ResultCount
@onready var _empty_list: Label = $Layout/Body/ListSide/EmptyList
@onready var _detail_host: MarginContainer = $Layout/Body/DetailSide/DetailHost
@onready var _detail_fallback: Label = $Layout/Body/DetailSide/DetailFallback
@onready var _retry: Button = $Layout/Body/DetailSide/RetryButton


func _ready() -> void:
    _back.pressed.connect(go_back)
    _exit.pressed.connect(_request_exit)
    _search.text_changed.connect(_on_query_changed)
    _retry.pressed.connect(_on_retry)
    resized.connect(_on_resized)
    _back.focus_mode = Control.FOCUS_ALL
    _exit.focus_mode = Control.FOCUS_ALL
    _retry.focus_mode = Control.FOCUS_ALL
    _search.focus_mode = Control.FOCUS_ALL
    _search.max_length = Model.MAX_QUERY_CHARS
    _search.placeholder_text = "搜索占位条目的名称、标签或状态"
    _search.tooltip_text = "输入过滤列表；不会查询网络或修改角色资料"
    _back.tooltip_text = "从详情返回列表"
    _exit.tooltip_text = "通知外部容器退出；本模块不会控制外部界面"
    _retry.tooltip_text = "仅尝试重新装入固定的本地资料展示面板"
    _refresh_ui()


func _on_resized() -> void:
    _refresh_layout()


func _refresh_layout() -> void:
    _compact = size.x < COMPACT_BREAKPOINT
    var route_name: String = _model.route()
    _list_side.visible = not _compact or route_name == "list"
    _detail_side.visible = not _compact or route_name == "detail"
    if _compact:
        $Layout/Body.add_theme_constant_override("separation", 0)
    else:
        $Layout/Body.add_theme_constant_override("separation", 14)
    var margin := 8 if _compact else 18
    for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
        add_theme_constant_override(side, margin)


func _message(value: String, is_error: bool = false) -> void:
    _status.text = value
    _status.add_theme_color_override(
        "font_color", Color("#ffcece") if is_error else Color("#c9dffa")
    )
    _status.tooltip_text = value


func _clear_rows() -> void:
    for child in _list.get_children():
        _list.remove_child(child)
        child.queue_free()
    _rows.clear()


func _rebuild_rows() -> void:
    _clear_rows()
    var visible: Array[Dictionary] = _model.visible_summaries()
    _count.text = "显示 %d / 共 %d 条合成占位资料" % [visible.size(), _model.count()]
    _empty_list.visible = visible.is_empty()
    _empty_list.text = "无占位记录" if _model.count() == 0 else "没有匹配的占位条目"
    for entry in visible:
        var identity: String = entry["profile_id"]
        var button := Button.new()
        button.name = "record_" + identity
        button.text = entry["display_name"]
        if not str(entry["status_label"]).is_empty():
            button.text += "  ·  " + str(entry["status_label"])
        button.tooltip_text = str(entry["display_name"]) + "\n" + str(entry["subtitle"])
        for property in button.get_property_list():
            if str(property.get("name", "")) == "accessibility_name":
                button.set("accessibility_name", str(entry["display_name"]))
                break
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.focus_mode = Control.FOCUS_ALL
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.custom_minimum_size.y = 44
        button.pressed.connect(_on_record_pressed.bind(identity))
        _list.add_child(button)
        _rows[identity] = button


func _ensure_detail_panel() -> bool:
    if _detail != null and is_instance_valid(_detail) and _detail.is_inside_tree():
        return true
    _detail = null
    if not ResourceLoader.exists(DETAIL_SCENE_PATH, "PackedScene"):
        _detail_fallback.text = "占位资料展示面板缺失。可尝试重载。"
        return false
    var resource: Resource = ResourceLoader.load(
        DETAIL_SCENE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE
    )
    var built: Dictionary = PanelFactory.instantiate_panel(resource)
    if not built["ok"]:
        _detail_fallback.text = "占位资料展示面板不可用。可尝试重载。"
        return false
    _detail = built["node"] as Control
    _detail.name = "DetailPanel"
    _detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _detail_host.add_child(_detail)
    return true


func _render_detail() -> void:
    var profile: Dictionary = _model.selected_profile_copy()
    if profile.is_empty():
        _detail_host.visible = false
        _detail_fallback.visible = true
        _detail_fallback.text = "从列表选择一条合成占位资料"
        _retry.visible = false
        if _detail != null and is_instance_valid(_detail):
            _detail.hide()
        return
    if not _ensure_detail_panel():
        _detail_host.visible = false
        _detail_fallback.visible = true
        _retry.visible = true
        _message("资料面板资源未就绪；列表与返回仍可使用", true)
        return
    var accepted: bool = _detail.call("set_profile", profile)
    if not accepted:
        _detail_host.visible = false
        _detail_fallback.text = "占位详情校验失败，未显示无效资料。"
        _detail_fallback.visible = true
        _retry.visible = false
        _detail.hide()
        _message("显示组件拒绝占位记录", true)
        return
    _detail_host.visible = true
    _detail.show()
    _detail_fallback.visible = false
    _retry.visible = false


func _refresh_ui() -> void:
    if not is_node_ready():
        return
    _rebuild_rows()
    _refresh_layout()
    _back.disabled = _model.route() != "detail"
    _render_detail()


func set_profiles(source: Variant) -> bool:
    if _busy:
        return false
    var result: Dictionary = _model.replace_profiles(source)
    if not result["ok"]:
        if is_node_ready():
            _message(result["error"], true)
        collection_rejected.emit(result["error"])
        return false
    if is_node_ready():
        _search.text = ""
        _message("占位资料已替换；尚未选择详情")
        _refresh_ui()
    collection_replaced.emit(_model.count())
    route_changed.emit("list", "")
    return true


func load_placeholder_profiles() -> bool:
    # Only loads the pinned synthetic fixture, never arbitrary paths.
    var read_result: Dictionary = FixtureLoader.read_known_fixture()
    if not read_result["ok"]:
        if is_node_ready():
            _message("占位资料加载失败：" + str(read_result["error"]), true)
        collection_rejected.emit(str(read_result["error"]))
        return false
    return set_profiles(read_result["data"])


func _on_query_changed(text_value: String) -> void:
    if not _model.set_query(text_value):
        _message("搜索文本超过长度限制", true)
        return
    _message("列表筛选仅在本地占位资料中执行")
    _refresh_ui()
    route_changed.emit("list", "")


func _on_record_pressed(identity: String) -> void:
    open_profile(identity)


func open_profile(identity: String) -> bool:
    if not _model.open_detail(identity):
        return false
    _refresh_ui()
    if is_node_ready():
        _message("正在查看合成占位详情")
        _back.grab_focus()
    route_changed.emit("detail", identity)
    return true


func go_back() -> bool:
    if not _model.back_to_list():
        return false
    _refresh_ui()
    if is_node_ready():
        _message("已返回占位资料列表")
    route_changed.emit("list", "")
    # Restore focus to search/list rather than stealing focus from the host.
    var first: Control = _search
    if is_node_ready():
        first.grab_focus()
    return true


func _request_exit() -> void:
    exit_requested.emit()


func _on_retry() -> void:
    _render_detail()


func route_copy() -> Dictionary:
    return {
        "route": _model.route(),
        "selected_id": _model.selected_id(),
        "query": _model.query(),
        "total": _model.count()
    }


func current_profile_copy() -> Dictionary:
    return _model.selected_profile_copy()


func visible_rows_copy() -> Array[Dictionary]:
    return _model.summaries_copy()
