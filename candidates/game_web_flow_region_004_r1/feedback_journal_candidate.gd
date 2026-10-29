extends RefCounted
## GAME-WEB-PLAY-REGION-005 r1: bounded, entirely in-memory UI feedback.
## Technical placeholder only. No clock, telemetry, persistence, real events.
const CAPACITY: int = 12
const ALLOWED: Array[String] = [
    "info", "enter", "leave", "selection", "success", "rejected", "dismiss", "reset"
]

var _next_sequence: int = 1
var _entries: Array[Dictionary] = []


func append(kind: String, message: String, target_id: StringName = &"") -> bool:
    if not ALLOWED.has(kind):
        return false
    if message.strip_edges().is_empty() or message.length() > 140:
        return false
    if target_id != &"" and not str(target_id).begins_with("placeholder_"):
        return false
    _entries.append({
        "sequence": _next_sequence,
        "kind": kind,
        "message": message,
        "target_id": target_id
    })
    _next_sequence += 1
    while _entries.size() > CAPACITY:
        _entries.pop_front()
    return true


func entries() -> Array[Dictionary]:
    return _entries.duplicate(true)


func count() -> int:
    return _entries.size()


func last_entry() -> Dictionary:
    if _entries.is_empty():
        return {}
    return _entries.back().duplicate(true)


func clear() -> void:
    _entries.clear()
    _next_sequence = 1


func lines_for_display(max_lines: int = 6) -> String:
    var safe_count: int = clampi(max_lines, 1, CAPACITY)
    if _entries.is_empty():
        return "尚无交互反馈。"
    var text_lines: PackedStringArray = []
    var start_at: int = maxi(0, _entries.size() - safe_count)
    for index in range(start_at, _entries.size()):
        var entry: Dictionary = _entries[index]
        text_lines.append("#%d [%s] %s" % [
            entry["sequence"], entry["kind"], entry["message"]
        ])
    return "\n".join(text_lines)
