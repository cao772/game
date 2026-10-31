extends RefCounted
## GAME-WEB-FLOW-CHAR-004 r1; local read-only view-state proposal, NOT_RUN.
## Profiles are full strict #14-compatible dictionaries; no story, save or IO.

const Contract = preload("res://profile_contract_candidate.gd")
const MAX_PROFILES := 24
const MAX_QUERY_CHARS := 80
const PAGE_SIZE := 6

var _profiles: Array[Dictionary] = []
var _by_id: Dictionary = {}
var _selected_id: String = ""
var _query: String = ""
var _page_index: int = 0


func replace_profiles(source: Variant) -> Dictionary:
    if typeof(source) != TYPE_ARRAY:
        return {"ok": false, "error": "资料集合必须是数组"}
    var entries: Array = source
    if entries.size() > MAX_PROFILES:
        return {"ok": false, "error": "资料数量超出候选上限"}
    var candidate: Array[Dictionary] = []
    var by_id: Dictionary = {}
    for index in range(entries.size()):
        var checked: Dictionary = Contract.validate(entries[index])
        if not checked["ok"]:
            return {"ok": false, "error": "记录 #%d 不合法：%s" % [index + 1, checked["error"]]}
        var item: Dictionary = checked["data"]
        var identity: String = item["profile_id"]
        if by_id.has(identity):
            return {"ok": false, "error": "资料标识重复"}
        candidate.append(item.duplicate(true))
        by_id[identity] = candidate.size() - 1

    # Atomic commit: malformed input never replaces the previously visible set.
    _profiles = candidate
    _by_id = by_id
    _selected_id = ""
    _query = ""
    _page_index = 0
    return {"ok": true, "error": ""}


func count() -> int:
    return _profiles.size()


func selected_id() -> String:
    return _selected_id


func route() -> String:
    return "detail" if not _selected_id.is_empty() else "list"


func query() -> String:
    return _query


func set_query(input_text: String) -> bool:
    if input_text.length() > MAX_QUERY_CHARS:
        return false
    var next_query := input_text.strip_edges().to_lower()
    if next_query == _query:
        return true
    _query = next_query
    # A changed search always returns to the list, never leaves a hidden
    # stale detail selection or invents a cross-page history stack.
    _selected_id = ""
    _page_index = 0
    return true


func _matches(profile: Dictionary) -> bool:
    if _query.is_empty():
        return true
    var text_parts: Array[String] = [
        str(profile["display_name"]), str(profile["subtitle"]),
        str(profile["status_label"])
    ]
    for tag in profile["tags"]:
        text_parts.append(str(tag))
    return " ".join(text_parts).to_lower().contains(_query)


func visible_summaries() -> Array[Dictionary]:
    var output: Array[Dictionary] = []
    for entry in _profiles:
        if _matches(entry):
            output.append({
                "profile_id": entry["profile_id"],
                "display_name": entry["display_name"],
                "subtitle": entry["subtitle"],
                "status_label": entry["status_label"],
                "summary": entry["summary"],
                "tags": (entry["tags"] as Array).duplicate()
            })
    return output



func filtered_count() -> int:
    var total := 0
    for profile in _profiles:
        if _matches(profile):
            total += 1
    return total


func page_count() -> int:
    return maxi(1, int(ceili(float(filtered_count()) / float(PAGE_SIZE))))


func page_index() -> int:
    return _page_index


func set_page(index: int) -> bool:
    if index < 0 or index >= page_count():
        return false
    if index == _page_index:
        return true
    _page_index = index
    _selected_id = ""
    return true


func page_state() -> Dictionary:
    return {
        "page_index": _page_index,
        "page_number": _page_index + 1,
        "page_count": page_count(),
        "page_size": PAGE_SIZE,
        "filtered": filtered_count(),
        "total": _profiles.size(),
        "has_previous": _page_index > 0,
        "has_next": _page_index + 1 < page_count()
    }


func page_summaries() -> Array[Dictionary]:
    var all_matching: Array[Dictionary] = visible_summaries()
    var start_index: int = _page_index * PAGE_SIZE
    var result: Array[Dictionary] = []
    for i in range(start_index, mini(start_index + PAGE_SIZE, all_matching.size())):
        result.append(all_matching[i].duplicate(true))
    return result


func _page_of(identity: String) -> int:
    var position := 0
    for profile in _profiles:
        if _matches(profile):
            if profile["profile_id"] == identity:
                return int(position / PAGE_SIZE)
            position += 1
    return -1


func open_detail(identity: String) -> bool:
    if not _by_id.has(identity):
        return false
    var candidate: Dictionary = _profiles[_by_id[identity]]
    if not _matches(candidate):
        return false
    var destination := _page_of(identity)
    if destination < 0:
        return false
    _page_index = destination
    _selected_id = identity
    return true


func back_to_list() -> bool:
    if _selected_id.is_empty():
        return false
    _selected_id = ""
    return true


func selected_profile_copy() -> Dictionary:
    if _selected_id.is_empty() or not _by_id.has(_selected_id):
        return {}
    var value: Dictionary = _profiles[_by_id[_selected_id]]
    return value.duplicate(true)


func summaries_copy() -> Array[Dictionary]:
    return visible_summaries()
