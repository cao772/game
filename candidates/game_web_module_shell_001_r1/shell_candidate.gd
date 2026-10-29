extends Control
## GAME-WEB-CONTINUE-SHELL-003 r1
## Standalone menu + shell-private assembly registry; no cross-PR execution.

signal page_changed(page_id: String)
signal simulated_request(slot: String, request_id: String)
signal assembly_changed(slot: String, status: String)

const Registry = preload("res://module_registry_candidate.gd")
const Placeholder = preload("res://placeholder_adapter_candidate.gd")
const SLOTS := ["round", "prompt", "profile", "bindings"]
const PAGES := ["home", "round", "prompt", "profile", "bindings", "modules"]
const PAGE_TITLES := {
    "home": "独立演示概览",
    "round": "回合候选（占位）",
    "prompt": "交互提示（占位）",
    "profile": "资料面板（占位）",
    "bindings": "输入配置（占位）",
    "modules": "模块装配与降级"
}
const STATUS_NAMES := {
    "synthetic_ready": "本地模拟",
    "missing": "未装配",
    "disabled": "已禁用",
    "blocked_dependency": "候选依赖阻塞",
    "pending_review": "候选待审核",
    "degraded": "故障降级",
    "unknown": "未知模块"
}
const ASSEMBLY_MODES := ["mock", "missing", "disabled", "pending"]
const HISTORY_LIMIT := 24

@onready var _panel: PanelContainer = $Frame/Layout/Body/View
@onready var _page_title: Label = $Frame/Layout/Body/View/Inner/Page/PageTitle
@onready var _page_body: Label = $Frame/Layout/Body/View/Inner/Page/PageBody
@onready var _preview_button: Button = $Frame/Layout/Body/View/Inner/Page/PreviewButton
@onready var _status: Label = $Frame/Layout/Body/View/Inner/Page/Status
@onready var _module_state: Label = $Frame/Layout/Body/View/Inner/Page/ModuleState
@onready var _assembly_controls: VBoxContainer = $Frame/Layout/Body/View/Inner/Page/AssemblyControls
@onready var _slot_selector: OptionButton = $Frame/Layout/Body/View/Inner/Page/AssemblyControls/SlotSelector
@onready var _mode_selector: OptionButton = $Frame/Layout/Body/View/Inner/Page/AssemblyControls/ModeSelector
@onready var _apply_button: Button = $Frame/Layout/Body/View/Inner/Page/AssemblyControls/ApplyButton
@onready var _refresh_button: Button = $Frame/Layout/Body/View/Inner/Page/AssemblyControls/RefreshButton
@onready var _restore_button: Button = $Frame/Layout/Body/View/Inner/Page/AssemblyControls/RestoreButton
@onready var _back_button: Button = $Frame/Layout/Body/Sidebar/BackButton
@onready var _title: Label = $Frame/Layout/Header/Title
@onready var _subtitle: Label = $Frame/Layout/Header/Subtitle
@onready var _footer: Label = $Frame/Layout/Footer

var _page: String = "home"
var _history: Array[String] = []
var _registry = Registry.new()
var _buttons: Dictionary = {}
var _status_message: String = "仅装配合成占位；上游 Draft PR 未加载。"


func _ready() -> void:
    _registry.restore_all_mocks()
    _buttons = {
        "home": $Frame/Layout/Body/Sidebar/HomeButton,
        "round": $Frame/Layout/Body/Sidebar/RoundButton,
        "prompt": $Frame/Layout/Body/Sidebar/PromptButton,
        "profile": $Frame/Layout/Body/Sidebar/ProfileButton,
        "bindings": $Frame/Layout/Body/Sidebar/BindingsButton,
        "modules": $Frame/Layout/Body/Sidebar/ModulesButton
    }
    for page_id in PAGES:
        var nav_button: Button = _buttons[page_id]
        nav_button.focus_mode = Control.FOCUS_ALL
        nav_button.pressed.connect(Callable(self, "show_page").bind(page_id))
    _back_button.pressed.connect(go_back)
    _preview_button.pressed.connect(_on_preview_pressed)
    _apply_button.pressed.connect(_on_apply_assembly)
    _refresh_button.pressed.connect(_on_refresh_slot)
    _restore_button.pressed.connect(restore_all_mocks)

    for slot in SLOTS:
        var slot_info: Dictionary = _registry.status(slot)
        _slot_selector.add_item(str(slot_info["label"]) + " · PR #" + str(slot_info["source_pr"]))
    _mode_selector.add_item("恢复合成占位")
    _mode_selector.add_item("模拟模块缺失")
    _mode_selector.add_item("模拟禁用")
    _mode_selector.add_item("登记候选（不加载代码）")
    _apply_demo_theme()
    _render()


