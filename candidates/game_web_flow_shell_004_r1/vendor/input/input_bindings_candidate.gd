extends RefCounted
## GAME-WEB-MODULE-INPUT-001 r1
## Private candidate bindings, conflicts, defaults and optional JSON persistence.
## Never calls InputMap. Never mutates PR #6 source.

signal bindings_changed(profile: Dictionary)

const VERSION := 1
const FILE_NAME := "input_bindings_candidate.json"
const ACTIONS := ["observe", "open_door", "withdraw", "reset_round", "cancel"]
const DEFAULT_CODES := {
    "observe": KEY_1,
    "open_door": KEY_2,
    "withdraw": KEY_3,
    "reset_round": KEY_R,
    "cancel": KEY_ESCAPE
}

var _codes: Dictionary = {}


func _init() -> void:
    _codes = DEFAULT_CODES.duplicate(true)


func _result(ok: bool, changed: bool = false, error: String = "",
        conflicts: Array = []) -> Dictionary:
    return {
        "ok": ok, "changed": changed, "error": error,
        "conflicts": conflicts.duplicate(true)
    }


func _known_action(action_id: String) -> bool:
    return ACTIONS.has(action_id)


# Supported logical keycodes only; no modifiers, combinations or physical_keycode.
func _supported_code(code: int) -> bool:
    return (code >= KEY_0 and code <= KEY_9) \
        or (code >= KEY_A and code <= KEY_Z) \
        or (code >= KEY_F1 and code <= KEY_F12) \
        or [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE,
            KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT].has(code)


func _numeric_code(value: Variant) -> int:
    var kind := typeof(value)
    if kind != TYPE_INT and kind != TYPE_FLOAT:
        return -1
    var numeric := float(value)
    if not is_finite(numeric) or numeric != floor(numeric):
        return -1
    if numeric < 1.0 or numeric > 16777215.0:
        return -1
    var code := int(numeric)
    if not _supported_code(code):
        return -1
    return code


func binding_for(action_id: StringName) -> int:
    if not _known_action(String(action_id)):
        return -1
    return int(_codes[String(action_id)])


func default_binding_for(action_id: StringName) -> int:
    if not _known_action(String(action_id)):
        return -1
    return int(DEFAULT_CODES[String(action_id)])


func profile() -> Dictionary:
    var entries: Array[Dictionary] = []
    for action_id in ACTIONS:
        entries.append({
            "action_id": action_id,
            "keycode": int(_codes[action_id])
        })
    return {"version": VERSION, "bindings": entries}


# Conflicts of a proposed binding with OTHER existing actions only.
func check_conflicts(action_id: StringName, proposed_code: Variant) -> Array[Dictionary]:
    var conflicts: Array[Dictionary] = []
    var action := String(action_id)
    var code := _numeric_code(proposed_code)
    if not _known_action(action) or code < 0:
        return conflicts
    for other_action in ACTIONS:
        if other_action != action and int(_codes[other_action]) == code:
            conflicts.append({
                "keycode": code,
                "action_ids": [other_action, action]
            })
    return conflicts


func rebind(action_id: StringName, proposed_code: Variant) -> Dictionary:
    var action := String(action_id)
    if not _known_action(action):
        return _result(false, false, "Unknown action")
    var code := _numeric_code(proposed_code)
    if code < 0:
        return _result(false, false, "Unsupported keycode")
    var collisions := check_conflicts(action_id, code)
    if not collisions.is_empty():
        return _result(false, false, "Keycode already assigned", collisions)
    if int(_codes[action]) == code:
        return _result(true)
    _codes[action] = code
    bindings_changed.emit(profile())
    return _result(true, true)


# Reset one action is intentionally rejected if its default is now occupied.
func reset_action(action_id: StringName) -> Dictionary:
    if not _known_action(String(action_id)):
        return _result(false, false, "Unknown action")
    return rebind(action_id, default_binding_for(action_id))


# Atomic reset of the entire map, including conflicts introduced by remapping.
func restore_defaults() -> Dictionary:
    if _codes == DEFAULT_CODES:
        return _result(true)
    _codes = DEFAULT_CODES.duplicate(true)
    bindings_changed.emit(profile())
    return _result(true, true)


