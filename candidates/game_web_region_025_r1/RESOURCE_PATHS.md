# RESOURCE_PATHS｜N25 独立工程依赖与可恢复性

**未来才允许导入的项目根：** `cao772/game/candidates/game_web_region_025_r1/`。不能以仓库 `main` 根或 PR #24/#32 的另一个子目录作为本工程根。**NOT_RUN。**

| 请求方/资源 | 固定路径 | 必需？ | 失败策略 |
| --- | --- | --- | --- |
| 本工程 `project.godot` | `res://main.tscn` | 是 | 无启动入口，必须阻塞，不能称可恢复 |
| `main.tscn` | `res://menu_flow_owner.gd` | 是 | 菜单本身无法导入；硬失败 |
| `menu_flow_owner.gd`（显式进入才动态加载） | `res://region_screen.tscn` | **可选模块场景** | 文件不存在/非 PackedScene 时在菜单显示 BLOCKED、保留原页 |
| `region_screen.tscn` | `res://accessible_demo.gd` | 装载区域时必需 | 脚本缺失/解析失败通常属于硬依赖，不能保证 GUI 捕获 |
| `accessible_demo.gd` | `res://validated_gateway.gd`, `res://synthetic_cases.gd`, `res://semantic_status.gd`, `res://keyboard_grid.gd` | 区域必需 | 无法进入或解析，视为 BLOCKED，不启用原 PR #24 区域代替 |
| `validated_gateway.gd` | `res://catalog_recovery.gd`, `res://synthetic_interaction.gd` | 区域必需 | 区域完整性失败，禁止交互 |
| `catalog_recovery.gd` | `res://region_validator.gd` | 区域必需 | 不绕开校验 |
| `catalog_recovery.gd` | `res://synthetic_regions.json` | **可选合成输入** | 由原 PR #32 代码内置同样 A/B/C 样本并显示来源；不加载其他文件或真实地图 |
| `synthetic_cases.gd` | `res://catalog_recovery.gd` | 区域必需 | 不开放无来源错误样例 |

**分类说明：** 模拟 `missing/disabled/pending/degraded` 是菜单内部人为选择的状态，不会删除文件、停止真正的进程或替换 Godot 资源。只有 `ResourceLoader.exists/load` 在真正调用时才可能表明固定 scene 是否存在/格式匹配；这个调用本任务**没有执行**。

菜单失败后的“显式恢复并重试”不会绕过缺少的文件。若场景真正缺失，返回的依然是 BLOCKED；若内层合成 JSON 无效而其内置 fallback 可用，区域可能挂载并显示 `FALLBACK_SYNTHETIC`，菜单不负责这一级别的诊断。

不会从任何私有目录、原稿、网络、历史聊天、其它 PR 运行树或用户磁盘猜测/加载文件，也不访问共享接口、存档或游戏世界。**NOT_RUN。**
