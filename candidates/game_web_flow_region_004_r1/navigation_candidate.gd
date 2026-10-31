extends RefCounted
## GAME-WEB-REGION-006 r1: deterministic, in-memory XZ target navigation.
## Trial straight-line movement only. No navmesh, AI, collision or world API.

const TRIAL_SPEED: float = 2.0
const ARRIVAL_DISTANCE: float = 1.20
const MAX_STEP_SECONDS: float = 0.10
const TRIAL_X_LIMIT: float = 5.0
const TRIAL_Z_LIMIT: float = 4.2

var _destination: Vector2 = Vector2.ZERO
var _destination_id: StringName = &""
var _mode: StringName = &"idle" # idle | moving | paused | arrived | cancelled
var _reason: String = ""
var _revision: int = 0


func start_to_target(id: StringName, catalog: Array[Dictionary], from: Vector2) -> bool:
    if not from.is_finite() or not str(id).begins_with("placeholder_"):
        return false
    var candidate: Dictionary = {}
    for target in catalog:
        if target.get("id", &"") == id:
            candidate = target
            break
    if candidate.is_empty() or not (candidate.get("position") is Vector2):
        return false
    var goal: Vector2 = candidate["position"]
    if not _within_limits(goal):
        return false
    _destination = goal
    _destination_id = id
    _mode = &"arrived" if from.distance_to(goal) <= ARRIVAL_DISTANCE else &"moving"
    _reason = "已在目的地" if _mode == &"arrived" else "导航已启动"
    _revision += 1
    return true


func _within_limits(point: Vector2) -> bool:
    return (
        point.is_finite()
        and absf(point.x) <= TRIAL_X_LIMIT
        and absf(point.y) <= TRIAL_Z_LIMIT
    )


func advance(from: Vector2, delta: float) -> Dictionary:
    if not _within_limits(from):
        return {"ok": false, "reason": "当前位置无效"}
    if _mode != &"moving":
        return {"ok": false, "reason": "导航未在运行"}
    if is_nan(delta) or is_inf(delta) or delta <= 0.0:
        return {"ok": false, "reason": "帧步长无效"}

    var step_seconds: float = minf(delta, MAX_STEP_SECONDS)
    var displacement: Vector2 = _destination - from
    var remaining: float = displacement.length()
    # Stop safely within synthetic enter radius (1.55 m), not inside cube.
    var motion: float = minf(TRIAL_SPEED * step_seconds, maxf(remaining - ARRIVAL_DISTANCE, 0.0))
    var next_position: Vector2 = from
    if remaining > 0.000001:
        next_position = from + displacement / remaining * motion
    var arrived: bool = next_position.distance_to(_destination) <= ARRIVAL_DISTANCE + 0.0001
    if arrived:
        _mode = &"arrived"
        _reason = "已到达合成目标"
        _revision += 1

    return {
        "ok": true,
        "position": next_position,
        "arrived": arrived,
        "target_id": _destination_id
    }


func pause_for_focus_loss() -> bool:
    if _mode != &"moving":
        return false
    _mode = &"paused"
    _reason = "窗口失焦：导航暂停，恢复窗口后须手动继续"
    _revision += 1
    return true


func pause_manually() -> bool:
    if _mode != &"moving":
        return false
    _mode = &"paused"
    _reason = "用户暂停合成导航"
    _revision += 1
    return true


func resume_after_focus_return(authorized: bool) -> bool:
    if _mode != &"paused" or not authorized:
        return false
    _mode = &"moving"
    _reason = "用户明确继续合成导航"
    _revision += 1
    return true


func cancel(message: String = "用户取消导航") -> bool:
    if _mode != &"moving" and _mode != &"paused":
        return false
    _mode = &"cancelled"
    _reason = message.substr(0, 96)
    _revision += 1
    return true


func reset() -> void:
    _destination_id = &""
    _destination = Vector2.ZERO
    _mode = &"idle"
    _reason = ""
    _revision += 1


func is_moving() -> bool:
    return _mode == &"moving"


func is_paused() -> bool:
    return _mode == &"paused"


func state() -> Dictionary:
    return {
        "mode": _mode,
        "target_id": _destination_id,
        "destination": _destination,
        "reason": _reason,
        "revision": _revision
    }
