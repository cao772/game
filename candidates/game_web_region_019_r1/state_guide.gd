extends RefCounted
## GAME-WEB-REGION-019 r1 | synthetic read-only guide, NOT_RUN.
## No saved data, events, gameplay integration, real names or places.

func _word(value: bool) -> String:
    return "是" if value else "否"

func render(state: Dictionary) -> String:
    var claim: Dictionary = state.get("claimed", {})
    var lines := PackedStringArray()
    lines.append("019｜合成状态证据卡，仅内存展示，不是实测报告")
    lines.append("场景：" + str(state.get("id", "?")) + " | 数据来源：" + str(state.get("source", "未知")))
    lines.append("当前位置：" + str(state.get("player", "?")) + " | 目标：" + str(state.get("target", "?")))
    lines.append("01｜记录主张（可能故意错误）")
    lines.append("  目标可达：" + _word(bool(claim.get("reachable", false))) +
        "；直线可见：" + _word(bool(claim.get("visible", false))))
    if bool(state.get("inspected", false)):
        var reachable: bool = bool(state.get("actual_reachable", false))
        var visible: bool = bool(state.get("actual_visible", false))
        lines.append("02｜当前位置的模拟核对结果")
        lines.append("  四向网格可达：" + _word(reachable) + "；采样视线：" + _word(visible))
        var matched: bool = bool(claim.get("reachable", false)) == reachable and bool(claim.get("visible", false)) == visible
        lines.append("  与记录一致：" + _word(matched))
        lines.append("  以上仅指演示动作，不代表实际运行测试通过。")
    else:
        lines.append("02｜观察尚未核对；不能把记录主张当成实际观察。")
    var path: Array = state.get("preview", [])
    lines.append("03｜当前路线预览格数：" + str(path.size()) + "（预览不移动人物）")
    lines.append("04｜允许撤销：" + _word(bool(state.get("undo_available", false))) +
        " | 内存撤销栈：" + str(state.get("undo_depth", 0)))
    lines.append("05｜资源状态：" + str(state.get("notice", "未说明")))
    lines.append("06｜最新操作反馈：" + str(state.get("feedback", "无")))
    lines.append("局限：非物理碰撞、非真实导航、非安全认证、无文件写入。")
    lines.append("工程验证状态：NOT_RUN。")
    return "\n".join(lines)

func next_step(state: Dictionary) -> String:
    var claim: Dictionary = state.get("claimed", {})
    if not bool(state.get("inspected", false)):
        return "建议：先执行【1. 重新核对可达与遮挡】。若需退回，可先【预览返回 S】。"
    var same: bool = bool(claim.get("reachable", false)) == bool(state.get("actual_reachable", false))         and bool(claim.get("visible", false)) == bool(state.get("actual_visible", false))
    if not same:
        return "建议：记录与模拟观察不同；可【2. 明确更正本地记录】，误改可【撤销】。"
    if not bool(state.get("actual_reachable", false)):
        return "建议：T 不可达；选择【预览返回 S】，不要尝试穿墙。"
    return "建议：记录与观察一致；可继续探索或切换到另一个 A/B/C 合成场景。"
