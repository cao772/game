extends SceneTree
## Future-only, NOT_RUN. No automatic invocation by the demo itself.
## Run only with explicit owner/Codex authorization later.

const DemoScene = preload("res://shell_demo.tscn")
const Placeholder = preload("res://placeholder_adapter_candidate.gd")
var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_verify")


func _check(condition: bool, case_id: String) -> void:
    if not condition:
        failures.append(case_id)


func _verify() -> void:
    var shell: Control = DemoScene.instantiate()
    get_root().add_child(shell)

    _check(shell.call("current_page") == "home", "S01")
    _check(shell.call("show_page", "round"), "S02a")
    _check(shell.call("current_page") == "round", "S02b")
    _check(not shell.call("show_page", "invalid"), "S03a")
    _check(shell.call("current_page") == "round", "S03b")
    for slot in ["prompt", "profile", "bindings"]:
        _check(shell.call("show_page", slot), "S04-" + slot)
        _check(shell.call("has_adapter", slot), "S05-" + slot)

    _check(shell.call("show_page", "home"), "S06")
    _check(not shell.call("install_adapter", "unknown", Placeholder.new("round")), "S07")
    _check(not shell.call("install_adapter", "round", RefCounted.new()), "S08")
    _check(shell.call("remove_adapter", "round"), "S09a")
    _check(not shell.call("has_adapter", "round"), "S09b")
    _check(shell.call("show_page", "round"), "S10a")
    var preview_button: Button = shell.get_node(
        "Frame/Layout/Body/View/Inner/Page/PreviewButton"
    )
    _check(preview_button.disabled, "S10b")
    _check(shell.call("install_adapter", "round", Placeholder.new("round")), "S11a")
    _check(not preview_button.disabled, "S11b")
    _check(shell.call("show_page", "home"), "S12a")
    _check(not preview_button.visible, "S12b")

    shell.queue_free()
    if failures.is_empty():
        print("PASS GAME-WEB-MODULE-SHELL-001 r1")
        quit(0)
    else:
        for case_id in failures:
            push_error("FAIL " + case_id)
        quit(1)
