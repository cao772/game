extends SceneTree
## GAME-WEB-CONTINUE-SHELL-003 r1
## FUTURE ONLY. Tests authored, absolutely NOT_RUN by this task.
## This file is not called by the demo or project settings.

const DemoScene = preload("res://shell_demo.tscn")
const Placeholder = preload("res://placeholder_adapter_candidate.gd")
const Registry = preload("res://module_registry_candidate.gd")

class BrokenPreview:
    extends RefCounted
    func preview() -> Dictionary:
        return {"ok": "yes", "title": "wrong", "body": "not valid"}
    func preview_action(_request_id: String) -> Dictionary:
        return {"ok": true, "simulated": true, "message": "should not run"}

class BrokenAction:
    extends RefCounted
    func preview() -> Dictionary:
        return {"ok": true, "title": "synthetic test", "body": "local only"}
    func preview_action(_request_id: String) -> Dictionary:
        return {"ok": true, "simulated": false, "message": "wrong flag"}

class RejectedAction:
    extends RefCounted
    func preview() -> Dictionary:
        return {"ok": true, "title": "synthetic test", "body": "local only"}
    func preview_action(_request_id: String) -> Dictionary:
        return {"ok": false, "simulated": true, "message": "local refusal"}

var failures: Array[String] = []
var signals_seen: int = 0
var last_signal: String = ""


func _initialize() -> void:
    call_deferred("_verify")


func _check(condition: bool, case_id: String) -> void:
    if not condition:
        failures.append(case_id)


func _on_simulated(slot: String, request_id: String) -> void:
    signals_seen += 1
    last_signal = slot + "/" + request_id


