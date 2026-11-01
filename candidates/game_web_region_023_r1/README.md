# GAME-WEB-REGION-023 r1｜PR #30 静态审查与隔离修复候选

**DRAFT / NOT_RUN / SYNTHETIC A/B/C ONLY / NO MAIN OR SHARED API CHANGE**

本目录针对 [Draft PR #30](https://github.com/cao772/game/pull/30) 固定 HEAD `3806fbf289dbe5bcb89bca11a98971c616ce6ab8` 做了**源码级审查和隔离式改进候选**。审查的是 #30 的校验、回退、局部交互、撤销、独立 Godot 项目资源路径，**没有在 #30 原分支上打补丁**。

**这是完整的独立 Godot 4 候选工程，但没有运行、解析、启动或测试。** 设计行为只属于未来验收预期。

## 本目录交付

- `project.godot`、`main.tscn`：独立场景根；Godot 的 `res://` 应指向本目录，而不是仓库 main 或 PR #30 文件夹。
- `region_validator.gd`、`synthetic_regions.json`、`synthetic_cases.gd`：采用 #30 已存在的**相同 Git blob**，未改动原验证规则或纯合成内容。
- `catalog_recovery.gd`：在**本目录内**加读取前文件大小门禁，保留单一回退源、三态和原有字段级诊断。
- `validated_gateway.gd`：保留 `BLOCKED` 根因，新增上游三态诊断一致性与字段类型防御，在失效时清空交互、不启动场景。
- `synthetic_interaction.gd`：完全重置遗留位置向量，保留四向 BFS、模拟 LOS、显式核对→内存更正、撤销等候选语义。
- `integration_demo.gd`：显示诊断“原因”和“修复动作”，只在文本变化时重设只读显示，并尝试保留滚动行；**需要未来 Godot 验证**。
- `FINDINGS.md`：逐条源级发现、原 PR #30 的精确行号、级别、修复措施和剩余风险。
- `PATCH_SCOPE.md`：独立源码副本、可撤回范围与所有权；`RESOURCE_PATHS.md`：资源依赖闭包及缺失资源处理；`FUTURE_ACCEPTANCE.md`：逐项 NOT_RUN 的未来验收。
- `SOURCE_REVIEW.md`：固定 HEAD、Git blob 和版本边界。

## 为什么不直接修改 PR #30

PR #30 仍为 Draft，其未运行过的源码不应被静态检查结果伪装成真实验证。本轮从独立 `main` 分支创建 **codex/game-web-region-023-r1**，只新增 `candidates/game_web_region_023_r1/` 内的文件，不修改旧 PR、共享输入接口、真实游戏区域/故事、主分支或任何已有存档。

## 降级/阻断原则

`SOURCE_ACCEPTED` 表示**结构校验接受**，不代表实际可达、物理安全或 Godot 运行通过；`FALLBACK_SYNTHETIC` 表示源有问题、改用内置合成样本，绝不能声称已修复源文件；`BLOCKED` 表示无可用活动场景，模型不允许操作。若缺必需脚本/项目根/引擎，无法在应用内部降级，必须按未来导入失败记录。

全部代码/数据都只是匿名合成 A/B/C，不含真实角色、地点、小说、私人草稿、聊天记录或未公开设定。**NOT_RUN**：无 Godot、GDScript/JSON 解析、代码执行、测试、CI、截图、UI/无障碍验证或性能跑分。
