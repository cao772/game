extends RefCounted
## REGION-023 | PR30-derived isolated gateway review candidate. NOT_RUN.
## The PR28 recovery component is the ONLY code permitted to load/fallback.
## This gateway neither reparses JSON nor runs a second fallback.
const RecoveryScript = preload("res://catalog_recovery.gd")
const InteractionScript = preload("res://synthetic_interaction.gd")
const ALLOWED_IDS = ["A", "B", "C"]

var _recovery
var _interaction
var _catalog: Dictionary = {}
var _result: Dictionary = {}
var _mode: String = "BLOCKED"
var _active: String = ""
var _info: String = "尚未读取合成样本。"

func _init() -> void:
    _recovery = RecoveryScript.new()
    _interaction = InteractionScript.new()

func load_local_synthetic() -> void:
    # Fixed res://synthetic_regions.json only; no arbitrary input path.
    _activate_result(_recovery.load_optional_fixture())

func load_example(raw: Variant) -> void:
    # Only future local synthetic boundary cases should call this method.
    _activate_result(_recovery.examine_variant(raw))

func load_example_text(raw_text: String) -> void:
    _activate_result(_recovery.examine_text(raw_text))

func _activate_result(response: Dictionary) -> void:
    _interaction.reset()
    _active = ""
    _catalog.clear()
    _result = response.duplicate(true)
    _mode = str(response.get("mode", "BLOCKED"))
    _info = str(response.get("message", "未获得有效的合成验证结果。"))
    if not ["SOURCE_ACCEPTED", "FALLBACK_SYNTHETIC"].has(_mode):
        _mode = "BLOCKED"
        _info = "校验或回退阻断：" + _info
        return
    # Fail closed if the upstream result's three-state diagnostic contract
    # contradicts its mode. These checks DO NOT replace structural validation.
    var source_report: Variant = response.get("report")
    var fallback_report: Variant = response.get("fallback_report")
    if not (source_report is Dictionary) or not (fallback_report is Dictionary):
        _block("上游诊断报告缺失或类型错误；停止。")
        return
    if _mode == "SOURCE_ACCEPTED" and not source_report.get("ok", false):
        _block("原数据未被校验器接受，不能进入交互。")
        return
    if _mode == "FALLBACK_SYNTHETIC":
        if not fallback_report.get("ok", false):
            _block("后备目录未通过自身结构检查；停止。")
            return
        if source_report.get("ok", false):
            _block("原数据已接受却标成回退；来源状态矛盾。")
            return
    # The result of PR28 recovery is the sole authority. Do not call the
    # old boolean loader, and do not replace rejection diagnostics.
    var raw: Variant = response.get("catalog")
    if not (raw is Dictionary):
        _block("恢复结果无目录对象；停止。")
        return
    var scenes: Variant = raw.get("scenarios")
    if not (scenes is Array) or scenes.size() != 3:
        _block("恢复目录不完整；停止。")
        return
    var clean: Array = []
    var seen: Dictionary = {}
    for original in scenes:
        if not (original is Dictionary):
            _block("恢复目录中出现非场景记录；停止。")
            return
        var id: Variant = original.get("id")
        if not (id is String) or not ALLOWED_IDS.has(id) or seen.has(id):
            _block("恢复目录 ID 不唯一；停止。")
            return
        seen[id] = true
        # Contract guards: fail closed on malformed upstream fields instead
        # of indexing a Variant; do not start another validation/fallback.
        var grid: Variant = original.get("grid")
        var claims: Variant = original.get("claimed")
        if not (grid is Array) or not (claims is Dictionary):
            _block("上游场景字段缺失或类型错误；停止。")
            return
        if not (claims.get("reachable") is bool) or not (claims.get("visible") is bool):
            _block("上游记录布尔字段类型错误；停止。")
            return
        clean.append({
            "id": id, "grid": grid.duplicate(true),
            "claimed": {
                "reachable": claims["reachable"],
                "visible": claims["visible"]
            }
        })
    if seen.size() != ALLOWED_IDS.size():
        _block("缺少 A/B/C 中的合成场景；停止。")
        return
    _catalog = {"scenarios": clean}
    if not select("A"):
        _block("无法初始化合成 A 场景，停止。")

func _block(reason: String) -> void:
    _mode = "BLOCKED"
    _catalog.clear()
    _active = ""
    _interaction.reset()
    _info = reason

func select(id: String) -> bool:
    if _mode == "BLOCKED" or not ALLOWED_IDS.has(id):
        return false
    for record in _catalog.get("scenarios", []):
        if record.get("id", "") == id:
            if _interaction.configure(record):
                _active = id
                return true
            _block("模型初始化失败；停止全部场景操作。")
            return false
    return false

func move(step: Vector2i) -> void:
    if _mode != "BLOCKED":
        _interaction.move(step)

func preview_target() -> void:
    if _mode != "BLOCKED":
        _interaction.preview_target()

func preview_return() -> void:
    if _mode != "BLOCKED":
        _interaction.preview_return()

func inspect() -> void:
    if _mode != "BLOCKED":
        _interaction.inspect()

func correct() -> void:
    if _mode != "BLOCKED":
        _interaction.correct()

func undo() -> void:
    if _mode != "BLOCKED":
        _interaction.undo()

func snapshot() -> Dictionary:
    # Never flatten structural validation, claimed state or observations.
    return {
        "mode": _mode, "source_message": _info,
        "source_report": _result.get("report", {}).duplicate(true),
        "fallback_report": _result.get("fallback_report", {}).duplicate(true),
        "active": _active, "synthetic": _interaction.snapshot(),
        "verification": "NOT_RUN"
    }