func _apply_demo_theme() -> void:
    var box_style := StyleBoxFlat.new()
    box_style.bg_color = Color("#15243a")
    box_style.border_color = Color("#354b68")
    box_style.set_border_width_all(1)
    box_style.set_corner_radius_all(12)
    _panel.add_theme_stylebox_override("panel", box_style)
    _title.add_theme_color_override("font_color", Color("#edf4ff"))
    _subtitle.add_theme_color_override("font_color", Color("#a8bdd5"))
    _page_title.add_theme_color_override("font_color", Color("#f1f6ff"))
    _page_body.add_theme_color_override("font_color", Color("#d4e2f3"))
    _status.add_theme_color_override("font_color", Color("#90b8e5"))
    _module_state.add_theme_color_override("font_color", Color("#d7e4f4"))
    _footer.add_theme_color_override("font_color", Color("#a8bdd5"))


func current_page() -> String:
    return _page


func history_copy() -> Array[String]:
    return _history.duplicate()


func assembly_snapshot() -> Array[Dictionary]:
    return _registry.snapshot()


func module_status(slot: String) -> Dictionary:
    return _registry.status(slot)


func current_view() -> Dictionary:
    if not SLOTS.has(_page):
        return {"ok": false, "status": "not_module", "title": "", "body": ""}
    return _registry.view(_page)


func _change_page(page_id: String, remember: bool) -> bool:
    if not PAGES.has(page_id):
        return false
    if page_id == _page:
        return true
    if remember:
        _history.append(_page)
        if _history.size() > HISTORY_LIMIT:
            _history.remove_at(0)
    _page = page_id
    _status_message = "导航已切换；模块装配状态仅在本地内存保存。"
    if SLOTS.has(_page):
        _registry.refresh(_page)
    if is_node_ready():
        _render()
    page_changed.emit(_page)
    return true


func show_page(page_id: String) -> bool:
    return _change_page(page_id, true)


func go_back() -> bool:
    if _history.is_empty():
        return false
    var destination: String = _history.pop_back()
    return _change_page(destination, false)


# Compatibility shim for the r1 shell's PRIVATE API, not a shared contract.
# Caller-provided code must be trusted and synthetic; no sandbox is offered.
func install_adapter(slot: String, adapter: RefCounted) -> bool:
    var ok: bool = _registry.mount_mock(slot, adapter)
    if ok:
        _on_assembly_mutation(slot)
    return ok


func remove_adapter(slot: String) -> bool:
    var ok: bool = _registry.remove(slot)
    if ok:
        _on_assembly_mutation(slot)
    return ok


func has_adapter(slot: String) -> bool:
    return _registry.is_mounted(slot)


func stage_candidate(slot: String) -> bool:
    var ok: bool = _registry.stage_candidate(slot)
    if ok:
        _on_assembly_mutation(slot)
    return ok


func disable_module(slot: String) -> bool:
    var ok: bool = _registry.disable(slot)
    if ok:
        _on_assembly_mutation(slot)
    return ok


func restore_mock(slot: String) -> bool:
    var ok: bool = _registry.restore_mock(slot)
    if ok:
        _on_assembly_mutation(slot)
    return ok


func restore_all_mocks() -> void:
    _registry.restore_all_mocks()
    _status_message = "四个槽位已重建为合成占位，未装载任何上游模块。"
    if is_node_ready():
        _render()
    for slot in SLOTS:
        assembly_changed.emit(slot, str(_registry.status(slot)["status"]))


func _on_assembly_mutation(slot: String) -> void:
    var state: Dictionary = _registry.status(slot)
    _status_message = str(state["label"]) + "：" + str(STATUS_NAMES.get(state["status"], "未知"))
    if is_node_ready():
        _render()
    assembly_changed.emit(slot, str(state["status"]))


