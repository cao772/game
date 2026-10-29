extends SceneTree
## GAME-WEB-PLAY-INPUT-005 r1 — future-only SceneTree verification.
## Authoring stage: NOT_RUN. Never run as part of this PR creation.

const PanelScene = preload("res://flow_input_005/input_settings_panel_005.tscn")
const Migrator = preload("res://input_profile_migration_003.gd")
const Bindings = preload("res://input_bindings_candidate.gd")

class FakeHostRouter:
    extends Node
    func _unhandled_key_input(_event: InputEvent) -> void:
        pass

var errors: Array[String] = []
var checks: int = 0
var outcomes: Array[Dictionary] = []


func _initialize() -> void:
    call_deferred("_exercise")


func _check(label: String, actual: Variant, expected: Variant) -> void:
    checks += 1
    if actual != expected:
        errors.append("%s | expected=%s actual=%s" % [
            label, str(expected), str(actual)
        ])


func _record(result: Dictionary) -> void:
    outcomes.append(result.duplicate(true))


func _write(path: String, source: String) -> bool:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(source)
    file.flush()
    var status := file.get_error()
    file.close()
    return status == OK


func _bytes(path: String) -> String:
    if FileAccess.file_exists(path):
        return FileAccess.get_file_as_string(path)
    return ""


func _delete_test_file(path: String) -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _new_ui(v2_path: String, v1_path: String):
    var ui = PanelScene.instantiate()
    ui.v2_profile_path = v2_path
    ui.legacy_profile_path = v1_path
    root.add_child(ui)
    return ui


