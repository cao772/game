extends SceneTree
## GAME-WEB-INPUT-006 r1 — FUTURE verification source only.
## NOT_RUN: no Godot/parser/CI/test execution in authoring window.
## Synthetic user:// fixtures; no source candidates or real settings altered.

const Scene006 = preload("res://flow_input_006/input_settings_panel_006.tscn")
const Bindings = preload("res://input_bindings_candidate.gd")
const Migrator = preload("res://input_profile_migration_003.gd")

var failures: Array[String] = []
var count: int = 0


func _initialize() -> void:
    call_deferred("_exercise")


func _assert(label: String, got: Variant, expected: Variant) -> void:
    count += 1
    if got != expected:
        failures.append("%s: expected=%s got=%s" % [
            label, str(expected), str(got)
        ])


func _make_panel(path: String, legacy: String):
    var panel = Scene006.instantiate()
    panel.v2_profile_path = path
    panel.legacy_profile_path = legacy
    root.add_child(panel)
    return panel


func _write(path: String, source: String) -> bool:
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(source)
    f.flush()
    var error := f.get_error()
    f.close()
    return error == OK


func _read(path: String) -> String:
    return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _cleanup(path: String) -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _memory_rebind(ui, action: StringName, code: int) -> Dictionary:
    ui.begin_rebind(action)
    var proposed: Dictionary = ui.preview_key_candidate(code)
    if not proposed.get("can_apply", false):
        return {"ok": false, "code": "PREVIEW_REJECTED"}
    return ui.apply_memory()


