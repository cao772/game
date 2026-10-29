extends PanelContainer
## GAME-WEB-MODULE-REGION-002 r1 / same independent PR #10 candidate.
## Generic placeholder-only UI; no state, save, or global input integration.
## No tests or Godot code were run during this authoring task.

signal interaction_requested(target_id: StringName)
signal prompt_visibility_changed(is_shown: bool)
signal placeholder_changed(target_id: StringName)
signal target_list_changed(target_count: int)
signal focus_state_changed(role: StringName)
signal style_changed()
# Coalesced, read-only local UI state notification; not a shared API.
signal prompt_state_changed(snapshot: Dictionary)

@onready var _padding: MarginContainer = $Padding
@onready var _target_label: Label = $Padding/Content/TargetLabel
@onready var _position_label: Label = $Padding/Content/PositionLabel
@onready var _hint_label: Label = $Padding/Content/HintLabel
@onready var _previous_button: Button = $Padding/Content/Navigation/PreviousButton
@onready var _next_button: Button = $Padding/Content/Navigation/NextButton
@onready var _action_button: Button = $Padding/Content/ActionButton
@onready var _dismiss_button: Button = $Padding/Content/DismissButton
@onready var _navigation: HBoxContainer = $Padding/Content/Navigation

var _active_target: StringName = &""
var _targets: Array[Dictionary] = []
var _active_index: int = -1
var _restore_focus: Control = null
var _last_focus_role: StringName = &"none"
var _request_count: int = 0
var _style: Dictionary = {}
var _state_revision: int = 0
var _state_update_queued: bool = false
var _last_emitted_state: Dictionary = {}


func _ready() -> void:
    hide()
    _style = _default_style()

    for button in [_previous_button, _next_button, _action_button, _dismiss_button]:
        button.focus_mode = Control.FOCUS_ALL
        button.focus_entered.connect(_sync_focus_state)
        button.focus_exited.connect(_schedule_focus_sync)

    _previous_button.pressed.connect(_on_previous_pressed)
    _next_button.pressed.connect(_on_next_pressed)
    _action_button.pressed.connect(_on_action_pressed)
    _dismiss_button.pressed.connect(hide_prompt)

    _navigation.visible = false
    _update_focus_graph()
    _render_style()
    set_process_unhandled_key_input(true)
    # Native window focus may change without a button focus-entered signal.
    get_window().focus_entered.connect(_schedule_focus_sync)
    get_window().focus_exited.connect(_schedule_focus_sync)
    _last_emitted_state = _state_core()


func _valid_text(value: Variant, limit: int) -> bool:
    return value is String and not value.strip_edges().is_empty() and value.length() <= limit


func _normalize_targets(input_targets: Array) -> Array[Dictionary]:
    var normalized: Array[Dictionary] = []
    if input_targets.is_empty() or input_targets.size() > 16:
        return normalized

    var unique_ids: Dictionary = {}
    for item in input_targets:
        if not item is Dictionary:
            return []
        var entry: Dictionary = item
        if not entry.has("id") or not entry.has("label"):
            return []

        var raw_id: Variant = entry["id"]
        if not (raw_id is StringName or raw_id is String):
            return []
        var target_id := StringName(str(raw_id))
        if str(target_id).strip_edges().is_empty() or str(target_id).length() > 64:
            return []
        if unique_ids.has(target_id):
            return []

        var label: Variant = entry["label"]
        var caption: Variant = entry.get("action_caption", "交互")
        if not _valid_text(label, 64) or not _valid_text(caption, 40):
            return []

        unique_ids[target_id] = true
        normalized.append({
            "id": target_id,
            "label": String(label),
            "action_caption": String(caption)
        })
    return normalized


# Backwards-compatible r1 entry point. A single-target list is installed.
func show_for_target(
    target_id: StringName,
    display_name: String,
    action_caption: String = "交互"
) -> bool:
    return show_for_targets([{
        "id": target_id,
        "label": display_name,
        "action_caption": action_caption
    }], 0)