func _exercise() -> void:
    var folder := "user://game_web_play_input_005_tests/" + str(Time.get_ticks_usec())
    var directory_result := DirAccess.make_dir_recursive_absolute(
        ProjectSettings.globalize_path(folder)
    )
    _check("create isolated fixtures", directory_result, OK)
    if directory_result != OK:
        _finish()
        return

    var v2 := folder + "/input_bindings_candidate_v2.json"
    var v1 := folder + "/input_bindings_candidate.json"
    var ui = _new_ui(v2, v1)
    ui.operation_finished.connect(_record)
    var model = Migrator.new()
    var defaults: Dictionary = Bindings.new().profile()

    _check("five rows", ui.backend.profile()["bindings"].size(), 5)
    _check("new recovery UI exists",
        ui.find_child("RetrySave", true, false) != null, true)
    _check("alternate-key UI exists",
        ui.find_child("AvailableKeyAlternatives", true, false) != null, true)
    _check("retry starts disabled", ui.ui_state_005()["retry_available"], false)
    _check("initial panel does not write disk", FileAccess.file_exists(v2), false)

    # Rebind preview collides but never performs an automatic swap.
    ui.begin_rebind(&"observe")
    var clash: Dictionary = ui.preview_key_candidate(KEY_2)
    _check("collision rejected", clash["can_apply"], false)
    _check("collision names current owner",
        str(clash["explanation"]).contains("open_door"), true)
    _check("conflict disables confirmation",
        ui.ui_state()["can_apply_save"], false)
    _check("conflict leaves defaults", ui.backend.profile(), defaults)
    _check("conflict gives alternatives", clash["alternatives"].size() > 0, true)

    if clash["alternatives"].size() > 0:
        var suggested := int(clash["alternatives"][0]["keycode"])
        ui._select_alternative(suggested)
        _check("clicking free key produces new preview",
            ui.ui_state()["can_apply_memory"], true)
        _check("alternative did not auto-commit",
            ui.backend.profile(), defaults)
    ui.cancel_preview()
    _check("cancel removes pending", ui.ui_state()["pending_kind"], "")
    _check("cancel leaves disk absent", FileAccess.file_exists(v2), false)

    # In-memory-only action and reset do not perform implicit saves.
    ui.begin_rebind(&"observe")
    _check("Z preview accepted",
        ui.preview_key_candidate(KEY_Z)["can_apply"], true)
    _check("preview no memory write", ui.backend.profile(), defaults)
    _check("explicit memory apply", ui.apply_memory()["ok"], true)
    _check("new memory key", ui.backend.profile()["bindings"][0]["keycode"], KEY_Z)
    _check("memory-only no disk", FileAccess.file_exists(v2), false)
    ui.preview_reset_action(&"observe")
    _check("single reset memory-only succeeds", ui.apply_memory()["ok"], true)
    _check("single default restored", ui.backend.profile(), defaults)

    # A collision at .tmp must leave the pending preview and memory intact.
    ui.begin_rebind(&"observe")
    ui.preview_key_candidate(KEY_Z)
    _check("temp occupant fixture", _write(v2 + ".tmp", "other writer"), true)
    var failed := ui.apply_and_save()
    _check("temp error", failed["code"], "TEMP_OCCUPIED")
    _check("temp error did not claim success", failed["ok"], false)
    _check("temp preserves live defaults", ui.backend.profile(), defaults)
    _check("temp preserves occupant", _bytes(v2 + ".tmp"), "other writer")
    _check("transient error permits deliberate retry",
        ui.ui_state_005()["retry_available"], true)
    _check("transient error retains pending proposal",
        ui.ui_state_005()["pending_kind"], "rebind")
    _check("failed save does not enable normal confirm",
        ui.ui_state()["can_apply_save"], false)

    # Cancellation after failure must never replay the pending operation.
    ui.cancel_preview()
    _check("cancel disarms retry", ui.ui_state_005()["retry_available"], false)
    _check("cancelled retry is rejected", ui.retry_save()["code"], "NO_RETRY")
    _check("cancelled retry leaves memory intact", ui.backend.profile(), defaults)
    _delete_test_file(v2 + ".tmp")

    # Retry is explicit, and rechecks the same target/path/profile.
    ui.begin_rebind(&"observe")
    ui.preview_key_candidate(KEY_Z)
    _check("second temp fixture", _write(v2 + ".tmp", "keep"), true)
    _check("save blocked", ui.apply_and_save()["code"], "TEMP_OCCUPIED")
    _delete_test_file(v2 + ".tmp")
    var saved := ui.retry_save()
    _check("retry successfully persists", saved["ok"], true)
    _check("retry disables itself", ui.ui_state_005()["retry_available"], false)
    _check("retry applied Z in memory", ui.backend.profile()["bindings"][0]["keycode"], KEY_Z)
    _check("V2 exists", FileAccess.file_exists(v2), true)
    var disk := model.read_v2(v2)
    _check("persisted V2 validates", disk["ok"], true)
    if disk["ok"]:
        _check("persisted V2 matches memory", disk["profile"], ui.backend.profile())

    # Changing the destination after preview must not write to a new path.
    ui.begin_rebind(&"observe")
    ui.preview_key_candidate(KEY_Y)
    var v2_original := ui.v2_profile_path
    var v2_changed := folder + "/alternate/input_bindings_candidate_v2.json"
    ui.v2_profile_path = v2_changed
    _check("changed path rejects stale confirmation",
        ui.apply_and_save()["code"], "STALE_PATH")
    _check("new path not created", FileAccess.file_exists(v2_changed), false)
    _check("stale path leaves memory Z", ui.backend.profile()["bindings"][0]["keycode"], KEY_Z)
    ui.v2_profile_path = v2_original

    # Stale external edit requires a real load; cannot use retry to overwrite.
    var outside := Bindings.new().profile()
    outside["bindings"][0]["keycode"] = KEY_Y
    var external_doc := model.to_v2(outside)
    _check("external candidate V2 valid", external_doc["ok"], true)
    if external_doc["ok"]:
        _check("write external V2 fixture",
            _write(v2, JSON.stringify(external_doc["v2"])), true)
        var external_bytes := _bytes(v2)
        ui.begin_rebind(&"observe")
        ui.preview_key_candidate(KEY_X)
        var conflict := ui.apply_and_save()
        _check("external file edit refused", conflict["code"], "EXTERNAL_CHANGE")
        _check("external bytes intact", _bytes(v2), external_bytes)
        _check("no retry for stale writer", ui.ui_state_005()["retry_available"], false)
        _check("stale writer did not change memory", ui.backend.profile()["bindings"][0]["keycode"], KEY_Z)
        _check("explicit load of external V2 succeeds", ui.load_current()["ok"], true)
        _check("external V2 loaded", ui.backend.profile()["bindings"][0]["keycode"], KEY_Y)

    # Occupying another action's default must block only single restore.
    ui.begin_rebind(&"open_door")
    ui.preview_key_candidate(KEY_1)
    _check("second action temporarily rebound", ui.apply_memory()["ok"], true)
    var conflict_snapshot := ui.backend.profile()
    var one := ui.preview_reset_action(&"observe")
    _check("single reset conflict", one["can_apply"], false)
    _check("single reset did not modify map", ui.backend.profile(), conflict_snapshot)
    ui.cancel_preview()

    # Full restore previews both changes and needs confirmation. Disk-first
    # failure cannot downgrade to silent memory-only restore.
    var reset_plan := ui.preview_restore_all()
    _check("full reset shows two actions", reset_plan["changes"].size(), 2)
    _check("temp file blocks full reset", _write(v2 + ".tmp", "busy"), true)
    var before_reset_bytes := _bytes(v2)
    _check("restore fails safely", ui.apply_and_save()["code"], "TEMP_OCCUPIED")
    _check("failed restore preserves memory", ui.backend.profile(), conflict_snapshot)
    _check("failed restore preserves V2", _bytes(v2), before_reset_bytes)
    _delete_test_file(v2 + ".tmp")
    _check("repreview available on transient failure",
        ui.ui_state_005()["repreview_available"], true)
    ui.repreview()
    _check("repreview does not change memory", ui.backend.profile(), conflict_snapshot)
    _check("confirmed full restore saves and applies", ui.apply_and_save()["ok"], true)
    _check("full defaults exact", ui.backend.profile(), defaults)
    _check("full defaults persisted", model.read_v2(v2)["profile"], defaults)

    # Already-default restore is allowed but must not rewrite identical V2.
    var bytes_after_reset := _bytes(v2)
    ui.preview_restore_all()
    var repeat := ui.apply_and_save()
    _check("repeat restore accepted", repeat["ok"], true)
    _check("repeat restore no disk commit", repeat["committed"], false)
    _check("repeat restore does not change bytes", _bytes(v2), bytes_after_reset)

    # A possibly committed failure must be marked "review" and not retried.
    ui.begin_rebind(&"observe")
    ui.preview_key_candidate(KEY_Z)
    ui._failed_save({
        "ok": false, "code": "POST_WRITE_VERIFY_FAILED",
        "message": "verification unknown", "committed": true
    }, "pending")
    _check("committed-unknown failure disables retry",
        ui.ui_state_005()["retry_available"], false)
    _check("committed-unknown failure clears pending",
        ui.ui_state_005()["pending_kind"], "")
    _check("committed-unknown warns manual review",
        ui.ui_state_005()["recovery_message"].contains("复核"), true)
    ui.cancel_preview()

    # Optional host keyboard router is disabled only during panel use.
    var router := FakeHostRouter.new()
    root.add_child(router)
    router.set_process_unhandled_key_input(true)
    var previously := router.is_processing_unhandled_key_input()
    _check("open with host router", ui.open_for_router(router)["ok"], true)
    _check("host keyboard handler paused",
        router.is_processing_unhandled_key_input(), false)
    ui.close_panel()
    _check("host handler flag restored",
        router.is_processing_unhandled_key_input(), previously)
    router.free()

    # Optional V1 migration remains explicit and cancellation leaves V1.
    var migration_dir := folder + "/migration"
    _check("migration fixture directory",
        DirAccess.make_dir_recursive_absolute(
            ProjectSettings.globalize_path(migration_dir)), OK)
    var legacy := migration_dir + "/input_bindings_candidate.json"
    var next_v2 := migration_dir + "/input_bindings_candidate_v2.json"
    var source := JSON.stringify(outside)
    _check("create legacy fixture", _write(legacy, source), true)
    var second = _new_ui(next_v2, legacy)
    _check("second panel migration preview",
        second.preview_migration()["code"], "MIGRATION_READY")
    _check("migration no V2 before confirmation",
        FileAccess.file_exists(next_v2), false)
    second.cancel_preview()
    _check("cancel migration preserves legacy", _bytes(legacy), source)
    second.preview_migration()
    _check("migration explicit confirm", second.apply_and_save()["ok"], true)
    _check("migration V2 validates", model.read_v2(next_v2)["ok"], true)
    _check("migration legacy still unchanged", _bytes(legacy), source)

    _check("finished with operation signal records", outcomes.is_empty(), false)

    ui.free()
    second.free()
    _delete_test_file(v2 + ".tmp")
    _delete_test_file(v2)
    _delete_test_file(legacy)
    _delete_test_file(next_v2)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(migration_dir))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
    _finish()


func _finish() -> void:
    paused = false
    if errors.is_empty():
        print("PASS GAME-WEB-PLAY-INPUT-005 r1 (%d checks)" % checks)
        quit(0)
        return
    for error in errors:
        printerr("FAIL " + error)
    printerr("FAIL GAME-WEB-PLAY-INPUT-005 r1 (%d/%d failed)" % [
        errors.size(), checks
    ])
    quit(1)
