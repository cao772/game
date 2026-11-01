extends Control
## REGION-023 | isolated PR30 review/repair candidate, A/B/C only.
## Source-only at authoring time, NOT_RUN. No global InputMap, save or events.
const GatewayScript = preload("res://validated_gateway.gd")
const CasesScript = preload("res://synthetic_cases.gd")

var _gateway
var _cases
var _choose: OptionButton
var _mode: Label
var _status: Label
var _facts: Label
var _map: TextEdit
var _issues: TextEdit

func _ready() -> void:
    _gateway = GatewayScript.new()
    _cases = CasesScript.new()
    _layout()
    # The ONLY file-loading entry; all recovery belongs to copied PR28 source.
    _gateway.load_local_synthetic()
    _render()

func _label(parent: Node, value: String) -> Label:
    var item := Label.new()
    item.text = value
    item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    parent.add_child(item)
    return item

func _button(parent: Node, caption: String, callback: Callable) -> Button:
    var item := Button.new()
    item.text = caption
    item.focus_mode = Control.FOCUS_ALL
    item.pressed.connect(callback)
    parent.add_child(item)
    return item

func _text(parent: Node, label_text: String) -> TextEdit:
    _label(parent, label_text)
    var item := TextEdit.new()
    item.editable = false
    item.focus_mode = Control.FOCUS_ALL
    item.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    item.custom_minimum_size = Vector2(0, 170)
    item.size_flags_vertical = Control.SIZE_EXPAND_FILL
    parent.add_child(item)
    return item

func _layout() -> void:
    var root := VBoxContainer.new()
    add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.offset_left = 16.0
    root.offset_top = 12.0
    root.offset_right = -16.0
    root.offset_bottom = -12.0
    _label(root, "GAME-WEB-REGION-023 | 静态审查修订候选 | NOT_RUN")
    _label(root, "Tab/Shift+Tab 导航，Enter/Space 激活按钮。全部是 A/B/C 内存数据，无实际游戏世界、存档或外部输入。")

    var source_row := HBoxContainer.new()
    root.add_child(source_row)
    _button(source_row, "重载固定合成 JSON", Callable(self, "_load_source"))
    _button(source_row, "合成样本：坏版本", func(): _load_example("BAD_VERSION"))
    _button(source_row, "合成样本：重复 ID", func(): _load_example("DUPLICATE_ID"))
    _button(source_row, "合成样本：缺少 T", func(): _load_example("MISSING_T"))
    _button(source_row, "合成样本：断路 C", func(): _load_example("VALID_DISCONNECTED_C"))

    var toolbar := HBoxContainer.new()
    root.add_child(toolbar)
    _label(toolbar, "选择字母场景：")
    _choose = OptionButton.new()
    for id in ["A", "B", "C"]:
        _choose.add_item(id)
    _choose.item_selected.connect(_select)
    toolbar.add_child(_choose)

    _button(toolbar, "向上", func(): _move(Vector2i(0, -1)))
    _button(toolbar, "向下", func(): _move(Vector2i(0, 1)))
    _button(toolbar, "向左", func(): _move(Vector2i(-1, 0)))
    _button(toolbar, "向右", func(): _move(Vector2i(1, 0)))

    var actions := HBoxContainer.new()
    root.add_child(actions)
    _button(actions, "预览到 T", Callable(self, "_target"))
    _button(actions, "预览返回 S", Callable(self, "_return"))
    _button(actions, "1. 核对", Callable(self, "_inspect"))
    _button(actions, "2. 更正内存记录", Callable(self, "_correct"))
    _button(actions, "撤销", Callable(self, "_undo"))

    _mode = _label(root, "")
    _status = _label(root, "")
    _facts = _label(root, "")
    var columns := HBoxContainer.new()
    columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(columns)

    var left := VBoxContainer.new()
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(left)
    _map = _text(left, "合成网格：# 墙、. 空格、: 路线、S 起点、T 目标、P 当前位置")

    var right := VBoxContainer.new()
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(right)
    _issues = _text(right, "输入诊断/来源说明（不能当作实际运行验收）")

func _load_source() -> void:
    _gateway.load_local_synthetic()
    _choose.select(0)
    _render()

func _load_example(kind: String) -> void:
    var sample: Dictionary = _cases.example(kind)
    if sample.get("kind") == "VARIANT":
        _gateway.load_example(sample["value"])
    _choose.select(0)
    _render()

func _select(index: int) -> void:
    if index < 0 or index > 2:
        return
    _gateway.select(["A", "B", "C"][index])
    _render()

func _move(step: Vector2i) -> void:
    _gateway.move(step)
    _render()