# Explicit, bounded list; never discovers characters or world objects.
# Invalid lists/indexes are rejected atomically without changing UI state.
func show_for_targets(input_targets: Array, initial_index: int = 0) -> bool:
    if not is_inside_tree():
        return false
    var proposed: Array[Dictionary] = _normalize_targets(input_targets)
    if proposed.is_empty() or initial_index < 0 or initial_index >= proposed.size():
        return false

    var was_shown: bool = is_prompt_shown()
    if not was_shown:
        var owner: Control = get_viewport().gui_get_focus_owner()
        if owner != null and not is_ancestor_of(owner):
            _restore_focus = owner
        else:
            _restore_focus = null

    _targets = proposed
    _active_index = initial_index
    _active_target = _targets[_active_index]["id"]

    _navigation.visible = _targets.size() > 1
    _update_focus_graph()
    _render_target()
    show()

    # Opening captures action focus; list replacement preserves the control
    # already focused within the prompt rather than stealing it mid-action.
    if not was_shown or _current_focus_role() == &"none":
        _action_button.grab_focus()
    _sync_focus_state()

    target_list_changed.emit(_targets.size())
    placeholder_changed.emit(_active_target)
    if not was_shown:
        prompt_visibility_changed.emit(true)
    _queue_state_emit()
    return true


# Selection is local UI state. It emits no gameplay interaction.
func select_target(index: int) -> bool:
    if not is_prompt_shown() or index < 0 or index >= _targets.size():
        return false
    if index == _active_index:
        return true
    _active_index = index
    _active_target = _targets[index]["id"]
    _render_target()
    placeholder_changed.emit(_active_target)
    _queue_state_emit()
    return true


# Replace the visible list while preserving selection by stable placeholder ID.
# preferred_id is a hint: if absent, the current ID is kept when available.
# If removed, the previous index is clamped into the next list. No action fires.
# An empty/invalid list is rejected atomically, never interpreted as dismissal.
func synchronize_targets(input_targets: Array, preferred_id: StringName = &"") -> bool:
    if not is_inside_tree() or not is_prompt_shown():
        return false
    var proposed: Array[Dictionary] = _normalize_targets(input_targets)
    if proposed.is_empty():
        return false

    var old_id: StringName = _active_target
    var new_index: int = -1

    if preferred_id != &"":
        for i in range(proposed.size()):
            if proposed[i]["id"] == preferred_id:
                new_index = i
                break

    if new_index < 0:
        for i in range(proposed.size()):
            if proposed[i]["id"] == old_id:
                new_index = i
                break

    if new_index < 0:
        new_index = mini(_active_index, proposed.size() - 1)

    _targets = proposed
    _active_index = new_index
    _active_target = proposed[new_index]["id"]
    _navigation.visible = _targets.size() > 1
    _update_focus_graph()
    _render_target()

    # Navigation can disappear while its Button owned focus.
    # Reacquire action only when there is no valid prompt control focused.
    if _current_focus_role() == &"none":
        _action_button.grab_focus()
    _sync_focus_state()

    target_list_changed.emit(_targets.size())
    if old_id != _active_target:
        placeholder_changed.emit(_active_target)
    _queue_state_emit()
    return true


# Direction must be -1 or 1. Cycling wraps within the explicit target list.
func cycle_target(direction: int) -> bool:
    if not is_prompt_shown() or _targets.size() < 2:
        return false
    if direction != -1 and direction != 1:
        return false
    var next_index: int = (_active_index + direction + _targets.size()) % _targets.size()
    return select_target(next_index)


func _render_target() -> void:
    var entry: Dictionary = _targets[_active_index]
    _target_label.text = "目标：" + str(entry["label"])
    _position_label.text = "占位目标 %d / %d" % [_active_index + 1, _targets.size()]
    _action_button.text = str(entry["action_caption"])
    _hint_label.text = "Tab / Shift+Tab 焦点；PgUp / PgDn 切换；Esc 隐藏"


func _update_focus_graph() -> void:
    var controls: Array[Button] = []
    if _targets.size() > 1:
        controls.append(_previous_button)
        controls.append(_next_button)
    controls.append(_action_button)
    controls.append(_dismiss_button)

    for index in range(controls.size()):
        var button: Button = controls[index]
        var next_button: Button = controls[(index + 1) % controls.size()]
        var previous_button: Button = controls[(index - 1 + controls.size()) % controls.size()]
        button.focus_next = button.get_path_to(next_button)
        button.focus_previous = button.get_path_to(previous_button)
        button.focus_neighbor_bottom = button.get_path_to(next_button)
        button.focus_neighbor_top = button.get_path_to(previous_button)


