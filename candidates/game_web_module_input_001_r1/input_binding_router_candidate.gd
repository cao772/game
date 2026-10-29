extends Node
## GAME-WEB-MODULE-INPUT-001 r1
## Optional PR #6 adapter. No source edits and no global InputMap writes.
## Attach after PR #6 integration._ready(), not as an autoload.

signal action_routed(action_id: StringName)

const BindingsCandidate = preload("res://input_bindings_candidate.gd")

# Cooperative ownership only among adapters of this class in one process.
static var _integration_owners: Dictionary = {}

var bindings = BindingsCandidate.new()
var _integration: Node = null
var _legacy_router: Node = null
var _original_unhandled: bool = false


func _ready() -> void:
    set_process_unhandled_key_input(true)


func _exit_tree() -> void:
    detach_integration()


func _result(ok: bool, error: String = "", action_id: StringName = &"") -> Dictionary:
    return {"ok": ok, "error": error, "action_id": action_id}


# PR #6 integrates by request_button_action and its child InputRouterCandidate.
# Disable ONLY that child Node's native unhandled keyboard processing
# while attached, or both old fixed keys and new mapped keys would fire.
# Restore the original processing flag on detach.
func attach_integration(integration: Node) -> Dictionary:
    if _integration != null:
        return _result(false, "Already attached")
    if not is_inside_tree() or integration == null or not integration.is_inside_tree():
        return _result(false, "Both nodes must be inside SceneTree")
    if integration == self or not integration.has_method("request_button_action"):
        return _result(false, "Missing PR #6 candidate dispatch method")
    var old_router: Node = integration.get_node_or_null("InputRouterCandidate")
    if old_router == null or not old_router.has_method("request_action"):
        return _result(false, "Missing PR #6 InputRouterCandidate child")
    var key := integration.get_instance_id()
    if _integration_owners.has(key):
        return _result(false, "Integration already has an adapter")

    _integration_owners[key] = get_instance_id()
    _original_unhandled = old_router.is_processing_unhandled_key_input()
    _integration = integration
    _legacy_router = old_router
    old_router.set_process_unhandled_key_input(false)
    return _result(true)


func detach_integration() -> void:
    if _integration != null:
        var key := _integration.get_instance_id()
        if _integration_owners.get(key, 0) == get_instance_id():
            _integration_owners.erase(key)
    if is_instance_valid(_legacy_router):
        _legacy_router.set_process_unhandled_key_input(_original_unhandled)
    _legacy_router = null
    _integration = null
    _original_unhandled = false


func attached() -> bool:
    return is_instance_valid(_integration) and is_instance_valid(_legacy_router)


func _blocked_now() -> bool:
    if not is_inside_tree():
        return true
    return get_tree().paused or not get_window().has_focus()


func _dispatch_to_integration(action_id: StringName) -> bool:
    if not attached():
        return false
    return bool(_integration.call("request_button_action", action_id))


# Injectable seam. Filtering by event and dispatch gate are separate.
# The injected receiver must return bool; no snapshot writes here.
func route_key_candidate(event: InputEventKey, blocked: bool,
        focus_owner: Control, receiver: Callable) -> Dictionary:
    if not is_inside_tree() or get_tree().paused:
        return _result(false, "Paused or detached from tree")
    var action_id: StringName = bindings.resolve_key_event(
        event, blocked, focus_owner
    )
    if action_id == &"":
        return _result(false, "Key event filtered")
    if not receiver.is_valid():
        return _result(false, "No action receiver", action_id)
    if not bool(receiver.call(action_id)):
        return _result(false, "Receiver refused action", action_id)
    action_routed.emit(action_id)
    return _result(true, "", action_id)


# Production keyboard path: REAL viewport focus and native focus checks.
func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not attached():
        return
    var outcome := route_key_candidate(
        event as InputEventKey,
        _blocked_now(),
        get_viewport().gui_get_focus_owner(),
        Callable(self, "_dispatch_to_integration")
    )
    if outcome["ok"]:
        get_viewport().set_input_as_handled()


# Optional mapped UI-button entry point. Buttons select action_id, not keycode.
# It always uses actual pause, window, and text focus, not injected overrides.
func request_button_action(action_id: StringName) -> bool:
    if not attached() or _blocked_now():
        return false
    if not BindingsCandidate.ACTIONS.has(String(action_id)):
        return false
    if BindingsCandidate.text_input_focused(
        get_viewport().gui_get_focus_owner()
    ):
        return false
    if not _dispatch_to_integration(action_id):
        return false
    action_routed.emit(action_id)
    return true
