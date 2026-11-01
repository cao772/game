extends RefCounted
## GAME-WEB-REGION-023 r1 | PR30-derived safe synthetic recovery. NOT_RUN.
const ValidatorScript = preload("res://region_validator.gd")
const FIXTURE_PATH = "res://synthetic_regions.json"
# Proposal-only read bound; PR28 JSON character cap still applies afterwards.
const MAX_LOCAL_FIXTURE_BYTES = 65536
const VERSION = "public-synthetic-region-017-v1"
const FALLBACK = {
    "schema_version": VERSION,
    "notice": "PUBLIC SYNTHETIC A/B/C FALLBACK ONLY; NOT_RUN",
    "scenarios": [
        {"id": "A", "title": "A | synthetic blocked sight",
         "grid": ["#########", "#S..#..T#", "#...#...#", "#.......#", "#.......#", "#.......#", "#########"],
         "claimed": {"reachable": true, "visible": true}},
        {"id": "B", "title": "B | synthetic detour",
         "grid": ["##########", "#S.......#", "#.######.#", "#.#....#.#", "#.#.##.#.#", "#...##..T#", "##########"],
         "claimed": {"reachable": false, "visible": false}},
        {"id": "C", "title": "C | synthetic isolated target",
         "grid": ["#########", "#S......#", "#.......#", "#####.###", "#..#.#T##", "#....####", "#########"],
         "claimed": {"reachable": true, "visible": false}}
    ]
}

func synthetic_fixture() -> Dictionary:
    return FALLBACK.duplicate(true)

func _external_issue(code: String, detail: String, fix: String) -> Dictionary:
    return {"severity": "WARNING", "code": code, "path": "$.resource",
        "message": detail, "action": fix}

func _recovery_report(source: Dictionary, why: Dictionary) -> Dictionary:
    var validator = ValidatorScript.new()
    var checked: Dictionary = validator.validate_variant(synthetic_fixture())
    if not checked["ok"]:
        return {"mode": "BLOCKED", "catalog": {}, "report": why,
            "fallback_report": checked,
            "message": "内置合成数据未通过自身验证。必须停止使用；不得静默放行。"}
    return {"mode": "FALLBACK_SYNTHETIC",
        "catalog": checked["catalog"],
        "report": why,
        "fallback_report": checked,
        "message": "原始候选不完整或有误，已降级至独立的内置合成 A/B/C；原输入未修改。" }

func examine_variant(raw: Variant) -> Dictionary:
    var validator = ValidatorScript.new()
    var report: Dictionary = validator.validate_variant(raw)
    if report["ok"]:
        return {"mode": "SOURCE_ACCEPTED", "catalog": report["catalog"],
            "report": report, "fallback_report": {},
            "message": "合成结构符合当前候选约束；非可达性、视线或性能验证。"}
    return _recovery_report(raw if raw is Dictionary else {}, report)

func examine_text(raw_text: String) -> Dictionary:
    var validator = ValidatorScript.new()
    var report: Dictionary = validator.validate_json_text(raw_text)
    if report["ok"]:
        return {"mode": "SOURCE_ACCEPTED", "catalog": report["catalog"],
            "report": report, "fallback_report": {},
            "message": "JSON 结构符合当前候选约束；尚未运行任何场景验收。"}
    return _recovery_report({}, report)

func load_optional_fixture() -> Dictionary:
    if not FileAccess.file_exists(FIXTURE_PATH):
        var note: Dictionary = _external_issue("FILE_MISSING",
            "唯一允许的可选合成数据文件不存在。",
            "恢复独立的 synthetic_regions.json，或明确使用内置 A/B/C。")
        return _recovery_report({}, {"ok": false, "status": "UNAVAILABLE",
            "errors": 0, "warnings": 1, "suppressed": 0, "issues": [note]})
    var file: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.READ)
    if file == null:
        var note: Dictionary = _external_issue("FILE_UNREADABLE",
            "可选合成数据文件不可读。",
            "检查本独立项目的资源安装；不要搜索或加载其他游戏文件。")
        return _recovery_report({}, {"ok": false, "status": "UNAVAILABLE",
            "errors": 0, "warnings": 1, "suppressed": 0, "issues": [note]})
    if file.get_length() > MAX_LOCAL_FIXTURE_BYTES:
        var note: Dictionary = _external_issue("FILE_TOO_LARGE",
            "合成资源超过候选 65536 字节读取上限，未读取文件正文。",
            "缩小本目录合成样本；不得加载其他项目文件。")
        return _recovery_report({}, {"ok": false, "status": "UNAVAILABLE",
            "errors": 0, "warnings": 1, "suppressed": 0, "issues": [note]})
    return examine_text(file.get_as_text())
