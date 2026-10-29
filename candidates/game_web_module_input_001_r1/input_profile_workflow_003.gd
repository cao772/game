extends RefCounted
## GAME-WEB-CONTINUE-INPUT-003 r1
## Opt-in migration and explicit confirmed restore workflow.
## Compatible with unchanged PR #15 settings/bindings candidate, NOT_RUN.
## No global InputMap changes, no gameplay state, no implicit file IO.

signal workflow_reported(report: Dictionary)

const Migrator = preload("res://input_profile_migration_003.gd")
const Settings = preload("res://input_settings_controller_candidate.gd")
const Bindings = preload("res://input_bindings_candidate.gd")

var settings = Settings.new()
var _migration = Migrator.new()
var _known_v2_hashes: Dictionary = {}
var _pending: Dictionary = {}
var _generation: int = 0
var _busy: bool = false


func _response(ok: bool, code: String, message: String = "",
        details: Dictionary = {}) -> Dictionary:
    var result: Dictionary = {
        "ok": ok,
        "code": code,
        "message": message,
        "committed": false,
        "memory_changed": false,
        "persisted": false
    }
    for key in details:
        result[key] = details[key]
    return result


func _publish(result: Dictionary) -> Dictionary:
    workflow_reported.emit(result.duplicate(true))
    return result


func _invalidate_pending() -> void:
    _pending.clear()
    _generation += 1


func current_profile() -> Dictionary:
    return settings.current_profile()


# Explicitly wire the same instance into PR #15's optional router:
# adapter.bindings = workflow.settings.bindings.
func preview_conflict(action_id: StringName, new_keycode: Variant) -> Dictionary:
    var preview: Dictionary = settings.preview_rebind(action_id, new_keycode)
    var explanation := ""
    var next_steps: Array[String] = []
    match str(preview["code"]):
        "CONFLICT":
            var owners := PackedStringArray()
            for collision in preview["conflicts"]:
                for owner in collision["owners"]:
                    var name := str(owner["action_id"])
                    if name != String(action_id) and not owners.has(name):
                        owners.append(name)
            explanation = "Key already assigned to: " + ", ".join(owners)
            next_steps = [
                "Choose an available alternative key",
                "Manually remap the conflicting action first",
                "Restore all defaults explicitly"
            ]
        "INVALID_KEY":
            explanation = "This value is not a supported logical keycode."
            next_steps = ["Select a supported logical keycode"]
        "UNKNOWN_ACTION":
            explanation = "This action is not defined by the input candidate."
        "READY":
            explanation = "No conflict was found."
        "UNCHANGED":
            explanation = "The binding already matches."
    preview["explanation"] = explanation
    preview["next_steps"] = next_steps
    return preview


func _default_v1() -> Dictionary:
    var profile := settings.current_profile()
    for entry in profile["bindings"]:
        entry["keycode"] = settings.bindings.default_binding_for(
            StringName(entry["action_id"])
        )
    return profile


func _changes(before: Dictionary, after: Dictionary) -> Array[Dictionary]:
    var old_codes: Dictionary = {}
    for item in before["bindings"]:
        old_codes[str(item["action_id"])] = int(item["keycode"])
    var differences: Array[Dictionary] = []
    for entry in after["bindings"]:
        var action := str(entry["action_id"])
        var desired := int(entry["keycode"])
        var previous := int(old_codes.get(action, -1))
        if previous != desired:
            differences.append({
                "action_id": action,
                "from_keycode": previous,
                "to_keycode": desired,
                "from_label": settings.key_display(previous),
                "to_label": settings.key_display(desired)
            })
    return differences


func _set_pending(kind: String, values: Dictionary) -> String:
    _invalidate_pending()
    var fingerprint := str(_generation) + "|" + kind
    for name in values.keys():
        fingerprint += "|" + str(name) + "=" + JSON.stringify(values[name])
    var token := fingerprint.sha256_text()
    _pending = values.duplicate(true)
    _pending["kind"] = kind
    _pending["token"] = token
    return token


