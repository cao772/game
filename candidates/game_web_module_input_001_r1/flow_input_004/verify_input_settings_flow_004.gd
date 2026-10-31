extends SceneTree
## GAME-WEB-FLOW-INPUT-004 r1 — DEFERRED headless SceneTree checks.
## Authored but NOT_RUN. No source project test invocation in this task.
## Future run: Godot 4.7.2 --headless --path <PR15 project> --script this file.

const PanelScene = preload("res://flow_input_004/input_settings_panel_004.tscn")
const Bindings = preload("res://input_bindings_candidate.gd")
const Migrator = preload("res://input_profile_migration_003.gd")

class FakeKeyboardRouter:
    extends Node
    func _unhandled_key_input(_event: InputEvent) -> void:
        pass

var errors: Array[String] = []
var checks: int = 0
var emitted: Array[Dictionary] = []


func _initialize() -> void:
    call_deferred("_verify")


func _eq(label: String, actual: Variant, wanted: Variant) -> void:
    checks += 1
    if actual != wanted:
        errors.append("%s expected=%s actual=%s" % [
            label, str(wanted), str(actual)
        ])


func _record(result: Dictionary) -> void:
    emitted.append(result.duplicate(true))


func _write_text(path: String, content: String) -> bool:
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(content)
    f.flush()
    var error := f.get_error()
    f.close()
    return error == OK