# Returns normalized bindings; rejects extras, unknown actions and duplicate keys.
# JSON numbers are floats on some Godot paths; integral floats are normalized.
func inspect_profile(candidate: Variant) -> Dictionary:
    if typeof(candidate) != TYPE_DICTIONARY:
        return _inspection_error("Root must be an object")
    var data: Dictionary = candidate
    if data.size() != 2 or not data.has("version") or not data.has("bindings"):
        return _inspection_error("Exactly version and bindings are required")
    var version_value: Variant = data["version"]
    var version_kind := typeof(version_value)
    if version_kind != TYPE_INT and version_kind != TYPE_FLOAT:
        return _inspection_error("Version must be numeric")
    if not is_finite(float(version_value)) or float(version_value) != float(VERSION):
        return _inspection_error("Unsupported version")
    if typeof(data["bindings"]) != TYPE_ARRAY:
        return _inspection_error("Bindings must be an array")
    var entries: Array = data["bindings"]
    if entries.size() != ACTIONS.size():
        return _inspection_error("A binding for every action is required")

    var proposed: Dictionary = {}
    var owner_by_code: Dictionary = {}
    var collisions: Array[Dictionary] = []
    for entry in entries:
        if typeof(entry) != TYPE_DICTIONARY:
            return _inspection_error("Each binding must be an object")
        var item: Dictionary = entry
        if item.size() != 2 or not item.has("action_id") or not item.has("keycode"):
            return _inspection_error("Each binding needs action_id and keycode only")
        if typeof(item["action_id"]) != TYPE_STRING:
            return _inspection_error("action_id must be a string")
        var action: String = item["action_id"]
        if not _known_action(action):
            return _inspection_error("Unknown action: " + action)
        if proposed.has(action):
            return _inspection_error("Duplicate action: " + action)
        var code := _numeric_code(item["keycode"])
        if code < 0:
            return _inspection_error("Unsupported keycode for " + action)
        proposed[action] = code
        if owner_by_code.has(code):
            collisions.append({
                "keycode": code,
                "action_ids": [owner_by_code[code], action]
            })
        else:
            owner_by_code[code] = action

    if not collisions.is_empty():
        return {
            "ok": false, "error": "Conflicting keycodes",
            "conflicts": collisions, "normalized": {}
        }
    if proposed.size() != ACTIONS.size():
        return _inspection_error("Missing actions")
    return {
        "ok": true, "error": "", "conflicts": [],
        "normalized": proposed.duplicate(true)
    }


func _inspection_error(message: String) -> Dictionary:
    return {
        "ok": false, "error": message,
        "conflicts": [], "normalized": {}
    }


# Transactional in-memory apply: invalid input cannot partially update bindings.
func apply_profile(candidate: Variant) -> Dictionary:
    var inspected := inspect_profile(candidate)
    if not inspected["ok"]:
        return _result(false, false, inspected["error"], inspected["conflicts"])
    var next_codes: Dictionary = inspected["normalized"].duplicate(true)
    if next_codes == _codes:
        return _result(true)
    _codes = next_codes
    bindings_changed.emit(profile())
    return _result(true, true)


# Pure selector for headless checks; does not dispatch to any game state.
func resolve_key_event(event: InputEventKey, blocked: bool,
        focus_owner: Control) -> StringName:
    if event == null or blocked or not event.pressed or event.echo:
        return &""
    if event.ctrl_pressed or event.alt_pressed \
            or event.shift_pressed or event.meta_pressed:
        return &""
    if text_input_focused(focus_owner):
        return &""
    var code := int(event.keycode)
    for action in ACTIONS:
        if int(_codes[action]) == code:
            return StringName(action)
    return &""


static func text_input_focused(owner: Control) -> bool:
    var current: Node = owner
    while current != null:
        if current is LineEdit or current is TextEdit:
            return true
        current = current.get_parent()
    return false


func _path_error(path: String) -> String:
    if not path.begins_with("user://"):
        return "Only user:// paths are allowed"
    var relative := path.trim_prefix("user://")
    if relative.is_empty() or relative.contains("\\") or relative.contains(":"):
        return "Invalid path syntax"
    for part in relative.split("/"):
        if part.is_empty() or part == "." or part == "..":
            return "Unsafe path segment"
    if path.get_file() != FILE_NAME:
        return "Path must end in " + FILE_NAME
    return ""


# Caller must create the parent directory; no unexpected filesystem writes.
# The fixed .tmp name follows a SINGLE-WRITER assumption only.
func save_profile(path: String) -> Dictionary:
    var path_error := _path_error(path)
    if not path_error.is_empty():
        return _result(false, false, path_error)
    if not DirAccess.dir_exists_absolute(path.get_base_dir()):
        return _result(false, false, "Destination directory missing")
    if DirAccess.dir_exists_absolute(path):
        return _result(false, false, "Destination path occupied")
    if FileAccess.file_exists(path):
        var existing := _read_profile(path)
        if not existing["ok"]:
            return _result(false, false, "Existing configuration rejected: " + existing["error"])
    var temp_path := path + ".tmp"
    if FileAccess.file_exists(temp_path) or DirAccess.dir_exists_absolute(temp_path):
        return _result(false, false, "Temporary path occupied")
    var file := FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        return _result(false, false, "Cannot create temporary file")
    file.store_string(JSON.stringify(profile(), "  "))
    file.flush()
    var write_error := file.get_error()
    file.close()
    if write_error != OK:
        DirAccess.remove_absolute(temp_path)
        return _result(false, false, "Temporary write failed")
    var rename_error := DirAccess.rename_absolute(temp_path, path)
    if rename_error != OK:
        DirAccess.remove_absolute(temp_path)
        return _result(false, false, "Rename failed: " + str(rename_error))
    return _result(true, true)


func _read_profile(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return _result(false, false, "Cannot read configuration")
    var source := file.get_as_text()
    file.close()
    var parser := JSON.new()
    if parser.parse(source) != OK:
        return _result(false, false, "Invalid JSON: " + parser.get_error_message())
    var inspected := inspect_profile(parser.data)
    if not inspected["ok"]:
        return _result(false, false, inspected["error"], inspected["conflicts"])
    return {
        "ok": true, "data": parser.data, "error": "", "conflicts": []
    }


func load_profile(path: String) -> Dictionary:
    var path_error := _path_error(path)
    if not path_error.is_empty():
        return _result(false, false, path_error)
    var loaded := _read_profile(path)
    if not loaded["ok"]:
        return _result(false, false, loaded["error"], loaded["conflicts"])
    return apply_profile(loaded["data"])
