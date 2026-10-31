extends RefCounted
## GAME-WEB-MODULE-INPUT-002 r1
## Isolated optional settings façade for MODULE-INPUT-001 (PR #15).
## Proposal only. No InputMap writes, no snapshots, no autoload.
## Code and tests: NOT_RUN.

signal configuration_changed(profile: Dictionary)
signal operation_reported(feedback: Dictionary)

const BindingsCandidate = preload("res://vendor/input/input_bindings_candidate.gd")
const ALTERNATIVES := [
    KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0,
    KEY_Q, KEY_W, KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P,
    KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_H, KEY_J, KEY_K,
    KEY_L, KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N, KEY_M
]

# Intentionally exposed for an isolated host:
# adapter.bindings = settings.bindings
var bindings = BindingsCandidate.new()
var _known_disk_hashes: Dictionary = {}
var _busy: bool = false


func _init() -> void:
    bindings.bindings_changed.connect(_on_bindings_changed)


func _on_bindings_changed(profile: Dictionary) -> void:
    configuration_changed.emit(profile.duplicate(true))


func _feedback(
    ok: bool, code: String, message: String,
    changed: bool = false, persisted: bool = false,
    action_id: StringName = &"", conflicts: Array = []
) -> Dictionary:
    return {
        "ok": ok,
        "code": code,
        "message": message,
        "changed": changed,
        "persisted": persisted,
        "action_id": String(action_id),
        "conflicts": conflicts.duplicate(true)
    }


func _report(result: Dictionary) -> Dictionary:
    operation_reported.emit(result.duplicate(true))
    return result


func current_profile() -> Dictionary:
    return bindings.profile().duplicate(true)


func key_display(code: int) -> String:
    if code >= KEY_A and code <= KEY_Z:
        return String.chr(code)
    if code >= KEY_0 and code <= KEY_9:
        return String.chr(code)
    if code >= KEY_F1 and code <= KEY_F12:
        return "F" + str(code - KEY_F1 + 1)
    match code:
        KEY_ESCAPE:
            return "Escape"
        KEY_ENTER:
            return "Enter"
        KEY_KP_ENTER:
            return "Num Enter"
        KEY_SPACE:
            return "Space"
        KEY_UP:
            return "Up"
        KEY_DOWN:
            return "Down"
        KEY_LEFT:
            return "Left"
        KEY_RIGHT:
            return "Right"
    return "Key " + str(code)


func _free_alternatives(exclude_action: StringName, maximum: int = 3) -> Array[Dictionary]:
    var output: Array[Dictionary] = []
    for code in ALTERNATIVES:
        if not bindings.check_conflicts(exclude_action, code).is_empty():
            continue
        var own_binding := bindings.binding_for(exclude_action)
        if code == own_binding:
            continue
        output.append({"keycode": code, "key_label": key_display(code)})
        if output.size() >= maximum:
            break
    return output


# PURE PREVIEW: does not mutate config, perform IO, or emit a signal.
# No invented automatic swap/override: all collisions require user decision.
func preview_rebind(action_id: StringName, keycode: Variant) -> Dictionary:
    var previous := bindings.binding_for(action_id)
    var preview := {
        "ok": false,
        "can_apply": false,
        "changed": false,
        "code": "",
        "message": "",
        "action_id": String(action_id),
        "current_keycode": previous,
        "current_key_label": key_display(previous),
        "proposed_keycode": keycode,
        "proposed_key_label": "",
        "conflicts": [],
        "alternatives": []
    }
    if previous < 0:
        preview["code"] = "UNKNOWN_ACTION"
        preview["message"] = "Unknown action"
        return preview

    # Delegate validation to PR #15's unchanged inspect_profile.
    var proposed_profile := bindings.profile()
    for entry in proposed_profile["bindings"]:
        if entry["action_id"] == String(action_id):
            entry["keycode"] = keycode

    var inspected := bindings.inspect_profile(proposed_profile)
    if not inspected["ok"]:
        preview["code"] = "CONFLICT" if not inspected["conflicts"].is_empty() else "INVALID_KEY"
        preview["message"] = inspected["error"]
        var enriched: Array[Dictionary] = []
        for conflict in inspected["conflicts"]:
            var names: Array = conflict["action_ids"]
            var owners: Array[Dictionary] = []
            for item in names:
                owners.append({
                    "action_id": String(item),
                    "keycode": conflict["keycode"],
                    "key_label": key_display(int(conflict["keycode"]))
                })
            enriched.append({
                "keycode": conflict["keycode"],
                "key_label": key_display(int(conflict["keycode"])),
                "owners": owners
            })
        preview["conflicts"] = enriched
        preview["alternatives"] = _free_alternatives(action_id)
        return preview

    var normalized: int = int(inspected["normalized"][String(action_id)])
    preview["proposed_keycode"] = normalized
    preview["proposed_key_label"] = key_display(normalized)
    preview["ok"] = true
    preview["can_apply"] = true
    preview["changed"] = normalized != previous
    preview["code"] = "READY" if normalized != previous else "UNCHANGED"
    preview["message"] = "Ready to apply" if normalized != previous else "Already assigned"
    return preview


