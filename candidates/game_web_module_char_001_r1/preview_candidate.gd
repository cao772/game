extends MarginContainer
## Local synthetic preview only. Explicit reload, bounded reads and atomic parsing.
## No private sources, external URLs, user inputs or gameplay state.

const FixtureLoader = preload("res://placeholder_fixture_loader_candidate.gd")
const FIXTURE_PATH := "res://placeholder_profiles.json"

var _examples: Array[Dictionary] = []
var _narrow: bool = false

@onready var _choice: OptionButton = $Layout/Toolbar/Choice
@onready var _clear_button: Button = $Layout/Toolbar/Clear
@onready var _reload_button: Button = $Layout/Toolbar/Reload
@onready var _status: Label = $Layout/Status
@onready var _panel = $Layout/Panel
@onready var _reading_area: ScrollContainer = $Layout/Panel/Layout/Scroll


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
    _reload_button.focus_next = _reload_button.get_path_to(_reading_area)
    _reading_area.focus_previous = _reading_area.get_path_to(_reload_button)
    _mark_accessible(_choice, "占位记录选择")
    _mark_accessible(_clear_button, "清除预览")
    _mark_accessible(_reload_button, "重新加载占位数据")
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


func _reset_preview() -> void:
    _examples.clear()
    _choice.clear()
    _choice.disabled = true
    _clear_button.disabled = true
    _panel.clear_profile()


func _status_message(message: String, is_error: bool = false) -> void:
    _status.text = message
    _status.add_theme_color_override(
        "font_color", Color("#ffd5d5") if is_error else Color("#d8e7fa")
    )
    _status.tooltip_text = message


func _load_examples() -> void:
    _reset_preview()
    _status_message("读取占位资料中")
    var stream := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
    if stream == null:
        _status_message("占位资料文件不可读取；可尝试重新加载", true)
        return
    var byte_length := stream.get_length()
    if byte_length > FixtureLoader.MAX_FIXTURE_BYTES:
        stream.close()
        _status_message("占位文件超过尺寸限制", true)
        return
    var raw := stream.get_as_text()
    stream.close()
    var parsed: Dictionary = FixtureLoader.parse_text(raw)
    if not parsed["ok"]:
        _status_message("加载失败：" + parsed["error"], true)
        return

    for profile in parsed["data"]:
        _examples.append(profile.duplicate(true))
        _choice.add_item(profile["display_name"])
    _choice.disabled = false
    _choice.select(0)
    _on_chosen(0)


func _on_chosen(index: int) -> void:
    if index < 0 or index >= _examples.size():
        _status_message("记录索引无效；未修改当前展示", true)
        return
    if _panel.set_profile(_examples[index]):
        _clear_button.disabled = false
        _status_message("仅供技术预览，未关联正式人物或正史")
    else:
        _status_message("无法展示：" + _panel.last_error(), true)


func _on_clear() -> void:
    _panel.clear_profile()
    _choice.select(-1)
    _clear_button.disabled = true
    _status_message("已清空展示；可重新选择占位记录")


func _on_reload() -> void:
    _load_examples()
