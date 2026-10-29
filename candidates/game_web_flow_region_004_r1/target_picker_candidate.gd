extends RefCounted
## GAME-WEB-PLAY-REGION-005 r1 — pure synthetic XZ mouse picking.
## Does not mutate state, scene, input routing, or real game objects.
const DEFAULT_PICK_RADIUS: float = 0.52

static func choose_at(
    ground_point: Vector2,
    catalog: Array[Dictionary],
    reachable: Array[StringName],
    pick_radius: float = DEFAULT_PICK_RADIUS
) -> Dictionary:
    if not ground_point.is_finite():
        return {"hit": false, "reason": "坐标无效"}
    if not Vector2(pick_radius, 0.0).is_finite() or pick_radius <= 0.0 or pick_radius > 2.0:
        return {"hit": false, "reason": "选择半径无效"}

    var best_id: StringName = &""
    var best_distance: float = INF
    for record in catalog:
        if not record.has("id") or not record.has("position"):
            continue
        if not record["position"] is Vector2:
            continue
        var position: Vector2 = record["position"]
        if not position.is_finite():
            continue
        var candidate_id: StringName = StringName(str(record["id"]))
        var distance: float = position.distance_to(ground_point)
        if distance > pick_radius:
            continue
        if distance < best_distance - 0.0001:
            best_distance = distance
            best_id = candidate_id
        elif absf(distance - best_distance) <= 0.0001:
            if best_id == &"" or str(candidate_id) < str(best_id):
                best_id = candidate_id

    if best_id == &"":
        return {"hit": false, "reason": "没有选中合成方块"}
    return {
        "hit": true,
        "target_id": best_id,
        "eligible": reachable.has(best_id),
        "distance_to_marker": best_distance
    }
