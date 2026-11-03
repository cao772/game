extends RefCounted
## Immutable, bounded save records for a single writer on one machine.
## Source reviewed only. Godot execution, Windows I/O and crash recovery NOT_RUN.

const ROOT := "user://game_runtime_v1"
const ROOT_NAME := "game_runtime_v1"
const MAX_PAYLOAD_BYTES := 1048576
const MAX_RECORD_BYTES := MAX_PAYLOAD_BYTES * 6 + 1024
const MAX_ENTRIES := 1024
const MAX_DEPTH := 32
const MAX_VALUES := 8192
const MAX_GENERATION := 2147483647
const MAX_SAFE_INTEGER := 9007199254740991

# Shared by instances of this script. Not an OS lock or a threading primitive.
static var _write_in_progress: bool = false


func write_record(slot: String, payload: Dictionary) -> Dictionary:
    if not _valid_slot(slot):
        return _error("INVALID_SLOT")
    if _write_in_progress:
        return _error("WRITE_BUSY")
    _write_in_progress = true
    var result: Dictionary = _write_locked(slot, payload)
    _write_in_progress = false
    return result


func read_latest(slot: String) -> Dictionary:
    if not _valid_slot(slot):
        return _error("INVALID_SLOT")
    if _write_in_progress:
        return _error("WRITE_BUSY")
    var scan: Dictionary = _scan(slot, false)
    if not scan["ok"]:
        return scan
    return _latest_from_scan(scan)


func _valid_slot(slot: String) -> bool:
    return slot == "free" or slot == "chapter"


func _error(code: String, detail: String = "") -> Dictionary:
    return {"ok": false, "code": code, "detail": detail}


func _sha256(bytes: PackedByteArray) -> String:
    var context := HashingContext.new()
    if context.start(HashingContext.HASH_SHA256) != OK:
        return ""
    if context.update(bytes) != OK:
        return ""
    return context.finish().hex_encode()


func _json_issue(value: Variant, depth: int, budget: Dictionary) -> String:
    if depth > MAX_DEPTH:
        return "JSON_DEPTH_LIMIT"
    budget["values"] += 1
    if budget["values"] > MAX_VALUES:
        return "JSON_VALUE_LIMIT"
    match typeof(value):
        TYPE_NIL, TYPE_BOOL:
            return ""
        TYPE_INT:
            if value < -MAX_SAFE_INTEGER or value > MAX_SAFE_INTEGER:
                return "INTEGER_NOT_JSON_EXACT"
        TYPE_FLOAT:
            if not is_finite(value):
                return "NONFINITE_NUMBER"
        TYPE_STRING:
            var string_value: String = value
            if string_value.length() > MAX_PAYLOAD_BYTES:
                return "PAYLOAD_TOO_LARGE"
            var encoded: PackedByteArray = string_value.to_utf8_buffer()
            if encoded.get_string_from_utf8() != string_value:
                return "INVALID_UNICODE"
            budget["bytes"] += encoded.size()
            if budget["bytes"] > MAX_PAYLOAD_BYTES:
                return "PAYLOAD_TOO_LARGE"
        TYPE_ARRAY:
            if value.size() > MAX_VALUES:
                return "JSON_VALUE_LIMIT"
            for item in value:
                var issue: String = _json_issue(item, depth + 1, budget)
                if not issue.is_empty():
                    return issue
        TYPE_DICTIONARY:
            if value.size() > MAX_VALUES:
                return "JSON_VALUE_LIMIT"
            for key in value:
                if typeof(key) != TYPE_STRING:
                    return "NON_STRING_KEY"
                var key_issue: String = _json_issue(key, depth + 1, budget)
                if not key_issue.is_empty():
                    return key_issue
                var issue: String = _json_issue(value[key], depth + 1, budget)
                if not issue.is_empty():
                    return issue
        _:
            return "NON_JSON_VALUE"
    return ""


func _json_equal(left: Variant, right: Variant) -> bool:
    var left_type: int = typeof(left)
    var right_type: int = typeof(right)
    if [TYPE_INT, TYPE_FLOAT].has(left_type) and [TYPE_INT, TYPE_FLOAT].has(right_type):
        # JSON has one numeric type. Safe integers and full-precision floats only.
        return left == right
    if left_type != right_type:
        return false
    if left_type == TYPE_ARRAY:
        if left.size() != right.size():
            return false
        for index in range(left.size()):
            if not _json_equal(left[index], right[index]):
                return false
        return true
    if left_type == TYPE_DICTIONARY:
        if left.size() != right.size():
            return false
        for key in left:
            if not right.has(key) or not _json_equal(left[key], right[key]):
                return false
        return true
    return left == right


