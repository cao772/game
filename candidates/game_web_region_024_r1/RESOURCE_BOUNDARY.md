# RESOURCE_BOUNDARY｜N24 独立 Godot 根与降级边界

**项目根（仅待未来安装/验证）：** `cao772/game/candidates/game_web_region_024_r1/`。整个目录自包含，不引用 PR #26/#31 或主游戏的 `res://` 资源。

| 入口/脚本 | 显式本地资源 | 类别 | 静态处理原则 |
| --- | --- | --- | --- |
| `project.godot` `run/main_scene` | `res://main.tscn` | 必需 | 缺失则无法启动，标 BLOCKED |
| `main.tscn` `ext_resource` | `res://accessible_demo.gd` | 必需 | 导入/解析失败，标 BLOCKED |
| `accessible_demo.gd` | `res://validated_gateway.gd`、`res://synthetic_cases.gd`、`res://semantic_status.gd`、`res://keyboard_grid.gd` | 必需 | 任一缺失应报导入失败，不伪称 fallback |
| `validated_gateway.gd` | `res://catalog_recovery.gd`、`res://synthetic_interaction.gd` | 必需 | 不能在失败时跳过校验进入真实或其他来源 |
| `catalog_recovery.gd` | `res://region_validator.gd` | 必需 | 校验器失败则无法证明输入结构有效 |
| `catalog_recovery.gd` `FIXTURE_PATH` | `res://synthetic_regions.json` | **可选合成输入** | 文件缺失/无效/超先验大小，原报告保留；经自身检查的纯合成 A/B/C 内置回退 |
| `synthetic_cases.gd` | `res://catalog_recovery.gd` | 必需 | 仅为显示已有合成错误样本，不读取外部文件 |

**禁止跨越**：动态路径选择、网络数据、其他 PR 的私有文件、游戏角色、真实区域、历史时钟、共享 InputMap/存档/事件、真实动作控制。重载按钮只调用固定合成路径，样本按钮只传由 PR31 现有 `synthetic_cases.gd` 构造的 A/B/C 内存数据。

**无依赖的媒体**：没有自定义字体、图片、声音、视频或动画；黑白焦点外框只是辅助，源状态、墙/路径和错误全部用文字/字符说明。但中文字体实际是否可用、屏幕阅读器是否读取文本及焦点顺序，均为未来实机验收事项。**NOT_RUN**。
