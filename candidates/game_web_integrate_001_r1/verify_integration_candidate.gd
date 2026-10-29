extends SceneTree
## GAME-WEB-INTEGRATE-001 r1. Finite headless tests, nonzero on failure.
## Native desktop focus and performance are NOT_RUN in this suite.

const Integration = preload("res://integration_candidate.gd")
const State = preload("res://round_snapshot_candidate.gd")

var failures: Array[String] = []
var checks: int = 0
var emitted: Array[Dictionary] = []


func _initialize() -> void:
    call_deferred("_run_tests")


func _check(label: String, actual: Variant, expected: Variant) -> void:
    checks += 1
    if actual != expected:
        failures.append("%s | actual=%s expected=%s" % [
            label, str(actual), str(expected)
        ])


func _event(code: int, pressed: bool = true, echo: bool = false) -> InputEventKey:
    var key := InputEventKey.new()
    key.keycode = code
    key.pressed = pressed
    key.echo = echo
    return key


func _seed(mode: String = "story") -> Dictionary:
    return {
        "version": 1,
        "mode": mode,
        "round_id": "integration-test-round",
        "phase": "ready",
        "door_open": false,
        "clock_seconds": 12.5
    }


func _capture_snapshot(data: Dictionary) -> void:
    emitted.append(data.duplicate(true))


func _file_text(path: String) -> String:
    if not FileAccess.file_exists(path):
        return ""
    return FileAccess.get_file_as_string(path)


