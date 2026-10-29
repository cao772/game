extends RefCounted
## Candidate-only fixture loading. Fixed res://play_005/vendor/char/ source; no arbitrary file paths.
## Exact byte limit, UTF-8 round-trip, atomic validation and typed failures.

const ProfileContract = preload("res://play_005/vendor/char/profile_contract_candidate.gd")
const FIXTURE_PATH := "res://play_005/vendor/char/placeholder_profiles.json"
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

    var entries: Array = parser.data
    if entries.is_empty():
        return _failed("占位数组没有记录")
    if entries.size() > MAX_RECORDS:
        return _failed("占位记录超过数量限制")

    var accepted: Array[Dictionary] = []
    var seen: Dictionary = {}
    for index in range(entries.size()):
        var checked: Dictionary = ProfileContract.validate(entries[index])
        if not checked["ok"]:
            return _failed("占位记录 #%d 无效：%s" % [index + 1, checked["error"]])
        var entry: Dictionary = checked["data"]
        var identifier: String = entry["profile_id"]
        if seen.has(identifier):
            return _failed("占位记录的 profile_id 重复")
        seen[identifier] = true
        accepted.append(entry.duplicate(true))
    return {"ok": true, "error": "", "data": accepted}


static func parse_bytes(bytes: PackedByteArray) -> Dictionary:
    if bytes.is_empty():
        return _failed("占位文件为空")
    if bytes.size() > MAX_FIXTURE_BYTES:
        return _failed("占位文件超过尺寸限制")
    var decoded := bytes.get_string_from_utf8()
    if decoded.to_utf8_buffer() != bytes:
        return _failed("占位文件不是有效 UTF-8")
    if decoded.begins_with("\uFEFF"):
        return _failed("占位文件包含不支持的 UTF-8 BOM")
    return parse_text(decoded)


static func read_known_fixture() -> Dictionary:
    # A resource preflight avoids a simple missing-file open, but an invalid
    # imported resource or OS error can still produce an engine diagnostic.
    if not FileAccess.file_exists(FIXTURE_PATH):
        return _failed("占位资源文件不存在")
    var file := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
    if file == null:
        return _failed("占位资源无法读取")

    var length := file.get_length()
    if length == 0:
        file.close()
        return _failed("占位资源为空")
    if length > MAX_FIXTURE_BYTES:
        file.close()
        return _failed("占位文件超过尺寸限制")

    var bytes: PackedByteArray = file.get_buffer(length)
    var io_error: Error = file.get_error()
    file.close()

    if bytes.size() != length:
        return _failed("占位资源读取不完整")
    if io_error != OK and io_error != ERR_FILE_EOF:
        return _failed("占位资源读取失败")
    return parse_bytes(bytes)
