extends MarginContainer
## GAME-WEB-CONTINUE-CHAR-003: error-tolerant preview, synthetic fixtures only.
## No other res:// paths, external URLs, private sources or gameplay actions.

const FixtureLoader = preload("res://placeholder_fixture_loader_candidate.gd")
const PanelResource = preload("res://preview_panel_resource_candidate.gd")
const PANEL_SCENE_PATH := "res://character_profile_panel.tscn"

var _examples: Array[Dictionary] = []
var _panel: Control = null
var _narrow: bool = false

@onready var _choice: OptionButton = $Layout/Toolbar/Choice
@onready var _clear_button: Button = $Layout/Toolbar/Clear
@onready var _reload_button: Button = $Layout/Toolbar/Reload
@onready var _status: Label = $Layout/Status
@onready var _panel_host: MarginContainer = $Layout/PanelHost
@onready var _fallback: Label = $Layout/PanelHost/Fallback


func _ready() -> void:
    _choice.item_selected.connect(_on_chosen)
    _clear_button.pressed.connect(_on_clear)
    _reload_button.pressed.connect(_on_reload)
    resized.connect(_update_spacing)
    _choice.focus_mode = Control.FOCUS_ALL
    _clear_button.focus_mode = Control.FOCUS_ALL
    _reload_button.focus_mode = Control.FOCUS_ALL
    _choice.focus_next = _choice.get_path_to(_clear_button)
    _clear_button.focus_previous = _clear_button.get_path_to(_choice)
    _clear_button.focus_next = _clear_button.get_path_to(_reload_button)
    _reload_button.focus_previous = _reload_button.get_path_to(_clear_button)
    _mark_accessible(_choice, "占位记录选择")
    _mark_accessible(_clear_button, "清除预览")
    _mark_accessible(_reload_button, "重新加载占位数据和组件")
    _mark_accessible(_status, "数据加载状态")
    if _has_property(_status, "accessibility_live"):
        _status.set("accessibility_live", 1)
    _update_spacing()
    _load_examples()


func _has_property(node: Object, property_name: String) -> bool:
    for prop in node.get_property_list():
        if str(prop.get("name", "")) == property_name:
            return true
    return false


func _mark_accessible(control: Control, readable_name: String) -> void:
    if _has_property(control, "accessibility_name"):
        control.set("accessibility_name", readable_name)
    control.tooltip_text = readable_name


func _update_spacing() -> void:
    var compact := size.x < 480.0
    if compact == _narrow and has_theme_constant_override("margin_left"):
        return
    _narrow = compact
    var padding := 8 if compact else 18
    for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
        add_theme_constant_override(side, padding)
    $Layout/Toolbar.add_theme_constant_override("separation", 5 if compact else 10)


func _status_message(message: String, is_error: bool = false) -> void:
    _status.text = message
    _status.add_theme_color_override(
        "font_color", Color("#ffd5d5") if is_error else Color("#d8e7fa")
    )
    _status.tooltip_text = message


func _show_panel_fallback(message: String) -> void:
    _fallback.text = message
    _fallback.visible = true
    _mark_accessible(_fallback, "资料展示组件不可用")


func _panel_available() -> bool:
    return _panel != null and is_instance_valid(_panel) and _panel.is_inside_tree()


func _ensure_panel() -> bool:
    if _panel_available():
        return true
    _panel = null
    if not ResourceLoader.exists(PANEL_SCENE_PATH, "PackedScene"):
        _show_panel_fallback("资料展示组件资源缺失。可尝试重载。")
        return false

    # Loading may produce Godot diagnostics for broken scripts or scene data.
    # Never convert such failures to a successful panel state.
    var resource: Resource = ResourceLoader.load(
        PANEL_SCENE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE
    )
    var built: Dictionary = PanelResource.instantiate_panel(resource)
    if not built["ok"]:
        _show_panel_fallback("资料展示组件加载失败。可尝试重载。")
        return false

    _panel = built["node"] as Control
    _panel.name = "CharacterProfilePanel"
    _panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _panel_host.add_child(_panel)
    _panel_host.move_child(_panel, 0)
    _fallback.visible = false
    return true


func _refresh_focus_chain() -> void:
    if not _panel_available():
        _reload_button.focus_next = NodePath("")
        return
    var section_nav: Control = _panel.get_node("Layout/SectionNav")
    var read_area: Control = _panel.get_node("Layout/Scroll")
    var target: Control = read_area
    if section_nav.visible:
        target = _panel.get_node("Layout/SectionNav/SectionChoice")
    _reload_button.focus_next = _reload_button.get_path_to(target)
    target.focus_previous = target.get_path_to(_reload_button)


func _reset_preview() -> void:
    _examples.clear()
    _choice.clear()
    _choice.disabled = true
    _clear_button.disabled = true
    if _panel_available():
        _panel.call("clear_profile")
    _refresh_focus_chain()


func _load_examples() -> void:
    _reset_preview()
    _status_message("读取合成占位资源中")
    if not _ensure_panel():
        _status_message("资料展示组件不可用；可尝试重载", true)
        return

    var result: Dictionary = FixtureLoader.read_known_fixture()
    if not result["ok"]:
        _status_message("占位资源加载失败：" + result["error"], true)
        _refresh_focus_chain()
        return

    for profile in result["data"]:
        _examples.append(profile.duplicate(true))
        _choice.add_item(profile["display_name"])
    _choice.disabled = false
    _choice.select(0)
    _on_chosen(0)


func _on_chosen(index: int) -> void:
    if not _panel_available():
        _status_message("资料展示组件不可用", true)
        return
    if index < 0 or index >= _examples.size():
        _status_message("占位记录索引无效；已保留当前展示", true)
        return
    if _panel.call("set_profile", _examples[index]):
        _clear_button.disabled = false
        _status_message("仅供技术预览：全部为合成占位资料")
        _refresh_focus_chain()
    else:
        _status_message("展示失败：" + str(_panel.call("last_error")), true)


func _on_clear() -> void:
    if _panel_available():
        _panel.call("clear_profile")
    _choice.select(-1)
    _clear_button.disabled = true
    _status_message("已清空展示；可重新选择占位记录")
    _refresh_focus_chain()


func _on_reload() -> void:
    _load_examples()


func preview_profile_copy() -> Dictionary:
    # Inspection-only helper for future headless acceptance; not shared API.
    if not _panel_available():
        return {}
    return _panel.call("profile_copy")
