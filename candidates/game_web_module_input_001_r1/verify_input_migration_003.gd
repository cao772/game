extends SceneTree
## GAME-WEB-CONTINUE-INPUT-003 r1 — future isolated verification only.
## Authoring status: NOT_RUN. Finite SceneTree, nonzero if assertions fail.
## No test or code was executed while creating this file.

const Migration = preload("res://input_profile_migration_003.gd")
const Workflow = preload("res://input_profile_workflow_003.gd")
const Bindings = preload("res://input_bindings_candidate.gd")

var failures: Array[String] = []
var assertions: int = 0
var workflow_events: Array[Dictionary] = []


func _initialize() -> void:
    call_deferred("_run")


func _expect(label: String, actual: Variant, expected: Variant) -> void:
    assertions += 1
    if actual != expected:
        failures.append("%s: actual=%s expected=%s" % [
            label, str(actual), str(expected)
        ])


func _write_fixture(path: String, value: String) -> bool:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(value)
    file.flush()
    var status := file.get_error()
    file.close()
    return status == OK


func _bytes(path: String) -> String:
    if not FileAccess.file_exists(path):
        return ""
    return FileAccess.get_file_as_string(path)


func _on_workflow(data: Dictionary) -> void:
    workflow_events.append(data.duplicate(true))


func _custom_v1(code: int) -> Dictionary:
    var binding_model = Bindings.new()
    var profile := binding_model.profile()
    profile["bindings"][0]["keycode"] = code
    return profile