# PREVIEW is read-only to disk; never creates/changes a file or live map.
# Only actually supplied legacy format (PR #15 V1) may be migrated.
func preview_migration(legacy_path: String, v2_path: String) -> Dictionary:
    _invalidate_pending()
    if _busy:
        return _response(false, "BUSY")
    var pair := _migration.validate_migration_pair(legacy_path, v2_path)
    if not pair["ok"]:
        return _response(false, pair["code"], pair["message"])
    if not DirAccess.dir_exists_absolute(v2_path.get_base_dir()):
        return _response(false, "MISSING_DIRECTORY", "Parent directory is missing")
    if FileAccess.file_exists(v2_path) or DirAccess.dir_exists_absolute(v2_path):
        return _response(false, "TARGET_EXISTS",
            "V2 destination already exists. Load it explicitly instead.")

    var source := _migration.read_legacy(legacy_path)
    if not source["ok"]:
        return _response(false, source["code"], source["message"], {
            "conflicts": source.get("conflicts", [])
        })
    var next := _migration.to_v2(source["profile"])
    if not next["ok"]:
        return _response(false, next["code"], next["message"], {
            "conflicts": next.get("conflicts", [])
        })

    var previous := settings.current_profile()
    var token := _set_pending("migration", {
        "legacy_path": legacy_path,
        "v2_path": v2_path,
        "legacy_digest": source["digest"],
        "memory_digest": JSON.stringify(previous).sha256_text(),
        "profile": next["v1"].duplicate(true)
    })
    return _response(true, "MIGRATION_READY", "Explicit confirmation required", {
        "confirmation_token": token,
        "source_format": "V1",
        "destination_format": "V2",
        "destination": v2_path,
        "changes": _changes(previous, next["v1"]),
        "legacy_retained": true
    })


# Caller confirmation cannot use a stale plan or alter its source document.
func confirm_migration(confirmation_token: String) -> Dictionary:
    if _busy:
        return _publish(_response(false, "BUSY"))
    if _pending.get("kind", "") != "migration" \
            or _pending.get("token", "") != confirmation_token \
            or confirmation_token.is_empty():
        return _publish(_response(false, "STALE_PREVIEW",
            "A current migration preview is required"))
    var plan := _pending.duplicate(true)
    _invalidate_pending()
    if JSON.stringify(settings.current_profile()).sha256_text() != plan["memory_digest"]:
        return _publish(_response(false, "MEMORY_CHANGED",
            "Bindings changed after the preview"))
    var source := _migration.read_legacy(plan["legacy_path"])
    if not source["ok"]:
        return _publish(_response(false, source["code"], source["message"]))
    if source["digest"] != plan["legacy_digest"]:
        return _publish(_response(false, "SOURCE_CHANGED",
            "Legacy profile changed since preview"))
    if FileAccess.file_exists(plan["v2_path"]) or DirAccess.dir_exists_absolute(plan["v2_path"]):
        return _publish(_response(false, "TARGET_EXISTS",
            "Destination now exists and was not overwritten"))

    var converted := _migration.to_v2(plan["profile"])
    if not converted["ok"]:
        return _publish(_response(false, converted["code"], converted["message"]))
    _busy = true
    var write_result := _migration.write_v2(plan["v2_path"], converted["v2"], "")
    _busy = false
    if not write_result["ok"]:
        return _publish(_response(false,
            write_result["code"], write_result["message"],
            {"committed": write_result.get("committed", false)}))

    # Bindings are published only after successful and verified disk write.
    var applied := settings.bindings.apply_profile(plan["profile"])
    if not applied["ok"]:
        return _publish(_response(false, "POST_WRITE_APPLY_FAILED",
            "Destination saved but live bindings were not applied; reload required",
            {"committed": true, "persisted": true}))
    _known_v2_hashes[plan["v2_path"]] = write_result["digest"]
    return _publish(_response(true, "MIGRATED", "V1 retained, V2 saved", {
        "committed": true,
        "persisted": true,
        "memory_changed": bool(applied["changed"]),
        "destination": plan["v2_path"],
        "legacy_retained": true
    }))


