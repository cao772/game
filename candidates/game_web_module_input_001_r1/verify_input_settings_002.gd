extends SceneTree
## GAME-WEB-MODULE-INPUT-002 r1
## FUTURE SceneTree acceptance suite. Authoring status: NOT_RUN.
## Does not touch InputMap, other candidate files or game snapshot storage.

const Settings = preload("res://input_settings_controller_candidate.gd")

var failures: Array[String] = []
var assertions: int = 0
var profile_events: Array[Dictionary] = []
var reports: Array[Dictionary] = []


func _initialize() -> void:
    call_deferred("_run")


func _check(name: String, actual: Variant, expected: Variant) -> void:
    assertions += 1
    if actual != expected:
        failures.append("%s: expected=%s actual=%s" % [
            name, str(expected), str(actual)
        ])


func _on_profile_changed(profile: Dictionary) -> void:
    profile_events.append(profile.duplicate(true))


func _on_report(data: Dictionary) -> void:
    reports.append(data.duplicate(true))


func _event(code: int, pressed: bool = true,
        echo: bool = false) -> InputEventKey:
    var key := InputEventKey.new()
    key.keycode = code
    key.pressed = pressed
    key.echo = echo
    return key


func _write_text(path: String, contents: String) -> bool:
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(contents)
    f.flush()
    var error := f.get_error()
    f.close()
    return error == OK


