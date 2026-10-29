extends Node
## GAME-WEB-INTEGRATE-001 r1 — isolated technical candidate.
## Uses INPUT r1 and STATE r1 unmodified. Not a shared API or canon.
## Runtime: InputRouter signal -> _on_router_action_requested -> dispatch_action.
## Headless: handle_key_candidate and dispatch_action accept injected gates.

signal snapshot_changed(snapshot: Dictionary)

const InputRouterCandidate = preload("res://input_router_candidate.gd")
const SnapshotCandidate = preload("res://round_snapshot_candidate.gd")

# Cooperative process-local path ownership. Not an inter-process file lock.
static var _path_owners: Dictionary = {}

var _router
var _storage = SnapshotCandidate.new()
var _snapshot: Dictionary = {}
var _save_path: String = ""
var _configured: bool = false
var _saving: bool = false
var _save_attempts: int = 0


func _ready() -> void:
    _router = InputRouterCandidate.new()
    _router.name = "InputRouterCandidate"
    add_child(_router)
    _router.action_requested.connect(_on_router_action_requested)


func _exit_tree() -> void:
    if _configured and _path_owners.get(_save_path, 0) == get_instance_id():
        _path_owners.erase(_save_path)


func _result(ok: bool, changed: bool = false, error: String = "") -> Dictionary:
    return {"ok": ok, "changed": changed, "error": error}


# Seed is used only if the named file does not exist. Existing valid data wins.
# The destination directory must already exist, as required by STATE r1.
# No disk write occurs during configuration.
func configure(seed: Variant, path: String) -> Dictionary:
    if not is_inside_tree():
        return _result(false, false, "Node must be in SceneTree")
    if _configured:
        return _result(false, false, "Already configured")

    var problem: String = _storage._schema_error(seed)
    if not problem.is_empty():
        return _result(false, false, problem)

    var mode: String = seed["mode"]
    problem = _storage._path_error(path, mode)
    if not problem.is_empty():
        return _result(false, false, problem)

    if _path_owners.has(path):
        return _result(false, false, "Writer path is already claimed")

    var initial: Dictionary = seed.duplicate(true)
    if FileAccess.file_exists(path):
        var loaded: Dictionary = _storage.load_snapshot(path, mode)
        if not loaded.get("ok", false):
            return _result(false, false, "Existing snapshot rejected: " + str(loaded.get("error", "")))
        initial = loaded["data"].duplicate(true)

    _snapshot = initial
    _save_path = path
    _configured = true
    _path_owners[path] = get_instance_id()
    return _result(true)


func snapshot_copy() -> Dictionary:
    return _snapshot.duplicate(true)


func save_attempt_count() -> int:
    return _save_attempts


# Button hookup: button.pressed.connect(
#     integration.request_button_action.bind(&"observe"))
# The original router enforces pause/native window focus; our signal listener
# adds real text-focus protection before dispatch.
func request_button_action(action_id: StringName) -> bool:
    if not _configured or _router == null:
        return false
    return _router.request_action(action_id)


func _runtime_blocked() -> bool:
    return not is_inside_tree() or get_tree().paused or not get_window().has_focus()


func _on_router_action_requested(action_id: StringName) -> void:
    dispatch_action(
        action_id,
        _runtime_blocked(),
        get_viewport().gui_get_focus_owner()
    )


# Headless input seam: uses INPUT r1's unchanged pure key decision.
# Runtime keyboard events are handled by the child InputRouter itself.
func handle_key_candidate(
    event: InputEventKey,
    blocked: bool,
    focus_owner: Control
) -> Dictionary:
    var action_id: StringName = InputRouterCandidate.action_for_key_event(
        event, blocked, focus_owner
    )
    if action_id == &"":
        return _result(false, false, "Key event filtered")
    return dispatch_action(action_id, blocked, focus_owner)


# Single mutation and save path shared by actions from keyboard and buttons.
# blocked/focus_owner are injectable test gates; production passes real gates.
func dispatch_action(
    action_id: StringName,
    blocked: bool,
    focus_owner: Control
) -> Dictionary:
    if not _configured or not is_inside_tree():
        return _result(false, false, "Not configured")
    if get_tree().paused or blocked:
        return _result(false, false, "Input blocked")
    if InputRouterCandidate._focus_is_text_input(focus_owner):
        return _result(false, false, "Text input focused")
    if _saving:
        return _result(false, false, "Write already in progress")
    if not InputRouterCandidate._valid_action(action_id):
        return _result(false, false, "Invalid action")

    # Cancel is deliberately non-mutating. No unprovided UI semantics assumed.
    if action_id == &"cancel":
        return _result(true)

    var candidate: Dictionary = _snapshot.duplicate(true)
    var phase: String = candidate["phase"]

    match action_id:
        &"observe":
            if phase != "ready":
                return _result(false, false, "Observe requires ready")
            candidate["phase"] = "observing"
        &"open_door":
            if phase != "ready" and phase != "observing":
                return _result(false, false, "Open requires ready or observing")
            candidate["phase"] = "resolved"
            candidate["door_open"] = true
        &"withdraw":
            if phase != "ready" and phase != "observing":
                return _result(false, false, "Withdraw requires ready or observing")
            candidate["phase"] = "deferred"
            candidate["door_open"] = false
        &"reset_round":
            # Reset only candidate phase and door flag. Preserve mode, ID,
            # and clock. No implied world-time rollback or new round ID.
            candidate["phase"] = "ready"
            candidate["door_open"] = false
        _:
            return _result(false, false, "Unmapped action")

    if candidate == _snapshot:
        return _result(true)  # Idempotent reset, no save.

    var problem: String = _storage._schema_error(candidate)
    if not problem.is_empty():
        return _result(false, false, "Candidate invalid: " + problem)

    _saving = true
    _save_attempts += 1
    var saved: Dictionary = _storage.save_snapshot(_save_path, candidate)
    _saving = false

    if not saved.get("ok", false):
        # On failure, the in-memory snapshot remains unchanged.
        return _result(false, false, "Save rejected: " + str(saved.get("error", "")))

    # Publish only after successful storage, with copy-on-read semantics.
    _snapshot = candidate.duplicate(true)
    snapshot_changed.emit(_snapshot.duplicate(true))
    return _result(true, true)
