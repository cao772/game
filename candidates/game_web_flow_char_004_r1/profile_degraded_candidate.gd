extends RefCounted
## GAME-WEB-CHAR-006 r1. Synthetic-only resource-degradation helper.
## No IO, private records, global state, or script loading.

const PROFILE_ID := "synthetic-resource-unavailable"


static func stub_profile() -> Dictionary:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "display_name": "内置占位资源不可用提示",
        "subtitle": "仅作为资源加载失败时的本地替代示例",
        "summary": "固定占位资源未能读取。此条目是代码内置的合成示例，"
            + "不是恢复后的资源，不包含真实人物或剧情。",
        "status_label": "资源降级 / 非原始数据",
        "tags": ["合成", "资源缺失", "待恢复"],
        "sections": [
            {
                "section_id": "resource-status",
                "heading": "占位资源状态",
                "items": [
                    {"label": "说明", "value": "可通过「重载占位」重新尝试固定的本地合成资源。"},
                    {"label": "数据来源", "value": "内置合成降级记录；不是已校验的外部资料。"}
                ]
            }
        ]
    }


static func full_text(profile: Dictionary) -> String:
    # Caller supplies an already validated full profile; this function is
    # a plain-text formatter for a broken PackedScene, not a renderer API.
    if profile.is_empty():
        return "未选择占位资料。"
    var lines: Array[String] = [
        "只读降级详情（原展示组件当前不可用）",
        "名称：" + str(profile.get("display_name", "")),
        "副标题：" + str(profile.get("subtitle", "")),
        "状态：" + str(profile.get("status_label", "")),
        "",
        "摘要：",
        str(profile.get("summary", "")),
        ""
    ]
    var tags: Array = profile.get("tags", [])
    if not tags.is_empty():
        var parts := PackedStringArray()
        for tag in tags:
            parts.append(str(tag))
        lines.append("标签：" + " / ".join(parts))
    for section in profile.get("sections", []):
        lines.append("")
        lines.append("【" + str(section.get("heading", "")) + "】")
        var items: Array = section.get("items", [])
        if items.is_empty():
            lines.append("暂无条目")
        for item in items:
            lines.append(str(item.get("label", "")) + "：")
            lines.append(str(item.get("value", "")))
    return "\n".join(lines)