func preview_reset_action(action_id: StringName) -> Dictionary:
    return preview_rebind(action_id, bindings.default_binding_for(action_id))


func preview_restore_defaults() -> Dictionary:
    var changes: Array[Dictionary] = []
    for action in BindingsCandidate.ACTIONS:
        var current_code := bindings.binding_for(StringName(action))
        var desired_code := bindings.default_binding_for(StringName(action))
        if current_code != desired_code:
            changes.append({
                "action_id": action,
                "from_keycode": current_code,
                "from_label": key_display(current_code),
                "to_keycode": desired_code,
                "to_label": key_display(desired_code)
            })
    return {
        "ok": true, "can_apply": true,
        "code": "READY" if not changes.is_empty() else "UNCHANGED",
        "changed": not changes.is_empty(),
        "changes": changes
    }


func _new_profile_with(action_id: StringName, keycode: int) -> Dictionary:
    var next := bindings.profile()
    for entry in next["bindings"]:
        if entry["action_id"] == String(action_id):
            entry["keycode"] = keycode
    return next


func _default_profile() -> Dictionary:
    var next := bindings.profile()
    for entry in next["bindings"]:
        entry["keycode"] = bindings.default_binding_for(StringName(entry["action_id"]))
    return next


func rebind(action_id: StringName, keycode: Variant) -> Dictionary:
    var preview := preview_rebind(action_id, keycode)
    if not preview["can_apply"]:
        return _report(_feedback(false, preview["code"], preview["message"],
            false, false, action_id, preview["conflicts"]))
    var result := bindings.rebind(action_id, preview["proposed_keycode"])
    return _report(_feedback(result["ok"],
        "APPLIED" if result["changed"] else "UNCHANGED",
        "Binding updated" if result["changed"] else "No change",
        result["changed"], false, action_id))


func reset_action(action_id: StringName) -> Dictionary:
    var preview := preview_reset_action(action_id)
    if not preview["can_apply"]:
        return _report(_feedback(false, preview["code"], preview["message"],
            false, false, action_id, preview["conflicts"]))
    return rebind(action_id, preview["proposed_keycode"])


func restore_defaults() -> Dictionary:
    var result := bindings.restore_defaults()
    return _report(_feedback(result["ok"],
        "DEFAULTS_RESTORED" if result["changed"] else "UNCHANGED",
        "Defaults restored" if result["changed"] else "Already default",
        result["changed"]))


# Explicit load: missing/corrupt files are errors, never silently replaced.
# Reject path changes after baseline is registered elsewhere.
func load(path: String) -> Dictionary:
    if _busy:
        return _report(_feedback(false, "BUSY", "Persistence operation in progress"))
    var error: String = bindings._path_error(path)
    if not error.is_empty():
        return _report(_feedback(false, "INVALID_PATH", error))

    var read := _read_file(path)
    if not read["ok"]:
        return _report(_feedback(false, read["code"], read["message"]))
    var inspected := bindings.inspect_profile(read["parsed"])
    if not inspected["ok"]:
        return _report(_feedback(false, "INVALID_PROFILE",
            inspected["error"], false, false, &"", inspected["conflicts"]))

    # Loading an externally changed file is an explicit user decision.
    var applied := bindings.apply_profile(read["parsed"])
    if not applied["ok"]:
        return _report(_feedback(false, "IMPORT_REJECTED", applied["error"],
            false, false, &"", applied["conflicts"]))
    _known_disk_hashes[path] = read["hash"]
    return _report(_feedback(true,
        "LOADED" if applied["changed"] else "UNCHANGED",
        "Profile loaded", applied["changed"], true))