func hide_prompt() -> bool:
    var was_shown: bool = is_prompt_shown()
    hide()
    _active_target = &""
    _targets.clear()
    _active_index = -1
    _navigation.visible = false
    _update_focus_graph()
    _publish_focus_role(&"none")

    if not was_shown:
        _restore_focus = null
        return false

    if is_instance_valid(_restore_focus):
        if _restore_focus.is_inside_tree() and _restore_focus.is_visible_in_tree():
            if _restore_focus.focus_mode != Control.FOCUS_NONE:
                _restore_focus.grab_focus()
    _restore_focus = null
    target_list_changed.emit(0)
    prompt_visibility_changed.emit(false)
    _queue_state_emit()
    return true


func is_prompt_shown() -> bool:
    return visible and _active_target != &""


func active_target_id() -> StringName:
    return _active_target


func target_count() -> int:
    return _targets.size()


func active_target_index() -> int:
    return _active_index


func request_count() -> int:
    return _request_count


# Snapshot is computed from the current widget state and viewport focus.
# Revision increments on coalesced state signals, not on every method call.
func state_snapshot() -> Dictionary:
    var result: Dictionary = _state_core()
    result["revision"] = _state_revision
    return result


func _state_core() -> Dictionary:
    var ids: Array[StringName] = []
    for item in _targets:
        ids.append(item["id"])
    return {
        "shown": is_prompt_shown(),
        "target_id": _active_target,
        "target_index": _active_index,
        "target_count": _targets.size(),
        "target_ids": ids,
        "focus_role": _current_focus_role(),
        "request_count": _request_count,
        "style": _style.duplicate(true)
    }


func _queue_state_emit() -> void:
    if not is_inside_tree() or _state_update_queued:
        return
    _state_update_queued = true
    call_deferred("_flush_state_emit")


func _flush_state_emit() -> void:
    _state_update_queued = false
    if not is_inside_tree():
        return
    var current: Dictionary = _state_core()
    if current == _last_emitted_state:
        return
    _last_emitted_state = current.duplicate(true)
    _state_revision += 1
    current["revision"] = _state_revision
    prompt_state_changed.emit(current.duplicate(true))


# Reads actual Viewport focus; a cached signal is not used as a false claim.
func focus_state() -> Dictionary:
    return {
        "shown": is_prompt_shown(),
        "role": _current_focus_role(),
        "target_id": _active_target,
        "target_index": _active_index,
        "target_count": _targets.size()
    }


func _current_focus_role() -> StringName:
    if not is_inside_tree() or not is_prompt_shown():
        return &"none"
    if not get_window().has_focus():
        return &"none"
    var owner: Control = get_viewport().gui_get_focus_owner()
    if owner == _previous_button and _navigation.visible:
        return &"previous"
    if owner == _next_button and _navigation.visible:
        return &"next"
    if owner == _action_button:
        return &"action"
    if owner == _dismiss_button:
        return &"dismiss"
    return &"none"


func _publish_focus_role(role: StringName) -> void:
    if role == _last_focus_role:
        return
    _last_focus_role = role
    focus_state_changed.emit(role)
    _queue_state_emit()


func _sync_focus_state() -> void:
    _publish_focus_role(_current_focus_role())


func _schedule_focus_sync() -> void:
    # A deferred read avoids reporting a transient 'none' when Tab moves
    # between two prompt buttons during the same UI event.
    call_deferred("_sync_focus_state")


# Theme dictionaries accept only the documented keys and bounded types.
# Invalid options leave the existing theme unchanged (atomic validation).
func apply_style(options: Dictionary) -> bool:
    if not is_inside_tree():
        return false
    var proposed: Dictionary = _style.duplicate(true)
    for key in options:
        if not (key is String) or not proposed.has(key):
            return false
        var value: Variant = options[key]
        match key:
            "background", "border", "text", "hint", "button_bg", "button_hover", "focus":
                if not value is Color:
                    return false
            "padding":
                if typeof(value) != TYPE_INT or value < 4 or value > 36:
                    return false
            "font_size":
                if typeof(value) != TYPE_INT or value < 12 or value > 30:
                    return false
            "corner_radius":
                if typeof(value) != TYPE_INT or value < 0 or value > 24:
                    return false
            "border_width":
                if typeof(value) != TYPE_INT or value < 0 or value > 5:
                    return false
            _:
                return false
        proposed[key] = value

    _style = proposed
    _render_style()
    style_changed.emit()
    _queue_state_emit()
    return true


func style_snapshot() -> Dictionary:
    return _style.duplicate(true)


