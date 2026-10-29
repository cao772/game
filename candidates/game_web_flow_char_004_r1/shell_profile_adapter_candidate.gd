extends RefCounted
## Independent shell PR #17-compatible SYNTHETIC mock only (NOT_RUN).
## This object is not a live Control mount and never invokes flow/game actions.

const SAMPLE_REQUEST := "sample_request"

func preview() -> Dictionary:
    return {
        "ok": true,
        "title": "占位资料浏览 · 本地模拟",
        "body": "角色资料列表 / 详情切换 / 返回列表\n"
            + "数据来源：纯合成占位，不含正式人物。\n"
            + "此适配器仅向独立 shell 的 profile 槽位提供简短模拟文本；"
            + "不会运行或打开角色资料组件。\n"
            + "真实 UI 装配需要另行审核的 Control 容器集成。"
    }


func preview_action(request_id: String) -> Dictionary:
    if request_id != SAMPLE_REQUEST:
        return {
            "ok": false,
            "simulated": true,
            "message": "不支持的占位模拟请求"
        }
    return {
        "ok": true,
        "simulated": true,
        "message": "仅确认 shell 本地模拟请求；未打开真实面板或修改状态。"
    }
