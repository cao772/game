extends MarginContainer
## GAME-WEB-PLAY-CHAR-005 r1 / synthetic-only flow, NOT_RUN.
## No canon, game state, global key binding, filesystem writes, or shell calls.

signal route_changed(route_name: String, profile_id: String)
signal exit_requested
signal collection_replaced(record_count: int)
signal collection_rejected(reason: String)

const Model = preload("res://profile_flow_model_candidate.gd")
const FixtureLoader = preload("res://placeholder_fixture_loader_candidate.gd")
const PanelFactory = preload("res://preview_panel_resource_candidate.gd")
const TextLayout = preload("res://profile_text_layout_candidate.gd")
const DETAIL_SCENE_PATH := "res://character_profile_panel.tscn"
const COMPACT_BREAKPOINT := 700.0
const LIST_EXCERPT_CHARS := 150

var _model = Model.new()
var _detail: Control = null
var _rows: Dictionary = {}
var _compact := false
var _suppress_search := false
var _list_scroll_position := 0
var _return_focus_id := ""

@onready var _back: Button = $Layout/Header/BackButton
@onready var _exit: Button = $Layout/Header/ExitButton
@onready var _reload_samples: Button = $Layout/Header/ReloadSamplesButton
@onready var _status: Label = $Layout/Status
@onready var _breadcrumb: Label = $Layout/Breadcrumb
@onready var _search: LineEdit = $Layout/Search
@onready var _list_side: VBoxContainer = $Layout/Body/ListSide
@onready var _detail_side: VBoxContainer = $Layout/Body/DetailSide
@onready var _list_scroll: ScrollContainer = $Layout/Body/ListSide/ListScroll
@onready var _list: VBoxContainer = $Layout/Body/ListSide/ListScroll/Rows
@onready var _count: Label = $Layout/Body/ListSide/ResultCount
@onready var _empty_list: Label = $Layout/Body/ListSide/EmptyList
@onready var _detail_host: MarginContainer = $Layout/Body/DetailSide/DetailHost
@onready var _detail_fallback: Label = $Layout/Body/DetailSide/DetailFallback
@onready var _retry: Button = $Layout/Body/DetailSide/RetryButton


func _ready() -> void:
    _back.pressed.connect(go_back)
    _exit.pressed.connect(_request_exit)
    _reload_samples.pressed.connect(_on_reload_samples)
    _search.text_changed.connect(_on_query_changed)
    _retry.pressed.connect(_on_retry)
    resized.connect(_on_resized)
    for control in [_back, _exit, _reload_samples, _retry, _search]:
        control.focus_mode = Control.FOCUS_ALL
    _search.max_length = Model.MAX_QUERY_CHARS
    _search.placeholder_text = "搜索合成条目的名称、标签或状态"
    _search.tooltip_text = "仅筛选本地占位数据；不会查询网络"
    _back.tooltip_text = "返回占位资料列表，不退出外部页面"
    _exit.tooltip_text = "向外部容器发出退出请求，本模块不会改变其路由"
    _reload_samples.tooltip_text = "重新读取固定的合成占位文件；不会读取私密文件"
    _retry.tooltip_text = "重新加载本地详情展示场景，不会更改占位资料"
    _refresh_ui()


func _on_resized() -> void:
    _refresh_layout()


func _refresh_layout() -> void:
    _compact = size.x < COMPACT_BREAKPOINT
    var detail_active := _model.route() == "detail"
    _list_side.visible = not _compact or not detail_active
    _detail_side.visible = not _compact or detail_active
    _search.visible = not _compact or not detail_active
    $Layout/Body.add_theme_constant_override("separation", 0 if _compact else 14)
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


func _excerpt(source: String) -> String:
    var normalized: String = TextLayout.visible_text(source).replace("\n", " ")
    if normalized.length() <= LIST_EXCERPT_CHARS:
        return normalized
    return normalized.substr(0, LIST_EXCERPT_CHARS) + "…（完整内容请打开详情）"


func _support_label(text_value: String) -> Label:
    var label := Label.new()
    label.text = text_value
    label.autowrap_mode = TextLayout.wrap_mode(text_value)
    label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
    label.clip_text = false
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.add_theme_color_override("font_color", Color("#c3d4ea"))
    label.add_theme_font_size_override("font_size", 14)
    return label


func _rebuild_rows() -> void:
    _clear_rows()
    var visible: Array[Dictionary] = _model.visible_summaries()
    _count.text = "显示 %d / 共 %d 条合成占位资料" % [visible.size(), _model.count()]
    _empty_list.visible = visible.is_empty()
    _empty_list.text = "暂无占位资料" if _model.count() == 0 else "没有匹配的占位条目"
    for entry in visible:
        var identity: String = entry["profile_id"]
        var container := VBoxContainer.new()
        container.name = "row_" + identity
        container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        container.add_theme_constant_override("separation", 4)

        var button := Button.new()
        button.name = "open_" + identity
        button.text = entry["display_name"]
        if not str(entry["status_label"]).is_empty():
            button.text += "  ·  " + str(entry["status_label"])
        button.tooltip_text = str(entry["display_name"]) + "\n" + str(entry["subtitle"])
        if _has_property(button, "accessibility_name"):
            button.set("accessibility_name", "打开资料：" + str(entry["display_name"]))
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.focus_mode = Control.FOCUS_ALL
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.custom_minimum_size.y = 44
        button.pressed.connect(_on_record_pressed.bind(identity))
        container.add_child(button)

        if not str(entry["subtitle"]).is_empty():
            container.add_child(_support_label(_excerpt(str(entry["subtitle"]))))
        var tags: Array = entry["tags"]
        if not tags.is_empty():
            var tag_words := PackedStringArray()
            for tag in tags:
                tag_words.append(str(tag))
            container.add_child(_support_label("标签：" + " / ".join(tag_words)))
        if not str(entry["summary"]).is_empty():
            container.add_child(_support_label(_excerpt(str(entry["summary"]))))
        _list.add_child(container)
        _rows[identity] = button


