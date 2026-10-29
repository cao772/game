extends RefCounted
## Private synthetic adapter for GAME-WEB-MODULE-SHELL-001 r1.
## No filesystem, network, original content, PR imports or gameplay dispatch.
## These are NOT interfaces exposed by Draft PR #6 / #10 / #14 / #15.

const KNOWN_SLOTS := ["round", "prompt", "profile", "bindings"]
var _slot: String = ""


func _init(slot_name: String = "") -> void:
    if KNOWN_SLOTS.has(slot_name):
        _slot = slot_name


func preview() -> Dictionary:
    match _slot:
        "round":
            return {
                "ok": true,
                "title": "回合状态 · 模拟展示",
                "body": "演示记录：样本-001\n模式：占位\n状态：未绑定\n时钟：未接入\n\n无状态写入；不读取 #6 快照。"
            }
        "prompt":
            return {
                "ok": true,
                "title": "交互提示 · 模拟展示",
                "body": "目标：合成目标 A\n动作：仅展示请求\n\n不创建 #10 组件实例；不处理真实目标或焦点优先级。"
            }
        "profile":
            return {
                "ok": true,
                "title": "信息面板 · 模拟展示",
                "body": "记录：合成资料 A\n标签：演示、占位\n详情：仅用于检验导航。\n\n不加载 #14 真实 Panel 或角色数据。"
            }
        "bindings":
            return {
                "ok": true,
                "title": "键位配置 · 模拟展示",
                "body": "键位样例：动作 A / 键 1；动作 B / 键 2\n\n仅合成样例，不读取 #15 配置文件，不修改 InputMap。"
            }
    return {"ok": false, "title": "适配器未连接", "body": "未知占位槽位"}


func preview_action(action_id: String) -> Dictionary:
    if _slot.is_empty() or action_id != "sample_request":
        return {"ok": false, "message": "未知模拟请求"}
    return {
        "ok": true,
        "message": "模拟请求已显示；未调用上游、未更改状态或持久化。",
        "simulated": true
    }
