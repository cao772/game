extends RefCounted
## GAME-WEB-REGION-024: text-first status projection. Does not mutate data.
## NOT_RUN. No color, animation, audio or external content.

func _yes(value: bool) -> String:
    return "是" if value else "否"

func provenance(report: Dictionary) -> String:
    var mode: String = str(report.get("mode", "BLOCKED"))
    match mode:
        "SOURCE_ACCEPTED":
            return "SOURCE_ACCEPTED｜原合成 JSON 结构被接受；不代表实机或路径验证通过。"
        "FALLBACK_SYNTHETIC":
            return "FALLBACK_SYNTHETIC｜原始输入有问题；当前使用内置合成 A/B/C，原文件未修复。"
        _:
            return "BLOCKED｜校验或回退不可用，当前没有可操作的合成场景。"

func facts(report: Dictionary) -> String:
    var active: Dictionary = report.get("synthetic", {})
    if not bool(active.get("ready", false)):
        return "当前活动场景：无。位置、记录更正和模拟核对均不可用。"
    var claim: Dictionary = active.get("claim", {})
    var lines := PackedStringArray()
    lines.append("场景：" + str(active.get("id", "?")) + "；当前位置 P=" + str(active.get("player", "?")))
    lines.append("起点 S=" + str(active.get("start", "?")) + "；目标 T=" + str(active.get("target", "?")))
    lines.append("记录主张（可能不正确）：可达=" + _yes(bool(claim.get("reachable", false))) +
        "；直视可见=" + _yes(bool(claim.get("visible", false))))
    if bool(active.get("inspected", false)):
        var actual: Dictionary = active.get("actual", {})
        lines.append("本次已触发合成模拟核对：四向网格可达=" +
            _yes(bool(actual.get("reachable", false))) +
            "；采样视线可见=" + _yes(bool(actual.get("visible", false))))
        if claim.get("reachable") != actual.get("reachable") or claim.get("visible") != actual.get("visible"):
            lines.append("冲突：记录与合成观察不同。可选择【2. 明确更正】，或直接撤销前次操作。")
        else:
            lines.append("当前记录与模拟观察一致；不证明真实路径安全。")
    else:
        lines.append("模拟观察：未核对。内部推算不得视作玩家已经确认的事实。")
    lines.append("撤销历史：" + str(active.get("undo_depth", 0)) + " 步（仅内存）。")
    lines.append("反馈：" + str(active.get("feedback", "无")))
    return "\n".join(lines)

func next_action(report: Dictionary) -> String:
    if str(report.get("mode", "BLOCKED")) == "BLOCKED":
        return "恢复建议：检查独立 Godot 项目资源及原始诊断；禁止移动或更正。"
    var active: Dictionary = report.get("synthetic", {})
    if not bool(active.get("ready", false)):
        return "恢复建议：重新载入本目录的合成数据或选择有效 A/B/C 样本。"
    if not bool(active.get("inspected", false)):
        return "下一步：可先预览到 T / 返回 S，再按【1. 核对】；误走可以【撤销】。"
    var c: Dictionary = active.get("claim", {})
    var a: Dictionary = active.get("actual", {})
    if c.get("reachable") != a.get("reachable") or c.get("visible") != a.get("visible"):
        return "下一步：记录与本地模拟检查不同，可明确更正；仅改内存。"
    if not bool(a.get("reachable", false)):
        return "下一步：T 当前不可达，使用【预览返回 S】；不可穿越墙格。"
    return "下一步：本次记录与模拟观察一致，可继续移动（之后必须重新核对）。"

func text_map(report: Dictionary) -> String:
    var active: Dictionary = report.get("synthetic", {})
    if not bool(active.get("ready", false)):
        return "无活动地图（BLOCKED），没有可读取的格子。"
    var rows: Array = active.get("grid", [])
    var route: Array = active.get("preview", [])
    var player: Vector2i = active.get("player", Vector2i.ZERO)
    var start: Vector2i = active.get("start", Vector2i.ZERO)
    var target: Vector2i = active.get("target", Vector2i.ZERO)
    var lines := PackedStringArray()
    lines.append("字符图例：# 墙，. 通路，: 预览路线，S 起点，T 目标，P 当前。颜色不传递额外信息。")
    for y in range(rows.size()):
        var line: String = ""
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
        lines.append("行%02d（列从 0 开始）：%s" % [y, line])
    return "\n".join(lines)

func diagnostics(report: Dictionary) -> String:
    var original: Dictionary = report.get("source_report", {})
    var fallback: Dictionary = report.get("fallback_report", {})
    var lines := PackedStringArray()
    lines.append("原输入结构状态：" + str(original.get("status", "UNAVAILABLE")))
    for issue in original.get("issues", []):
        lines.append("[%s] %s @ %s" % [
            str(issue.get("severity", "?")), str(issue.get("code", "?")),
            str(issue.get("path", "?"))])
        lines.append("原因：" + str(issue.get("message", "")))
        lines.append("修复建议：" + str(issue.get("action", "")))
    if int(original.get("suppressed", 0)) > 0:
        lines.append("原输入诊断超过显示上限，原数据仍不可接受。")
    var mode: String = str(report.get("mode", "BLOCKED"))
    if mode == "FALLBACK_SYNTHETIC" or mode == "BLOCKED":
        lines.append("后备状态：" + str(fallback.get("status", "UNAVAILABLE")))
        for item in fallback.get("issues", []):
            lines.append("后备[%s] %s @ %s" % [
                str(item.get("severity", "?")), str(item.get("code", "?")),
                str(item.get("path", "?"))])
            lines.append("原因：" + str(item.get("message", "")))
            lines.append("处理：" + str(item.get("action", "")))
    lines.append("以上为候选运行时拟显示的诊断，不构成本任务的实际测试。NOT_RUN。")
    return "\n".join(lines)
