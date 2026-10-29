extends MarginContainer
## GAME-WEB-CONTINUE-CHAR-003 r1: placeholder-only UI candidate, NOT_RUN.
## No story, save or input-system changes. API names remain unapproved.

signal profile_accepted(profile_id: String)
signal profile_rejected(reason: String)
signal profile_cleared

const ProfileContract = preload("res://profile_contract_candidate.gd")
const TextLayout = preload("res://profile_text_layout_candidate.gd")
const NARROW_WIDTH := 480.0

var _profile: Dictionary = {}
var _last_error: String = ""
var _compact: bool = false
var _section_nodes: Array[Control] = []

@onready var _header: VBoxContainer = $Layout/Scroll/Content/Header
@onready var _name: Label = $Layout/Scroll/Content/Header/NameLabel
@onready var _subtitle: Label = $Layout/Scroll/Content/Header/SubtitleLabel
@onready var _status: Label = $Layout/Scroll/Content/Header/StatusLabel
@onready var _summary: Label = $Layout/Scroll/Content/Header/SummaryLabel
@onready var _tags: HFlowContainer = $Layout/Scroll/Content/Header/Tags
@onready var _separator: HSeparator = $Layout/Scroll/Content/Separator
@onready var _scroll: ScrollContainer = $Layout/Scroll
@onready var _sections: VBoxContainer = $Layout/Scroll/Content/Sections
@onready var _empty: Label = $Layout/EmptyState
@onready var _help: Label = $Layout/HelpLabel
@onready var _section_nav: HBoxContainer = $Layout/SectionNav
@onready var _section_caption: Label = $Layout/SectionNav/SectionCaption
@onready var _section_choice: OptionButton = $Layout/SectionNav/SectionChoice
@onready var _section_jump: Button = $Layout/SectionNav/SectionJump


func _ready() -> void:
    resized.connect(_on_resized)
    _section_jump.pressed.connect(_on_jump_pressed)
    _apply_layout()
    _scroll.focus_mode = Control.FOCUS_ALL
    _scroll.follow_focus = true
    if _has_property(_scroll, "draw_focus_border"):
        _scroll.set("draw_focus_border", true)
    _section_choice.focus_mode = Control.FOCUS_ALL
    _section_jump.focus_mode = Control.FOCUS_ALL
    _section_choice.focus_next = _section_choice.get_path_to(_section_jump)
    _section_jump.focus_previous = _section_jump.get_path_to(_section_choice)
    _section_jump.focus_next = _section_jump.get_path_to(_scroll)
    _scroll.focus_previous = _scroll.get_path_to(_section_jump)
    _set_assistive(_scroll, "人物资料阅读区域",
        "Tab 聚焦；上下方向键、翻页键、Home、End 浏览完整内容")
    _set_assistive(_section_choice, "章节选择")
    _set_assistive(_section_jump, "跳至所选章节")
    _set_assistive(_empty, "等待资料", _empty.text)
    _set_assistive(_help, "键盘操作提示", _help.text)
    _render()


func _has_property(subject: Object, property_name: String) -> bool:
    for entry in subject.get_property_list():
        if str(entry.get("name", "")) == property_name:
            return true
    return false


func _set_assistive(control: Control, readable_name: String, description: String = "") -> void:
    if _has_property(control, "accessibility_name"):
        control.set("accessibility_name", readable_name)
    if _has_property(control, "accessibility_description"):
        control.set("accessibility_description", description)
    var tooltip := description if not description.is_empty() else readable_name
    if tooltip.length() > 160:
        tooltip = tooltip.substr(0, 160) + "…（全文请阅读正文）"
    control.tooltip_text = tooltip


func _on_resized() -> void:
    var old_compact := _compact
    _apply_layout()
    if old_compact != _compact and is_node_ready():
        var previous_position := _scroll.scroll_vertical
        _render()
        _scroll.set_deferred("scroll_vertical", previous_position)


func _apply_layout() -> void:
    _compact = size.x < NARROW_WIDTH
    var padding := 10 if _compact else 20
    for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
        add_theme_constant_override(side, padding)
    if is_node_ready():
        _section_caption.visible = not _compact


func is_compact_layout() -> bool:
    return _compact


func set_profile(source: Variant) -> bool:
    var checked: Dictionary = ProfileContract.validate(source)
    if not checked["ok"]:
        _last_error = checked["error"]
        profile_rejected.emit(_last_error)
        return false
    _profile = checked["data"].duplicate(true)
    _last_error = ""
    if is_node_ready():
        _render()
    profile_accepted.emit(_profile["profile_id"])
    return true


func clear_profile() -> void:
    _profile.clear()
    _last_error = ""
    if is_node_ready():
        _render()
    profile_cleared.emit()