func _target() -> void:
    _gateway.preview_target()
    _render()

func _return() -> void:
    _gateway.preview_return()
    _render()

func _inspect() -> void:
    _gateway.inspect()
    _render()

func _correct() -> void:
    _gateway.correct()
    _render()

func _undo() -> void:
    _gateway.undo()
    _render()

func _text_grid(data: Dictionary) -> String:
    if not bool(data.get("ready", false)):
        return "BLOCKED: 没有可交互的合成网格。"
    var rows: Array = data.get("grid", [])
    var player: Vector2i = data.get("player", Vector2i.ZERO)
    var target: Vector2i = data.get("target", Vector2i.ZERO)
    var start: Vector2i = data.get("start", Vector2i.ZERO)
    var route: Array = data.get("preview", [])
    var lines := PackedStringArray()
    for y in range(rows.size()):
        var line := ""
        for x in range(str(rows[y]).length()):
            var p := Vector2i(x, y)
            var ch: String = str(rows[y]).substr(x, 1)
            if route.has(p) and ch != "#":
                ch = ":"
            if p == start:
                ch = "S"
            if p == target:
                ch = "T"
            if p == player:
                ch = "P"
            line += ch
        lines.append("行%02d | %s" % [y, line])
    return "\n".join(lines)

func _set_readonly_text(control: TextEdit, value: String) -> void:
    # Do not reset the diagnostics reader on unrelated model refresh.
    if control.text == value:
        return
    var previous_line: int = control.scroll_vertical
    control.text = value
    control.scroll_vertical = previous_line

func _format_issues(result: Dictionary) -> String:
    var source_report: Dictionary = result.get("source_report", {})
    var fallback_report: Dictionary = result.get("fallback_report", {})
    var lines := PackedStringArray()
    lines.append("输入状态：" + str(source_report.get("status", "UNAVAILABLE")))
    lines.append("原始错误数：" + str(source_report.get("errors", "?")) +
        "；警告数：" + str(source_report.get("warnings", "?")))
    for issue in source_report.get("issues", []):
        lines.append("[%s] %s @ %s" % [
            str(issue.get("severity", "?")), str(issue.get("code", "?")),
            str(issue.get("path", "?"))])
        lines.append("原因：" + str(issue.get("message", "?")))
        lines.append("处理：" + str(issue.get("action", "?")))
    if int(source_report.get("suppressed", 0)) > 0:
        lines.append("诊断被截断，不能批准原数据。")
    if result["mode"] == "FALLBACK_SYNTHETIC":
        lines.append("回退来源：内置纯合成 A/B/C（不是修复后的原文件）。")
        lines.append("内置回退检查：" + str(fallback_report.get("status", "UNKNOWN")))
    if result["mode"] == "BLOCKED":
        lines.append("BLOCKED：没有加载可交互的场景。")
        lines.append("内置回退检查：" + str(fallback_report.get("status", "未提供")))
        for issue in fallback_report.get("issues", []):
            lines.append("后备[%s] %s @ %s" % [
                str(issue.get("severity", "?")), str(issue.get("code", "?")),
                str(issue.get("path", "?"))])
            lines.append("后备原因：" + str(issue.get("message", "?")))
            lines.append("后备处理：" + str(issue.get("action", "?")))
    lines.append("工程验证状态：NOT_RUN。")
    return "\n".join(lines)

func _render() -> void:
    var data: Dictionary = _gateway.snapshot()
    var active: Dictionary = data["synthetic"]
    _mode.text = "数据模式：" + str(data["mode"]) + "（结构状态不是可达性或 QA 通过）。"
    _status.text = str(data["source_message"]) + "\n本地反馈：" + str(active.get("feedback", "无"))
    var facts := "记录主张：尚未进入场景。"
    if bool(active.get("ready", false)):
        var claim: Dictionary = active["claim"]
        facts = "场景 " + str(active["id"]) + "，P=" + str(active["player"]) + "\n" +             "记录主张（可能错误）：可达=" + str(claim.get("reachable")) +             "、可见=" + str(claim.get("visible"))
        if bool(active.get("inspected", false)):
            var observed: Dictionary = active.get("actual", {})
            facts += "\n显式模拟核对：可达=" + str(observed.get("reachable")) +                 "、采样可见=" + str(observed.get("visible"))
        else:
            facts += "\n显式模拟核对：未执行；不暴露未确认的推算数值。"
        facts += "\n本地撤销层数：" + str(active.get("undo_depth", 0))
    _facts.text = facts
    _set_readonly_text(_map, _text_grid(active))
    _set_readonly_text(_issues, _format_issues(data))
