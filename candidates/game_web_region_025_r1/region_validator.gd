extends RefCounted
## GAME-WEB-REGION-020 r1, source-only structural diagnostics. NOT_RUN.
## This validator accepts only synthetic A/B/C dictionaries; no file or game writes.
const VERSION = "public-synthetic-region-017-v1"
const IDS = ["A", "B", "C"]
const SYMBOLS = ["#", ".", "S", "T"]
const MAX_INPUT_CHARS = 16000 # Candidate guard, not a measured limit.
const MAX_ISSUES = 48 # Candidate guard, not a measured limit.

var _suppressed: int = 0

func _issue(out: Array, kind: String, code: String, path: String, detail: String, fix: String) -> void:
    if out.size() >= MAX_ISSUES:
        _suppressed += 1
        return
    out.append({"severity": kind, "code": code, "path": path,
        "message": detail, "action": fix})

func _result(out: Array, source: Variant = null) -> Dictionary:
    var errors: int = 0
    var warnings: int = 0
    for item in out:
        if item["severity"] == "ERROR":
            errors += 1
        elif item["severity"] == "WARNING":
            warnings += 1
    var ok: bool = errors == 0 and _suppressed == 0 and source is Dictionary
    return {"ok": ok, "status": "ACCEPTED" if ok else "REJECTED",
        "errors": errors, "warnings": warnings,
        "suppressed": _suppressed, "issues": out.duplicate(true),
        "catalog": (source as Dictionary).duplicate(true) if ok else {},
        "verification": "NOT_RUN"}

func validate_json_text(text: String) -> Dictionary:
    _suppressed = 0
    var issues: Array = []
    if text.strip_edges().is_empty():
        _issue(issues, "ERROR", "EMPTY_JSON", "$", "输入为空。", "提供 A/B/C 合成 JSON 对象。")
        return _result(issues)
    if text.length() > MAX_INPUT_CHARS:
        _issue(issues, "ERROR", "INPUT_TOO_LARGE", "$", "超过候选字符上限。",
            "缩减至小型纯合成 A/B/C 数据；禁止导入真实地图。")
        return _result(issues)
    var parser := JSON.new()
    if parser.parse(text) != OK:
        _issue(issues, "ERROR", "JSON_SYNTAX", "$",
            "JSON 第 %d 行语法错误：%s" % [parser.get_error_line(), parser.get_error_message()],
            "修正引号、逗号、括号或转义，再重新检查。")
        return _result(issues)
    return validate_variant(parser.get_data())

func validate_variant(raw: Variant) -> Dictionary:
    _suppressed = 0
    var issues: Array = []
    if not (raw is Dictionary):
        _issue(issues, "ERROR", "ROOT_OBJECT", "$",
            "顶层不是对象。", "改为含 schema_version 和 scenarios 的 JSON 对象。")
        return _result(issues)
    var doc: Dictionary = raw
    if doc.get("schema_version") != VERSION:
        _issue(issues, "ERROR", "VERSION", "$.schema_version",
            "版本与 PR #26 的合成格式不符。",
            "使用 public-synthetic-region-017-v1，不要擅自改共享接口。")
    for key in doc.keys():
        if not ["schema_version", "scenarios", "notice"].has(key):
            _issue(issues, "WARNING", "UNKNOWN_ROOT_FIELD", "$." + str(key),
                "发现未定义顶层字段。", "检查拼写；未定义字段不会被用于地图判定。")
    if doc.has("notice") and not (doc["notice"] is String):
        _issue(issues, "WARNING", "NOTICE_FORMAT", "$.notice",
            "可选 notice 不是字符串。", "改为文字或移除该可选字段。")
    var value: Variant = doc.get("scenarios")
    if not (value is Array):
        _issue(issues, "ERROR", "SCENE_ARRAY", "$.scenarios",
            "缺少场景数组。", "提供恰好三项 A、B、C。")
        return _result(issues)
    var scenes: Array = value
    if scenes.size() != 3:
        _issue(issues, "ERROR", "SCENE_COUNT", "$.scenarios",
            "当前 %d 项；要求恰好三项。" % scenes.size(),
            "确保 A、B、C 各一项，不添加其他地区或真实地图。")
    var seen: Dictionary = {}
    for i in range(mini(scenes.size(), 3)):
        var at: String = "$.scenarios[%d]" % i
        if not (scenes[i] is Dictionary):
            _issue(issues, "ERROR", "SCENE_OBJECT", at,
                "场景条目不是对象。", "填写 id、title、grid、claimed 四个字段。")
            continue
        var s: Dictionary = scenes[i]
        for key in s.keys():
            if not ["id", "title", "grid", "claimed"].has(key):
                _issue(issues, "WARNING", "UNKNOWN_SCENE_FIELD", at + "." + str(key),
                    "未知场景字段。", "检查拼写；不用于地图判定。")
        var ident: Variant = s.get("id")
        if not (ident is String) or not IDS.has(ident):
            _issue(issues, "ERROR", "SCENE_ID", at + ".id",
                "id 不属于 A/B/C。", "使用唯一的 A、B、C。")
        elif seen.has(ident):
            _issue(issues, "ERROR", "DUPLICATE_ID", at + ".id",
                "标识 %s 重复。" % ident, "移除重复条目，保留各一个。")
        else:
            seen[ident] = true
        var title: Variant = s.get("title")
        if not (title is String) or title.length() < 1 or title.length() > 40:
            _issue(issues, "ERROR", "TITLE", at + ".title",
                "标题要求 1–40 字符。", "使用简短的纯合成标题。")
        _check_claim(s.get("claimed"), at + ".claimed", issues)
        _check_grid(s.get("grid"), at + ".grid", issues)
    for ident in IDS:
        if not seen.has(ident):
            _issue(issues, "ERROR", "MISSING_ID", "$.scenarios",
                "缺少场景 %s。" % ident, "补齐该合成场景，不能复用其他 id。")
    return _result(issues, doc)