func _run() -> void:
    var s = Settings.new()
    s.configuration_changed.connect(_on_profile_changed)
    s.operation_reported.connect(_on_report)

    var initial := s.current_profile()
    _check("default observe", s.bindings.binding_for(&"observe"), KEY_1)
    _check("default reset", s.bindings.binding_for(&"reset_round"), KEY_R)
    _check("key display", s.key_display(KEY_ESCAPE), "Escape")
    _check("letter display", s.key_display(KEY_Z), "Z")

    # Conflict preview reports both owner names without changing the map.
    var collision: Dictionary = s.preview_rebind(&"observe", KEY_2)
    _check("conflict preview blocks apply", collision["can_apply"], false)
    _check("conflict code", collision["code"], "CONFLICT")
    _check("conflict count", collision["conflicts"].size(), 1)
    if collision["conflicts"].size() == 1:
        _check("conflict key label", collision["conflicts"][0]["key_label"], "2")
        _check("conflict owners count",
            collision["conflicts"][0]["owners"].size(), 2)
    _check("alternatives available", collision["alternatives"].is_empty(), false)
    _check("preview cannot mutate", s.current_profile(), initial)
    _check("preview cannot signal", profile_events.size(), 0)
    _check("preview cannot report", reports.size(), 0)

    var unknown := s.preview_rebind(&"unsupported", KEY_Z)
    _check("unknown action rejected", unknown["code"], "UNKNOWN_ACTION")
    var bad_key := s.preview_rebind(&"observe", "Z")
    _check("wrong key type rejected", bad_key["code"], "INVALID_KEY")
    var same := s.preview_rebind(&"observe", KEY_1)
    _check("same key accepted", same["can_apply"], true)
    _check("same key no change", same["changed"], false)
    _check("single reset preview no-op",
        s.preview_reset_action(&"observe")["changed"], false)
    _check("whole defaults preview no-op",
        s.preview_restore_defaults()["changed"], false)

    # In-memory operations work without implicit saves.
    _check("rebind committed", s.rebind(&"observe", KEY_Z)["changed"], true)
    _check("one profile event", profile_events.size(), 1)
    _check("changed key routes", s.bindings.resolve_key_event(
        _event(KEY_Z), false, null), &"observe")
    _check("old key no route", s.bindings.resolve_key_event(
        _event(KEY_1), false, null), &"")
    _check("remapping has no automatic persistence", reports.back()["persisted"], false)
    _check("rebind identical no event",
        s.rebind(&"observe", KEY_Z)["changed"], false)
    _check("unchanged event count", profile_events.size(), 1)
    _check("occupy old default", s.rebind(&"open_door", KEY_1)["changed"], true)
    var before_blocked := s.current_profile()
    _check("single reset conflict rejected",
        s.reset_action(&"observe")["ok"], false)
    _check("single reset conflict reason", reports.back()["code"], "CONFLICT")
    _check("conflict does not mutate state", s.current_profile(), before_blocked)
    _check("preview full restore shows two changes",
        s.preview_restore_defaults()["changes"].size(), 2)
    _check("atomic default restore", s.restore_defaults()["changed"], true)
    _check("defaults restored", s.current_profile(), initial)
    _check("repeat restore no write or signal",
        s.restore_defaults()["changed"], false)

    # Validate file operations in unique user:// fixture directory.
    var folder := "user://game_web_module_input_002_r1_tests/" + str(Time.get_ticks_usec())
    var path := folder + "/input_bindings_candidate.json"
    var other_path := folder + "/other/input_bindings_candidate.json"
    _check("path traversal blocked",
        s.save("user://../input_bindings_candidate.json")["code"], "INVALID_PATH")
    _check("wrong filename blocked",
        s.save(folder + "/incorrect.json")["code"], "INVALID_PATH")
    _check("missing directory blocked",
        s.save(path)["code"], "MISSING_DIRECTORY")

    var create_status := DirAccess.make_dir_recursive_absolute(
        ProjectSettings.globalize_path(folder)
    )
    _check("fixture folder created", create_status, OK)

    if create_status == OK:
        _check("initial save", s.save(path)["code"], "SAVED")
        _check("saved file exists", FileAccess.file_exists(path), true)
        var disk_before := FileAccess.get_file_as_string(path)
        _check("repeat save avoids rewrite", s.save(path)["code"], "ALREADY_PERSISTED")
        _check("same disk bytes", FileAccess.get_file_as_string(path), disk_before)
        _check("rebind_and_save success",
            s.rebind_and_save(&"observe", KEY_Z, path)["code"], "SAVED_AND_APPLIED")
        _check("persisted observe binding", s.bindings.binding_for(&"observe"), KEY_Z)

        # Independent reader may load and validate existing config.
        var second = Settings.new()
        _check("save into known existing file without load refused",
            second.save(path)["code"], "LOAD_REQUIRED")
        _check("explicit load succeeds", second.load(path)["ok"], true)
        _check("loaded key matches", second.bindings.binding_for(&"observe"), KEY_Z)
        _check("loaded profile on second instance",
            second.current_profile(), s.current_profile())

        # Attempting to reset one default when another action owns that key.
        _check("occupy default while preserving uniqueness",
            s.rebind_and_save(&"open_door", KEY_1, path)["ok"], true)
        var before_conflict := s.current_profile()
        var disk_conflict := FileAccess.get_file_as_string(path)
        _check("reset_action_and_save conflict",
            s.reset_action_and_save(&"observe", path)["code"], "CONFLICT")
        _check("conflicted reset did not mutate", s.current_profile(), before_conflict)
        _check("conflicted reset did not write", FileAccess.get_file_as_string(path),
            disk_conflict)

        # Disk-first full restore: detects occupied .tmp before changing memory.
        _check("create temp occupant", _write_text(path + ".tmp", "keep"), true)
        var pending_profile := s.current_profile()
        _check("occupied temp rejects reset",
            s.restore_defaults_and_save(path)["code"], "TEMP_OCCUPIED")
        _check("failed reset keeps memory", s.current_profile(), pending_profile)
        _check("failed reset keeps file", FileAccess.get_file_as_string(path),
            disk_conflict)
        _check("occupied temp not overwritten",
            FileAccess.get_file_as_string(path + ".tmp"), "keep")
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
        _check("restore defaults with persistence",
            s.restore_defaults_and_save(path)["code"], "SAVED_AND_APPLIED")
        _check("restored map equals original", s.current_profile(), initial)
        _check("already persisted restore no changes",
            s.restore_defaults_and_save(path)["changed"], false)

        # Valid external writer creates a lost-update risk: reject stale save.
        var external := initial.duplicate(true)
        external["bindings"][0]["keycode"] = KEY_Y
        _check("fixture external update", _write_text(path,
            JSON.stringify(external)), true)
        var externally_modified := FileAccess.get_file_as_string(path)
        var before_reject := s.current_profile()
        _check("stale rebind/save refused",
            s.rebind_and_save(&"observe", KEY_Z, path)["code"], "EXTERNAL_CHANGE")
        _check("stale save leaves memory unchanged",
            s.current_profile(), before_reject)
        _check("stale save leaves disk unchanged",
            FileAccess.get_file_as_string(path), externally_modified)
        _check("explicit reload accepts new file", s.load(path)["ok"], true)
        _check("reload picks external key", s.bindings.binding_for(&"observe"), KEY_Y)
        _check("save after reload permitted", s.save(path)["ok"], true)

        # Reject corrupt external content with no silent reset or overwrite.
        _check("inject invalid JSON", _write_text(path, "{broken"), true)
        var corrupted_text := FileAccess.get_file_as_string(path)
        var old_profile := s.current_profile()
        _check("corrupt load rejected", s.load(path)["code"], "MALFORMED_JSON")
        _check("corrupt save rejected", s.save(path)["code"], "MALFORMED_JSON")
        _check("corrupt file preserved", FileAccess.get_file_as_string(path),
            corrupted_text)
        _check("corruption keeps memory", s.current_profile(), old_profile)

        # A fresh path has no known baseline, and must not be created implicitly.
        _check("missing nested parent rejected",
            s.restore_defaults_and_save(other_path)["code"], "MISSING_DIRECTORY")

        # Restore fixture for a deletion-after-load check.
        _check("repair test fixture explicitly",
            _write_text(path, JSON.stringify(initial)), true)
        _check("load repaired fixture", s.load(path)["ok"], true)
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
        _check("externally deleted config refused",
            s.save(path)["code"], "EXTERNAL_DELETE")

        # Delete only isolated test fixtures. No production/user files.
        DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))

    # Return owned copies: mutation by consumers cannot change internal data.
    var leaked := s.current_profile()
    leaked["bindings"][0]["keycode"] = KEY_Q
    _check("profile is detached copy",
        s.bindings.binding_for(&"observe") == KEY_Q, false)

    _check("operation reports emitted", reports.is_empty(), false)
    _finish()


func _finish() -> void:
    paused = false
    if failures.is_empty():
        print("PASS GAME-WEB-MODULE-INPUT-002 r1 (%d assertions)" % assertions)
        quit(0)
        return
    for failure in failures:
        printerr("FAIL " + failure)
    printerr("FAIL GAME-WEB-MODULE-INPUT-002 r1 (%d/%d failures)" % [
        failures.size(), assertions
    ])
    quit(1)
