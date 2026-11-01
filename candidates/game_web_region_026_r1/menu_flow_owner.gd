extends Control
## GAME-WEB-REGION-026 r1: private coordinator for menu, region and event preview.
## No shared API, PR #18 runtime import, game event dispatch or save integration.

const REGION_SCENE := "res://region_screen.tscn"
const EVENT_SCENE := "res://event_preview_screen.tscn"
const AVAILABILITY := ["ready", "missing", "disabled", "pending", "degraded"]
const MODE_LABELS := {
    "ready": "合成模块就绪（仅菜单模拟状态）",
    "missing": "模块未装配（模拟）",
    "disabled": "模块被禁用（模拟）",
    "pending": "模块待审核（模拟）",
    "degraded": "模块故障降级（模拟）"
}

var _route: String = "menu"
var _menu_page: String = "home"
var _region_return_page: String = "home"
var _event_origin_route: String = ""
var _event_return_page: String = "home"
var _availability: String = "ready"
var _attempts: int = 0
var _notice: String = "菜单、区域和事件预览均为独立合成候选。"

var _menu_holder: VBoxContainer
var _region_holder: VBoxContainer
var _event_holder: VBoxContainer
var _region_stage: Control
var _event_stage: Control
var _route_label: Label
var _notice_label: Label
var _menu_info: Label
var _mode_select: OptionButton
var _home_button: Button
var _status_button: Button
var _menu_region_button: Button
var _menu_event_button: Button
var _menu_back_button: Button
var _region_back_button: Button
var _region_event_button: Button
var _event_back_button: Button
var _event_menu_button: Button
var _region_instance: Control = null
var _event_instance: Control = null


func _ready() -> void:
    _build_ui()
    _refresh_view()


func _label(parent: Node, value: String) -> Label:
    var item := Label.new()
    item.text = value
    item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(item)
    return item


func _button(parent: Node, caption: String, action: Callable) -> Button:
    var item := Button.new()
    item.text = caption
    item.tooltip_text = caption
    item.focus_mode = Control.FOCUS_ALL
    item.pressed.connect(action)
    parent.add_child(item)
    return item


func _build_ui() -> void:
    var root := VBoxContainer.new()
    add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.offset_left = 12.0
    root.offset_top = 10.0
    root.offset_right = -12.0
    root.offset_bottom = -10.0

    _label(root, "GAME-WEB-REGION-026｜菜单 ↔ 合成区域 ↔ 合成事件预览｜NOT_RUN")
    _route_label = _label(root, "")
    _notice_label = _label(root, "")

    _menu_holder = VBoxContainer.new()
    _menu_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(_menu_holder)
    var menu_nav := HBoxContainer.new()
    _menu_holder.add_child(menu_nav)
    _home_button = _button(menu_nav, "菜单概览", func(): _show_menu_page("home"))
    _status_button = _button(menu_nav, "模块状态", func(): _show_menu_page("status"))
    _menu_back_button = _button(menu_nav, "返回上一层", Callable(self, "_return_previous"))
    _menu_info = _label(_menu_holder, "")
    _menu_region_button = _button(_menu_holder, "进入独立 A/B/C 合成区域", Callable(self, "_enter_region"))
    _menu_event_button = _button(_menu_holder, "从菜单打开合成事件预览", Callable(self, "_open_event_from_menu"))
    _label(_menu_holder, "菜单状态仅用于本地导航演示，不代表真实模块健康或游戏状态。")
    _label(_menu_holder, "事件预览使用独立固定事件 ID；不会把 A/B/C 区域目标自动映射为事件。")

    var status_box := VBoxContainer.new()
    _menu_holder.add_child(status_box)
    _label(status_box, "模拟装配状态（只影响菜单是否允许进入区域）：")
    _mode_select = OptionButton.new()
    for key in AVAILABILITY:
        _mode_select.add_item(MODE_LABELS[key])
    _mode_select.item_selected.connect(_set_availability)
    status_box.add_child(_mode_select)
    _button(status_box, "显式恢复模拟就绪并重试进入区域", Callable(self, "_restore_and_retry"))

    _region_holder = VBoxContainer.new()
    _region_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(_region_holder)
    var region_bar := HBoxContainer.new()
    _region_holder.add_child(region_bar)
    _region_back_button = _button(region_bar, "返回来源菜单", Callable(self, "_return_previous"))
    _region_event_button = _button(region_bar, "打开独立合成事件预览", Callable(self, "_open_event_from_region"))
    _button(region_bar, "回到菜单概览并清除区域", Callable(self, "_return_home"))
    _label(_region_holder, "区域来自 PR #33 的原样公开合成副本。事件入口位于外层工具栏；不读取 A/B/C 私有快照，也不建立目标→事件映射。")
    _region_stage = Control.new()
    _region_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _region_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _region_holder.add_child(_region_stage)

    _event_holder = VBoxContainer.new()
    _event_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(_event_holder)
    var event_bar := HBoxContainer.new()
    _event_holder.add_child(event_bar)
    _event_back_button = _button(event_bar, "返回事件预览来源页", Callable(self, "_return_from_event"))
    _event_menu_button = _button(event_bar, "返回菜单概览并清除区域", Callable(self, "_return_home"))
    _label(_event_holder, "事件预览是独立临时子页面。来自区域时，区域实例保持挂载但隐藏；返回后恢复原实例。")
    _event_stage = Control.new()
    _event_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _event_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _event_holder.add_child(_event_stage)