func _on_apply_assembly() -> void:
    var index: int = _slot_selector.selected
    var mode_index: int = _mode_selector.selected
    if index < 0 or index >= SLOTS.size() or mode_index < 0 \
            or mode_index >= ASSEMBLY_MODES.size():
        _status_message = "装配选择无效；无状态变化。"
        _render()
        return
    var slot: String = SLOTS[index]
    match ASSEMBLY_MODES[mode_index]:
        "mock":
            restore_mock(slot)
        "missing":
            remove_adapter(slot)
        "disabled":
            disable_module(slot)
        "pending":
            stage_candidate(slot)


func _on_refresh_slot() -> void:
    var index: int = _slot_selector.selected
    if index < 0 or index >= SLOTS.size():
        return
    var slot: String = SLOTS[index]
    var state: Dictionary = _registry.refresh(slot)
    _status_message = "手动刷新：" + str(state.get("status", "unknown"))
    _render()
    assembly_changed.emit(slot, str(state.get("status", "unknown")))


func _status_text(status_id: String) -> String:
    return str(STATUS_NAMES.get(status_id, status_id))


func _overview_text() -> String:
    var lines: Array[String] = [
        "此入口只组合本地占位适配器；没有真实玩法、人物或存档。",
        "",
        "当前模块状态（全部为候选）:"
    ]
    for info in _registry.snapshot():
        lines.append("• " + str(info["label"]) + " / PR #" + str(info["source_pr"]) \
            + "： " + _status_text(str(info["status"])))
    lines.append("")
    lines.append("进入「模块装配」可模拟缺失、禁用、依赖阻塞与恢复；所有操作仅在内存中生效。")
    return "\n".join(lines)


func _assembly_text() -> String:
    var lines: Array[String] = [
        "选择槽位和模拟装配模式，再点击「应用」。不会下载或执行任何 Draft PR。",
        "待审核候选仅登记来源编号，不能触发交互或写入游戏状态。",
        ""
    ]
    for info in _registry.snapshot():
        lines.append("• " + str(info["label"]) + "（#" + str(info["source_pr"]) + "）" \
            + " · " + _status_text(str(info["status"])))
    lines.append("")
    lines.append("输入配置候选 #15 依赖 #6；只有两者都登记候选后才显示「待审核」，不表示兼容或集成成功。")
    return "\n".join(lines)


func _render() -> void:
    _page_title.text = PAGE_TITLES[_page]
    _assembly_controls.visible = _page == "modules"
    _preview_button.visible = SLOTS.has(_page)
    _module_state.visible = SLOTS.has(_page)
    _back_button.disabled = _history.is_empty()

    for page_id in PAGES:
        var button: Button = _buttons[page_id]
        button.disabled = page_id == _page

    if _page == "home":
        _page_body.text = _overview_text()
    elif _page == "modules":
        _page_body.text = _assembly_text()
    else:
        var info: Dictionary = _registry.status(_page)
        var shown: Dictionary = _registry.view(_page)
        _page_body.text = str(shown["title"]) + "\n\n" + str(shown["body"])
        _module_state.text = "状态：" + _status_text(str(info["status"])) \
            + " · 来源候选 PR #" + str(info["source_pr"])
        _preview_button.disabled = not bool(info["action_enabled"])
    _status.text = _status_message


# Injected block flag is ONLY a deterministic future-test seam.
# Pause cannot be overridden. Native path uses actual window focus.
func request_demo(blocked_override: Variant = null) -> Dictionary:
    if not SLOTS.has(_page):
        return {"ok": false, "message": "当前不是模块页面"}
    if not is_inside_tree() or get_tree().paused:
        return {"ok": false, "message": "页面未就绪或暂停"}
    var blocked: bool = not get_window().has_focus()
    if blocked_override != null:
        blocked = bool(blocked_override)
    if blocked:
        _status_message = "模拟请求被拦截：窗口无焦点。"
        _render()
        return {"ok": false, "message": _status_message}
    var result: Dictionary = _registry.invoke_mock(_page, "sample_request")
    _status_message = str(result.get("message", "模拟请求被拒绝。"))
    if result.get("ok", false):
        simulated_request.emit(_page, "sample_request")
    _render()
    return result


func _on_preview_pressed() -> void:
    request_demo()