func _exercise() -> void:
    var folder := "user://game_web_input_006_tests/" + str(Time.get_ticks_usec())
    var made := DirAccess.make_dir_recursive_absolute(
        ProjectSettings.globalize_path(folder))
    _assert("private fixture folder", made, OK)
    if made != OK:
        _finish()
        return

    var target := folder + "/input_bindings_candidate_v2.json"
    var legacy := folder + "/input_bindings_candidate.json"
    var ui = _make_panel(target, legacy)
    var defaults: Dictionary = Bindings.new().profile()
    var migrator = Migrator.new()

    _assert("five stable actions", ui.backend.profile()["bindings"].size(), 5)
    _assert("no automatic V2 write", FileAccess.file_exists(target), false)
    _assert("swap button exists", ui.find_child("PreviewSwap", true, false) != null, true)
    _assert("undo button exists", ui.find_child("PreviewUndo", true, false) != null, true)
    _assert("focus explanation exists",
        ui.find_child("AccessibleFocusHint", true, false) != null, true)
    _assert("initial history depth", ui.ui_state_006()["undo_depth"], 0)
    _assert("initial undo disabled", ui.ui_state_006()["undo_available"], false)

    # Conflicted rebind cannot auto-apply. Swap remains a separate explicit step.
    ui.begin_rebind(&"observe")
    var conflict: Dictionary = ui.preview_key_candidate(KEY_2)
    _assert("collision surfaced", conflict.get("code", ""), "CONFLICT")
    _assert("automatic apply disabled", ui.ui_state()["can_apply_memory"], false)
    _assert("swap offered when single owner", ui.ui_state_006()["swap_available"], true)
    _assert("conflict does not mutate", ui.backend.profile(), defaults)
    var swap_plan: Dictionary = ui.choose_swap()
    _assert("explicit swap preview", swap_plan.get("code", ""), "SWAP_READY")
    _assert("swap proposal includes both changes", swap_plan.get("changes", []).size(), 2)
    _assert("swap preview still no mutation", ui.backend.profile(), defaults)
    _assert("swap now needs confirmation", ui.ui_state()["can_apply_memory"], true)
    ui.cancel_preview()
    _assert("cancel swap leaves settings", ui.backend.profile(), defaults)
    _assert("cancel swap no history", ui.ui_state_006()["undo_depth"], 0)

    ui.begin_rebind(&"observe")
    ui.preview_key_candidate(KEY_2)
    ui.choose_swap()
    var applied := ui.apply_memory()
    _assert("memory-only swap applied", applied.get("ok", false), true)
    _assert("observes KEY_2", ui.backend.workflow.settings.bindings.binding_for(
        &"observe"), KEY_2)
    _assert("door takes KEY_1", ui.backend.workflow.settings.bindings.binding_for(
        &"open_door"), KEY_1)
    _assert("valid map after swap",
        ui.backend.workflow.settings.bindings.inspect_profile(
            ui.backend.profile())["ok"], true)
    _assert("no disk for memory swap", FileAccess.file_exists(target), false)
    _assert("one reversible entry", ui.ui_state_006()["undo_depth"], 1)

    # Memory-only undo is itself previewed and confirmed; it cannot touch disk.
    var undo: Dictionary = ui.preview_undo()
    _assert("undo offered", undo.get("code", ""), "UNDO_READY")
    _assert("undo scope is memory", undo.get("scope", ""), "memory")
    _assert("memory-only confirm available", ui.ui_state()["can_apply_memory"], true)
    _assert("disk confirm unavailable", ui.ui_state()["can_apply_save"], false)
    ui.cancel_preview()
    _assert("cancel undo preserves swap", ui.backend.workflow.settings.bindings.binding_for(
        &"observe"), KEY_2)
    _assert("cancel undo retains history", ui.ui_state_006()["undo_depth"], 1)
    ui.preview_undo()
    var undone := ui.apply_memory()
    _assert("undo applies old memory snapshot", undone.get("ok", false), true)
    _assert("memory returns to original defaults", ui.backend.profile(), defaults)
    _assert("undo consumes journal entry", ui.ui_state_006()["undo_depth"], 0)

    # Single reset collision can also be swapped, but not implicitly.
    _assert("observe temporary remap", _memory_rebind(ui, &"observe", KEY_Z)["ok"], true)
    _assert("door can occupy released 1",
        _memory_rebind(ui, &"open_door", KEY_1)["ok"], true)
    var taken_default: Dictionary = ui.preview_reset_action(&"observe")
    _assert("individual restore still blocked", taken_default.get("code", ""), "CONFLICT")
    _assert("swap offered on reset conflict", ui.ui_state_006()["swap_available"], true)
    var previous := ui.backend.profile()
    ui.choose_swap()
    ui.cancel_preview()
    _assert("cancelled swap leaves both bindings", ui.backend.profile(), previous)

    # Entire defaults restore is still explicit, atomic intent and undoable.
    var whole: Dictionary = ui.preview_restore_all()
    _assert("whole defaults has changes", whole.get("changes", []).size(), 2)
    _assert("whole restore cancellation safe", ui.ui_state()["can_apply_memory"], true)
    ui.cancel_preview()
    _assert("cancel restore leaves profile", ui.backend.profile(), previous)
    ui.preview_restore_all()
    _assert("whole restore memory success", ui.apply_memory()["ok"], true)
    _assert("whole restore matches defaults", ui.backend.profile(), defaults)
    _assert("restore adds one undo entry", ui.ui_state_006()["undo_depth"], 3)
    ui.preview_undo()
    _assert("undo whole restore in memory", ui.apply_memory()["ok"], true)
    _assert("undo reestablishes previous map", ui.backend.profile(), previous)

    # An explicit standalone save is a new journal epoch; never offer
    # a misleading undo of a disk state that was not recorded.
    _assert("explicit save-current", ui.save_current()["ok"], true)
    _assert("save-current clears prior journal", ui.ui_state_006()["undo_depth"], 0)
    _assert("saved V2 validates", migrator.read_v2(target)["ok"], true)
    _assert("saved V2 matches live", migrator.read_v2(target)["profile"],
        ui.backend.profile())

    # Persisted swap records the before snapshot and can be undone disk-first.
    ui.begin_rebind(&"observe")
    var occupied: Dictionary = ui.preview_key_candidate(KEY_1)
    _assert("observe currently KEY_Z/KEY_1 occupied", occupied["code"], "CONFLICT")
    ui.choose_swap()
    var disk_swap := ui.apply_and_save()
    _assert("disk-first swap accepted", disk_swap.get("ok", false), true)
    _assert("disk swap journal entry", ui.ui_state_006()["undo_depth"], 1)
    _assert("V2 now matches swapped memory",
        migrator.read_v2(target)["profile"], ui.backend.profile())
    undo = ui.preview_undo()
    _assert("disk undo scope", undo.get("scope", ""), "disk")
    _assert("disk undo cannot silently downgrade to memory",
        ui.ui_state()["can_apply_memory"], false)
    _assert("disk undo confirmation is save", ui.ui_state()["can_apply_save"], true)

    # An occupied temp must block persisted undo without changing live keys.
    _assert("temp occupied fixture", _write(target + ".tmp", "do not overwrite"), true)
    var before_failed_undo := ui.backend.profile()
    var before_disk := _read(target)
    var blocked := ui.apply_and_save()
    _assert("temp blocks persisted undo", blocked.get("code", ""), "TEMP_OCCUPIED")
    _assert("failed persisted undo leaves RAM", ui.backend.profile(),
        before_failed_undo)
    _assert("failed persisted undo leaves V2", _read(target), before_disk)
    _assert("temp untouched", _read(target + ".tmp"), "do not overwrite")
    _assert("pending undo retained for retry",
        ui.ui_state()["pending_kind"], "undo")
    _assert("only explicit retry enabled", ui.ui_state_005()["retry_available"], true)
    _cleanup(target + ".tmp")
    var retried := ui.retry_save()
    _assert("user retry persists undo", retried.get("ok", false), true)
    _assert("persisted undo restores previous memory", ui.backend.profile(), previous)
    _assert("persisted undo restores previous disk", migrator.read_v2(target)["profile"],
        previous)
    _assert("undo consumed once", ui.ui_state_006()["undo_depth"], 0)

    # A lost-update risk blocks undo; external data is never overwritten.
    ui.begin_rebind(&"observe")
    ui.preview_key_candidate(KEY_2)
    var disk_rebind := ui.apply_and_save()
    _assert("persisted rebind succeeds", disk_rebind.get("ok", false), true)
    _assert("journal has persisted change", ui.ui_state_006()["undo_depth"], 1)
    var external: Dictionary = Bindings.new().profile()
    external["bindings"][0]["keycode"] = KEY_Y
    var external_v2: Dictionary = migrator.to_v2(external)
    _assert("external candidate valid", external_v2["ok"], true)
    _assert("write synthetic external V2",
        _write(target, JSON.stringify(external_v2["v2"])), true)
    var external_bytes := _read(target)
    ui.preview_undo()
    var refused := ui.apply_and_save()
    _assert("external update rejects undo", refused.get("code", ""), "EXTERNAL_CHANGE")
    _assert("external bytes not overwritten", _read(target), external_bytes)
    _assert("unsafe retry not offered", ui.ui_state_005()["retry_available"], false)
    _assert("explicit V2 reload", ui.load_current()["ok"], true)
    _assert("fresh load clears old journal", ui.ui_state_006()["undo_depth"], 0)

    # Accessibility is a concrete focus contract, not screen-reader proof.
    var bind_button = ui.find_child("Bind_observe", true, false) as Button
    _assert("binding control present", bind_button != null, true)
    if bind_button != null:
        _assert("binding focus enabled",
            bind_button.focus_mode, Control.FOCUS_ALL)
        _assert("binding has keyboard next path",
            str(bind_button.focus_next).is_empty(), false)
        _assert("binding has descriptive tooltip",
            bind_button.tooltip_text.is_empty(), false)
    var undo_button = ui.find_child("PreviewUndo", true, false) as Button
    if undo_button != null:
        _assert("undo has focus mode",
            undo_button.focus_mode, Control.FOCUS_ALL)

    # Backspace is unavailable for PR #15 bindings, so it is a safe
    # capture-cancel chord for keyboard-only access.
    ui.begin_rebind(&"cancel")
    var backspace := InputEventKey.new()
    backspace.keycode = KEY_BACKSPACE
    backspace.pressed = true
    backspace.echo = false
    ui._input(backspace)
    _assert("Backspace cancels key capture",
        ui.ui_state()["capture_action"], "")
    _assert("Backspace does not remap Escape", ui.backend.workflow.settings.bindings.binding_for(
        &"cancel"), KEY_ESCAPE)

    # The panel's open/close only alters the supplied adapter Node flag.
    var original := ui.ui_state_006()["undo_depth"]
    _assert("no spontaneous undo record on focus operations",
        ui.ui_state_006()["undo_depth"], original)

    # Clean up only explicitly generated unique fixtures.
    ui.free()
    _cleanup(target + ".tmp")
    _cleanup(target)
    _cleanup(legacy)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
    _finish()


func _finish() -> void:
    paused = false
    if failures.is_empty():
        print("PASS GAME-WEB-INPUT-006 r1 (%d assertions)" % count)
        quit(0)
        return
    for failure in failures:
        printerr("FAIL " + failure)
    printerr("FAIL GAME-WEB-INPUT-006 r1 (%d/%d failures)" % [
        failures.size(), count
    ])
    quit(1)
