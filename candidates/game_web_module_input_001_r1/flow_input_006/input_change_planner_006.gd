extends RefCounted
## GAME-WEB-INPUT-006 r1 — pure swap planning + bounded undo journal.
## Reuses PR #15's five-action validator. No IO and no InputMap calls.
## NOT_RUN: no parser, engine, or test execution.

const MAX_HISTORY := 10
var _history: Array[Dictionary] = []


func _reject(code: String, message: String) -> Dictionary:
    return {"ok": false, "code": code, "message": message,
        "can_apply": false, "changes": [], "profile": {}}


func digest(profile: Dictionary) -> String:
    return JSON.stringify(profile).sha256_text()


func preview_swap(settings, action_id: StringName, occupied_keycode: int) -> Dictionary:
    var action := String(action_id)
    var prior_code: int = settings.bindings.binding_for(action_id)
    if prior_code < 0:
        return _reject("UNKNOWN_ACTION", "The requested action is not defined")
    var preview: Dictionary = settings.preview_rebind(action_id, occupied_keycode)
    if preview.get("code", "") != "CONFLICT":
        return _reject("NOT_A_CONFLICT", "Only an existing key collision can be swapped")
    var current: Dictionary = settings.bindings.profile()
    var owner := ""
    var owner_code := -1
    for entry in current["bindings"]:
        var entry_action: String = str(entry["action_id"])
        if entry_action != action and int(entry["keycode"]) == occupied_keycode:
            if not owner.is_empty():
                return _reject("AMBIGUOUS_OWNER", "More than one action owns this key")
            owner = entry_action
            owner_code = int(entry["keycode"])
    if owner.is_empty():
        return _reject("NO_OWNER", "The occupied key was not found")
    # Swap old and occupied keys in one detached whole-profile candidate.
    # No intermediate invalid mapping ever becomes live.
    var target: Dictionary = current.duplicate(true)
    for entry in target["bindings"]:
        if str(entry["action_id"]) == action:
            entry["keycode"] = owner_code
        elif str(entry["action_id"]) == owner:
            entry["keycode"] = prior_code
    var inspected: Dictionary = settings.bindings.inspect_profile(target)
    if not inspected["ok"]:
        return _reject("INVALID_SWAP", str(inspected["error"]))
    return {
        "ok": true, "code": "SWAP_READY", "message": "Explicit swap preview",
        "can_apply": true, "action_id": action,
        "owner_action": owner, "occupied_keycode": occupied_keycode,
        "profile": target.duplicate(true),
        "base_digest": digest(current),
        "changes": [
            {"action_id": action, "from_keycode": prior_code,
                "to_keycode": owner_code},
            {"action_id": owner, "from_keycode": owner_code,
                "to_keycode": prior_code}
        ]
    }


func record(before: Dictionary, after: Dictionary,
        scope: String, path: String = "") -> bool:
    if before == after or not ["memory", "disk"].has(scope):
        return false
    if scope == "disk" and path.is_empty():
        return false
    _history.append({
        "before": before.duplicate(true),
        "after": after.duplicate(true),
        "before_digest": digest(before),
        "after_digest": digest(after),
        "scope": scope,
        "path": path
    })
    while _history.size() > MAX_HISTORY:
        _history.remove_at(0)
    return true


func peek(current: Dictionary, active_path: String) -> Dictionary:
    if _history.is_empty():
        return _reject("NO_UNDO", "No reversible configuration change")
    var entry: Dictionary = _history.back()
    if digest(current) != str(entry["after_digest"]):
        return _reject("HISTORY_STALE", "Live bindings changed outside the journal")
    if entry["scope"] == "disk" and entry["path"] != active_path:
        return _reject("HISTORY_PATH_CHANGED", "Persisted configuration path changed")
    return {"ok": true, "code": "UNDO_READY", "can_apply": true,
        "scope": str(entry["scope"]),
        "before": entry["before"].duplicate(true),
        "after": entry["after"].duplicate(true),
        "path": str(entry["path"]), "message": ""}


func pop_after_success() -> void:
    if not _history.is_empty():
        _history.pop_back()


func clear() -> void:
    _history.clear()


func size() -> int:
    return _history.size()
