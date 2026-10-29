extends Node
## GAME-WEB-INPUT-001 r1
## Independent input routing candidate. No InputMap changes.

signal action_requested(action_id: StringName)


func _ready() -> void:
    set_process_unhandled_key_input(true)


# Pure decision function: no SceneTree or window access.
static func action_for_key_event(
    event: InputEventKey,
    blocked: bool,
    focus_owner: Control
) -> StringName:
    if event == null or blocked:
        return &""

    # Echo suppression; no persistent key latch.
    if not event.pressed or event.echo:
        return &""

    if _focus_is_text_input(focus_owner):
        return &""

    match event.keycode:
        KEY_1:
            return &"observe"
        KEY_2:
            return &"open_door"
        KEY_3:
            return &"withdraw"
        KEY_R:
            return &"reset_round"
        KEY_ESCAPE:
            return &"cancel"

    return &""


static func _focus_is_text_input(
    focus_owner: Control
) -> bool:
    var current: Node = focus_owner

    while current != null:
        if current is LineEdit or current is TextEdit:
            return true
        current = current.get_parent()

    return false


static func _valid_action(action_id: StringName) -> bool:
    match action_id:
        &"observe", &"open_door", &"withdraw", \
        &"reset_round", &"cancel":
            return true

    return false


func _runtime_blocked() -> bool:
    if not is_inside_tree():
        return true

    return get_tree().paused or not get_window().has_focus()


# Shared entry point for keyboard and UI buttons.
# blocked_override is for deterministic headless testing.
# Null means use real window focus.
# SceneTree pause is always enforced.
func request_action(
    action_id: StringName,
    blocked_override: Variant = null
) -> bool:
    if not _valid_action(action_id):
        return false

    if not is_inside_tree() or get_tree().paused:
        return false

    var unfocused: bool = not get_window().has_focus()

    if blocked_override != null:
        unfocused = bool(blocked_override)

    if unfocused:
        return false

    action_requested.emit(action_id)
    return true


# Injectable routing seam for headless tests.
func route_key_event(
    event: InputEventKey,
    blocked: bool,
    focus_owner: Control
) -> bool:
    var action_id := action_for_key_event(
        event, blocked, focus_owner
    )

    if action_id == &"":
        return false

    return request_action(action_id, blocked)


# Production path reads the actual viewport focus.
func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey:
        return

    var blocked := _runtime_blocked()
    var focus_owner := get_viewport().gui_get_focus_owner()

    if route_key_event(
        event as InputEventKey,
        blocked,
        focus_owner
    ):
        get_viewport().set_input_as_handled()