func _has_property(value: Object, key: String) -> bool:
    for property in value.get_property_list():
        if str(property.get("name", "")) == key:
            return true
    return false


func _forget_detail_instance() -> void:
    if _detail != null and is_instance_valid(_detail):
        if _detail.get_parent() != null:
            _detail.get_parent().remove_child(_detail)
        _detail.queue_free()
    _detail = null


func _ensure_detail_panel() -> bool:
    if _detail != null and is_instance_valid(_detail) and _detail.is_inside_tree():
        return true
    _detail = null
    if not ResourceLoader.exists(DETAIL_SCENE_PATH, "PackedScene"):
        _detail_fallback.text = "占位资料展示面板资源缺失；列表和返回仍可使用。"
        return false
    var resource: Resource = ResourceLoader.load(
        DETAIL_SCENE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE
    )
    var built: Dictionary = PanelFactory.instantiate_panel(resource)
    if not built["ok"]:
        _detail_fallback.text = "占位资料展示面板不可用；可以重试本地资源。"
        return false
    _detail = built["node"] as Control
    _detail.name = "DetailPanel"
    _detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _detail_host.add_child(_detail)
    return true


func _render_detail() -> bool:
    var profile: Dictionary = _model.selected_profile_copy()
    if profile.is_empty():
        _detail_host.visible = false
        _detail_fallback.visible = true
        _detail_fallback.text = "从列表选择一条合成占位资料"
        _retry.visible = false
        if _detail != null and is_instance_valid(_detail):
            _detail.hide()
        return true
    if not _ensure_detail_panel():
        _detail_host.visible = false
        _detail_fallback.visible = true
        _retry.visible = true
        _message("详情资源不可用；请返回列表或尝试重新加载", true)
        return false
    var accepted: bool = _detail.call("set_profile", profile)
    if not accepted:
        _detail_host.visible = false
        _detail_fallback.text = "资料展示组件拒绝本条占位记录。"
        _detail_fallback.visible = true
        _retry.visible = true
        _detail.hide()
        _message("详情未加载；原始占位记录未被修改", true)
        return false
    _detail_host.visible = true
    _detail.show()
    _detail_fallback.visible = false
    _retry.visible = false
    return true


func _refresh_ui() -> void:
    if not is_node_ready():
        return
    _rebuild_rows()
    _refresh_layout()
    var in_detail := _model.route() == "detail"
    _back.disabled = not in_detail
    _breadcrumb.text = "占位资料 / 详情" if in_detail else "占位资料 / 列表"
    _render_detail()


func set_profiles(source: Variant) -> bool:
    var result: Dictionary = _model.replace_profiles(source)
    if not result["ok"]:
        if is_node_ready():
            _message("拒绝无效资料；已保留上次有效列表：" + str(result["error"]), true)
        collection_rejected.emit(str(result["error"]))
        return false
    _return_focus_id = ""
    _list_scroll_position = 0
    if is_node_ready():
        _suppress_search = true
        _search.text = ""
        _suppress_search = false
        _message("占位资料已完整替换，可从列表查看详情")
        _refresh_ui()
        _list_scroll.scroll_vertical = 0
    collection_replaced.emit(_model.count())
    route_changed.emit("list", "")
    return true


func load_placeholder_profiles() -> bool:
    # Fixed, synthetic-only path; failure preserves the last valid injection.
    var result: Dictionary = FixtureLoader.read_known_fixture()
    if not result["ok"]:
        if is_node_ready():
            _message("占位资源读取失败；已保留原有列表：" + str(result["error"]), true)
        collection_rejected.emit(str(result["error"]))
        return false
    return set_profiles(result["data"])


func _on_reload_samples() -> void:
    load_placeholder_profiles()


func _on_query_changed(value: String) -> void:
    if _suppress_search:
        return
    if not _model.set_query(value):
        _message("搜索长度超过候选限制", true)
        return
    _return_focus_id = ""
    _list_scroll_position = 0
    _message("占位资料筛选仅在当前有效列表中进行")
    _refresh_ui()
    route_changed.emit("list", "")


func _on_record_pressed(identity: String) -> void:
    open_profile(identity)


func open_profile(identity: String) -> bool:
    if not _model.open_detail(identity):
        return false
    if is_node_ready():
        _return_focus_id = identity
        _list_scroll_position = _list_scroll.scroll_vertical
        _message("正在浏览完整的合成占位资料")
        _refresh_ui()
        if _back.visible and not _back.disabled:
            _back.grab_focus()
    route_changed.emit("detail", identity)
    return true


func go_back() -> bool:
    if not _model.back_to_list():
        return false
    if is_node_ready():
        _message("已返回占位资料列表")
        _refresh_ui()
        _list_scroll.set_deferred("scroll_vertical", _list_scroll_position)
        var target: Control = _search
        if _rows.has(_return_focus_id):
            target = _rows[_return_focus_id]
        target.grab_focus()
    route_changed.emit("list", "")
    return true


func _request_exit() -> void:
    exit_requested.emit()


func _on_retry() -> void:
    if _model.route() != "detail":
        return
    _forget_detail_instance()
    if _render_detail():
        _message("详情展示组件已重新加载；仍仅使用占位数据")


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
