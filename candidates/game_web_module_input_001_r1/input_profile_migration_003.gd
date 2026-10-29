extends RefCounted
## GAME-WEB-CONTINUE-INPUT-003 r1.
## Independent STRICT V1 -> V2 profile conversion and guarded file transport.
## No changes to InputMap, existing candidate sources, or round snapshots.
## Authoring status: NOT_RUN.

const Bindings = preload("res://input_bindings_candidate.gd")
const LEGACY_FILENAME := "input_bindings_candidate.json"
const V2_FILENAME := "input_bindings_candidate_v2.json"
const FORMAT := "game_web_input_bindings"
const SCHEMA_VERSION := 2


func _fail(code: String, message: String, conflicts: Array = [],
        committed: bool = false) -> Dictionary:
    return {
        "ok": false, "code": code, "message": message,
        "conflicts": conflicts.duplicate(true),
        "committed": committed
    }


func _success(code: String, additional: Dictionary = {}) -> Dictionary:
    var result := {
        "ok": true, "code": code, "message": "",
        "conflicts": [], "committed": false
    }
    for key in additional:
        result[key] = additional[key]
    return result


func _explain_conflicts(conflicts: Array) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for item in conflicts:
        if typeof(item) != TYPE_DICTIONARY:
            continue
        var owners: Array[String] = []
        if item.has("action_ids") and typeof(item["action_ids"]) == TYPE_ARRAY:
            for action in item["action_ids"]:
                owners.append(str(action))
        var code := int(item.get("keycode", -1))
        result.append({
            "keycode": code, "action_ids": owners,
            "reason": "The same logical keycode is assigned to multiple actions",
            "resolution": "Choose one free key per action; no automatic swap"
        })
    return result


func _validate_v1(candidate: Variant) -> Dictionary:
    var binding_model = Bindings.new()
    var result: Dictionary = binding_model.inspect_profile(candidate)
    if not result["ok"]:
        return _fail(
            "CONFLICT" if not result["conflicts"].is_empty() else "INVALID_V1",
            str(result["error"]),
            _explain_conflicts(result["conflicts"])
        )
    # Normalize order by the exact PR #15 declared action list.
    var normalized: Dictionary = result["normalized"]
    var entries: Array[Dictionary] = []
    for action in Bindings.ACTIONS:
        entries.append({
            "action_id": action, "keycode": int(normalized[action])
        })
    return _success("VALID_V1", {
        "profile": {"version": Bindings.VERSION, "bindings": entries}
    })


# New format is deliberately a different filename so PR #15's strict
# V1 validator never accidentally reads/overwrites a V2 file.
func to_v2(legacy_document: Variant) -> Dictionary:
    var v1 := _validate_v1(legacy_document)
    if not v1["ok"]:
        return v1
    return _success("MIGRATED_IN_MEMORY", {
        "v1": v1["profile"].duplicate(true),
        "v2": {
            "schema_version": SCHEMA_VERSION,
            "format": FORMAT,
            "bindings": v1["profile"]["bindings"].duplicate(true)
        }
    })


func validate_v2(document: Variant) -> Dictionary:
    if typeof(document) != TYPE_DICTIONARY:
        return _fail("INVALID_V2", "V2 must be a JSON object")
    var data: Dictionary = document
    if data.size() != 3 or not data.has("schema_version") \
            or not data.has("format") or not data.has("bindings"):
        return _fail("INVALID_V2", "V2 must contain only schema_version, format, bindings")
    if typeof(data["format"]) != TYPE_STRING or data["format"] != FORMAT:
        return _fail("INVALID_V2", "Unknown format identifier")
    var version: Variant = data["schema_version"]
    if typeof(version) != TYPE_INT and typeof(version) != TYPE_FLOAT:
        return _fail("INVALID_V2", "Schema version must be numeric")
    if not is_finite(float(version)) or float(version) != float(SCHEMA_VERSION):
        return _fail("UNSUPPORTED_VERSION", "Unsupported schema_version")

    # Reuse the ONLY supplied canonical candidate validation rules;
    # do not silently drop actions, synthesize bindings, or repair collisions.
    var normalized := _validate_v1({
        "version": Bindings.VERSION,
        "bindings": data["bindings"]
    })
    if not normalized["ok"]:
        return _fail(normalized["code"], normalized["message"],
            normalized["conflicts"])
    var converted := to_v2(normalized["profile"])
    return _success("VALID_V2", {
        "v1": normalized["profile"].duplicate(true),
        "v2": converted["v2"].duplicate(true)
    })


func _validate_path(path: String, basename: String) -> Dictionary:
    if not path.begins_with("user://"):
        return _fail("INVALID_PATH", "Only user:// paths are allowed")
    var relative := path.trim_prefix("user://")
    if relative.is_empty() or relative.contains("\\") or relative.contains(":"):
        return _fail("INVALID_PATH", "Invalid path syntax")
    for segment in relative.split("/"):
        if segment.is_empty() or segment == "." or segment == "..":
            return _fail("INVALID_PATH", "Unsafe path segment")
    if path.get_file() != basename:
        return _fail("INVALID_PATH", "Incorrect profile filename")
    return _success("PATH_OK")


func validate_legacy_path(path: String) -> Dictionary:
    return _validate_path(path, LEGACY_FILENAME)


func validate_v2_path(path: String) -> Dictionary:
    return _validate_path(path, V2_FILENAME)


