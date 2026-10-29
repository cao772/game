extends RefCounted
## GAME-WEB-FLOW-INPUT-004 r1, isolated UI backing adapter.
## Delegates to PR #15 V1 binding model, V2 migrator and Workflow.
## All IO is explicitly invoked by a UI command; NO InputMap access.
## NOT_RUN.

signal profile_changed(profile: Dictionary)

const Workflow = preload("res://play_005/vendor/input/input_profile_workflow_003.gd")
const Migrator = preload("res://play_005/vendor/input/input_profile_migration_003.gd")
const Bindings = preload("res://play_005/vendor/input/input_bindings_candidate.gd")

var workflow = Workflow.new()
var _migrator = Migrator.new()
var _known_hash: Dictionary = {}
var _busy: bool = false


func _init() -> void:
    workflow.settings.configuration_changed.connect(_on_profile_changed)


func _on_profile_changed(profile: Dictionary) -> void:
    profile_changed.emit(profile.duplicate(true))


func _fail(code: String, message: String = "") -> Dictionary:
    return {"ok": false, "code": code, "message": message,
        "persisted": false, "committed": false, "changed": false}


func _success(code: String, changed: bool = false,
        persisted: bool = false, committed: bool = false) -> Dictionary:
    return {"ok": true, "code": code, "message": "",
        "persisted": persisted, "committed": committed, "changed": changed}


func profile() -> Dictionary:
    return workflow.current_profile()


func preview(action_id: StringName, keycode: Variant) -> Dictionary:
    return workflow.preview_conflict(action_id, keycode)


func preview_restore() -> Dictionary:
    return workflow.settings.preview_restore_defaults()


func key_label(code: int) -> String:
    return workflow.settings.key_display(code)


func _candidate_for(action_id: StringName, code: int) -> Dictionary:
    var candidate := profile()
    for entry in candidate["bindings"]:
        if entry["action_id"] == String(action_id):
            entry["keycode"] = code
    return candidate


func _default_candidate() -> Dictionary:
    var candidate := profile()
    for entry in candidate["bindings"]:
        entry["keycode"] = workflow.settings.bindings.default_binding_for(
            StringName(entry["action_id"])
        )
    return candidate


# Explicit memory-only command. No implicit disk read/write or UI KeyEvent dispatch.
func rebind_memory(action_id: StringName, keycode: Variant) -> Dictionary:
    var preview_result := preview(action_id, keycode)
    if not preview_result.get("can_apply", false):
        return _fail(str(preview_result.get("code", "INVALID_KEY")),
            str(preview_result.get("message", "")))
    var result := workflow.settings.rebind(action_id, preview_result["proposed_keycode"])
    return {
        "ok": result["ok"], "code": result["code"],
        "message": result["message"],
        "persisted": false, "committed": false, "changed": result["changed"]
    }


# No load on startup. Never replace an unknown existing file.
func load_v2(path: String) -> Dictionary:
    if _busy:
        return _fail("BUSY")
    var result := workflow.load_v2(path)
    if not result["ok"]:
        return _fail(str(result["code"]), str(result["message"]))
    var checked := _migrator.read_v2(path)
    if not checked["ok"]:
        return _fail("POST_LOAD_READ_FAILED", str(checked["message"]))
    _known_hash[path] = checked["digest"]
    return _success("LOADED", bool(result.get("memory_changed", false)), true)


# Support PR #15's explicit one-shot migration flow but never overwrite legacy.
func preview_migration(legacy: String, destination: String) -> Dictionary:
    return workflow.preview_migration(legacy, destination)


func confirm_migration(token: String, destination: String) -> Dictionary:
    if _busy:
        return _fail("BUSY")
    var result := workflow.confirm_migration(token)
    if not result["ok"]:
        return {"ok": false, "code": str(result["code"]),
            "message": str(result["message"]), "changed": false,
            "persisted": bool(result.get("committed", false)),
            "committed": bool(result.get("committed", false))}
    var verified := _migrator.read_v2(destination)
    if not verified["ok"]:
        return {"ok": false, "code": "MIGRATION_COMMITTED_NEEDS_RELOAD",
            "message": "Migration committed but V2 readback needs review",
            "changed": false, "persisted": true, "committed": true}
    _known_hash[destination] = verified["digest"]
    return _success("MIGRATED", bool(result.get("memory_changed", false)),
        true, bool(result.get("committed", false)))


# Disk-first change: no in-memory apply until a verified save succeeds.
# Only a known V2 file may be updated; create-if-absent is explicit.
func _commit_candidate(path: String, candidate: Dictionary) -> Dictionary:
    if _busy:
        return _fail("BUSY")
    var validated := _migrator.to_v2(candidate)
    if not validated["ok"]:
        return _fail(str(validated["code"]), str(validated["message"]))
    var expected_digest := ""
    if FileAccess.file_exists(path):
        if not _known_hash.has(path):
            return _fail("LOAD_REQUIRED", "Load existing V2 before editing")
        expected_digest = _known_hash[path]
    elif _known_hash.has(path):
        return _fail("EXTERNAL_DELETE", "Loaded V2 file disappeared")

    var before := profile()
    _busy = true
    var stored := _migrator.write_v2(path, validated["v2"], expected_digest)
    if not stored["ok"]:
        _busy = false
        return {
            "ok": false, "code": stored["code"], "message": stored["message"],
            "changed": false,
            "persisted": bool(stored.get("committed", false)),
            "committed": bool(stored.get("committed", false))
        }

    # PR #15 Workflow is the only live owner of the bindings instance.
    # Its loader checks valid V2 and remembers its disk baseline for reset flow.
    var loaded := workflow.load_v2(path)
    if not loaded["ok"]:
        _busy = false
        return {"ok": false, "code": "COMMITTED_NEEDS_RELOAD",
            "message": "V2 saved but live reload failed",
            "changed": false, "persisted": true,
            "committed": bool(stored.get("committed", false))}
    _known_hash[path] = stored["digest"]
    _busy = false
    return _success("SAVED_AND_APPLIED" if before != profile()
        else "ALREADY_PERSISTED", before != profile(), true,
        bool(stored.get("committed", false)))


func rebind_and_save(action_id: StringName, keycode: Variant, path: String) -> Dictionary:
    var proposed := preview(action_id, keycode)
    if not proposed.get("can_apply", false):
        return _fail(str(proposed.get("code", "INVALID_KEY")),
            str(proposed.get("message", "")))
    return _commit_candidate(path,
        _candidate_for(action_id, int(proposed["proposed_keycode"])))


func save_current(path: String) -> Dictionary:
    return _commit_candidate(path, profile())


# Full restore is a single atomic *intent*, not a swap of occupied individual
# defaults. On disk failure, live memory is not changed.
func restore_defaults_and_save(path: String) -> Dictionary:
    return _commit_candidate(path, _default_candidate())


func restore_defaults_memory() -> Dictionary:
    var result := workflow.settings.restore_defaults()
    return {"ok": result["ok"], "code": result["code"],
        "message": result["message"], "persisted": false, "committed": false,
        "changed": result["changed"]}


func cancel_workflow() -> void:
    workflow.cancel_pending()


func disk_known(path: String) -> bool:
    return _known_hash.has(path)