func _read_text(path: String) -> String:
    return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _cleanup_file(path: String) -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _verify() -> void:
    var sandbox := "user://game_web_flow_input_004_tests/" + str(Time.get_ticks_usec())
    var folder_result := DirAccess.make_dir_recursive_absolute(
        ProjectSettings.globalize_path(sandbox))
    _eq("create isolated directory", folder_result, OK)
    if folder_result != OK:
        _finish()
        return

    var path := sandbox + "/input_bindings_candidate_v2.json"
    var legacy_path := sandbox + "/input_bindings_candidate.json"
    var ui = PanelScene.instantiate()
    ui.v2_profile_path = path
    ui.legacy_profile_path = legacy_path
    root.add_child(ui)
    ui.operation_finished.connect(_record)

    var initial: Dictionary = ui.backend.profile()
    _eq("panel initial contains five entries", initial["bindings"].size(), 5)
    _eq("default observe key", ui.backend.workflow.settings.bindings.binding_for(
        &"observe"), KEY_1)
    _eq("no initial config file created", FileAccess.file_exists(path), false)
    _eq("panel initially idle", ui.ui_state()["pending_kind"], "")
    _eq("panel initially no confirm", ui.ui_state()["can_apply_save"], false)

    # Actual controls exist, including per-row rebind/reset buttons.
    for action in Bindings.ACTIONS:
        _eq("binding button exists " + action,
            ui.find_child("Bind_" + action, true, false) != null, true)
        _eq("reset button exists " + action,
            ui.find_child("Reset_" + action, true, false) != null, true)

    # Capture is two-stage: keyboard preview never mutates or writes.
    ui.begin_rebind(&"observe")
    _eq("capture target", ui.ui_state()["capture_action"], "observe")
    var conflict := ui.preview_key_candidate(KEY_2)
    _eq("conflicting key cannot apply", conflict["can_apply"], false)
    _eq("conflict action owner", str(conflict["explanation"]).contains(
        "open_door"), true)
    _eq("conflict disables memory confirm",
        ui.ui_state()["can_apply_memory"], false)
    _eq("conflict disables save confirm",
        ui.ui_state()["can_apply_save"], false)
    _eq("conflict left original map", ui.backend.profile(), initial)
    _eq("conflict did not save", FileAccess.file_exists(path), false)
    ui.cancel_preview()
    _eq("cancel clears preview", ui.ui_state()["pending_kind"], "")
    _eq("cancel no write", FileAccess.file_exists(path), false)

    # Valid preview and explicit in-memory commit.
    ui.begin_rebind(&"observe")
    var proposal := ui.preview_key_candidate(KEY_Z)
    _eq("valid key preview", proposal["can_apply"], true)
    _eq("preview new key", proposal["proposed_keycode"], KEY_Z)
    _eq("preview did not mutate", ui.backend.profile(), initial)
    _eq("preview enables memory confirm", ui.ui_state()["can_apply_memory"], true)
    _eq("preview enables persisted confirm", ui.ui_state()["can_apply_save"], true)
    var memory_result := ui.apply_memory()
    _eq("memory only accepted", memory_result["ok"], true)
    _eq("memory only key now Z", ui.backend.workflow.settings.bindings.binding_for(
        &"observe"), KEY_Z)
    _eq("memory-only did not write", FileAccess.file_exists(path), false)
    _eq("confirmation cleared", ui.ui_state()["pending_kind"], "")

    # Reset individual binding to an unoccupied default.
    var one := ui.preview_reset_action(&"observe")
    _eq("single reset ready", one["can_apply"], true)
    _eq("single reset only memory", ui.apply_memory()["ok"], true)
    _eq("single default restored", ui.backend.profile(), initial)

    # Occupied default blocks single-reset; full reset is atomic in memory.
    ui.begin_rebind(&"observe")
    ui.preview_key_candidate(KEY_Z)
    ui.apply_memory()
    ui.begin_rebind(&"open_door")
    ui.preview_key_candidate(KEY_1)
    ui.apply_memory()
    var state_before_conflict := ui.backend.profile()
    one = ui.preview_reset_action(&"observe")
    _eq("single reset collision is rejected", one["can_apply"], false)
    _eq("single reset cannot confirm", ui.ui_state()["can_apply_memory"], false)
    _eq("single reset did not change map", ui.backend.profile(), state_before_conflict)
    ui.cancel_preview()

    var all := ui.preview_restore_all()
    _eq("full restore has changes", all["changes"].size(), 2)
    _eq("full restore explicit confirmation", ui.ui_state()["can_apply_memory"], true)
    ui.cancel_preview()
    _eq("cancelled restore no mutation", ui.backend.profile(), state_before_conflict)
    ui.preview_restore_all()
    _eq("full memory restore", ui.apply_memory()["ok"], true)
    _eq("whole-map reset restored original", ui.backend.profile(), initial)

    # Create V2 ONLY on explicit save; again repeated save no write.
    ui.begin_rebind(&"observe")
    ui.preview_key_candidate(KEY_Z)
    _eq("save-and-apply success", ui.apply_and_save()["ok"], true)
    _eq("V2 persisted", FileAccess.file_exists(path), true)
    var migrated = Migrator.new()
    _eq("V2 schema valid", migrated.read_v2(path)["ok"], true)
    _eq("saved custom map", migrated.read_v2(path)["profile"],
        ui.backend.profile())
    var first_saved := _read_text(path)
    _eq("repeat save no write", ui.save_current()["committed"], false)
    _eq("repeat disk bytes", _read_text(path), first_saved)

    # A new panel does NOT auto-load; explicit load is required.
    var ui2 = PanelScene.instantiate()
    ui2.v2_profile_path = path
    root.add_child(ui2)
    _eq("second panel starts default", ui2.backend.profile(), initial)
    _eq("blind overwrite requires load", ui2.save_current()["code"],
        "LOAD_REQUIRED")
    _eq("explicit V2 load", ui2.load_current()["ok"], true)
    _eq("loaded custom binding", ui2.backend.profile(), ui.backend.profile())

    # Disk-first reset respects .tmp occupancy and leaves memory unchanged.
    _eq("temp occupant created", _write_text(path + ".tmp", "occupied"), true)
    var before_blocked := ui2.backend.profile()
    var before_bytes := _read_text(path)
    ui2.preview_restore_all()
    var blocked := ui2.apply_and_save()
    _eq("temp occupant blocks reset", blocked["code"], "TEMP_OCCUPIED")
    _eq("failed reset did not mutate", ui2.backend.profile(), before_blocked)
    _eq("failed reset did not replace disk", _read_text(path), before_bytes)
    _eq("temp occupant untouched", _read_text(path + ".tmp"), "occupied")
    _cleanup_file(path + ".tmp")

    ui2.preview_restore_all()
    _eq("confirmed persisted full reset", ui2.apply_and_save()["ok"], true)
    _eq("full reset defaults applied", ui2.backend.profile(), initial)
    _eq("full reset defaults on disk", migrated.read_v2(path)["profile"], initial)

    # Existing target modified elsewhere must be rejected, not overwritten.
    var external_profile := Bindings.new().profile()
    external_profile["bindings"][0]["keycode"] = KEY_Y
    var external_doc := migrated.to_v2(external_profile)["v2"]
    _eq("inject valid external V2",
        _write_text(path, JSON.stringify(external_doc)), true)
    var external_bytes := _read_text(path)
    ui2.begin_rebind(&"observe")
    ui2.preview_key_candidate(KEY_Z)
    var stale := ui2.apply_and_save()
    _eq("external change rejected", stale["code"], "EXTERNAL_CHANGE")
    _eq("external bytes preserved", _read_text(path), external_bytes)
    _eq("stale save memory unchanged", ui2.backend.profile(), initial)
    _eq("explicit reload permits new V2", ui2.load_current()["ok"], true)
    _eq("external code loaded", ui2.backend.workflow.settings.bindings.binding_for(
        &"observe"), KEY_Y)

    # Explicit V1 migration from a separate destination. Legacy retained.
    var migrate_dir := sandbox + "/migrate"
    _eq("migration fixture directory", DirAccess.make_dir_recursive_absolute(
        ProjectSettings.globalize_path(migrate_dir)), OK)
    var legacy2 := migrate_dir + "/input_bindings_candidate.json"
    var target2 := migrate_dir + "/input_bindings_candidate_v2.json"
    var source_bytes := JSON.stringify(external_profile)
    _eq("write migration fixture", _write_text(legacy2, source_bytes), true)
    var ui3 = PanelScene.instantiate()
    ui3.legacy_profile_path = legacy2
    ui3.v2_profile_path = target2
    root.add_child(ui3)
    var migrate_preview := ui3.preview_migration()
    _eq("migration preview ready", migrate_preview["code"], "MIGRATION_READY")
    _eq("preview leaves legacy intact", _read_text(legacy2), source_bytes)
    _eq("preview no V2 creation", FileAccess.file_exists(target2), false)
    ui3.cancel_preview()
    _eq("cancel migration leaves V2 absent", FileAccess.file_exists(target2), false)
    ui3.preview_migration()
    _eq("explicit migration confirms", ui3.apply_and_save()["ok"], true)
    _eq("migrated V2 present", migrated.read_v2(target2)["ok"], true)
    _eq("migrated V1 preserved", _read_text(legacy2), source_bytes)

    # Settings panel can optionally suspend PR #15 adapter when host supplies it.
    var router := FakeKeyboardRouter.new()
    root.add_child(router)
    router.set_process_unhandled_key_input(true)
    var before_open := router.is_processing_unhandled_key_input()
    _eq("session opens", ui.open_for_router(router)["ok"], true)
    _eq("game router temporarily disabled",
        router.is_processing_unhandled_key_input(), false)
    ui.close_panel()
    _eq("router flag restored after close",
        router.is_processing_unhandled_key_input(), before_open)
    _eq("settings panel hidden on close", ui.visible, false)
    router.free()

    # Only generated fixtures are removed, no external files or PR sources.
    ui.free()
    ui2.free()
    ui3.free()
    _cleanup_file(path)
    _cleanup_file(target2)
    _cleanup_file(legacy2)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(migrate_dir))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox))
    _eq("completion reached", true, true)
    _finish()


func _finish() -> void:
    paused = false
    if errors.is_empty():
        print("PASS GAME-WEB-FLOW-INPUT-004 r1 (%d assertions)" % checks)
        quit(0)
        return
    for error in errors:
        printerr("FAIL: " + error)
    printerr("FAIL GAME-WEB-FLOW-INPUT-004 r1 (%d/%d failed)" % [
        errors.size(), checks
    ])
    quit(1)