func _open_root(create: bool) -> Dictionary:
    var user_dir := DirAccess.open("user://")
    if user_dir == null:
        return _error("USER_DIRECTORY_UNAVAILABLE")
    if user_dir.is_link(ROOT_NAME):
        return _error("SAVE_ROOT_IS_LINK")
    if not user_dir.dir_exists(ROOT_NAME):
        if user_dir.file_exists(ROOT_NAME):
            return _error("SAVE_ROOT_NOT_DIRECTORY")
        if not create:
            return {"ok": true, "code": "ROOT_ABSENT", "directory": null}
        var creation: Error = user_dir.make_dir(ROOT_NAME)
        if creation != OK:
            return _error("SAVE_ROOT_CREATE_FAILED", str(creation))
    if user_dir.is_link(ROOT_NAME):
        return _error("SAVE_ROOT_IS_LINK")
    var directory := DirAccess.open(ROOT)
    if directory == null:
        return _error("SAVE_ROOT_OPEN_FAILED")
    return {"ok": true, "code": "ROOT_READY", "directory": directory}


func _scan(slot: String, create: bool) -> Dictionary:
    var root: Dictionary = _open_root(create)
    if not root["ok"]:
        return root
    var records: Array = []
    var directory: DirAccess = root["directory"]
    if directory == null:
        return {"ok": true, "code": "SCANNED", "records": records, "entry_count": 0}
    directory.include_hidden = true
    directory.include_navigational = false
    var begin_error: Error = directory.list_dir_begin()
    if begin_error != OK:
        return _error("SAVE_SCAN_FAILED", str(begin_error))
    var count: int = 0
    var name: String = directory.get_next()
    while not name.is_empty():
        count += 1
        if count > MAX_ENTRIES:
            directory.list_dir_end()
            return _error("SAVE_DIRECTORY_LIMIT")
        var prefix: String = slot + "-"
        if name.to_lower().begins_with(prefix) and name.to_lower().ends_with(".json"):
            if name != name.to_lower():
                directory.list_dir_end()
                return _error("INVALID_RECORD_NAME", name)
            var digits: String = name.substr(prefix.length(), name.length() - prefix.length() - 5)
            # Canonical positive decimal names avoid aliases and integer overflow.
            if digits.is_empty() or digits.length() > 10 or digits.begins_with("0"):
                directory.list_dir_end()
                return _error("INVALID_RECORD_NAME", name)
            for index in range(digits.length()):
                var code_point: int = digits.unicode_at(index)
                if code_point < 48 or code_point > 57:
                    directory.list_dir_end()
                    return _error("INVALID_RECORD_NAME", name)
            var generation: int = digits.to_int()
            if generation < 1 or generation > MAX_GENERATION:
                directory.list_dir_end()
                return _error("GENERATION_OUT_OF_RANGE", name)
            records.append({"name": name, "generation": generation})
        name = directory.get_next()
    directory.list_dir_end()
    records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["generation"] > b["generation"])
    return {"ok": true, "code": "SCANNED", "records": records, "entry_count": count}


func _read_record(name: String, expected_generation: int) -> Dictionary:
    var root: Dictionary = _open_root(false)
    if not root["ok"]:
        return root
    var directory: DirAccess = root["directory"]
    if directory == null:
        return _error("SAVE_ROOT_DISAPPEARED")
    if directory.is_link(name) or directory.dir_exists(name):
        return _error("RECORD_NOT_REGULAR_FILE", name)
    var path: String = ROOT.path_join(name)
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return _error("RECORD_OPEN_FAILED", name)
    var size: int = file.get_length()
    if size < 1 or size > MAX_RECORD_BYTES:
        file.close()
        return _error("RECORD_SIZE_INVALID", name)
    var bytes: PackedByteArray = file.get_buffer(size)
    var read_error: Error = file.get_error()
    file.close()
    if bytes.size() != size or (read_error != OK and read_error != ERR_FILE_EOF):
        return _error("RECORD_READ_FAILED", name)
    var text: String = bytes.get_string_from_utf8()
    if text.to_utf8_buffer() != bytes:
        return _error("RECORD_UTF8_INVALID", name)
    var parser := JSON.new()
    if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
        return _error("RECORD_JSON_INVALID", name)
    var record: Dictionary = parser.data
    if record.size() != 4 or not record.has_all(["format", "generation", "payload_sha256", "payload_json"]):
        return _error("RECORD_SCHEMA_INVALID", name)
    if not _integer_equals(record["format"], 1) or not _integer_equals(record["generation"], expected_generation):
        return _error("RECORD_IDENTITY_INVALID", name)
    if typeof(record["payload_json"]) != TYPE_STRING or typeof(record["payload_sha256"]) != TYPE_STRING:
        return _error("RECORD_SCHEMA_INVALID", name)
    var payload_json: String = record["payload_json"]
    var payload_bytes: PackedByteArray = payload_json.to_utf8_buffer()
    if payload_bytes.size() > MAX_PAYLOAD_BYTES:
        return _error("PAYLOAD_TOO_LARGE", name)
    var digest: String = _sha256(payload_bytes)
    if digest.is_empty() or digest != record["payload_sha256"]:
        return _error("RECORD_HASH_MISMATCH", name)
    var payload_parser := JSON.new()
    if payload_parser.parse(payload_json) != OK or typeof(payload_parser.data) != TYPE_DICTIONARY:
        return _error("PAYLOAD_JSON_INVALID", name)
    var payload: Dictionary = payload_parser.data
    var issue: String = _json_issue(payload, 0, {"values": 0, "bytes": 0})
    if not issue.is_empty():
        return _error(issue, name)
    return {"ok": true, "code": "RECORD_VALID", "payload": payload, "generation": expected_generation, "path": path}


