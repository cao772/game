# GAME-WEB-REGION-022 r1｜合成数据校验→回退→交互隔离候选

**DRAFT · NOT_RUN · A/B/C PUBLIC SYNTHETIC FIXTURES ONLY · NO CANON/MAIN/SHARED API CHANGE**

本目录是完整、独立的 Godot 4 候选工程，但**从未运行、解析或测试**。只读取公开 GitHub 来源：
- [Draft PR #28](https://github.com/cao772/game/pull/28)，审核 SHA `6eb7ee2f889305ec1211441c7848637bc1c551c1`：`region_validator.gd`、`catalog_recovery.gd`、`synthetic_regions.json`；相关边界案例及说明；
- [Draft PR #29](https://github.com/cao772/game/pull/29)，审核 SHA `1c7a2dcc7c5dd0343b8f4837731b3afadf6a77c5`：`COMPATIBILITY_MATRIX.md`、`RISK_REGISTER.md`、`STAGED_MIGRATION.md`、`ACCEPTANCE_PLAN.md`。
这两份 PR 都尚为 Draft，不能据此断言已经可运行。N22 分支从 `main` `533b11f50c0d359cd0a5424d5216b0145727699a` 单独创建，**不基于别的 Draft 分支**。

## 文件与责任边界

| 文件 | 职责 |
| --- | --- |
| `region_validator.gd` | 按 Git blob 原样复制自 PR #28：A/B/C JSON 的版本、类型、边界、唯一性与错误路径诊断 |
| `catalog_recovery.gd` | 按 Git blob 原样复制自 PR #28：**唯一合成资源加载者**、三态 `SOURCE_ACCEPTED/FALLBACK_SYNTHETIC/BLOCKED` 与内置合成回退 |
| `synthetic_regions.json` | PR #28 原始 **公开合成** blob，四 PR 共享同一 Git blob，不是产品真实地图 |
| `validated_gateway.gd` | N22 新增适配入口：只接受上游已批准目录、过滤多余字段、分离源诊断、阻断后禁止交互 |
| `synthetic_interaction.gd` | N22 新增独立本地交互模型：格网四向 BFS、示意遮挡、移动、两步核对→更正、撤销与返回 S；**没有文件加载和回退** |
| `synthetic_cases.gd` | N22 新增内存样本：坏版本、重复 ID、缺 T、有效但隔断的 C 等；**不是测试脚本或测试结果** |
| `integration_demo.gd`、`main.tscn`、`project.godot` | N22 独立按钮/文字式演示工程，不引用共享游戏 InputMap、存档、人物/真实地点 |
| `INTEGRATION_CONTRACT.md`、`DESIGN.md`、`FUTURE_ACCEPTANCE.md`、`SOURCE_REVIEW.md` | 数据边界、选择理由、风险对策、未来验收与来源 |

## 设计主线（未来运行预期，不是已发生事实）

```text
res://synthetic_regions.json（固定可选合成资源）
    ↓
PR28 catalog_recovery.gd（唯一 Loader / 唯一 fallback）
    ↓    mode + report + fallback_report + catalog
N22 validated_gateway.gd（门禁 + 白名单 + 单份活动场景）
    ↓    {id, grid, claimed}，无外来字段
N22 synthetic_interaction.gd（仅内存，绝不二次加载或回退）
    ↓    local snapshot（claim 与 inspect/actual 分离）
N22 integration_demo.gd（纯文本与按钮交互）
```

**安全退化：**
- 可选合成 JSON 有效：`SOURCE_ACCEPTED`，它**只表示结构接受**，不说明路线/视线/实机运行已通过。
- JSON 缺失、损坏、版本错误：PR28 按其内部规则生成错误诊断、检查内置合成 A/B/C，然后如可用显示 `FALLBACK_SYNTHETIC`；**原文件没有被修好**。
- 内置 fallback 也无效、网关遇到不可用数据：`BLOCKED`，清空活动场景和内存状态，按钮不能触发移动/核对/更正。
- 任何**必需**脚本、scene 或 Godot 环境缺失：属于项目导入失败，无法由运行中的候选模块自动降级；不可谎称恢复成功。

**演示交互（尚未执行）：** 切 A/B/C、四向按钮移动、目标/返程路线预览、`1. 核对`、`2. 更正内存记录`、撤销。纯文本字符地图标明 `# . : S T P`，所有观察必须经过显式 Inspect 才出现在 `actual` 里。没有自动走路、跨场景记忆、文件写入、世界事件或 UI 全局快捷键。

## 证据状态与限制

**NOT_RUN。** 本轮只通过 GitHub 建立源文件、提交和 Draft PR，**不运行 Godot、不运行任何脚本、解析器、测试、CI、性能评估或 GUI**。此刻不能声称模块能编译、互通、符合无障碍、路径准确或 fallback 必然生效。候选按钮的后续使用也不等于真是“实际游戏安全认证”。

源文件包含原样公开合成数据，没有真实剧情、地点、人物、原稿、聊天证据、私有信息，也不触及共享接口与 `main`。需要未来另行授权实机验收；默认保留 Draft。
