extends Control
## GAME-WEB-REGION-020 r1 | stand-alone synthetic diagnostics UI | NOT_RUN.
## Buttons trigger only local read-only validation in a future authorized run.
const RecoveryScript = preload("res://catalog_recovery.gd")
const CasesScript = preload("res://synthetic_boundary_cases.gd")
var _recovery
var _cases
var _choice: OptionButton
var _summary: Label
var _details: TextEdit

func _ready() -> void:
    _recovery = RecoveryScript.new()
    _cases = CasesScript.new()
    _build_ui()
    _summary.text = "请选择公开合成案例再检查。所有案例均 NOT_RUN。"

func _button(parent: Node, title: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = title
    button.focus_mode = Control.FOCUS_ALL
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

func _build_ui() -> void:
    var root := VBoxContainer.new()
    add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.offset_left = 18.0
    root.offset_top = 16.0
    root.offset_right = -18.0
    root.offset_bottom = -16.0
    var heading := Label.new()
    heading.text = "GAME-WEB-REGION-020 | A/B/C 合成地图结构诊断 | NOT_RUN"
    root.add_child(heading)
    var note := Label.new()
    note.text = "仅阅读本目录固定 synthetic_regions.json 与内存示例；结构被接受≠可达/视线/运行验收。"
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(note)
    var toolbar := HBoxContainer.new()
    root.add_child(toolbar)
    _choice = OptionButton.new()
    _choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for name in CasesScript.CASES:
        _choice.add_item(name)
    toolbar.add_child(_choice)
    _button(toolbar, "检查选中合成边界案例", Callable(self, "_check_case"))
    _button(root, "读取并检查本目录可选合成 JSON", Callable(self, "_check_file"))
    _summary = Label.new()
    _summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(_summary)
    _details = TextEdit.new()
    _details.editable = false
    _details.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    _details.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _details.text = "诊断输出将显示：级别、代码、字段路径、问题及修复步骤。"
    root.add_child(_details)

func _check_case() -> void:
    var id: String = CasesScript.CASES[_choice.selected]
    var sample: Dictionary = _cases.catalog_case(id)
    if sample.get("kind") == "text":
        _show(_recovery.examine_text(sample["value"]), id)
    elif sample.get("kind") == "variant":
        _show(_recovery.examine_variant(sample["value"]), id)
    else:
        _summary.text = "未知合成案例；未进行数据校验。"
        _details.text = "候选说明：请重新选择列出的 A/B/C 示例。"

func _check_file() -> void:
    _show(_recovery.load_optional_fixture(), "PR26_PINNED_SYNTHETIC_FILE")

func _show(response: Dictionary, label: String) -> void:
    var report: Dictionary = response.get("report", {})
    var mode: String = str(response.get("mode", "BLOCKED"))
    var catalog: Dictionary = response.get("catalog", {})
    var scenarios: Array = catalog.get("scenarios", [])
    _summary.text = "案例 %s | 处理模式 %s | 原数据错误 %s，警告 %s | 可用合成场景数 %d" % [
        label, mode, str(report.get("errors", "?")),
        str(report.get("warnings", "?")), scenarios.size()]
    var lines := PackedStringArray()
    lines.append(str(response.get("message", "无处理结果。")))
    lines.append("输入结构判定：" + str(report.get("status", "UNAVAILABLE")))
    lines.append("错误代码为候选设计；不是自动化测试通过证据。")
    var issues: Array = report.get("issues", [])
    if issues.is_empty():
        lines.append("没有结构诊断记录；不代表游戏逻辑通过。")
    for issue in issues:
        lines.append("[%s] %s @ %s" % [
            str(issue.get("severity", "?")), str(issue.get("code", "?")),
            str(issue.get("path", "?"))])
        lines.append("原因：" + str(issue.get("message", "")))
        lines.append("处理：" + str(issue.get("action", "")))
    if int(report.get("suppressed", 0)) > 0:
        lines.append("诊断条数超过上限，有项目被省略；整份输入不可接受。")
    if mode == "FALLBACK_SYNTHETIC":
        lines.append("注意：显示的合成地图来自内置回退，不是修好后的原文件。")
    lines.append("NOT_RUN：未执行 Godot、脚本解析、交互或任何测试。")
    _details.text = "\n".join(lines)