func _integer_equals(value: Variant, expected: int) -> bool:
    if typeof(value) == TYPE_INT:
        return value == expected
    if typeof(value) == TYPE_FLOAT:
        return is_finite(value) and value == float(expected)
    return false


func _latest_from_scan(scan: Dictionary) -> Dictionary:
    var skipped: Array = []
    var records: Array = scan["records"]
    for record in records:
        var result: Dictionary = _read_record(record["name"], record["generation"])
        if result["ok"]:
            result["code"] = "LOADED" if skipped.is_empty() else "RECOVERED_OLDER_RECORD"
            result["skipped"] = skipped
            return result
        skipped.append({"name": record["name"], "code": result["code"]})
    return {"ok": false, "code": "NO_SAVES" if records.is_empty() else "NO_VALID_RECORD", "skipped": skipped}


func _write_locked(slot: String, payload: Dictionary) -> Dictionary:
    var issue: String = _json_issue(payload, 0, {"values": 0, "bytes": 0})
    if not issue.is_empty():
        return _error(issue)
    var payload_json: String = JSON.stringify(payload, "", true, true)
    var payload_bytes: PackedByteArray = payload_json.to_utf8_buffer()
    if payload_bytes.size() > MAX_PAYLOAD_BYTES:
        return _error("PAYLOAD_TOO_LARGE")
    var parser := JSON.new()
    if parser.parse(payload_json) != OK or not _json_equal(payload, parser.data):
        return _error("PAYLOAD_ROUNDTRIP_FAILED")
    var digest: String = _sha256(payload_bytes)
    if digest.is_empty():
        return _error("HASH_FAILED")
    var scan: Dictionary = _scan(slot, true)
    if not scan["ok"]:
        return scan
    # Reserve room for the temporary entry; promotion renames it in place.
    if scan["entry_count"] >= MAX_ENTRIES:
        return _error("SAVE_DIRECTORY_LIMIT")
    var records: Array = scan["records"]
    var generation: int = 1
    var skipped: Array = []
    if not records.is_empty():
        var latest: Dictionary = _latest_from_scan(scan)
        if not latest["ok"]:
            return latest
        skipped = latest["skipped"]
        if records[0]["generation"] >= MAX_GENERATION:
            return _error("GENERATION_EXHAUSTED")
        generation = records[0]["generation"] + 1
    var envelope: Dictionary = {
        "format": 1, "generation": generation,
        "payload_sha256": digest, "payload_json": payload_json
    }
    var serialized: String = JSON.stringify(envelope, "", true, true)
    if serialized.to_utf8_buffer().size() > MAX_RECORD_BYTES:
        return _error("RECORD_SIZE_INVALID")
    var root: Dictionary = _open_root(false)
    if not root["ok"]:
        return root
    var directory: DirAccess = root["directory"]
    if directory == null:
        return _error("SAVE_ROOT_DISAPPEARED")
    var final_name: String = "%s-%d.json" % [slot, generation]
    if _name_exists(directory, final_name):
        return _error("RECORD_ALREADY_EXISTS", final_name)
    var random_bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
    if random_bytes.size() != 16:
        return _error("TEMP_NAME_FAILED")
    var temp_name: String = ".pending-%s-%s.tmp" % [slot, random_bytes.hex_encode()]
    if _name_exists(directory, temp_name):
        return _error("TEMP_ALREADY_EXISTS")
    var temp_path: String = ROOT.path_join(temp_name)
    var file := FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        return _error("TEMP_OPEN_FAILED", temp_name)
    file.store_string(serialized)
    file.flush()
    var write_error: Error = file.get_error()
    file.close()
    if write_error != OK:
        return _error("TEMP_WRITE_FAILED", temp_name)
    var readback: Dictionary = _read_record(temp_name, generation)
    if not readback["ok"] or not _json_equal(payload, readback.get("payload")):
        return _error("TEMP_READBACK_FAILED", temp_name)
    # Recheck immediately before rename. Single-writer requirement is essential:
    # Godot rename can replace an existing destination; no cross-process CAS.
    root = _open_root(false)
    if not root["ok"]:
        return root
    directory = root["directory"]
    if directory == null or _name_exists(directory, final_name) or directory.is_link(temp_name):
        return _error("PROMOTION_CONFLICT", temp_name)
    var promote_error: Error = directory.rename(temp_name, final_name)
    if promote_error != OK:
        return _error("PROMOTION_FAILED", temp_name)
    var committed: Dictionary = _read_record(final_name, generation)
    if not committed["ok"] or not _json_equal(payload, committed.get("payload")):
        return _error("COMMIT_READBACK_FAILED", final_name)
    return {"ok": true, "code": "SAVED", "generation": generation, "path": committed["path"], "skipped": skipped}


func _name_exists(directory: DirAccess, name: String) -> bool:
    return directory.file_exists(name) or directory.dir_exists(name) or directory.is_link(name)