func _check_claim(value: Variant, path: String, out: Array) -> void:
    if not (value is Dictionary):
        _issue(out, "ERROR", "CLAIM_OBJECT", path,
            "claimed 缺失或不是对象。", "提供 reachable 和 visible 布尔值。")
        return
    var c: Dictionary = value
    for key in c.keys():
        if not ["reachable", "visible"].has(key):
            _issue(out, "WARNING", "UNKNOWN_CLAIM_FIELD", path + "." + str(key),
                "未知记录字段。", "该字段不会参与结构判定。")
    for key in ["reachable", "visible"]:
        if not (c.get(key) is bool):
            _issue(out, "ERROR", "CLAIM_BOOL", path + "." + key,
                "必须使用布尔值 true/false。", "不要使用数字、字符串或 null。")

func _check_grid(value: Variant, path: String, out: Array) -> void:
    if not (value is Array):
        _issue(out, "ERROR", "GRID_ARRAY", path,
            "grid 缺失或不是字符串行数组。", "提供 5–12 行等宽字符网格。")
        return
    var rows: Array = value
    if rows.size() < 5 or rows.size() > 12:
        _issue(out, "ERROR", "GRID_HEIGHT", path,
            "行数 %d 超出 5–12。" % rows.size(), "调整行数，保持 # 外边界。")
    var width: int = -1
    var starts: int = 0
    var targets: int = 0
    for y in range(mini(rows.size(), 12)):
        var at: String = path + "[%d]" % y
        if not (rows[y] is String):
            _issue(out, "ERROR", "ROW_STRING", at,
                "此行不是字符串。", "每行使用 # . S T 组成的文本。")
            continue
        var row: String = rows[y]
        if width == -1:
            width = row.length()
        if row.length() < 5 or row.length() > 16:
            _issue(out, "ERROR", "GRID_WIDTH", at,
                "本行宽 %d，不在 5–16。" % row.length(), "调整到合法宽度。")
        if row.length() != width:
            _issue(out, "ERROR", "RAGGED_ROW", at,
                "宽 %d，与参考宽 %d 不一致。" % [row.length(), width],
                "使所有网格行等宽；不允许自动截断补齐。")
        for x in range(mini(row.length(), 16)):
            var ch: String = row.substr(x, 1)
            var cell_path: String = at + "[%d]" % x
            if not SYMBOLS.has(ch):
                _issue(out, "ERROR", "GRID_GLYPH", cell_path,
                    "非法字符。", "只允许 # 墙、. 路、S 起点、T 目标。")
                continue
            if (y == 0 or y == rows.size() - 1 or x == 0 or x == row.length() - 1) and ch != "#":
                _issue(out, "ERROR", "PERIMETER", cell_path,
                    "外围不是 # 墙。", "封闭外围；S/T 应位于内部。")
            if ch == "S":
                starts += 1
            elif ch == "T":
                targets += 1
    if starts != 1:
        _issue(out, "ERROR", "START_COUNT", path,
            "检查到 %d 个 S，必须恰好一个。" % starts,
            "添加缺失 S 或移除重复 S。")
    if targets != 1:
        _issue(out, "ERROR", "TARGET_COUNT", path,
            "检查到 %d 个 T，必须恰好一个。" % targets,
            "添加缺失 T 或移除重复 T。")