func _run_tests() -> void:
    var sandbox := "user://game_web_integrate_001_tests/" + str(Time.get_ticks_usec())
    var directory_error := DirAccess.make_dir_recursive_absolute(
        ProjectSettings.globalize_path(sandbox)
    )
    _check("isolated test directory created", directory_error, OK)
    if directory_error != OK:
        _finish()
        return

    var story_path := sandbox + "/story.round_snapshot.json"
    var free_path := sandbox + "/free.round_snapshot.json"
    var controller = Integration.new()
    root.add_child(controller)
    controller.snapshot_changed.connect(_capture_snapshot)

    # Configuration is validated but must not write any snapshot.
    var invalid_seed := _seed()
    invalid_seed["clock_seconds"] = -1.0
    _check("invalid seed rejected",
        controller.configure(invalid_seed, story_path)["ok"], false)
    _check("bad configure did not claim path",
        controller.configure(_seed(), story_path)["ok"], true)
    _check("configure does not create file",
        FileAccess.file_exists(story_path), false)
    _check("configure no write attempts", controller.save_attempt_count(), 0)

    # A second controller cannot claim the same path in this process.
    var competitor = Integration.new()
    root.add_child(competitor)
    _check("cooperative single writer path lock",
        competitor.configure(_seed(), story_path)["ok"], false)
    competitor.free()

    # Invalid input must not emit, write, or mutate memory.
    var before := controller.snapshot_copy()
    _check("unknown action rejected",
        controller.dispatch_action(&"not_an_action", false, null)["ok"], false)
    _check("unmapped key rejected",
        controller.handle_key_candidate(_event(KEY_Q), false, null)["ok"], false)
    _check("echo rejected",
        controller.handle_key_candidate(_event(KEY_1, true, true), false, null)["ok"], false)
    _check("release rejected",
        controller.handle_key_candidate(_event(KEY_1, false), false, null)["ok"], false)
    _check("blocked key rejected",
        controller.handle_key_candidate(_event(KEY_1), true, null)["ok"], false)
    _check("no memory mutation on filtered input", controller.snapshot_copy(), before)
    _check("no file written on filtered input",
        FileAccess.file_exists(story_path), false)
    _check("no write attempts on filtered input", controller.save_attempt_count(), 0)

    # Both text widgets and their descendant Controls must block input.
    var line := LineEdit.new()
    var line_child := Control.new()
    line.add_child(line_child)
    var edit := TextEdit.new()
    var edit_child := Control.new()
    edit.add_child(edit_child)
    for focused in [line, line_child, edit, edit_child]:
        _check("text focused key blocked",
            controller.handle_key_candidate(_event(KEY_1), false, focused)["ok"],
            false)
        _check("text focused button blocked",
            controller.dispatch_action(&"open_door", false, focused)["ok"],
            false)
    _check("text focus no writes", controller.save_attempt_count(), 0)

    # First valid input: one save, then publish, persisted data matches memory.
    _check("observe accepted",
        controller.handle_key_candidate(_event(KEY_1), false, null)["changed"], true)
    _check("observe phase", controller.snapshot_copy()["phase"], "observing")
    _check("observe exactly one attempt", controller.save_attempt_count(), 1)
    _check("observe emitted once", emitted.size(), 1)
    var storage := State.new()
    var persisted := storage.load_snapshot(story_path, "story")
    _check("observe persisted", persisted["ok"], true)
    if persisted["ok"]:
        _check("disk equals memory", persisted["data"], controller.snapshot_copy())
    _check("clock not modified", controller.snapshot_copy()["clock_seconds"], 12.5)

    # Unsupported phase transition and echo do not trigger a second save.
    _check("repeat observe transition rejected",
        controller.handle_key_candidate(_event(KEY_1), false, null)["ok"], false)
    _check("echo still rejected",
        controller.handle_key_candidate(_event(KEY_2, true, true), false, null)["ok"],
        false)
    _check("no extra writes on rejected transition", controller.save_attempt_count(), 1)

    # Open changes exactly two fields; a second open is refused.
    _check("open accepted",
        controller.handle_key_candidate(_event(KEY_2), false, null)["changed"], true)
    _check("door open", controller.snapshot_copy()["door_open"], true)
    _check("phase resolved", controller.snapshot_copy()["phase"], "resolved")
    _check("open attempt count", controller.save_attempt_count(), 2)
    _check("open twice rejected",
        controller.dispatch_action(&"open_door", false, null)["ok"], false)
    _check("no extra write for second open", controller.save_attempt_count(), 2)

    # Cancel has no invented persistence semantics.
    var resolved := controller.snapshot_copy()
    var resolved_bytes := _file_text(story_path)
    _check("cancel acknowledged", controller.dispatch_action(&"cancel", false, null)["ok"],
        true)
    _check("cancel no mutation", controller.snapshot_copy(), resolved)
    _check("cancel no write", controller.save_attempt_count(), 2)
    _check("cancel disk unchanged", _file_text(story_path), resolved_bytes)

    # Reset is idempotent: only phase/door reset, no clock or round-id rewrites.
    _check("reset accepted",
        controller.handle_key_candidate(_event(KEY_R), false, null)["changed"], true)
    _check("reset phase", controller.snapshot_copy()["phase"], "ready")
    _check("reset door", controller.snapshot_copy()["door_open"], false)
    _check("reset preserves clock", controller.snapshot_copy()["clock_seconds"], 12.5)
    _check("reset preserves round_id",
        controller.snapshot_copy()["round_id"], "integration-test-round")
    _check("reset one write", controller.save_attempt_count(), 3)
    _check("repeat reset no change",
        controller.dispatch_action(&"reset_round", false, null)["changed"], false)
    _check("repeat reset no write", controller.save_attempt_count(), 3)

    # New press after a completed cycle is legitimate.
    _check("legitimate new key press",
        controller.handle_key_candidate(_event(KEY_1), false, null)["changed"], true)
    _check("new press saved", controller.save_attempt_count(), 4)

    # A real Button.pressed signal can call the same dispatch entry.
    # This is a headless/injected button simulation, NOT a native click test.
    var button := Button.new()
    root.add_child(button)
    var button_results: Array[Dictionary] = []
    button.pressed.connect(func() -> void:
        button_results.append(
            controller.dispatch_action(&"withdraw", false, null)
        )
    )
    button.pressed.emit()
    _check("button route result received", button_results.size(), 1)
    _check("button routes to withdraw", controller.snapshot_copy()["phase"], "deferred")
    _check("button exactly one write", controller.save_attempt_count(), 5)
    if button_results.size() == 1:
        _check("button route reported changed", button_results[0]["changed"], true)
    else:
        _check("button route reported changed", false, true)

    # SceneTree pause wins even over false injected blocked flag.
    paused = true
    var paused_state := controller.snapshot_copy()
    _check("pause rejects reset",
        controller.dispatch_action(&"reset_round", false, null)["ok"], false)
    _check("pause leaves state intact", controller.snapshot_copy(), paused_state)
    _check("pause leaves attempt count intact", controller.save_attempt_count(), 5)
    paused = false
    _check("resume permits reset",
        controller.dispatch_action(&"reset_round", false, null)["changed"], true)
    _check("resume exactly one save", controller.save_attempt_count(), 6)

    # Existing file wins over supplied seed: no startup overwrite.
    controller.free()
    var reload = Integration.new()
    root.add_child(reload)
    var different_seed := _seed()
    different_seed["clock_seconds"] = 999.0
    _check("reload configured", reload.configure(different_seed, story_path)["ok"], true)
    _check("reload preserved persisted clock",
        reload.snapshot_copy()["clock_seconds"], 12.5)
    _check("reload did not save", reload.save_attempt_count(), 0)

    # Corrupt existing snapshot must not be silently overwritten.
    var corrupted := FileAccess.open(story_path, FileAccess.WRITE)
    _check("test could corrupt isolated fixture", corrupted != null, true)
    if corrupted != null:
        corrupted.store_string("{bad json")
        corrupted.close()
    var memory_before_fail := reload.snapshot_copy()
    var bytes_before_fail := _file_text(story_path)
    _check("corrupt target save rejected",
        reload.dispatch_action(&"observe", false, null)["ok"], false)
    _check("failed save no memory mutation",
        reload.snapshot_copy(), memory_before_fail)
    _check("failed save no disk replacement", _file_text(story_path), bytes_before_fail)
    _check("failed save one attempt", reload.save_attempt_count(), 1)
    _check("failed save tmp cleaned",
        FileAccess.file_exists(story_path + ".tmp"), false)
    reload.free()

    var rejects_corrupt = Integration.new()
    root.add_child(rejects_corrupt)
    _check("corrupt startup rejected",
        rejects_corrupt.configure(_seed(), story_path)["ok"], false)
    rejects_corrupt.free()

    # Separate free-mode path, cannot cross-load story filename/mode.
    var free_controller = Integration.new()
    root.add_child(free_controller)
    _check("free path configured",
        free_controller.configure(_seed("free"), free_path)["ok"], true)
    _check("mode preserved", free_controller.snapshot_copy()["mode"], "free")
    _check("free mode withdraw",
        free_controller.dispatch_action(&"withdraw", false, null)["changed"], true)
    _check("free snapshot saved once", free_controller.save_attempt_count(), 1)
    _check("story file not changed by free action",
        _file_text(story_path), bytes_before_fail)
    _check("free load succeeds", storage.load_snapshot(free_path, "free")["ok"],
        true)
    _check("cross-mode load refused", storage.load_snapshot(free_path, "story")["ok"],
        false)
    free_controller.free()

    # Clean only the uniquely named test fixture directory.
    line.free()
    edit.free()
    button.free()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(story_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(free_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox))
    _finish()


func _finish() -> void:
    paused = false
    if failures.is_empty():
        print("PASS GAME-WEB-INTEGRATE-001 r1 (%d assertions)" % checks)
        quit(0)
        return
    for failure in failures:
        printerr("FAIL " + failure)
    printerr("FAIL GAME-WEB-INTEGRATE-001 r1 (%d/%d failed)" %
        [failures.size(), checks])
    quit(1)
