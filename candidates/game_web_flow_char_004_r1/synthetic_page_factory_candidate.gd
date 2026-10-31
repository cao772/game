extends RefCounted
## Explicit synthetic pagination demonstration, no disk/network or story sources.
## 14 items (3 pages of 6); can also create 0..24 records for future QA.

const LIMIT := 24


static func build(count: int = 14) -> Array[Dictionary]:
    var output: Array[Dictionary] = []
    if count < 0 or count > LIMIT:
        return output
    for index in range(count):
        var identity := "page-demo-%02d" % index
        var record := {
            "schema_version": 1,
            "profile_id": identity,
            "display_name": "合成分页条目 %02d" % index,
            "subtitle": "仅用于列表分页、列表焦点与详情回退演示",
            "summary": "这是完全合成的占位长文本。"
                + "它仅演示第 %02d 条的阅读与返回。 " % index
                + "Mixed English / 中文 paragraphs.\r\n\r\n"
                + "syntheticSequence".repeat(16),
            "status_label": "纯合成占位",
            "tags": ["合成", "分页", "示例"],
            "sections": [
                {
                    "section_id": "intro",
                    "heading": "基础字段（占位）",
                    "items": [
                        {"label": "编号", "value": identity},
                        {"label": "来源", "value": "运行时生成的合成数据，无真实角色设定"}
                    ]
                },
                {
                    "section_id": "long-detail",
                    "heading": "长内容压力样本",
                    "items": [
                        {"label": "连续字符", "value": "Synthetic1234".repeat(30)},
                        {"label": "尾部文字", "value": "最后一段：可使用章节跳转与滚动阅读。"}
                    ]
                }
            ]
        }
        output.append(record)
    return output
