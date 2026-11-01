# SOURCE_REVIEW｜PR #28 与 PR #29 的只读溯源

**本轮只使用公开 GitHub 源码/说明，不运行任何代码或测试，NOT_RUN。**

## 固定输入（当次实际读取）
- [PR #28](https://github.com/cao772/game/pull/28)：Draft/Open，HEAD `6eb7ee2f889305ec1211441c7848637bc1c551c1`，目录 `candidates/game_web_region_020_r1/`。已读实际 GitHub 原文件 `region_validator.gd`、`catalog_recovery.gd`、`synthetic_regions.json`、`synthetic_boundary_cases.gd`，核对相关文件清单。
- [PR #29](https://github.com/cao772/game/pull/29)：Draft/Open，HEAD `1c7a2dcc7c5dd0343b8f4837731b3afadf6a77c5`，目录 `candidates/game_web_region_021_r1/`。已读 `COMPATIBILITY_MATRIX.md`、`RISK_REGISTER.md`、`STAGED_MIGRATION.md`、`ACCEPTANCE_PLAN.md`，核对 PR 变更清单。
- `main` 审阅时 HEAD `533b11f50c0d359cd0a5424d5216b0145727699a`。N22 从该 SHA 创建单独 `codex/` 分支，没有在 PR28/29 的提交上叠加。

## 关键文件证据（固定 SHA 的源代码直链）
| 原始定位 | 源码支持的事实 | 本轮的独立候选处理 |
| --- | --- | --- |
| [#28 `region_validator.gd` L4–52](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/region_validator.gd#L4-L52) | 合成版本、输入/诊断候选上限、`validate_json_text` | 完全保留相同原始 Git blob，不改规则 |
| [#28 `region_validator.gd` L52–179](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/region_validator.gd#L52-L179) | `validate_variant` 检查 A/B/C、网格和字段；不检验真实可达 | 在网关把结构结论与本地 BFS/LOS 分离 |
| [#28 `catalog_recovery.gd` L3–21](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/catalog_recovery.gd#L3-L21) | 只引用本地 `res://synthetic_regions.json`、定义固定合成 fallback | 复制原始 SHA，唯一资源入口 |
| [#28 `catalog_recovery.gd` L25–75](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/catalog_recovery.gd#L25-L75) | `SOURCE_ACCEPTED`、`FALLBACK_SYNTHETIC`、`BLOCKED`，回退自己也需验证 | 网关读取三态，保留输入原报告与回退报告，不执行第二套 fallback |
| [#28 `synthetic_regions.json`](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/synthetic_regions.json) | 仅 A/B/C 合成格网，Git blob `2c336868a30f6c247a1a8f04c5d5a5fe5e31bed5` | 新目录只复制同一 blob，不加入真实数据 |
| [#29 `RISK_REGISTER.md`](https://github.com/cao772/game/blob/1c7a2dcc7c5dd0343b8f4837731b3afadf6a77c5/candidates/game_web_region_021_r1/RISK_REGISTER.md) | 明确 R01–R12，优先指出重名 Godot 根、双回退、结构与可达分离、过早展示核对、焦点等 | N22 只做“输入校验→合成模型”的隔离薄片；其余未解决的风险保留 |
| [#29 `COMPATIBILITY_MATRIX.md`](https://github.com/cao772/game/blob/1c7a2dcc7c5dd0343b8f4837731b3afadf6a77c5/candidates/game_web_region_021_r1/COMPATIBILITY_MATRIX.md) | 各模块是独立 Godot 工程，不是现成堆叠的分支 | 自有 N22 `project.godot/main.tscn`，不强行导入原根 |
| [#29 `STAGED_MIGRATION.md`](https://github.com/cao772/game/blob/1c7a2dcc7c5dd0343b8f4837731b3afadf6a77c5/candidates/game_web_region_021_r1/STAGED_MIGRATION.md) | 先冻结源事实、定义单一加载链，再在独立候选中考虑交互/显示/授权测试 | 只落实前置校验 + 合成局部模型，不接共享状态、保存或正史 |
| [#29 `ACCEPTANCE_PLAN.md`](https://github.com/cao772/game/blob/1c7a2dcc7c5dd0343b8f4837731b3afadf6a77c5/candidates/game_web_region_021_r1/ACCEPTANCE_PLAN.md) | A01–A32 都是未来用例而非实测 | N22 新拟 FUTURE_ACCEPTANCE 仍全部 NOT_RUN |

**精确复制的 N22 Git blobs（无源码修改）：**
- `region_validator.gd` → `6b10b8a305cca07e27080406b8e205985334296b`
- `catalog_recovery.gd` → `f3e9bd6aab7e9965e93b3139a4f66453b816a7b4`
- `synthetic_regions.json` → `2c336868a30f6c247a1a8f04c5d5a5fe5e31bed5`

**未知与非结论：** 以上都是源级证据，不代表现有 GDScript 能成功解析、模拟路线正确、失焦/可访问性真实有效、PR28 的回退在 Godot 实际发生，或 N22 真正完成了产品级集成。这一轮未触碰 #28/#29 或其他 PR。