func apply_style_preset(preset: StringName) -> bool:
    match preset:
        &"default":
            return apply_style(_default_style())
        &"high_contrast":
            return apply_style({
                "background": Color(0.035, 0.04, 0.06, 0.98),
                "border": Color(0.95, 0.95, 0.97, 1.0),
                "text": Color(1.0, 1.0, 1.0, 1.0),
                "hint": Color(0.92, 0.94, 1.0, 1.0),
                "button_bg": Color(0.12, 0.14, 0.19, 1.0),
                "button_hover": Color(0.26, 0.29, 0.34, 1.0),
                "focus": Color(1.0, 0.83, 0.2, 1.0),
                "padding": 16,
                "font_size": 18,
                "corner_radius": 4,
                "border_width": 2
            })
        _:
            return false


func _default_style() -> Dictionary:
    return {
        "background": Color(0.10, 0.13, 0.19, 0.96),
        "border": Color(0.34, 0.43, 0.58, 1.0),
        "text": Color(0.95, 0.96, 0.98, 1.0),
        "hint": Color(0.76, 0.82, 0.90, 1.0),
        "button_bg": Color(0.20, 0.27, 0.37, 1.0),
        "button_hover": Color(0.26, 0.36, 0.49, 1.0),
        "focus": Color(0.96, 0.76, 0.31, 1.0),
        "padding": 12,
        "font_size": 16,
        "corner_radius": 8,
        "border_width": 1
    }


func _box_style(bg: Color, line: Color, line_width: int, radius: int) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = bg
    box.border_color = line
    box.set_border_width_all(line_width)
    box.set_corner_radius_all(radius)
    return box


func _render_style() -> void:
    var pad: int = _style["padding"]
    for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
        _padding.add_theme_constant_override(side, pad)

    add_theme_stylebox_override("panel", _box_style(
        _style["background"], _style["border"],
        _style["border_width"], _style["corner_radius"]
    ))

    for label in [_target_label, _position_label, _hint_label]:
        label.add_theme_font_size_override("font_size", _style["font_size"])
        label.add_theme_color_override("font_color", _style["text"])
    _hint_label.add_theme_color_override("font_color", _style["hint"])

    for button in [_previous_button, _next_button, _action_button, _dismiss_button]:
        button.add_theme_font_size_override("font_size", _style["font_size"])
        for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
            button.add_theme_color_override(color_name, _style["text"])
        button.add_theme_stylebox_override("normal", _box_style(
            _style["button_bg"], _style["border"], 1, _style["corner_radius"]
        ))
        button.add_theme_stylebox_override("hover", _box_style(
            _style["button_hover"], _style["border"], 1, _style["corner_radius"]
        ))
        button.add_theme_stylebox_override("pressed", _box_style(
            _style["button_hover"], _style["border"], 1, _style["corner_radius"]
        ))
        var focus_box := _box_style(
            Color(0.0, 0.0, 0.0, 0.0), _style["focus"], 3,
            _style["corner_radius"]
        )
        focus_box.draw_center = false
        button.add_theme_stylebox_override("focus", focus_box)


# Test seam preserved: optional override affects native focus only.
# Tree pause always blocks; no world-state mutation or persistence.
func request_interaction(blocked_override: Variant = null) -> bool:
    if not is_inside_tree() or not is_prompt_shown():
        return false
    if get_tree().paused:
        return false
    var blocked: bool = not get_window().has_focus()
    if blocked_override != null:
        blocked = bool(blocked_override)
    if blocked:
        return false
    _request_count += 1
    interaction_requested.emit(_active_target)
    _queue_state_emit()
    return true


func _on_action_pressed() -> void:
    request_interaction()


func _on_previous_pressed() -> void:
    cycle_target(-1)


func _on_next_pressed() -> void:
    cycle_target(1)


# Only page switching and Escape while prompt owns focus; never 1/2/3/R.
func _unhandled_key_input(event: InputEvent) -> void:
    if not is_prompt_shown() or get_tree().paused or not get_window().has_focus():
        return
    if not event is InputEventKey:
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    if key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed:
        return
    if _current_focus_role() == &"none":
        return

    if key_event.keycode == KEY_ESCAPE:
        hide_prompt()
        get_viewport().set_input_as_handled()
        return
    if key_event.keycode == KEY_PAGEUP and cycle_target(-1):
        get_viewport().set_input_as_handled()
    elif key_event.keycode == KEY_PAGEDOWN and cycle_target(1):
        get_viewport().set_input_as_handled()