func _remove_fixture(path: String) -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _run() -> void:
    var migration = Migration.new()
    var workflow = Workflow.new()
    workflow.workflow_reported.connect(_on_workflow)

    # Exact PR #15 V1 document is the ONLY supported migration source.
    var legacy: Dictionary = _custom_v1(KEY_Z)
    var converted: Dictionary = migration.to_v2(legacy)
    _expect("V1 to V2 accepted", converted["ok"], true)
    if not converted["ok"]:
        _finish()
        return
    _expect("target version", converted["v2"]["schema_version"], 2)
    _expect("target kind", converted["v2"]["format"], "game_web_input_bindings")
    _expect("v2 conversion preserves legacy key",
        converted["v2"]["bindings"][0]["keycode"], KEY_Z)
    _expect("v2 validates", migration.validate_v2(converted["v2"])["ok"], true)
    _expect("roundtrip exact v1",
        migration.validate_v2(converted["v2"])["v1"], legacy)

    var version_mismatch := converted["v2"].duplicate(true)
    version_mismatch["schema_version"] = 3
    _expect("v2 rejects unsupported future version",
        migration.validate_v2(version_mismatch)["code"], "UNSUPPORTED_VERSION")
    version_mismatch = converted["v2"].duplicate(true)
    version_mismatch["extra"] = true
    _expect("v2 rejects extra field",
        migration.validate_v2(version_mismatch)["code"], "INVALID_V2")
    version_mismatch = converted["v2"].duplicate(true)
    version_mismatch["format"] = "unexpected"
    _expect("v2 rejects foreign format",
        migration.validate_v2(version_mismatch)["code"], "INVALID_V2")
    var conflicted_v1 := legacy.duplicate(true)
    conflicted_v1["bindings"][1]["keycode"] = KEY_Z
    var conflict_result := migration.to_v2(conflicted_v1)
    _expect("migrator rejects duplicate key", conflict_result["code"], "CONFLICT")
    _expect("migrator reports owning action names",
        conflict_result["conflicts"].size(), 1)
    if conflict_result["conflicts"].size() > 0:
        _expect("report lists two action owners",
            conflict_result["conflicts"][0]["action_ids"].size(), 2)
    _expect("migrator does not accept invented legacy map",
        migration.to_v2({"observe": KEY_Z})["ok"], false)
    _expect("v2 rejects duplicate binding",
        migration.validate_v2({
            "schema_version": 2,
            "format": "game_web_input_bindings",
            "bindings": conflicted_v1["bindings"]
        })["ok"], false)

    # Explanations are read-only and do not silently swap assignments.
    var before_preview := workflow.current_profile()
    var collision := workflow.preview_conflict(&"observe", KEY_2)
    _expect("conflict code", collision["code"], "CONFLICT")
    _expect("conflict blocks apply", collision["can_apply"], false)
    _expect("explanation names owning action",
        str(collision["explanation"]).contains("open_door"), true)
    _expect("conflict provides next steps", collision["next_steps"].size() > 0, true)
    _expect("conflict preview leaves memory intact",
        workflow.current_profile(), before_preview)
    _expect("unknown action explained",
        workflow.preview_conflict(&"undefined", KEY_Z)["code"], "UNKNOWN_ACTION")
    _expect("new Z is available",
        workflow.preview_conflict(&"observe", KEY_Z)["can_apply"], true)

    # No global InputMap interaction is made. All test IO is in a unique dir.
    var root_dir := "user://game_web_continue_input_003_tests/" + str(Time.get_ticks_usec())
    var ensure_dir := DirAccess.make_dir_recursive_absolute(
        ProjectSettings.globalize_path(root_dir)
    )
    _expect("isolated fixture directory", ensure_dir, OK)
    if ensure_dir != OK:
        _finish()
        return
    var legacy_path := root_dir + "/input_bindings_candidate.json"
    var v2_path := root_dir + "/input_bindings_candidate_v2.json"

    _expect("wrong legacy filename rejected",
        migration.validate_migration_pair(root_dir + "/a.json", v2_path)["ok"],
        false)
    _expect("unsafe traversal rejected",
        migration.validate_v2_path("user://../input_bindings_candidate_v2.json")["ok"],
        false)
    _expect("missing legacy blocked",
        workflow.preview_migration(legacy_path, v2_path)["code"], "MISSING_FILE")

    var legacy_text := JSON.stringify(legacy, "  ")
    _expect("write isolated V1 fixture",
        _write_fixture(legacy_path, legacy_text), true)

    # A preview is side-effect-free for disk and live bindings.
    var proposal: Dictionary = workflow.preview_migration(legacy_path, v2_path)
    _expect("migration preview available", proposal["code"], "MIGRATION_READY")
    _expect("preview did not create V2", FileAccess.file_exists(v2_path), false)
    _expect("preview did not alter V1", _bytes(legacy_path), legacy_text)
    _expect("preview did not mutate memory", workflow.current_profile(), before_preview)
    var token: String = proposal.get("confirmation_token", "")
    _expect("token is provided", token.is_empty(), false)

    _expect("incorrect token rejected",
        workflow.confirm_migration("wrong")["code"], "STALE_PREVIEW")
    _expect("incorrect token did not create V2", FileAccess.file_exists(v2_path), false)

    # Explicit cancellation invalidates a previously proposed operation.
    _expect("cancel pending", workflow.cancel_pending()["code"], "CANCELLED")
    _expect("cancelled token rejected",
        workflow.confirm_migration(token)["code"], "STALE_PREVIEW")

    # Editing legacy between preview and confirmation must abort, not overwrite.
    proposal = workflow.preview_migration(legacy_path, v2_path)
    token = proposal["confirmation_token"]
    var replacement := _custom_v1(KEY_Y)
    _expect("modify V1 fixture", _write_fixture(legacy_path, JSON.stringify(replacement)), true)
    _expect("stale source rejected",
        workflow.confirm_migration(token)["code"], "SOURCE_CHANGED")
    _expect("source mismatch no V2", FileAccess.file_exists(v2_path), false)

    # Editing live mappings between preview and confirmation must also abort.
    proposal = workflow.preview_migration(legacy_path, v2_path)
    token = proposal["confirmation_token"]
    _expect("memory rebind accepted",
        workflow.settings.rebind(&"observe", KEY_X)["ok"], true)
    _expect("stale memory rejected",
        workflow.confirm_migration(token)["code"], "MEMORY_CHANGED")
    _expect("stale memory no V2", FileAccess.file_exists(v2_path), false)

    # Successful migration creates a separate V2 without editing legacy.
    var source_before_commit := _bytes(legacy_path)
    proposal = workflow.preview_migration(legacy_path, v2_path)
    token = proposal["confirmation_token"]
    var committed := workflow.confirm_migration(token)
    _expect("migration commits", committed["code"], "MIGRATED")
    _expect("migration persisted flag", committed["persisted"], true)
    _expect("destination created", FileAccess.file_exists(v2_path), true)
    _expect("legacy unchanged by migration", _bytes(legacy_path), source_before_commit)
    _expect("memory adopts migrated action key",
        workflow.settings.bindings.binding_for(&"observe"), KEY_Y)
    _expect("loaded destination preserves V1 map",
        migration.read_v2(v2_path)["profile"], replacement)
    _expect("token one-shot",
        workflow.confirm_migration(token)["code"], "STALE_PREVIEW")
    _expect("duplicate migration cannot overwrite target",
        workflow.preview_migration(legacy_path, v2_path)["code"], "TARGET_EXISTS")

    # Explicit V2 load is required for any other process/controller instance.
    var fresh = Workflow.new()
    _expect("fresh controller loads V2",
        fresh.load_v2(v2_path)["code"], "LOADED")
    _expect("fresh load matches binding", fresh.settings.bindings.binding_for(&"observe"),
        KEY_Y)

    # Repeated restore preview cannot mutate anything.
    var disk_before_reset := _bytes(v2_path)
    var memory_before_reset := workflow.current_profile()
    var restore := workflow.preview_restore_defaults(v2_path)
    _expect("restore preview ready", restore["code"], "RESTORE_READY")
    _expect("restore one binding planned", restore["changes"].size(), 1)
    _expect("restore preview did not change disk", _bytes(v2_path), disk_before_reset)
    _expect("restore preview did not change memory",
        workflow.current_profile(), memory_before_reset)

    var restore_token: String = restore["confirmation_token"]
    _expect("wrong restore token rejected",
        workflow.confirm_restore_defaults("not-the-token")["code"], "STALE_PREVIEW")
    _expect("wrong restore token left disk unchanged",
        _bytes(v2_path), disk_before_reset)

    # A fixed temporary occupant prevents both disk and memory changes.
    _expect("create temporary-path occupant",
        _write_fixture(v2_path + ".tmp", "keep"), true)
    _expect("restore sees temp collision",
        workflow.confirm_restore_defaults(restore_token)["code"], "TEMP_OCCUPIED")
    _expect("occupied temp retained", _bytes(v2_path + ".tmp"), "keep")
    _expect("failed reset left disk unchanged", _bytes(v2_path), disk_before_reset)
    _expect("failed reset left memory unchanged",
        workflow.current_profile(), memory_before_reset)
    _remove_fixture(v2_path + ".tmp")

    # A previous preview cannot be reused after an independent memory change.
    restore = workflow.preview_restore_defaults(v2_path)
    restore_token = restore["confirmation_token"]
    _expect("change live bindings for stale-memory test",
        workflow.settings.rebind(&"observe", KEY_Z)["ok"], true)
    _expect("reset detects stale live mapping",
        workflow.confirm_restore_defaults(restore_token)["code"], "MEMORY_CHANGED")

    # A valid external edit must not be overwritten by stale restore.
    restore = workflow.preview_restore_defaults(v2_path)
    restore_token = restore["confirmation_token"]
    var external := migration.to_v2(_custom_v1(KEY_X))["v2"]
    _expect("simulate external V2 change",
        _write_fixture(v2_path, JSON.stringify(external)), true)
    var external_text := _bytes(v2_path)
    _expect("external change blocks restoring",
        workflow.confirm_restore_defaults(restore_token)["code"], "EXTERNAL_CHANGE")
    _expect("external disk preserved", _bytes(v2_path), external_text)

    _expect("explicit V2 reload required and succeeds",
        workflow.load_v2(v2_path)["ok"], true)
    _expect("reload adopts external key",
        workflow.settings.bindings.binding_for(&"observe"), KEY_X)

    restore = workflow.preview_restore_defaults(v2_path)
    restore_token = restore["confirmation_token"]
    var reset_result := workflow.confirm_restore_defaults(restore_token)
    _expect("confirmed defaults restored", reset_result["code"], "DEFAULTS_RESTORED")
    _expect("restored defaults persisted", reset_result["persisted"], true)
    _expect("default restored in memory",
        workflow.settings.bindings.binding_for(&"observe"), KEY_1)
    _expect("default restored on disk",
        migration.read_v2(v2_path)["profile"], Bindings.new().profile())
    _expect("restoration did not alter legacy", _bytes(legacy_path), source_before_commit)

    # Repeated restore is idempotent and does not rewrite an identical file.
    var final_default_bytes := _bytes(v2_path)
    restore = workflow.preview_restore_defaults(v2_path)
    _expect("default preview no changes", restore["changes"].size(), 0)
    reset_result = workflow.confirm_restore_defaults(restore["confirmation_token"])
    _expect("repeat reset successful", reset_result["ok"], true)
    _expect("repeat reset did not commit another write",
        reset_result["committed"], false)
    _expect("repeat reset disk bytes stable", _bytes(v2_path), final_default_bytes)

    # A deleted target after a successful load cannot be silently recreated.
    _remove_fixture(v2_path)
    _expect("previously loaded target deletion detected",
        workflow.preview_restore_defaults(v2_path)["code"], "EXTERNAL_DELETE")

    # Another NEW path can be created by explicit restore without V1.
    var second_dir := root_dir + "/separate_fixture"
    _expect("second fixture directory",
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(second_dir)),
        OK)
    var other_v2 := second_dir + "/input_bindings_candidate_v2.json"
    var other_preview := fresh.preview_restore_defaults(other_v2)
    _expect("fresh new-file defaults preview", other_preview["code"], "RESTORE_READY")
    _expect("new defaults not written on preview", FileAccess.file_exists(other_v2), false)
    var other_result := fresh.confirm_restore_defaults(other_preview["confirmation_token"])
    _expect("explicit default config creation", other_result["ok"], true)
    _expect("new-file defaults persisted", migration.read_v2(other_v2)["ok"], true)

    # Corrupt existing V2: refused without a silent repair.
    var corrupt := _bytes(other_v2)
    _expect("inject corrupt V2 fixture", _write_fixture(other_v2, "{broken"), true)
    var old_memory := fresh.current_profile()
    _expect("corrupt load refused", fresh.load_v2(other_v2)["code"], "MALFORMED_JSON")
    _expect("corrupt file intact", _bytes(other_v2), "{broken")
    _expect("corrupt profile no live change", fresh.current_profile(), old_memory)
    _expect("corrupt restore preview refused",
        fresh.preview_restore_defaults(other_v2)["ok"], false)

    # Cleanup only uniquely created fixtures, not game/PR files.
    _remove_fixture(other_v2)
    _remove_fixture(v2_path)
    _remove_fixture(legacy_path)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(second_dir))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(root_dir))
    _expect("saved original V2 bytes existed", corrupt.is_empty(), false)
    _expect("workflow report signal fired", workflow_events.size() > 0, true)
    _finish()


func _finish() -> void:
    paused = false
    if failures.is_empty():
        print("PASS GAME-WEB-CONTINUE-INPUT-003 r1 (%d assertions)" % assertions)
        quit(0)
        return
    for failure in failures:
        printerr("FAIL " + failure)
    printerr("FAIL GAME-WEB-CONTINUE-INPUT-003 r1 (%d/%d)" % [
        failures.size(), assertions
    ])
    quit(1)