# Explicitly accept V2 on disk. No automatic migrations, no implicit restore.
func load_v2(v2_path: String) -> Dictionary:
    _invalidate_pending()
    if _busy:
        return _publish(_response(false, "BUSY"))
    var read := _migration.read_v2(v2_path)
    if not read["ok"]:
        return _publish(_response(false, read["code"], read["message"], {
            "conflicts": read.get("conflicts", [])
        }))
    var result := settings.bindings.apply_profile(read["profile"])
    if not result["ok"]:
        return _publish(_response(false, "APPLY_FAILED", str(result["error"])))
    _known_v2_hashes[v2_path] = read["digest"]
    return _publish(_response(true, "LOADED", "V2 profile loaded", {
        "persisted": true,
        "memory_changed": bool(result["changed"])
    }))


func preview_restore_defaults(v2_path: String) -> Dictionary:
    _invalidate_pending()
    if _busy:
        return _response(false, "BUSY")
    var valid := _migration.validate_v2_path(v2_path)
    if not valid["ok"]:
        return _response(false, valid["code"], valid["message"])
    if not DirAccess.dir_exists_absolute(v2_path.get_base_dir()):
        return _response(false, "MISSING_DIRECTORY", "Parent directory is missing")

    var baseline := ""
    var disk_default := false
    if FileAccess.file_exists(v2_path):
        if not _known_v2_hashes.has(v2_path):
            return _response(false, "LOAD_REQUIRED",
                "Load the existing V2 profile before saving defaults")
        var read := _migration.read_v2(v2_path)
        if not read["ok"]:
            return _response(false, read["code"], read["message"])
        if read["digest"] != _known_v2_hashes[v2_path]:
            return _response(false, "EXTERNAL_CHANGE", "V2 file changed since load")
        baseline = read["digest"]
        disk_default = read["profile"] == _default_v1()
    elif _known_v2_hashes.has(v2_path):
        return _response(false, "EXTERNAL_DELETE", "Loaded V2 file was deleted")
    elif DirAccess.dir_exists_absolute(v2_path):
        return _response(false, "OCCUPIED_PATH", "Destination is a directory")

    var desired := _default_v1()
    var before := settings.current_profile()
    var token := _set_pending("restore", {
        "v2_path": v2_path,
        "target_digest": baseline,
        "memory_digest": JSON.stringify(before).sha256_text(),
        "desired": desired.duplicate(true)
    })
    return _response(true, "RESTORE_READY", "Explicit confirmation required", {
        "confirmation_token": token,
        "changes": _changes(before, desired),
        "disk_already_default": disk_default,
        "will_create_file": baseline.is_empty()
    })


func confirm_restore_defaults(confirmation_token: String) -> Dictionary:
    if _busy:
        return _publish(_response(false, "BUSY"))
    if _pending.get("kind", "") != "restore" \
            or _pending.get("token", "") != confirmation_token \
            or confirmation_token.is_empty():
        return _publish(_response(false, "STALE_PREVIEW", "Re-preview required"))
    var plan := _pending.duplicate(true)
    _invalidate_pending()
    if JSON.stringify(settings.current_profile()).sha256_text() != plan["memory_digest"]:
        return _publish(_response(false, "MEMORY_CHANGED",
            "Bindings changed since restore preview"))
    var converted := _migration.to_v2(plan["desired"])
    if not converted["ok"]:
        return _publish(_response(false, converted["code"], converted["message"]))
    _busy = true
    var persisted := _migration.write_v2(
        plan["v2_path"], converted["v2"], plan["target_digest"]
    )
    _busy = false
    if not persisted["ok"]:
        return _publish(_response(false, persisted["code"], persisted["message"], {
            "committed": persisted.get("committed", false)
        }))
    var applied := settings.bindings.apply_profile(plan["desired"])
    if not applied["ok"]:
        return _publish(_response(false, "POST_WRITE_APPLY_FAILED",
            "Disk saved but memory update failed; reload required",
            {"committed": bool(persisted["committed"]), "persisted": true}))
    _known_v2_hashes[plan["v2_path"]] = persisted["digest"]
    return _publish(_response(true, "DEFAULTS_RESTORED", "V2 defaults active", {
        "committed": bool(persisted["committed"]),
        "persisted": true,
        "memory_changed": bool(applied["changed"])
    }))


# Cancel does not write disk or modify bindings, and invalidates old tokens.
func cancel_pending() -> Dictionary:
    var had_pending := not _pending.is_empty()
    _invalidate_pending()
    return _publish(_response(true, "CANCELLED" if had_pending else "NO_PENDING",
        "No changes were applied"))