func validate_migration_pair(legacy_path: String, target_path: String) -> Dictionary:
    var legacy := validate_legacy_path(legacy_path)
    if not legacy["ok"]:
        return legacy
    var target := validate_v2_path(target_path)
    if not target["ok"]:
        return target
    if legacy_path.get_base_dir() != target_path.get_base_dir():
        return _fail("DIFFERENT_DIRECTORY",
            "Migration requires the same isolated parent directory")
    return _success("PAIR_OK")


# No user-facing file, no implicit directories, no repair, no fallback.
func read_json_file(path: String, filename: String) -> Dictionary:
    var path_result := _validate_path(path, filename)
    if not path_result["ok"]:
        return path_result
    if DirAccess.dir_exists_absolute(path):
        return _fail("OCCUPIED_PATH", "Path points to a directory")
    if not FileAccess.file_exists(path):
        return _fail("MISSING_FILE", "Profile file does not exist")
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return _fail("READ_FAILED", "Cannot open profile for reading")
    var raw := file.get_as_text()
    file.close()
    var decoder := JSON.new()
    if decoder.parse(raw) != OK:
        return _fail("MALFORMED_JSON", "Invalid JSON content")
    return _success("READ_OK", {
        "data": decoder.data,
        "digest": raw.sha256_text()
    })


func read_legacy(path: String) -> Dictionary:
    var read := read_json_file(path, LEGACY_FILENAME)
    if not read["ok"]:
        return read
    var normalized := _validate_v1(read["data"])
    if not normalized["ok"]:
        return normalized
    return _success("VALID_V1", {
        "digest": read["digest"],
        "profile": normalized["profile"].duplicate(true)
    })


func read_v2(path: String) -> Dictionary:
    var read := read_json_file(path, V2_FILENAME)
    if not read["ok"]:
        return read
    var valid := validate_v2(read["data"])
    if not valid["ok"]:
        return valid
    return _success("VALID_V2", {
        "digest": read["digest"],
        "profile": valid["v1"].duplicate(true),
        "document": valid["v2"].duplicate(true)
    })


# expected_digest == "" is CREATE-ONLY; a nonempty digest means update
# exactly the file that was explicitly loaded. A fixed .tmp file assumes
# only one writer, with no cross-process lock or crash durability guarantee.
func write_v2(path: String, candidate: Variant,
        expected_digest: String) -> Dictionary:
    var safe := validate_v2_path(path)
    if not safe["ok"]:
        return safe
    var checked := validate_v2(candidate)
    if not checked["ok"]:
        return checked
    if not DirAccess.dir_exists_absolute(path.get_base_dir()):
        return _fail("MISSING_DIRECTORY", "Parent directory is missing")
    if DirAccess.dir_exists_absolute(path):
        return _fail("OCCUPIED_PATH", "Destination is a directory")

    var current_digest := ""
    if FileAccess.file_exists(path):
        if expected_digest.is_empty():
            return _fail("TARGET_EXISTS", "Destination already exists; explicit load required")
        var existing := read_v2(path)
        if not existing["ok"]:
            return _fail("INVALID_EXISTING", "Existing V2 document is invalid")
        current_digest = existing["digest"]
        if current_digest != expected_digest:
            return _fail("EXTERNAL_CHANGE", "Destination changed since preview/load")
    elif not expected_digest.is_empty():
        return _fail("EXTERNAL_DELETE", "Previously loaded destination disappeared")

    var desired: Dictionary = checked["document"]
    var serialized := JSON.stringify(desired, "  ")
    if not current_digest.is_empty():
        var old_read := read_v2(path)
        if old_read["ok"] and old_read["profile"] == checked["v1"]:
            return _success("ALREADY_PERSISTED", {
                "digest": current_digest, "committed": false
            })

    var temporary := path + ".tmp"
    if FileAccess.file_exists(temporary) or DirAccess.dir_exists_absolute(temporary):
        return _fail("TEMP_OCCUPIED", "Existing temporary file is left untouched")

    var output := FileAccess.open(temporary, FileAccess.WRITE)
    if output == null:
        return _fail("WRITE_FAILED", "Cannot create temporary file")
    output.store_string(serialized)
    output.flush()
    var write_error := output.get_error()
    output.close()
    if write_error != OK:
        DirAccess.remove_absolute(temporary)
        return _fail("WRITE_FAILED", "Temporary write failed")

    # Recheck immediately before rename. This still cannot close TOCTOU races.
    if FileAccess.file_exists(path):
        if expected_digest.is_empty():
            DirAccess.remove_absolute(temporary)
            return _fail("TARGET_EXISTS", "Destination appeared during write")
        var late_read := read_v2(path)
        if not late_read["ok"] or late_read["digest"] != expected_digest:
            DirAccess.remove_absolute(temporary)
            return _fail("EXTERNAL_CHANGE", "Destination changed during write")
    elif not expected_digest.is_empty():
        DirAccess.remove_absolute(temporary)
        return _fail("EXTERNAL_DELETE", "Destination disappeared during write")

    var rename_error := DirAccess.rename_absolute(temporary, path)
    if rename_error != OK:
        DirAccess.remove_absolute(temporary)
        return _fail("RENAME_FAILED", "Cannot rename prepared configuration")

    # Rename has committed. If verification fails, DO NOT falsely claim rollback.
    var verified := read_v2(path)
    if not verified["ok"] or verified["profile"] != checked["v1"]:
        return _fail("POST_WRITE_VERIFY_FAILED",
            "Write committed but verification failed; explicit review required",
            [], true)
    return _success("SAVED", {
        "digest": verified["digest"],
        "committed": true
    })