func _set_availability(index: int) -> void:
    if _route != "menu" or index < 0 or index >= AVAILABILITY.size():
        return
    _availability = AVAILABILITY[index]
    _notice = "菜单模拟装配状态已改为：" + MODE_LABELS[_availability] + "。不会改变区域文件或其他 PR。"
    _refresh_view()


func _show_menu_page(page: String) -> void:
    if _route != "menu" or not ["home", "status"].has(page):
        return
    _menu_page = page
    _notice = "菜单页面已切换；未读取区域或事件数据。"
    _refresh_view()


func _can_enter_region() -> String:
    if _route != "menu":
        return "当前不在菜单。"
    if not is_inside_tree() or get_tree().paused:
        return "页面不在场景树或已暂停。"
    var window: Window = get_window()
    if window == null or not window.has_focus():
        return "窗口无焦点；重新聚焦后需再次显式点击。"
    if _availability != "ready":
        return MODE_LABELS.get(_availability, "未知模块状态") + "；请显式恢复模拟就绪。"
    return ""


func _enter_region() -> void:
    _attempts += 1
    var reason: String = _can_enter_region()
    if not reason.is_empty():
        _notice = "BLOCKED：" + reason
        _refresh_view()
        return
    if not ResourceLoader.exists(REGION_SCENE, "PackedScene"):
        _notice = "BLOCKED：固定区域场景 region_screen.tscn 缺失；仍停留菜单。"
        _refresh_view()
        return
    var resource: Resource = ResourceLoader.load(REGION_SCENE, "PackedScene")
    if not (resource is PackedScene):
        _notice = "BLOCKED：区域资源不是 PackedScene；没有切换页面。"
        _refresh_view()
        return
    var raw: Node = (resource as PackedScene).instantiate()
    if not (raw is Control):
        if raw != null:
            raw.free()
        _notice = "BLOCKED：区域根节点不是 Control；拒绝挂载。"
        _refresh_view()
        return
    var screen: Control = raw as Control
    _region_stage.add_child(screen)
    screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _region_instance = screen
    _region_return_page = _menu_page
    _route = "region"
    _notice = "已进入独立 A/B/C 合成区域；没有读取或创建事件上下文。"
    _refresh_view()
    _region_back_button.grab_focus()


func _open_event_from_menu() -> void:
    _open_event_preview("menu")


func _open_event_from_region() -> void:
    _open_event_preview("region")


func _open_event_preview(source_route: String) -> void:
    if source_route != _route or not ["menu", "region"].has(source_route):
        _notice = "BLOCKED：事件预览来源路由不匹配。"
        _refresh_view()
        return
    if not is_inside_tree() or get_tree().paused:
        _notice = "BLOCKED：当前页面未就绪或已暂停。"
        _refresh_view()
        return
    if not ResourceLoader.exists(EVENT_SCENE, "PackedScene"):
        _notice = "BLOCKED：固定事件预览场景 event_preview_screen.tscn 缺失；保留当前页面。"
        _refresh_view()
        return
    var resource: Resource = ResourceLoader.load(EVENT_SCENE, "PackedScene")
    if not (resource is PackedScene):
        _notice = "BLOCKED：事件预览资源不是 PackedScene；保留当前页面。"
        _refresh_view()
        return
    var raw: Node = (resource as PackedScene).instantiate()
    if not (raw is Control):
        if raw != null:
            raw.free()
        _notice = "BLOCKED：事件预览根节点不是 Control；拒绝挂载。"
        _refresh_view()
        return

    var screen: Control = raw as Control
    screen.set("origin_route", source_route)
    if source_route == "region" and is_instance_valid(_region_instance):
        var focus_owner: Control = get_viewport().gui_get_focus_owner()
        if focus_owner != null and (_region_instance == focus_owner or _region_instance.is_ancestor_of(focus_owner)):
            focus_owner.release_focus()
    _event_stage.add_child(screen)
    screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
    # The event scene is mounted before committing the route. The region
    # remains alive but hidden when it was the source; no state is copied.
    _event_instance = screen
    _event_origin_route = source_route
    _event_return_page = _menu_page
    _route = "event"
    _notice = "已打开独立合成事件预览；只传递来源标签，不传递区域快照或真实状态。"
    _refresh_view()
    _event_back_button.grab_focus()


