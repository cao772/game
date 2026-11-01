# GAME-WEB-REGION-025 r1｜合成菜单 → 可访问区域 → 返回桥接候选

**DRAFT · NOT_RUN · PUBLIC SYNTHETIC A/B/C ONLY · NO SHARED INTERFACES · NO MAIN MERGE**

本目录是一个可独立放在 Godot 4 项目根的**源码候选**，不是已运行/验收过的项目。只在新目录内组合菜单控制器与 [PR #32](https://github.com/cao772/game/pull/32) 的现有可访问合成区域副本；参考 [PR #24](https://github.com/cao772/game/pull/24) 的主页/模块状态/历史返回/失败不自动跨页语义，但**不复制、调用或改写 #24 的 Shell、事件映射、角色、存档和私有导航接口**。

## 确认来源

- **PR #24:** Draft/Open、HEAD `5768eeef65fe5d54b1c5a692c44400332da61506`。其 `shell_candidate.gd` 具有首页/模块页/返回历史与 missing/disabled/pending/degraded；其 `play_005/play_shell.gd` 提供 `return_menu/return_previous`、失败不跳页和独立资源挂载。该 Play Shell 的“region”特指另一份候选 Node3D 与 `flow_snapshot`，**不能**误称 PR #32 的 Control 区域实现了这些接口。
- **PR #32:** Draft/Open、HEAD `cc70e20dbf916bb15c1844c1efb749adb6c14b4d`。实际 `accessible_demo.gd` 是独立 Control，依赖 `keyboard_grid/semantic_status/validated_gateway/synthetic_interaction/catalog_recovery/region_validator` 与纯合成 A/B/C fixture。保留其九份源码文件的**相同 Git blob**，不修改其自有校验/回退/交互行为。
- N25 新分支 `codex/game-web-region-025-r1` 从 main `533b11f50c0d359cd0a5424d5216b0145727699a` 单独建立，**不是**叠加 PR #24/#32。所有文件仅在 `candidates/game_web_region_025_r1/`。

## 新增/复用文件

| 文件 | 作用 |
| --- | --- |
| `menu_flow_owner.gd` | **N25 新增**；菜单页面 home/status、模拟装配状态、显式进入/返回/重试和失败文本；不访问任何区域内部模型 |
| `main.tscn` | **N25 新增**；固定菜单入口，只有一个项目根 |
| `region_screen.tscn` | **N25 新增**；采用本地 `accessible_demo.gd` 的独立 Control 区域壳 |
| `project.godot` | **N25 新增**；`res://main.tscn`，不会覆盖 PR #24/#32 的其他 `project.godot` |
| `accessible_demo.gd` / `keyboard_grid.gd` / `semantic_status.gd` | 与 PR #32 相同 blob；区域自己的键盘、缩放、非颜色状态 |
| `validated_gateway.gd` / `synthetic_interaction.gd` / `catalog_recovery.gd` / `region_validator.gd` | 与 PR #32 相同 blob；区域独占校验、后备与本地模型状态 |
| `synthetic_cases.gd` / `synthetic_regions.json` | 与 PR #32 相同 blob；公开合成错误案例与 A/B/C 样本 |
| `DESIGN.md` / `STATE_OWNERSHIP.md` / `RESOURCE_PATHS.md` / `SOURCE_REVIEW.md` / `FUTURE_ACCEPTANCE.md` | 静态边界、所有权、失效路径、固定行号证据与未来测试 |

## 预期交互（代码已编写，尚未执行）

1. 菜单概览/模拟模块状态页（均为 N25 自有）：选择公开合成区域模块，模块模拟状态可显式设为 `ready/missing/disabled/pending/degraded`。这些状态只用于测试菜单拒绝进入，**不反映真实 PR 模块健康**。
2. 在 `ready` 且有活动窗口/场景树、固定 `region_screen.tscn` 资源可用时，才动态实例化区域 Control。**只有成功挂载后**从 menu 转为 region；进入失败仍停留原菜单页，显示 BLOCKED 及具体恢复建议。
3. 区域内部自己加载固定 `synthetic_regions.json`；若该可选文件错/缺则使用 PR #32 已有的内置合成后备，显示 `FALLBACK_SYNTHETIC`；若内置后备亦不合法则显示 `BLOCKED`。**菜单不二次回退，也不承诺知道区域内部是否可玩。**
4. 区域上方始终提供 **“返回上层菜单”** 与 **“回到菜单概览”**。返回前移除并释放区域实例（以及它的本地网格位置/核对/更正/撤销/诊断对象），新进入才会再建立干净区域；菜单只保留自己的模块模拟状态、来源页与最近提示。
5. 失败后选择“显式恢复模拟就绪并重试”，更新的只是菜单内存标志，随后重新检查固定场景资源。没有自动猜测新文件、加载真实数据、替换共享接口或回跳事件。

## 明确不做

- 不把 PR #24 的 Node3D、`flow_snapshot()`、`play_006` target→event 规则或其 `return_previous` 方法签名用于 PR #32；它们来源和语义不同，没有已批准的共享合同。
- 不新增共享 `InputMap`、自动时间推进、正式存档、跨页面事件、人物/地点/剧情/手稿、网络/外部文件或隐藏状态持久化。
- 不支持从主游戏进程直接安装本项目；它是新的**独立单机候选副本**。
- **NOT_RUN**：未启动 Godot、GDScript/JSON 解析、代码、测试、CI、GUI、屏幕阅读器或性能采样；功能行为描述全是未来可验证的预期，不能标 PASS。
