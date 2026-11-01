extends Control
## GAME-WEB-REGION-025 r1: synthetic menu -> region -> menu only.
## Independent flow owner. No save, event, shared shell API or real scene.
## Source candidate; NOT_RUN.
const REGION_SCENE := "res://region_screen.tscn"
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
var _return_page: String = "home"
var _availability: String = "ready"
var _attempts: int = 0
var _notice: String = "尚未进入区域。菜单只负责导航，不持有区域数据。"
var _region_instance: Control = null

var _menu_holder: VBoxContainer
var _region_holder: VBoxContainer
var _region_stage: Control
var _status_holder: VBoxContainer
var _notice_label: Label
var _route_label: Label
var _menu_info: Label
var _mode_select: OptionButton
var _home_button: Button
var _status_button: Button
var _open_button: Button
var _retry_button: Button
var _back_button: Button
var _region_back_button: Button

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

func _button(parent: Node, title: String, action: Callable) -> Button:
    var item := Button.new()
    item.text = title
    item.tooltip_text = title
    item.focus_mode = Control.FOCUS_ALL
    item.pressed.connect(action)
    parent.add_child(item)
    return item

func _build_ui() -> void:
    var root := VBoxContainer.new()
    add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.offset_left = 12.0
    root.offset_top = 12.0
    root.offset_right = -12.0
    root.offset_bottom = -12.0

    _label(root, "GAME-WEB-REGION-025 | 合成菜单 ↔ 可访问区域桥 | NOT_RUN")
    _route_label = _label(root, "")
    _notice_label = _label(root, "")

    _menu_holder = VBoxContainer.new()
    _menu_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(_menu_holder)
    var nav := HBoxContainer.new()
    _menu_holder.add_child(nav)
    _home_button = _button(nav, "菜单：概览", func(): _show_menu_page("home"))
    _status_button = _button(nav, "菜单：模块状态", func(): _show_menu_page("status"))
    _back_button = _button(nav, "返回上一层", Callable(self, "_return_previous"))
    _menu_info = _label(_menu_holder, "")
    _open_button = _button(_menu_holder, "进入独立 A/B/C 合成区域", Callable(self, "_enter_region"))
    _status_holder = VBoxContainer.new()
    _menu_holder.add_child(_status_holder)
    _label(_status_holder, "模拟装配状态（仅菜单内存；不读取或改变真实模块）：")
    _mode_select = OptionButton.new()
    for key in AVAILABILITY:
        _mode_select.add_item(MODE_LABELS[key])
    _mode_select.item_selected.connect(_set_availability)
    _status_holder.add_child(_mode_select)
    _retry_button = _button(_menu_holder, "显式恢复模拟就绪并重试进入", Callable(self, "_restore_and_retry"))
    _label(_menu_holder, "菜单只登记路由、模拟装配状态与最近错误；区域由独立子场景管理。返回会销毁原区域实例。")
    _label(_menu_holder, "没有任何真实关卡、存档、事件、人物、地点或输入路由器。")

    _region_holder = VBoxContainer.new()
    _region_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(_region_holder)
    var region_bar := HBoxContainer.new()
    _region_holder.add_child(region_bar)
    _region_back_button = _button(region_bar, "返回上层菜单（清空本次区域内存）", Callable(self, "_return_previous"))
    _button(region_bar, "回到菜单概览（清空本次区域内存）", Callable(self, "_return_home"))
    _label(_region_holder, "区域内容来自固定 PR #32 的合成候选副本，进入时新建，返回时释放。")
    _region_stage = Control.new()
    _region_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _region_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _region_holder.add_child(_region_stage)

func _set_availability(index: int) -> void:
    if _route != "menu" or index < 0 or index >= AVAILABILITY.size():
        return
    _availability = AVAILABILITY[index]
    _notice = "模拟模块状态已更改为：" + MODE_LABELS[_availability] + "。不会影响任何外部 PR。"
    _refresh_view()

func _show_menu_page(page: String) -> void:
    if _route != "menu" or not ["home", "status"].has(page):
        return
    _menu_page = page
    _notice = "菜单内部导航已切换；未装载区域数据。"
    _refresh_view()

