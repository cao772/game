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
const Degraded = preload("res://profile_degraded_candidate.gd")
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
var _page_focus: Dictionary = {}
var _fixture_degraded := false
var _detail_degraded := false

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
@onready var _previous: Button = $Layout/Body/ListSide/Pagination/PreviousPageButton
@onready var _next: Button = $Layout/Body/ListSide/Pagination/NextPageButton
@onready var _page_label: Label = $Layout/Body/ListSide/Pagination/PageLabel
@onready var _empty_list: Label = $Layout/Body/ListSide/EmptyList
@onready var _detail_host: MarginContainer = $Layout/Body/DetailSide/DetailHost
@onready var _detail_fallback: Label = $Layout/Body/DetailSide/DetailFallback
@onready var _retry: Button = $Layout/Body/DetailSide/RetryButton
@onready var _fallback_scroll: ScrollContainer = $Layout/Body/DetailSide/FallbackScroll
@onready var _fallback_text: Label = $Layout/Body/DetailSide/FallbackScroll/FullText


func _ready() -> void:
    _back.pressed.connect(go_back)
    _exit.pressed.connect(_request_exit)
    _reload_samples.pressed.connect(_on_reload_samples)
    _search.text_changed.connect(_on_query_changed)
    _retry.pressed.connect(_on_retry)
    _previous.pressed.connect(_on_previous_page)
    _next.pressed.connect(_on_next_page)
    resized.connect(_on_resized)
    for control in [_back, _exit, _reload_samples, _retry, _search, _previous, _next]:
        control.focus_mode = Control.FOCUS_ALL
    _search.max_length = Model.MAX_QUERY_CHARS
    _search.placeholder_text = "搜索合成条目的名称、标签或状态"
    _search.tooltip_text = "仅筛选本地占位数据；不会查询网络"
    _back.tooltip_text = "返回占位资料列表，不退出外部页面"
    _exit.tooltip_text = "向外部容器发出退出请求，本模块不会改变其路由"
    _reload_samples.tooltip_text = "重新读取固定的合成占位文件；不会读取私密文件"
    _retry.tooltip_text = "重新加载本地详情展示场景，不会更改占位资料"
    _previous.tooltip_text = "查看上一页合成资料"
    _next.tooltip_text = "查看下一页合成资料"
    _fallback_scroll.focus_mode = Control.FOCUS_ALL
    _fallback_scroll.tooltip_text = "降级全文阅读区；可使用键盘或鼠标滚动"
    _fallback_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _fallback_text.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
    _fallback_text.clip_text = false
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
    var visible: Array[Dictionary] = _model.page_summaries()
    var paging: Dictionary = _model.page_state()
    _count.text = "本页 %d 条 · 筛选 %d / 总计 %d" % [visible.size(), paging["filtered"], paging["total"]]
    _page_label.text = "第 %d / %d 页" % [paging["page_number"], paging["page_count"]]
    _previous.disabled = not paging["has_previous"]
    _next.disabled = not paging["has_next"]
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
        button.focus_entered.connect(_on_record_focused.bind(identity))
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


func _on_record_focused(identity: String) -> void:
    _page_focus[str(_model.page_index())] = identity


func _change_page(direction: int) -> bool:
    if _model.route() != "list":
        return false
    var destination := _model.page_index() + direction
    if not _model.set_page(destination):
        return false
    _list_scroll_position = 0
    _return_focus_id = ""
    _refresh_ui()
    call_deferred("_restore_list_focus", str(_page_focus.get(str(destination), "")),
        destination, 0)
    return true


func _on_previous_page() -> void:
    _change_page(-1)


func _on_next_page() -> void:
    _change_page(1)


func _restore_list_focus(identity: String, page_index: int, position: int) -> void:
    if not is_node_ready() or _model.route() != "list":
        return
    if _model.page_index() != page_index:
        return
    var control: Control = _search
    if _rows.has(identity) and is_instance_valid(_rows[identity]):
        control = _rows[identity]
    elif not _rows.is_empty():
        var first_key: String = str(_rows.keys()[0])
        control = _rows[first_key]
    if control.visible and control.is_inside_tree():
        control.grab_focus()
    _list_scroll.scroll_vertical = position


func _show_degraded_detail(profile: Dictionary, reason: String) -> void:
    _detail_degraded = true
    _detail_host.visible = false
    if _detail != null and is_instance_valid(_detail):
        _detail.hide()
    _detail_fallback.text = reason + "；下方仍可查看完整只读文本。"
    _detail_fallback.visible = true
    _fallback_text.text = TextLayout.visible_text(Degraded.full_text(profile))
    _fallback_text.autowrap_mode = TextLayout.wrap_mode(_fallback_text.text)
    _fallback_scroll.visible = true
    _fallback_scroll.scroll_vertical = 0
    _retry.visible = true


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
        _fallback_scroll.visible = false
        _detail_degraded = false
        if _detail != null and is_instance_valid(_detail):
            _detail.hide()
        return true
    if not _ensure_detail_panel():
        _show_degraded_detail(profile, "原资料面板资源缺失或无效")
        _message("当前为完整只读降级详情，可重试原组件", true)
        return false
    var accepted: bool = _detail.call("set_profile", profile)
    if not accepted:
        _show_degraded_detail(profile, "原资料面板拒绝占位资料")
        _message("当前为完整只读降级详情；原始资料未修改", true)
        return false
    _detail_host.visible = true
    _detail_degraded = false
    _detail.show()
    _fallback_scroll.visible = false
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
    _page_focus.clear()
    _fixture_degraded = false
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
    return apply_placeholder_result(FixtureLoader.read_known_fixture())


func apply_placeholder_result(result: Dictionary) -> bool:
    # Deterministic future fault-injection seam; never accepts file paths.
    if result.get("ok", false) == true and result.has("data"):
        return set_profiles(result["data"])
    var explanation: String = str(result.get("error", "资源未能读取"))
    if _model.count() == 0:
        if set_profiles([Degraded.stub_profile()]):
            _fixture_degraded = true
            if is_node_ready():
                _message("固定占位资源缺失；使用内置合成降级条目：" + explanation, true)
    elif is_node_ready():
        if _fixture_degraded:
            _message("固定占位资源仍缺失；继续保留内置合成降级条目：" + explanation, true)
        else:
            _message("占位资源缺失；保留上次已验证列表：" + explanation, true)
    collection_rejected.emit(explanation)
    return false


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
    _page_focus.clear()
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
        call_deferred("_restore_list_focus", _return_focus_id,
            _model.page_index(), _list_scroll_position)
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
        "total": _model.count(),
        "page": _model.page_state(),
        "fixture_degraded": _fixture_degraded,
        "detail_degraded": _detail_degraded
    }


func current_profile_copy() -> Dictionary:
    return _model.selected_profile_copy()


func visible_rows_copy() -> Array[Dictionary]:
    # Preserve 004 behavior: complete filtered list, not only this page.
    return _model.summaries_copy()


func current_page_rows_copy() -> Array[Dictionary]:
    return _model.page_summaries()


func set_page_number(number: int) -> bool:
    if _model.route() != "list":
        return false
    var destination := number - 1
    if destination == _model.page_index():
        return true
    if not _model.set_page(destination):
        return false
    _refresh_ui()
    if is_node_ready():
        _list_scroll.scroll_vertical = 0
    return true
