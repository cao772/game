extends RefCounted
## GAME-WEB-REGION-006 r1: focus return policy for a single trial prompt.
## Pure state policy: never calls the OS, Node or gameplay input directly.
## Host MUST verify actual native window focus before applying a claim.

var _pending_restore: bool = false
var _was_prompt_focused: bool = false
var _saved_role: StringName = &"none"
var _saved_id: StringName = &""
var _require_key_release: bool = false
var _window_inactive: bool = false
var _revision: int = 0


func capture_window_loss(
    prior_role: StringName, selected_id: StringName, prompt_shown: bool
) -> void:
    _window_inactive = true
    _require_key_release = true
    _pending_restore = prompt_shown and selected_id != &"" and _role_allowed(prior_role)
    _was_prompt_focused = _pending_restore
    _saved_role = prior_role if _pending_restore else &"none"
    _saved_id = selected_id if _pending_restore else &""
    _revision += 1


func mark_window_returned() -> void:
    _window_inactive = false
    _revision += 1


func _role_allowed(role: StringName) -> bool:
    return role in [&"action", &"previous", &"next", &"dismiss"]


func claim_focus(
    prompt_shown: bool,
    selected_id: StringName,
    host_has_focus: bool
) -> Dictionary:
    # Claim consumes pending request exactly once; it cannot auto-confirm.
    if _window_inactive or not _pending_restore:
        return {"restore": false, "reason": "无待恢复提示焦点"}
    _pending_restore = false
    _revision += 1
    if not _was_prompt_focused or not prompt_shown or selected_id != _saved_id:
        return {"restore": false, "reason": "目标或提示状态已变化"}
    if host_has_focus:
        return {"restore": false, "reason": "宿主控件已有焦点，不抢占"}
    return {"restore": true, "role": _saved_role, "target_id": _saved_id}


func clear_pending() -> void:
    if not _pending_restore:
        return
    _pending_restore = false
    _revision += 1


func consume_key_release_gate(all_movement_keys_released: bool) -> bool:
    # Return true only when gameplay WASD input may resume after OS blur.
    if _window_inactive:
        return false
    if _require_key_release:
        if not all_movement_keys_released:
            return false
        _require_key_release = false
        _revision += 1
    return true


func reset() -> void:
    _pending_restore = false
    _was_prompt_focused = false
    _saved_role = &"none"
    _saved_id = &""
    _require_key_release = false
    _window_inactive = false
    _revision += 1


func snapshot() -> Dictionary:
    return {
        "window_inactive": _window_inactive,
        "pending_restore": _pending_restore,
        "saved_role": _saved_role,
        "saved_id": _saved_id,
        "require_key_release": _require_key_release,
        "revision": _revision
    }
