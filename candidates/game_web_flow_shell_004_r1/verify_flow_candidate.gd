extends SceneTree
## Future-only verification for GAME-WEB-FLOW-SHELL-004 r1.
## This script is NOT_RUN; do not execute without author approval.

const Flow = preload("res://flow_entry.tscn")
var failures: Array[String] = []
var requested: int = 0
var bindings_changed: int = 0

func _initialize() -> void:
    call_deferred("_verify")

func _check(value: bool, case_id: String) -> void:
    if not value:
        failures.append(case_id)

func _on_prompt(_id: StringName) -> void:
    requested += 1

func _on_binding(_action: String, _key: int) -> void:
    bindings_changed += 1

func _verify() -> void:
    var app: Variant = Flow.instantiate()
    get_root().add_child(app)
    app.connect("synthetic_prompt_requested", Callable(self, "_on_prompt"))
    app.connect("synthetic_binding_changed", Callable(self, "_on_binding"))
    var shell: Variant = app.get_node("Shell")

    _check(str(shell.call("current_page")) == "home", "F01")
    _check(bool(app.call("begin_flow")), "F02")
    _check(str(app.call("current_flow_step")) == "prompt", "F03")
    var stage: VBoxContainer = app.get_node(
        "Shell/Frame/Layout/Body/View/Inner/Page/IsolatedModuleStage")
    _check(stage.get_child_count() == 1, "F04")
    var prompt: Node = stage.get_child(0)
    _check(prompt.has_method("show_for_targets"), "F05")
    _check(bool(prompt.call("is_prompt_shown")), "F06")
    _check(bool(prompt.call("cycle_target", 1)), "F07")
    _check(bool(prompt.call("request_interaction", false)), "F08")
    _check(requested == 1, "F09")

    _check(bool(app.call("advance_flow")), "F10")
    _check(str(app.call("current_flow_step")) == "profile", "F11")
    _check(stage.get_child_count() == 1, "F12")
    var profile: Node = stage.get_child(0)
    _check(profile.has_method("profile_copy"), "F13")
    var profile_data: Dictionary = profile.call("profile_copy")
    _check(str(profile_data.get("profile_id", "")) == "sample-record-a", "F14")
    _check(bool(app.call("advance_flow")), "F15")
    _check(str(app.call("current_flow_step")) == "bindings", "F16")
    _check(stage.get_child_count() == 1, "F17")

    var action_selector: OptionButton = stage.get_node("InputCandidateControls/ActionSelector")
    var key_selector: OptionButton = stage.get_node("InputCandidateControls/KeySelector")
    _check(action_selector.item_count == 5, "F18")
    _check(key_selector.item_count >= 10, "F19")
    action_selector.select(0)
    key_selector.select(1) # KEY_2 is already owned by open_door.
    app.call("_preview_binding")
    var feedback: Label = stage.get_node("InputCandidateControls/PreviewFeedback")
    _check(feedback.text.find("冲突") >= 0 or feedback.text.find("不能应用") >= 0, "F20")
    var emitted_before: int = bindings_changed
    app.call("_apply_binding")
    _check(bindings_changed == emitted_before, "F21")
    key_selector.select(5) # KEY_4 free at defaults.
    app.call("_apply_binding")
    _check(bindings_changed == emitted_before + 1, "F22")
    app.call("_restore_bindings")
    _check(bool(app.call("advance_flow")), "F23")
    _check(str(shell.call("current_page")) == "home", "F24")

    # Failed dependency does not block navigation and does not mount a real widget.
    _check(bool(shell.call("remove_adapter", "prompt")), "F25")
    _check(bool(app.call("show_page", "prompt")), "F26")
    _check(stage.get_child_count() == 0, "F27")
    _check(str(shell.call("module_status", "prompt")["status"]) == "missing", "F28")
    _check(bool(shell.call("stage_candidate", "bindings")), "F29")
    _check(str(shell.call("module_status", "bindings")["status"]) == "blocked_dependency", "F30")
    _check(bool(app.call("show_page", "bindings")), "F31")
    _check(stage.get_child_count() == 0, "F32")
    _check(bool(shell.call("stage_candidate", "round")), "F33")
    _check(str(shell.call("module_status", "bindings")["status"]) == "pending_review", "F34")
    _check(stage.get_child_count() == 0, "F35")
    _check(bool(shell.call("restore_mock", "prompt")), "F36")
    _check(bool(app.call("show_page", "prompt")), "F37")
    _check(stage.get_child_count() == 1, "F38")

    # Missing instance or resource path and native focus-loss cases need manual
    # authorized tests; this source does not prove editor/run compatibility.
    app.queue_free()
    if failures.is_empty():
        print("PASS GAME-WEB-FLOW-SHELL-004 r1")
        quit(0)
    else:
        for item in failures:
            push_error("FAIL " + item)
        quit(1)
