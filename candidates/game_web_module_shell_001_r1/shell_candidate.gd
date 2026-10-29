extends Control
## GAME-WEB-MODULE-SHELL-001 r1, standalone navigation demo.
## This controller ONLY calls local synthetic adapters.
## It does not instantiate, copy or invoke Draft PR #6/#10/#14/#15.

signal page_changed(page_id: String)
signal simulated_request(slot: String, request_id: String)

const PlaceholderAdapter = preload("res://placeholder_adapter_candidate.gd")
const SLOTS := ["round", "prompt", "profile", "bindings"]
const PAGE_TITLES := {
    "home": "独立演示概览",
    "round": "回合候选（占位）",
    "prompt": "交互提示（占位）",
    "profile": "角色面板（占位）",
    "bindings": "输入配置（占位）"
}

@onready var _panel: PanelContainer = $Frame/Layout/Body/View
@onready var _page_title: Label = $Frame/Layout/Body/View/Inner/Page/PageTitle
@onready var _page_body: Label = $Frame/Layout/Body/View/Inner/Page/PageBody
@onready var _preview_button: Button = $Frame/Layout/Body/View/Inner/Page/PreviewButton
@onready var _status: Label = $Frame/Layout/Body/View/Inner/Page/Status
@onready var _title: Label = $Frame/Layout/Header/Title
@onready var _subtitle: Label = $Frame/Layout/Header/Subtitle
@onready var _footer: Label = $Frame/Layout/Footer

var _page: String = "home"
var _adapters: Dictionary = {}
var _buttons: Dictionary = {}
var _status_message: String = "四个上游候选均未加载；本入口独立运行。"


func _ready() -> void:
    for slot in SLOTS:
        _adapters[slot] = PlaceholderAdapter.new(slot)

    _buttons = {
        "home": $Frame/Layout/Body/Sidebar/HomeButton,
        "round": $Frame/Layout/Body/Sidebar/RoundButton,
        "prompt": $Frame/Layout/Body/Sidebar/PromptButton,
        "profile": $Frame/Layout/Body/Sidebar/ProfileButton,
        "bindings": $Frame/Layout/Body/Sidebar/BindingsButton
    }
    for page_id in PAGE_TITLES.keys():
        var nav_button: Button = _buttons[page_id]
        nav_button.pressed.connect(Callable(self, "show_page").bind(page_id))
        nav_button.focus_mode = Control.FOCUS_ALL

    _preview_button.pressed.connect(_on_preview_pressed)
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
    _footer.add_theme_color_override("font_color", Color("#a8bdd5"))


func current_page() -> String:
    return _page


func show_page(page_id: String) -> bool:
    if not PAGE_TITLES.has(page_id):
        return false
    var changed: bool = _page != page_id
    _page = page_id
    _status_message = "独立候选：未连接上游功能。"
    if is_node_ready():
        _render()
    if changed:
        page_changed.emit(_page)
    return true


# A strictly shell-local, unapproved future injection seam.
# Only the requested slot is replaced; no PR interface compatibility implied.
# Adapters are trusted code supplied by the future host, not untrusted JSON.
func install_adapter(slot: String, adapter: RefCounted) -> bool:
    if not SLOTS.has(slot) or adapter == null:
        return false
    if not adapter.has_method("preview") or not adapter.has_method("preview_action"):
        return false
    _adapters[slot] = adapter
    if is_node_ready() and _page == slot:
        _render()
    return true


func remove_adapter(slot: String) -> bool:
    if not SLOTS.has(slot) or not _adapters.has(slot):
        return false
    _adapters.erase(slot)
    if is_node_ready() and _page == slot:
        _render()
    return true


func has_adapter(slot: String) -> bool:
    return SLOTS.has(slot) and _adapters.has(slot)


func _adapter_preview(slot: String) -> Dictionary:
    if not _adapters.has(slot):
        return {"ok": false, "title": "未连接", "body": "此槽位没有适配器。"}
    var adapter: RefCounted = _adapters[slot]
    if not is_instance_valid(adapter) or not adapter.has_method("preview"):
        return {"ok": false, "title": "接口缺失", "body": "适配器未提供 preview()。"}
    var result: Variant = adapter.call("preview")
    if typeof(result) != TYPE_DICTIONARY:
        return {"ok": false, "title": "接口无效", "body": "preview() 必须返回 Dictionary。"}
    if typeof(result.get("title")) != TYPE_STRING or typeof(result.get("body")) != TYPE_STRING:
        return {"ok": false, "title": "接口无效", "body": "缺少字符串 title/body。"}
    return result


func _render() -> void:
    _page_title.text = PAGE_TITLES[_page]
    _preview_button.visible = _page != "home"
    _preview_button.disabled = _page == "home" or not has_adapter(_page)

    for nav_page in _buttons.keys():
        var button: Button = _buttons[nav_page]
        button.disabled = nav_page == _page

    if _page == "home":
        _page_body.text = (
            "这是独立的 Godot 主菜单候选，仅用于演示导航和插槽隔离。\n\n"
            + "• 回合候选：本地合成记录\n"
            + "• 交互提示：本地合成目标\n"
            + "• 角色面板：本地合成资料\n"
            + "• 输入配置：本地合成键位\n\n"
            + "没有加载其他 Draft PR、真实剧情、存档或共享接口。"
        )
    else:
        var sample: Dictionary = _adapter_preview(_page)
        _page_body.text = str(sample["title"]) + "\n\n" + str(sample["body"])
        _preview_button.disabled = not bool(sample.get("ok", false))
    _status.text = _status_message


func _on_preview_pressed() -> void:
    if _page == "home" or not has_adapter(_page):
        return
    if not is_inside_tree() or get_tree().paused or not get_window().has_focus():
        _status_message = "模拟请求被拦截：暂停或窗口无焦点。"
        _render()
        return
    var adapter: RefCounted = _adapters[_page]
    if not is_instance_valid(adapter) or not adapter.has_method("preview_action"):
        _status_message = "拒绝：适配器缺少 preview_action()。"
        _render()
        return
    var result: Variant = adapter.call("preview_action", "sample_request")
    if typeof(result) != TYPE_DICTIONARY or not bool(result.get("ok", false)):
        _status_message = "模拟请求被拒绝；未执行任何游戏动作。"
        _render()
        return
    _status_message = str(result.get("message", "模拟请求已返回。"))
    simulated_request.emit(_page, "sample_request")
    _render()
