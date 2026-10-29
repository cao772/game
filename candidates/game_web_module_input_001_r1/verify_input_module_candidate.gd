extends SceneTree
## GAME-WEB-MODULE-INPUT-001 r1 — future verification fixture.
## THIS SCRIPT HAS NOT BEEN RUN BY THE AUTHORING WINDOW.

const Bindings = preload("res://input_bindings_candidate.gd")
const Adapter = preload("res://input_binding_router_candidate.gd")

class FakeRouter:
    extends Node

    func _unhandled_key_input(_event: InputEvent) -> void:
        pass


class FakeIntegration:
    extends Node

    var received: Array[StringName] = []

    func _ready() -> void:
        var router := FakeRouter.new()
        router.name = "InputRouterCandidate"
        add_child(router)
        router.set_process_unhandled_key_input(true)

    func request_button_action(action_id: StringName) -> bool:
        received.append(action_id)
        return true


var failures: Array[String] = []
var assertions: int = 0


func _initialize() -> void:
    call_deferred("_run")


func _check(label: String, actual: Variant, expected: Variant) -> void:
    assertions += 1
    if actual != expected:
        failures.append("%s expected=%s actual=%s" % [
            label, str(expected), str(actual)
        ])


func _key(code: int, down: bool = true, echo: bool = false) -> InputEventKey:
    var event := InputEventKey.new()
    event.keycode = code
    event.pressed = down
    event.echo = echo
    return event


func _fixture_path(folder: String) -> String:
    return folder + "/input_bindings_candidate.json"


