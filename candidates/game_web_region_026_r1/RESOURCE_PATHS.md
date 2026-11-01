# RESOURCE_PATHS｜N26 独立工程固定依赖

**唯一工程根：** `cao772/game/candidates/game_web_region_026_r1/`。不要从仓库根、PR #18 目录或 PR #33 目录启动本工程。NOT_RUN。

| 组件 | 固定资源 | 依赖 / 行为 |
| --- | --- | --- |
| `project.godot` | `res://main.tscn` | N26 独立入口 |
| `main.tscn` | `res://menu_flow_owner.gd` | 菜单、区域、事件三个顶层 holder 的唯一路由 owner |
| `menu_flow_owner.gd` | `res://region_screen.tscn` | 只有菜单显式进入区域时才加载 |
| `region_screen.tscn` | `res://accessible_demo.gd` | PR #33 Control 区域；继续依赖同目录的 region validator/gateway/grid/status/cases/interaction 文件 |
| `menu_flow_owner.gd` | `res://event_preview_screen.tscn` | 只有菜单或区域显式点击事件预览时才加载 |
| `event_preview_screen.tscn` | `res://event_preview_screen.gd` | 事件 UI；顶层返回按钮由菜单外层拥有 |
| `event_preview_screen.gd` | `res://event_preview_model_candidate.gd` | 新建临时事件预览模型；只传来源标签，不接收 region state |
| `event_preview_model_candidate.gd` | `res://fixtures/placeholder_start.json` | 固定 EVENT_START |
| 同上 | `res://fixtures/placeholder_next.json` | 固定 EVENT_NEXT |
| 同上 | `res://fixtures/placeholder_end.json` | 固定 EVENT_END |

## 故障策略

- 缺失/非 PackedScene/根节点非 Control 的**区域场景**：不提交 route，菜单仍在原页，显示 BLOCKED；修复固定资源后显式重试。
- 缺失/非 PackedScene/根节点非 Control 的**事件预览场景**：不提交 route，来源页仍可见；用户可再次显式点击。
- 三份固定 event JSON 中任一缺失、空、超 16 KiB、UTF-8/JSON/结构/ID/引用错误：事件页内显示 BLOCKED、禁用分支和观察控件；外层返回仍在；用户可显式重新读取固定 fixture。
- 不自动寻找其它 fixture、不复制 PR #18 的输入目录扫描、不使用 PR #33 的 region fallback 替代 event fixture、不加载任意路径。
- 缺失/解析失败的必需 GDScript 可能使 Godot 导入失败；这属于项目导入级 BLOCKED，不能宣称由页面控件修复。
- N26 的 local fixed-fixture guard 不是 PR #9 checker；它不提供 checker 的目录/符号链接/重复 JSON key/TOCTOU/SourceIndex 完整保障。

**路径与资源可用性未执行验证。所有故障行为均为待验收预期，NOT_RUN。**
