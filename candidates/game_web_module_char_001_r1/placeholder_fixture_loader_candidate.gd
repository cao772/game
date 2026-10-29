extends RefCounted
## Pure preview fixture parsing. NO filesystem or network. Unapproved and NOT_RUN.
## Atomic acceptance: malformed/partial/duplicate records never escape.

const ProfileContract = preload("res://profile_contract_candidate.gd")
const MAX_FIXTURE_BYTES: int = 65536
const MAX_RECORDS: int = 12

static func _failed(message: String) -> Dictionary:
    return {"ok": false, "error": message, "data": []}


static func parse_text(source: Variant) -> Dictionary:
    if typeof(source) != TYPE_STRING:
        return _failed("占位数据输入必须为文本")
    var raw: String = source
    if raw.to_utf8_buffer().size() > MAX_FIXTURE_BYTES:
        return _failed("占位文件超过尺寸限制")
    if raw.strip_edges().is_empty():
        return _failed("占位文件为空")

    var parser := JSON.new()
    if parser.parse(raw) != OK:
        return _failed("占位 JSON 语法错误")
    if typeof(parser.data) != TYPE_ARRAY:
        return _failed("占位数据根节点必须为数组")
    var source_entries: Array = parser.data
    if source_entries.is_empty():
        return _failed("占位数组没有记录")
    if source_entries.size() > MAX_RECORDS:
        return _failed("占位记录超过数量限制")

    var results: Array[Dictionary] = []
    var seen: Dictionary = {}
    for index in range(source_entries.size()):
        var checked: Dictionary = ProfileContract.validate(source_entries[index])
        if not checked["ok"]:
            return _failed("占位记录 #%d 无效：%s" % [index + 1, checked["error"]])
        var entry: Dictionary = checked["data"]
        var identifier: String = entry["profile_id"]
        if seen.has(identifier):
            return _failed("占位记录的 profile_id 重复")
        seen[identifier] = true
        results.append(entry.duplicate(true))
    return {"ok": true, "error": "", "data": results}