func profile_copy() -> Dictionary:
    return _profile.duplicate(true)


func last_error() -> String:
    return _last_error


func section_count() -> int:
    return _section_nodes.size()


func _clear_children(container: Node) -> void:
    for child in container.get_children():
        container.remove_child(child)
        child.queue_free()


func _write_label(label: Label, value: String) -> void:
    label.text = TextLayout.visible_text(value)
    label.autowrap_mode = TextLayout.wrap_mode(label.text)
    label.clip_text = false
    label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.custom_minimum_size = Vector2.ZERO


func _make_text(value: String, point_size: int, tint: Color, context: String = "") -> Label:
    var result := Label.new()
    _write_label(result, value)
    result.add_theme_font_size_override("font_size", point_size)
    result.add_theme_color_override("font_color", tint)
    if not context.is_empty():
        _set_assistive(result, context, value)
    return result


func _card_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#17253b")
    style.border_color = Color("#486383")
    style.set_border_width_all(1)
    style.set_corner_radius_all(9)
    var padding := 9 if _compact else 16
    style.content_margin_left = padding
    style.content_margin_right = padding
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    return style


func _add_section(section: Dictionary) -> void:
    var card := PanelContainer.new()
    card.name = "section_" + str(section["section_id"])
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.add_theme_stylebox_override("panel", _card_style())
    _set_assistive(card, "资料章节：" + section["heading"])

    var body := VBoxContainer.new()
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 10)
    card.add_child(body)
    body.add_child(_make_text(section["heading"], 18, Color("#f2f5fb"), "章节标题"))

    var entries: Array = section["items"]
    if entries.is_empty():
        body.add_child(_make_text("暂无条目", 14, Color("#cbd7e9"), "空章节"))
    else:
        for index in range(entries.size()):
            var entry: Dictionary = entries[index]
            var entry_box := VBoxContainer.new()
            entry_box.name = "item_%d" % index
            entry_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            entry_box.add_theme_constant_override("separation", 5)
            entry_box.add_child(_make_text(entry["label"], 13, Color("#b9cce5"), "字段名称"))
            entry_box.add_child(_make_text(entry["value"], 16, Color("#eef3fa"), entry["label"]))
            body.add_child(entry_box)
            if index != entries.size() - 1:
                body.add_child(HSeparator.new())
    _sections.add_child(card)
    _section_nodes.append(card)


func _on_jump_pressed() -> void:
    var index := _section_choice.selected
    if index < 0 or index >= _section_nodes.size():
        return
    var selected_node: Control = _section_nodes[index]
    if is_instance_valid(selected_node) and selected_node.is_inside_tree():
        _scroll.ensure_control_visible(selected_node)


func _render() -> void:
    _clear_children(_tags)
    _clear_children(_sections)
    _section_nodes.clear()
    _section_choice.clear()

    var present := not _profile.is_empty()
    _header.visible = present
    _separator.visible = present
    _scroll.visible = present
    _empty.visible = not present
    _help.visible = present
    _section_nav.visible = false
    if not present:
        _section_jump.disabled = true
        return

    _write_label(_name, _profile["display_name"])
    _write_label(_subtitle, _profile["subtitle"])
    _subtitle.visible = not _subtitle.text.is_empty()
    _write_label(_status, _profile["status_label"])
    _status.visible = not _status.text.is_empty()
    _write_label(_summary, _profile["summary"])
    _summary.visible = not _summary.text.is_empty()
    _set_assistive(_name, "资料名称", _name.text)
    _set_assistive(_subtitle, "副标题", _subtitle.text)
    _set_assistive(_status, "状态", _status.text)
    _set_assistive(_summary, "摘要", _summary.text)

    for tag in _profile["tags"]:
        var capsule := PanelContainer.new()
        var style := _card_style()
        style.bg_color = Color("#294663")
        style.border_color = Color("#5c84ac")
        style.set_corner_radius_all(12)
        style.content_margin_left = 9
        style.content_margin_right = 9
        style.content_margin_top = 5
        style.content_margin_bottom = 5
        capsule.add_theme_stylebox_override("panel", style)
        capsule.add_child(_make_text(tag, 13, Color("#f2f5fb"), "资料标签"))
        _tags.add_child(capsule)
    _tags.visible = not _profile["tags"].is_empty()

    var sections: Array = _profile["sections"]
    _section_nav.visible = not sections.is_empty()
    if sections.is_empty():
        _sections.add_child(_make_text("暂无展示章节", 15, Color("#cbd7e9"), "空章节列表"))
        _section_jump.disabled = true
    else:
        for section in sections:
            _add_section(section)
            _section_choice.add_item(section["heading"])
        _section_choice.select(0)
        _section_jump.disabled = false

    _scroll.scroll_vertical = 0