func _verify() -> void:
    var shell: Control = DemoScene.instantiate()
    get_root().add_child(shell)
    shell.simulated_request.connect(_on_simulated)

    # Preserve original r1 smoke cases, adapted to the new private registry.
    _check(shell.current_page() == "home", "S01")
    _check(shell.show_page("round"), "S02a")
    _check(shell.current_page() == "round", "S02b")
    _check(not shell.show_page("invalid"), "S03a")
    _check(shell.current_page() == "round", "S03b")
    for slot in ["prompt", "profile", "bindings"]:
        _check(shell.show_page(slot), "S04-" + slot)
        _check(shell.has_adapter(slot), "S05-" + slot)
    _check(shell.show_page("home"), "S06")
    _check(not shell.install_adapter("unknown", Placeholder.new("round")), "S07")
    _check(not shell.install_adapter("round", RefCounted.new()), "S08")
    _check(shell.remove_adapter("round"), "S09a")
    _check(not shell.has_adapter("round"), "S09b")
    _check(shell.show_page("round"), "S10a")
    var preview_button: Button = shell.get_node(
        "Frame/Layout/Body/View/Inner/Page/PreviewButton"
    )
    _check(preview_button.disabled, "S10b")
    _check(shell.install_adapter("round", Placeholder.new("round")), "S11a")
    _check(not preview_button.disabled, "S11b")
    _check(shell.show_page("home"), "S12a")
    _check(not preview_button.visible, "S12b")

    # C01-C05: deterministic navigation, history and module menu.
    _check(shell.history_copy().size() > 0, "C01")
    var history_before: int = shell.history_copy().size()
    _check(shell.show_page("home"), "C02a")
    _check(shell.history_copy().size() == history_before, "C02b")
    _check(shell.show_page("modules"), "C03a")
    _check(shell.current_page() == "modules", "C03b")
    _check(shell.go_back(), "C04a")
    _check(shell.current_page() == "home", "C04b")
    _check(not shell.show_page("bad_page"), "C05a")
    _check(shell.current_page() == "home", "C05b")

    # C06-C12: slot assembly and visible fail-closed status.
    shell.restore_all_mocks()
    var snap: Array[Dictionary] = shell.assembly_snapshot()
    _check(snap.size() == 4, "C06a")
    _check(str(snap[0]["status"]) == "synthetic_ready", "C06b")
    _check(shell.remove_adapter("prompt"), "C07a")
    _check(shell.module_status("prompt")["status"] == "missing", "C07b")
    _check(shell.show_page("prompt"), "C08a")
    _check(not shell.current_view()["ok"], "C08b")
    _check(preview_button.disabled, "C08c")
    _check(shell.disable_module("profile"), "C09a")
    _check(shell.module_status("profile")["status"] == "disabled", "C09b")
    _check(shell.stage_candidate("bindings"), "C10a")
    _check(shell.module_status("bindings")["status"] == "blocked_dependency", "C10b")
    _check(shell.stage_candidate("round"), "C11a")
    _check(shell.module_status("bindings")["status"] == "pending_review", "C11b")
    _check(not shell.module_status("bindings")["action_enabled"], "C11c")
    _check(shell.restore_mock("round"), "C12a")
    _check(shell.module_status("bindings")["status"] == "blocked_dependency", "C12b")

    # C13-C20: malformed preview/action, retry and explicit request gating.
    _check(shell.install_adapter("profile", BrokenPreview.new()), "C13a")
    _check(shell.module_status("profile")["status"] == "degraded", "C13b")
    _check(shell.show_page("profile"), "C14a")
    _check(preview_button.disabled, "C14b")
    _check(not shell.current_view()["ok"], "C14c")
    _check(shell.install_adapter("profile", BrokenAction.new()), "C15a")
    _check(shell.module_status("profile")["status"] == "synthetic_ready", "C15b")
    var before_bad: int = signals_seen
    var bad_request: Dictionary = shell.request_demo(false)
    _check(not bad_request["ok"], "C16a")
    _check(shell.module_status("profile")["status"] == "degraded", "C16b")
    _check(signals_seen == before_bad, "C16c")
    _check(shell.restore_mock("profile"), "C17a")
    _check(shell.module_status("profile")["status"] == "synthetic_ready", "C17b")
    var blocked_result: Dictionary = shell.request_demo(true)
    _check(not blocked_result["ok"], "C18a")
    _check(signals_seen == before_bad, "C18b")
    var sample_result: Dictionary = shell.request_demo(false)
    _check(sample_result.get("ok", false), "C19a")
    _check(sample_result.get("simulated", false), "C19b")
    _check(signals_seen == before_bad + 1, "C19c")
    _check(last_signal == "profile/sample_request", "C19d")
    _check(shell.install_adapter("profile", RejectedAction.new()), "C20a")
    _check(not shell.request_demo(false)["ok"], "C20b")
    _check(signals_seen == before_bad + 1, "C20c")

    # C21-C24: registry isolation, no data mutation, invalid slot, pause.
    var registry = Registry.new()
    registry.restore_all_mocks()
    var original: Array[Dictionary] = registry.snapshot()
    original[0]["status"] = "faked_by_caller"
    _check(registry.status("round")["status"] == "synthetic_ready", "C21")
    _check(not registry.stage_candidate("other"), "C22a")
    _check(registry.status("other")["status"] == "unknown", "C22b")
    _check(not registry.invoke_mock("round", "open_door")["ok"], "C23")
    shell.restore_mock("profile")
    paused = true
    var paused_result: Dictionary = shell.request_demo(false)
    paused = false
    _check(not paused_result["ok"], "C24a")
    _check(signals_seen == before_bad + 1, "C24b")

    # C25-C29: assembly controls and recovery retain navigation.
    shell.show_page("modules")
    var slot_selector: OptionButton = shell.get_node(
        "Frame/Layout/Body/View/Inner/Page/AssemblyControls/SlotSelector"
    )
    var mode_selector: OptionButton = shell.get_node(
        "Frame/Layout/Body/View/Inner/Page/AssemblyControls/ModeSelector"
    )
    _check(slot_selector.item_count == 4, "C25a")
    _check(mode_selector.item_count == 4, "C25b")
    slot_selector.select(1)  # prompt
    mode_selector.select(1)  # missing
    shell.call("_on_apply_assembly")
    _check(shell.module_status("prompt")["status"] == "missing", "C26")
    mode_selector.select(0)  # restore local mock
    shell.call("_on_apply_assembly")
    _check(shell.module_status("prompt")["status"] == "synthetic_ready", "C27")
    shell.restore_all_mocks()
    for slot in ["round", "prompt", "profile", "bindings"]:
        _check(shell.module_status(slot)["status"] == "synthetic_ready", "C28-" + slot)
    _check(shell.current_page() == "modules", "C29")

    shell.queue_free()
    if failures.is_empty():
        print("PASS GAME-WEB-CONTINUE-SHELL-003 r1")
        quit(0)
    else:
        for case_id in failures:
            push_error("FAIL " + case_id)
        quit(1)
