# RESOURCE_PATHS｜独立 Godot 项目的静态依赖表

**本页只用 PR #30 公开源代码推导资源路径，不运行项目，也不向其他仓库/私有文件读取资源。NOT_RUN。**

在未来被明确授权后，正确的项目根应该是：

`cao772/game/candidates/game_web_region_023_r1/`

| 文件或调用方 | 依赖资源（相对于上述候选目录） | 是否必需 | 缺失时正确处理 |
| --- | --- | --- | --- |
| `project.godot` 的 `run/main_scene` | `res://main.tscn` | 必需 | 引擎无法启动，记 BLOCK |
| `main.tscn` 的 `ext_resource` | `res://integration_demo.gd` | 必需 | 场景载入失败，记 BLOCK |
| `integration_demo.gd` `preload` | `res://validated_gateway.gd` | 必需 | 解析/导入失败，记 BLOCK |
| `integration_demo.gd` `preload` | `res://synthetic_cases.gd` | 必需 | 解析/导入失败，记 BLOCK |
| `validated_gateway.gd` `preload` | `res://catalog_recovery.gd` | 必需 | 解析/导入失败，记 BLOCK |
| `validated_gateway.gd` `preload` | `res://synthetic_interaction.gd` | 必需 | 解析/导入失败，记 BLOCK |
| `catalog_recovery.gd` `preload` | `res://region_validator.gd` | 必需 | 解析/导入失败，记 BLOCK |
| `catalog_recovery.gd` 固定 `FIXTURE_PATH` | `res://synthetic_regions.json` | **可选** | 缺失/不可读/超候选大小或无效则提供明确诊断，再使用经校验的**纯合成**内置 A/B/C |
| `synthetic_cases.gd` `preload` | `res://catalog_recovery.gd` | 必需 | 解析/导入失败，记 BLOCK |

**不能把“文件确实在 GitHub”当成 Godot 导入实测通过。** 这个目录根设计属于本地 Godot 项目的一部分；从仓库 main 根运行、把 N23 的资源裸露到其他 PR 的项目根或覆盖原 PR30 文件都不在授权范围内。

**无其他资源依赖：** 未引入图片、音频、字体、网络地址、真实地图/角色/文本或未公开资料。界面仅使用 Godot 内置 GUI 控件和字符网格。上游 JSON 的 `title`/ `notice` 属于固定公开合成文本；不能据此授权任何外部或私有输入。
