extends PanelContainer
## GAME-WEB-MODULE-REGION-001 r1 — isolated interaction prompt candidate.
## Public technical placeholder only. No story, shared event bus or save contract.
##
## A host explicitly calls show_for_target(...) / hide_prompt().
## Pressing the focused action Button via Enter/Space or clicking it emits
## interaction_requested(target_id); it does NOT change the host's state.
## Escape dismisses only while focus belongs to this prompt.

signal interaction_requested(target_id: StringName)
signal prompt_visibility_changed(is_shown: bool)
signal placeholder_changed(target_id: StringName)

@onready var _target_label: Label = $Padding/Content/TargetLabel
@onready var _hint_label: Label = $Padding/Content/HintLabel
@onready var _action_button: Button = $Padding/Content/ActionButton
@onready var _dismiss_button: Button = $Padding/Content/DismissButton

var _active_target: StringName = &""
var _restore_focus: Control = null
var _request_count: int = 0


func _ready() -> void:
    hide()
    _action_button.focus_mode = Control.FOCUS_ALL
    _dismiss_button.focus_mode = Control.FOCUS_ALL

    # Explicit Tab and reverse-Tab loop within the two prompt buttons.
    _action_button.focus_next = _action_button.get_path_to(_dismiss_button)
    _action_button.focus_previous = _action_button.get_path_to(_dismiss_button)
    _dismiss_button.focus_next = _dismiss_button.get_path_to(_action_button)
    _dismiss_button.focus_previous = _dismiss_button.get_path_to(_action_button)

    # Arrow-key navigation between the only two controls, without InputMap edits.
    _action_button.focus_neighbor_bottom = _action_button.get_path_to(_dismiss_button)
    _action_button.focus_neighbor_top = _action_button.get_path_to(_dismiss_button)
    _dismiss_button.focus_neighbor_top = _dismiss_button.get_path_to(_action_button)
    _dismiss_button.focus_neighbor_bottom = _dismiss_button.get_path_to(_action_button)

    _action_button.pressed.connect(_on_action_pressed)
    _dismiss_button.pressed.connect(hide_prompt)
    set_process_unhandled_key_input(true)


func show_for_target(
    target_id: StringName,
    display_name: String,
    action_caption: String = "交互"
) -> bool:
    # Placeholder labels only: no implicit character, lore or gameplay semantics.
    if not is_inside_tree():
        return false
    if str(target_id).strip_edges().is_empty():
        return false
    if display_name.strip_edges().is_empty() or display_name.length() > 64:
        return false
    if action_caption.strip_edges().is_empty() or action_caption.length() > 40:
        return false

    var was_shown: bool = is_prompt_shown()
    if not was_shown:
        var focus_owner: Control = get_viewport().gui_get_focus_owner()
        if focus_owner != null and not is_ancestor_of(focus_owner):
            _restore_focus = focus_owner
        else:
            _restore_focus = null

    _active_target = target_id
    _target_label.text = "目标：" + display_name
    _hint_label.text = "Tab 切换焦点；Enter / Space 确认；Esc 隐藏"
    _action_button.text = action_caption
    show()
    _action_button.grab_focus()

    placeholder_changed.emit(_active_target)
    if not was_shown:
        prompt_visibility_changed.emit(true)
    return true


func hide_prompt() -> bool:
    var was_shown: bool = is_prompt_shown()
    hide()
    _active_target = &""

    if not was_shown:
        _restore_focus = null
        return false

    # Restore only a still-valid, visible, focusable outside control.
    if is_instance_valid(_restore_focus):
        if _restore_focus.is_inside_tree():
            if _restore_focus.is_visible_in_tree():
                if _restore_focus.focus_mode != Control.FOCUS_NONE:
                    _restore_focus.grab_focus()
    _restore_focus = null
    prompt_visibility_changed.emit(false)
    return true


func is_prompt_shown() -> bool:
    return visible and _active_target != &""


func active_target_id() -> StringName:
    return _active_target


func request_count() -> int:
    return _request_count


# Test seam: blocked_override replaces ONLY native window focus.
# Pause always blocks, even if override is false.
# This is NOT a global input router and has no persistence side effects.
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
    return true


func _on_action_pressed() -> void:
    request_interaction()


func _unhandled_key_input(event: InputEvent) -> void:
    if not is_prompt_shown() or get_tree().paused:
        return
    if not get_window().has_focus():
        return
    if not event is InputEventKey:
        return

    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    if key_event.keycode != KEY_ESCAPE:
        return

    # Do not intercept Escape when focus is outside the prompt.
    var owner: Control = get_viewport().gui_get_focus_owner()
    if owner != _action_button and owner != _dismiss_button:
        return

    hide_prompt()
    get_viewport().set_input_as_handled()