func _read_file(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {
            "ok": false,
            "code": "READ_FAILED",
            "message": "Could not read configuration"
        }
    var content := file.get_as_text()
    file.close()
    var parser := JSON.new()
    if parser.parse(content) != OK:
        return {
            "ok": false, "code": "MALFORMED_JSON",
            "message": "Existing configuration contains invalid JSON"
        }
    return {
        "ok": true, "parsed": parser.data,
        "hash": content.sha256_text()
    }


# IO PRECHECK: refuse unknown/external changes. Do not auto-repair corrupt files.
func _persist_valid_profile(path: String, candidate: Dictionary) -> Dictionary:
    if _busy:
        return _feedback(false, "BUSY", "Persistence operation in progress")
    var problem: String = bindings._path_error(path)
    if not problem.is_empty():
        return _feedback(false, "INVALID_PATH", problem)
    var checked := bindings.inspect_profile(candidate)
    if not checked["ok"]:
        return _feedback(false, "INVALID_PROFILE",
            checked["error"], false, false, &"", checked["conflicts"])
    if not DirAccess.dir_exists_absolute(path.get_base_dir()):
        return _feedback(false, "MISSING_DIRECTORY", "Parent directory does not exist")
    if DirAccess.dir_exists_absolute(path):
        return _feedback(false, "OCCUPIED_PATH", "Destination is a directory")

    var existing_hash := ""
    var existing_profile: Dictionary = {}
    if FileAccess.file_exists(path):
        var existing := _read_file(path)
        if not existing["ok"]:
            return _feedback(false, existing["code"], existing["message"])
        var valid := bindings.inspect_profile(existing["parsed"])
        if not valid["ok"]:
            return _feedback(false, "INVALID_EXISTING",
                "Existing file rejected: " + valid["error"],
                false, false, &"", valid["conflicts"])
        existing_hash = existing["hash"]
        if not _known_disk_hashes.has(path):
            return _feedback(false, "LOAD_REQUIRED",
                "Load existing configuration before overwriting")
        if _known_disk_hashes[path] != existing_hash:
            return _feedback(false, "EXTERNAL_CHANGE",
                "Configuration was modified outside this component")
        existing_profile = valid["normalized"]
    elif _known_disk_hashes.has(path):
        return _feedback(false, "EXTERNAL_DELETE",
            "Previously loaded configuration is now missing")

    var wanted_codes: Dictionary = checked["normalized"]
    if not existing_hash.is_empty() and existing_profile == wanted_codes:
        return _feedback(true, "ALREADY_PERSISTED", "Disk already matches",
            false, true)

    var temporary := path + ".tmp"
    if FileAccess.file_exists(temporary) or DirAccess.dir_exists_absolute(temporary):
        return _feedback(false, "TEMP_OCCUPIED",
            "Temporary path is occupied; no overwrite attempted")

    var serialized := JSON.stringify(candidate, "  ")
    _busy = true
    var file := FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        _busy = false
        return _feedback(false, "WRITE_FAILED", "Cannot create temporary file")
    file.store_string(serialized)
    file.flush()
    var write_error := file.get_error()
    file.close()
    if write_error != OK:
        DirAccess.remove_absolute(temporary)
        _busy = false
        return _feedback(false, "WRITE_FAILED", "Temporary write failed")

    # This is a single-process candidate, NOT an OS lock or full
    # power-loss-safe transaction. No explicit delete-before-rename.
    var rename_error := DirAccess.rename_absolute(temporary, path)
    if rename_error != OK:
        DirAccess.remove_absolute(temporary)
        _busy = false
        return _feedback(false, "RENAME_FAILED",
            "Rename failed: " + str(rename_error))

    _known_disk_hashes[path] = serialized.sha256_text()
    _busy = false
    return _feedback(true, "SAVED", "Configuration saved", false, true)


func save(path: String) -> Dictionary:
    return _report(_persist_valid_profile(path, bindings.profile()))


# Disk-first commit: a failed save leaves runtime bindings and signals intact.
# No implicit autosave; operation must be explicitly requested.
func rebind_and_save(action_id: StringName, keycode: Variant, path: String) -> Dictionary:
    var preview := preview_rebind(action_id, keycode)
    if not preview["can_apply"]:
        return _report(_feedback(false, preview["code"], preview["message"],
            false, false, action_id, preview["conflicts"]))
    var wanted := _new_profile_with(action_id, preview["proposed_keycode"])
    return _commit_profile(wanted, path, action_id)


func reset_action_and_save(action_id: StringName, path: String) -> Dictionary:
    var preview := preview_reset_action(action_id)
    if not preview["can_apply"]:
        return _report(_feedback(false, preview["code"], preview["message"],
            false, false, action_id, preview["conflicts"]))
    return _commit_profile(
        _new_profile_with(action_id, preview["proposed_keycode"]),
        path, action_id
    )


func restore_defaults_and_save(path: String) -> Dictionary:
    return _commit_profile(_default_profile(), path)


func _commit_profile(candidate: Dictionary, path: String,
        action_id: StringName = &"") -> Dictionary:
    var checked := bindings.inspect_profile(candidate)
    if not checked["ok"]:
        return _report(_feedback(false, "INVALID_PROFILE",
            checked["error"], false, false, action_id, checked["conflicts"]))
    var previous := bindings.profile()
    var persisted := _persist_valid_profile(path, candidate)
    if not persisted["ok"]:
        return _report(persisted)
    # Profile is valid and applied synchronously only AFTER disk succeeded.
    var apply_result := bindings.apply_profile(candidate)
    if not apply_result["ok"]:
        return _report(_feedback(false, "POST_SAVE_IMPORT_FAILED",
            "Disk committed but in-memory apply failed; reload required",
            false, true, action_id, apply_result["conflicts"]))
    var changed: bool = previous != bindings.profile()
    var outcome_code := "SAVED_AND_APPLIED"
    if not changed:
        outcome_code = "ALREADY_PERSISTED" if persisted["code"] == "ALREADY_PERSISTED" else "SAVED_NO_CHANGE"
    return _report(_feedback(true, outcome_code,
        "Saved and applied" if changed else "No in-memory change",
        changed, true, action_id))


# Explicitly clear in-process baseline ONLY; never remove any disk file.
# Useful when switching test profile paths; next existing-file save needs load.
func forget_disk_baseline(path: String) -> void:
    _known_disk_hashes.erase(path)