func _run() -> void:
    var bindings = Bindings.new()
    var defaults := bindings.profile()

    # 1. Supplied INPUT r1 keys are the candidate defaults.
    var default_codes := [KEY_1, KEY_2, KEY_3, KEY_R, KEY_ESCAPE]
    var action_ids := ["observe", "open_door", "withdraw", "reset_round", "cancel"]
    for index in range(action_ids.size()):
        _check("default key " + action_ids[index],
            bindings.binding_for(StringName(action_ids[index])),
            default_codes[index])
        _check("default resolve " + action_ids[index],
            bindings.resolve_key_event(_key(default_codes[index]), false, null),
            StringName(action_ids[index]))
    _check("unknown action code", bindings.binding_for(&"other"), -1)

    # 2. Invalid rebinds are non-mutating and report conflicts.
    _check("occupied key denied", bindings.rebind(&"observe", KEY_2)["ok"], false)
    _check("occupied key is reported",
        bindings.check_conflicts(&"observe", KEY_2).size(), 1)
    _check("unknown action rejected", bindings.rebind(&"other", KEY_Z)["ok"], false)
    _check("modifier key unsupported", bindings.rebind(&"observe", KEY_SHIFT)["ok"], false)
    _check("invalid numeric type rejected", bindings.rebind(&"observe", "Z")["ok"], false)
    _check("default map remains unchanged after rejections", bindings.profile(), defaults)

    # 3. Valid changes, echo, release, modifier and focused text input.
    _check("valid rebind accepted", bindings.rebind(&"observe", KEY_Z)["changed"], true)
    _check("new key resolves", bindings.resolve_key_event(
        _key(KEY_Z), false, null), &"observe")
    _check("old key no longer resolves", bindings.resolve_key_event(
        _key(KEY_1), false, null), &"")
    _check("echo denied", bindings.resolve_key_event(
        _key(KEY_Z, true, true), false, null), &"")
    _check("key release denied", bindings.resolve_key_event(
        _key(KEY_Z, false), false, null), &"")
    _check("unknown key denied", bindings.resolve_key_event(
        _key(KEY_Q), false, null), &"")
    _check("injected loss of focus denied", bindings.resolve_key_event(
        _key(KEY_Z), true, null), &"")
    var modifier_event := _key(KEY_Z)
    modifier_event.ctrl_pressed = true
    _check("modified chord denied", bindings.resolve_key_event(
        modifier_event, false, null), &"")

    var line := LineEdit.new()
    var line_child := Control.new()
    line.add_child(line_child)
    var edit := TextEdit.new()
    var edit_child := Control.new()
    edit.add_child(edit_child)
    for owner in [line, line_child, edit, edit_child]:
        _check("text input focus blocked", bindings.resolve_key_event(
            _key(KEY_Z), false, owner), &"")
    var neutral := Control.new()
    _check("non-text focus permitted", bindings.resolve_key_event(
        _key(KEY_Z), false, neutral), &"observe")

    # 4. Reset one action only if default key is free.
    _check("occupy another default", bindings.rebind(&"open_door", KEY_1)["ok"], true)
    var before_conflicted_reset := bindings.profile()
    _check("single reset conflict rejected",
        bindings.reset_action(&"observe")["ok"], false)
    _check("conflicted reset nonmutating",
        bindings.profile(), before_conflicted_reset)
    _check("whole-map defaults restored",
        bindings.restore_defaults()["changed"], true)
    _check("defaults restored exactly", bindings.profile(), defaults)
    _check("repeated defaults are a no-op",
        bindings.restore_defaults()["changed"], false)
    _check("single reset no-op", bindings.reset_action(&"observe")["changed"], false)

    # 5. Profile schema validation and transactional imports.
    var corrupted: Dictionary = defaults.duplicate(true)
    corrupted["bindings"][1]["keycode"] = corrupted["bindings"][0]["keycode"]
    _check("duplicate profile rejected", bindings.inspect_profile(corrupted)["ok"], false)
    _check("duplicate collision reported",
        bindings.inspect_profile(corrupted)["conflicts"].size(), 1)
    _check("bad profile apply rejected", bindings.apply_profile(corrupted)["ok"], false)
    _check("failed import unchanged", bindings.profile(), defaults)
    var unknown: Dictionary = defaults.duplicate(true)
    unknown["bindings"][0]["action_id"] = "unapproved_action"
    _check("unknown profile action rejected", bindings.apply_profile(unknown)["ok"], false)
    var extra: Dictionary = defaults.duplicate(true)
    extra["unapproved_field"] = "no"
    _check("extra top-level field rejected", bindings.apply_profile(extra)["ok"], false)
    _check("non-object rejected", bindings.apply_profile([])["ok"], false)

    var numeric: Dictionary = defaults.duplicate(true)
    numeric["version"] = 1.0
    numeric["bindings"][0]["keycode"] = float(KEY_1)
    _check("integral JSON numbers accepted", bindings.apply_profile(numeric)["ok"], true)
    _check("numeric normalization is stable", bindings.profile(), defaults)
    var custom: Dictionary = defaults.duplicate(true)
    custom["bindings"][0]["keycode"] = KEY_Z
    _check("custom import accepted", bindings.apply_profile(custom)["changed"], true)
    _check("custom import sets new code", bindings.binding_for(&"observe"), KEY_Z)
    _check("restore before persistence", bindings.restore_defaults()["ok"], true)

    # 6. Filesystem rules (future headless test only). Unique private fixture.
    var directory := "user://game_web_module_input_001_r1_tests/" + str(Time.get_ticks_usec())
    var path := _fixture_path(directory)
    _check("unsafe path rejected",
        bindings.save_profile("user://../input_bindings_candidate.json")["ok"], false)
    _check("wrong filename rejected",
        bindings.save_profile(directory + "/other.json")["ok"], false)
    _check("missing directory rejected",
        bindings.save_profile(path)["ok"], false)
    var make_error := DirAccess.make_dir_recursive_absolute(
        ProjectSettings.globalize_path(directory)
    )
    _check("create isolated fixture directory", make_error, OK)

    if make_error == OK:
        _check("save defaults", bindings.save_profile(path)["ok"], true)
        _check("saved file exists", FileAccess.file_exists(path), true)
        _check("remap after save", bindings.rebind(&"observe", KEY_Z)["ok"], true)
        _check("load original", bindings.load_profile(path)["ok"], true)
        _check("loaded defaults", bindings.profile(), defaults)
        _check("load no-op", bindings.load_profile(path)["changed"], false)
        var existing := FileAccess.get_file_as_string(path)
        var file := FileAccess.open(path, FileAccess.WRITE)
        _check("fixture opens for corrupt overwrite", file != null, true)
        if file != null:
            file.store_string("{not json")
            file.close()
        var corrupt_contents := FileAccess.get_file_as_string(path)
        var previous := bindings.profile()
        _check("corrupt load rejected", bindings.load_profile(path)["ok"], false)
        _check("corrupt load no memory change", bindings.profile(), previous)
        _check("corrupt destination save rejected", bindings.save_profile(path)["ok"], false)
        _check("corrupt destination preserved",
            FileAccess.get_file_as_string(path), corrupt_contents)
        _check("temporary file not created",
            FileAccess.file_exists(path + ".tmp"), false)
        _check("fixture had saved bytes", existing.is_empty(), false)
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
        DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))

    # 7. PR #6-compatible attach/detach without loading/changing PR #6 source.
    var fake := FakeIntegration.new()
    root.add_child(fake)
    var legacy: Node = fake.get_node("InputRouterCandidate")
    var original_flag := legacy.is_processing_unhandled_key_input()
    var adapter = Adapter.new()
    root.add_child(adapter)
    _check("attach succeeds", adapter.attach_integration(fake)["ok"], true)
    _check("adapter owns target", adapter.attached(), true)
    _check("legacy handler disabled", legacy.is_processing_unhandled_key_input(), false)

    var competitor = Adapter.new()
    root.add_child(competitor)
    _check("second adapter denied", competitor.attach_integration(fake)["ok"], false)
    competitor.free()

    var recipient := Callable(fake, "request_button_action")
    _check("key forwarded to supplied receiver",
        adapter.route_key_candidate(_key(KEY_1), false, null, recipient)["ok"], true)
    _check("forwarded action is canonical", fake.received[0], &"observe")
    var received_before := fake.received.size()
    _check("echo does not forward",
        adapter.route_key_candidate(_key(KEY_1, true, true),
            false, null, recipient)["ok"], false)
    _check("blocked key does not forward",
        adapter.route_key_candidate(_key(KEY_1), true, null, recipient)["ok"], false)
    _check("text-focused key does not forward",
        adapter.route_key_candidate(_key(KEY_1), false, line_child, recipient)["ok"],
        false)
    _check("no accidental receiver calls", fake.received.size(), received_before)
    _check("no receiver refuses",
        adapter.route_key_candidate(_key(KEY_1), false, null, Callable())["ok"],
        false)
    _check("empty receiver no extra actions", fake.received.size(), received_before)

    paused = true
    _check("paused SceneTree blocks injected false gate",
        adapter.route_key_candidate(_key(KEY_1), false, null, recipient)["ok"], false)
    paused = false
    _check("resumed SceneTree forwards again",
        adapter.route_key_candidate(_key(KEY_1), false, null, recipient)["ok"], true)

    adapter.detach_integration()
    _check("detach disables adapter", adapter.attached(), false)
    _check("legacy handler flag restored",
        legacy.is_processing_unhandled_key_input(), original_flag)
    _check("reattach allowed", adapter.attach_integration(fake)["ok"], true)
    adapter.free()
    _check("exit restores old flag",
        legacy.is_processing_unhandled_key_input(), original_flag)

    fake.free()
    line.free()
    edit.free()
    neutral.free()
    _finish()


func _finish() -> void:
    paused = false
    if failures.is_empty():
        print("PASS GAME-WEB-MODULE-INPUT-001 r1 (%d checks)" % assertions)
        quit(0)
        return
    for issue in failures:
        printerr("FAIL " + issue)
    printerr("FAIL GAME-WEB-MODULE-INPUT-001 r1 (%d/%d failures)" % [
        failures.size(), assertions
    ])
    quit(1)