func _clear_event() -> void:
    if is_instance_valid(_event_instance):
        _event_stage.remove_child(_event_instance)
        _event_instance.queue_free()
    _event_instance = null


func _clear_region() -> void:
    if is_instance_valid(_region_instance):
        _region_stage.remove_child(_region_instance)
        _region_instance.queue_free()
    _region_instance = null
    for child in _region_stage.get_children():
        _region_stage.remove_child(child)
        child.queue_free()


func _return_from_event() -> void:
    if _route != "event":
        return
    _clear_event()
    if _event_origin_route == "region" and is_instance_valid(_region_instance):
        _route = "region"
        _menu_page = _event_return_page
        _notice = "已返回原 A/B/C 区域实例；区域内存状态没有经过事件预览修改。"
        _event_origin_route = ""
        _refresh_view()
        _region_event_button.grab_focus()
        return
    _route = "menu"
    _menu_page = _event_return_page
    _event_origin_route = ""
    _notice = "已返回原菜单页面；事件预览临时状态已销毁。"
    _refresh_view()
    _menu_event_button.grab_focus()


func _return_previous() -> void:
    if _route == "event":
        _return_from_event()
    elif _route == "region":
        _clear_region()
        _route = "menu"
        _menu_page = _region_return_page
        _region_return_page = "home"
        _notice = "已返回来源菜单；区域临时状态已随区域实例销毁。"
        _refresh_view()
        _menu_region_button.grab_focus()
    elif _menu_page == "status":
        _menu_page = "home"
        _notice = "已从模块状态返回菜单概览。"
        _refresh_view()
        _menu_region_button.grab_focus()
    else:
        _notice = "已位于菜单概览，没有更早的页面。"
        _refresh_view()


func _return_home() -> void:
    if _route == "event":
        _clear_event()
        if _event_origin_route == "region":
            _clear_region()
        _event_origin_route = ""
    elif _route == "region":
        _clear_region()
    _route = "menu"
    _menu_page = "home"
    _region_return_page = "home"
    _event_return_page = "home"
    _notice = "已回到菜单概览；区域与事件预览临时状态均已销毁。"
    _refresh_view()
    _menu_region_button.grab_focus()


func _restore_and_retry() -> void:
    if _route != "menu":
        return
    _availability = "ready"
    _mode_select.select(0)
    _notice = "用户显式恢复菜单模拟就绪；重新检查固定区域场景。"
    _enter_region()


func _refresh_view() -> void:
    if _menu_holder == null:
        return
    _menu_holder.visible = _route == "menu"
    _region_holder.visible = _route == "region"
    _event_holder.visible = _route == "event"
    _route_label.text = "导航所有权：menu / region / event｜当前：" + _route + (" / " + _menu_page if _route == "menu" else "")
    _notice_label.text = "最近状态：" + _notice

    _home_button.disabled = _route != "menu" or _menu_page == "home"
    _status_button.disabled = _route != "menu" or _menu_page == "status"
    _menu_back_button.disabled = _route != "menu" or _menu_page == "home"
    _menu_region_button.visible = _menu_page == "home"
    _menu_event_button.visible = true
    _mode_select.get_parent().visible = _menu_page == "status"
    _menu_info.text = ("概览：可进入 A/B/C 区域或单独预览固定事件。" if _menu_page == "home" else
        "模块状态：") + "\n区域模拟装配：" + MODE_LABELS.get(_availability, "未知")
    _region_back_button.disabled = _route != "region"
    _region_event_button.disabled = _route != "region"
    _event_back_button.disabled = _route != "event"
    _event_menu_button.disabled = _route != "event"
