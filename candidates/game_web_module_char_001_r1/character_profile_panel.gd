extends MarginContainer
## Public (candidate only): set_profile, clear_profile, profile_copy, last_error.
## Read-only display. Never parses markup, loads portrait URLs, saves or dispatches game actions.

signal profile_accepted(profile_id: String)
signal profile_rejected(reason: String)
signal profile_cleared

const ProfileContract = preload("res://profile_contract_candidate.gd")

var _profile: Dictionary = {}
var _last_error: String = ""

@onready var _header: VBoxContainer = $Layout/Header
@onready var _name: Label = $Layout/Header/NameLabel
@onready var _subtitle: Label = $Layout/Header/SubtitleLabel
@onready var _status: Label = $Layout/Header/StatusLabel
@onready var _summary: Label = $Layout/Header/SummaryLabel
@onready var _tags: HFlowContainer = $Layout/Header/Tags
@onready var _separator: HSeparator = $Layout/Separator
@onready var _scroll: ScrollContainer = $Layout/Scroll
@onready var _sections: VBoxContainer = $Layout/Scroll/Sections
@onready var _empty: Label = $Layout/EmptyState


func _ready() -> void:
    _render()


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


func _clear_children(container: Node) -> void:
    for child in container.get_children():
        container.remove_child(child)
        child.queue_free()


func _make_text(value: String, point_size: int, tint: Color) -> Label:
    var result := Label.new()
    result.text = value
    result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    result.add_theme_font_size_override("font_size", point_size)
    result.add_theme_color_override("font_color", tint)
    return result


func _card_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#17253b")
    style.border_color = Color("#334865")
    style.set_border_width_all(1)
    style.set_corner_radius_all(10)
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 14
    style.content_margin_bottom = 14
    return style


func _add_section(section: Dictionary) -> void:
    var card := PanelContainer.new()
    card.name = "section_" + str(section["section_id"])
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.add_theme_stylebox_override("panel", _card_style())

    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 11)
    card.add_child(body)
    body.add_child(_make_text(section["heading"], 18, Color("#f2f5fb")))

    var entries: Array = section["items"]
    if entries.is_empty():
        body.add_child(_make_text("暂无条目", 13, Color("#b6c4d8")))
    else:
        for index in range(entries.size()):
            var entry: Dictionary = entries[index]
            var entry_box := VBoxContainer.new()
            entry_box.name = "item_%d" % index
            entry_box.add_theme_constant_override("separation", 4)
            entry_box.add_child(_make_text(entry["label"], 12, Color("#aebed6")))
            entry_box.add_child(_make_text(entry["value"], 15, Color("#eef3fa")))
            body.add_child(entry_box)
            if index != entries.size() - 1:
                body.add_child(HSeparator.new())
    _sections.add_child(card)


func _render() -> void:
    _clear_children(_tags)
    _clear_children(_sections)
    var present := not _profile.is_empty()
    _header.visible = present
    _separator.visible = present
    _scroll.visible = present
    _empty.visible = not present
    if not present:
        return

    _name.text = _profile["display_name"]
    _subtitle.text = _profile["subtitle"]
    _subtitle.visible = not _subtitle.text.is_empty()
    _status.text = _profile["status_label"]
    _status.visible = not _status.text.is_empty()
    _summary.text = _profile["summary"]
    _summary.visible = not _summary.text.is_empty()

    for tag in _profile["tags"]:
        var capsule := PanelContainer.new()
        var style := _card_style()
        style.bg_color = Color("#28405e")
        style.border_color = Color("#3e6388")
        style.set_corner_radius_all(12)
        style.content_margin_left = 10
        style.content_margin_right = 10
        style.content_margin_top = 5
        style.content_margin_bottom = 5
        capsule.add_theme_stylebox_override("panel", style)
        capsule.add_child(_make_text(tag, 12, Color("#f2f5fb")))
        _tags.add_child(capsule)
    _tags.visible = not _profile["tags"].is_empty()

    var sections: Array = _profile["sections"]
    if sections.is_empty():
        _sections.add_child(
            _make_text("暂无展示章节", 14, Color("#b6c4d8"))
        )
    else:
        for section in sections:
            _add_section(section)
    _scroll.scroll_vertical = 0