func _can_enter() -> String:
    if _route != "menu":
        return "当前不在菜单；不能重复进入区域。"
    if not is_inside_tree() or get_tree().paused:
        return "页面不在场景树或已暂停；拒绝进入。"
    var window: Window = get_window()
    if window == null or not window.has_focus():
        return "窗口无焦点；拒绝进入，需重新聚焦并显式操作。"
    if _availability != "ready":
        return MODE_LABELS.get(_availability, "未知装配状态") + "；请显式恢复模拟就绪后重试。"
    return ""

func _enter_region() -> void:
    _attempts += 1
    var reason: String = _can_enter()
    if not reason.is_empty():
        _notice = "BLOCKED：" + reason
        _refresh_view()
        return
    # Dynamic scene loading: a missing *scene* can fail gracefully at menu.
    # Required scripts inside the scene remain hard Godot import/parse dependencies.
    if not ResourceLoader.exists(REGION_SCENE, "PackedScene"):
        _notice = "BLOCKED：缺少本目录固定区域场景 region_screen.tscn；仍停留菜单。"
        _refresh_view()
        return
    var resource: Resource = ResourceLoader.load(REGION_SCENE, "PackedScene")
    if not (resource is PackedScene):
        _notice = "BLOCKED：区域资源不是有效 PackedScene；未切换页面。"
        _refresh_view()
        return
    var raw: Node = (resource as PackedScene).instantiate()
    if not (raw is Control):
        if raw != null:
            raw.free()
        _notice = "BLOCKED：区域根节点不是 Control；已拒绝挂载。"
        _refresh_view()
        return
    var screen: Control = raw as Control
    _region_stage.add_child(screen)
    screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
    # Commit the navigation state only after the local control is mounted.
    _region_instance = screen
    _return_page = _menu_page
    _route = "region"
    _notice = "已进入公开合成 A/B/C；来源校验及回退仅由区域内部拥有。"
    _refresh_view()
    _region_back_button.grab_focus()

func _clear_region() -> void:
    if is_instance_valid(_region_instance):
        _region_stage.remove_child(_region_instance)
        _region_instance.queue_free()
    _region_instance = null
    # Defensive cleanup of any failed/incomplete local mount.
    for child in _region_stage.get_children():
        _region_stage.remove_child(child)
        child.queue_free()

func _return_previous() -> void:
    if _route == "region":
        _clear_region()
        _route = "menu"
        _menu_page = _return_page
        _return_page = "home"
        _notice = "已返回原菜单页；旧区域位置、核对、更正、撤销和回退状态随实例销毁。"
        _refresh_view()
        _open_button.grab_focus()
    elif _menu_page == "status":
        _menu_page = "home"
        _notice = "已由模块状态返回菜单概览。"
        _refresh_view()
        _status_button.grab_focus()
    else:
        _notice = "已位于菜单概览；没有更多上一层记录。"
        _refresh_view()

func _return_home() -> void:
    if _route == "region":
        _clear_region()
    _route = "menu"
    _menu_page = "home"
    _return_page = "home"
    _notice = "已回到菜单概览；无跨区域的活动状态或自动事件跳转。"
    _refresh_view()
    _open_button.grab_focus()

func _restore_and_retry() -> void:
    if _route != "menu":
        return
    _availability = "ready"
    _mode_select.select(0)
    _notice = "用户显式恢复了合成就绪标记；现在重新检查资源并尝试进入。"
    _enter_region()

func _refresh_view() -> void:
    if _menu_holder == null or _region_holder == null:
        return
    _menu_holder.visible = _route == "menu"
    _region_holder.visible = _route == "region"
    _route_label.text = "导航所有权：菜单 | 当前页面：" + _route +         (" / " + _menu_page if _route == "menu" else " / A/B/C 区域实例") +         " | 尝试进入：" + str(_attempts) + " 次（仅内存）"
    _notice_label.text = "最近状态：" + _notice
    _home_button.disabled = _route != "menu" or _menu_page == "home"
    _status_button.disabled = _route != "menu" or _menu_page == "status"
    _back_button.disabled = _route != "menu" or _menu_page == "home"
    _status_holder.visible = _menu_page == "status"
    _menu_info.text = ("概览：进入合成 A/B/C，或查看装配与失败模式。" if _menu_page == "home" else         "模块状态：") + "\n区域模拟装配：" + MODE_LABELS.get(_availability, "未知") +         "\n进入前校验固定场景资源，失败不会进入新页面。"
    _retry_button.visible = _availability != "ready"
