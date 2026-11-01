# GAME-WEB-REGION-021 r1｜PR #25–#28 静态集成设计及风险报告

**独立文档候选 · NOT_RUN · 仅公开合成 A/B/C · 不批准合并或接口修改**

本目录是对四份**仍为 Draft 的独立 GitHub PR**所做的源文件级交接分析，**不是**第四套运行项目，也没有改写任何现有代码。输入仅限公开仓库 `cao772/game` 中 #25–#28 的公开源码和说明；不含真实场景、人物、地点、小说、私人原稿、聊天记录或未公开设定。事实、静态推断和未来设计选择分别标记为 **[源]**、**[静态风险/推断]** 和 **[N21 建议]**。

## 本轮实际读取的固定源码快照

| PR | 当前候选作用（源） | 固定 HEAD / 状态 | 文件数 |
| --- | --- | --- | --- |
| [#25](https://github.com/cao772/game/pull/25) | 017：A/B/C 遮挡、四向网格寻路、显式本地记录更正 | `8372c1fe5f6471ec6af788b65b68fa54fe7db65a`，Draft/Open | 10 |
| [#26](https://github.com/cao772/game/pull/26) | 018：文字替代、键盘/焦点、字体/动效、撤销 | `cd15ec7bc04cceb388f5174b3d8e83e620a23205`，Draft/Open | 11 |
| [#27](https://github.com/cao772/game/pull/27) | 019：只读状态导览、固定/清除证据卡、下一步提示 | `fdbb6688d07a6a7cebe36b999b82482987362499`，Draft/Open | 11 |
| [#28](https://github.com/cao772/game/pull/28) | 020：输入结构诊断、错误路径与修复建议、合成回退 | `6eb7ee2f889305ec1211441c7848637bc1c551c1`，Draft/Open | 13 |

四份 PR 的 base 都是 `main` `533b11f50c0d359cd0a5424d5216b0145727699a`，**并非层层堆叠的代码分支**。所有候选都具有独立 `project.godot`、`main.tscn`，在各自项目中引用 `res://...` 根目录脚本；不能未经迁移就拷贝/合并到单个 Godot 工程。**所有四份均 NOT_RUN，本文也 NOT_RUN。** 详细证据见 [SOURCE_LEDGER.md](SOURCE_LEDGER.md)。

## 本次文档（无实现代码）

| 文件 | 作用 |
| --- | --- |
| [SOURCE_LEDGER.md](SOURCE_LEDGER.md) | 固定 GitHub 快照、源码文件路径、精确行号和可追溯来源 |
| [COMPATIBILITY_MATRIX.md](COMPATIBILITY_MATRIX.md) | 数据形状、脚本边界、输入/恢复/诊断、依赖及冲突矩阵 |
| [RISK_REGISTER.md](RISK_REGISTER.md) | 按严重度标注的具体静态源码风险、失败机制、缓解措施和验证门槛 |
| [STAGED_MIGRATION.md](STAGED_MIGRATION.md) | 不碰 `main`/共享接口的分阶段候选迁移与回滚策略 |
| [ACCEPTANCE_PLAN.md](ACCEPTANCE_PLAN.md) | 未来获授权后才可执行的验收案例，逐例均标 NOT_RUN |

## 主要结论（源码支持与谨慎推断）

1. **[源]** 四份 `synthetic_regions.json` 文件的 Git blob 都是 `2c336868a30f6c247a1a8f04c5d5a5fe5e31bed5`，包含相同版本 `public-synthetic-region-017-v1`。**[N21 建议]** 以该固定合成 fixture 作为未来迁移期的对照样本，而**不是**产品主线 schema 承诺。
2. **[源]** #26 和 #27 的 `region_model.gd` Git blob 相同：`48ab256c9755525c3ebfdbf0614a5bef081c132a`；#27 的 `map_view.gd` 也与 #26 相同。#27 不是向 #26 branch 推送更改，而是独立复制/扩展宿主。**[N21 建议]** 未来先整理候选的所有权，再决定是否抽取公共模块。
3. **[源]** #28 的 `catalog_recovery.gd` 是另一个独立的验证/回退入口，不是 #26 `load_catalog()` 的替换实现，代码中两者尚未连接。**[静态风险]** 误以为“#28 已给 #27 接好验证器”会形成无证据的集成声明。
4. **[源]** #25 的直接采样视线与四邻 BFS、#26 的文本/焦点/撤销、#27 的证据卡、#28 的结构诊断分别有不同语义；结构正确并不等于声明 `claimed` 正确、可达或实际安全。
5. **[N21 建议]** 采用“**先锁边界、再只读适配、最后受权验证**”的方案：继续以四个原 PR 为独立审查对象，把真实代码合并、共享脚本和游戏内接入留给后续单独授权的集成窗口。

## 限制与停止线

本任务**没有执行任何** Godot、GDScript/JSON 解析、项目代码、测试、CI、UI、焦点操作、屏幕阅读器或性能测量。行号与哈希来自 GitHub 只读源码检索及 Git diff/文件列表；**Git 提交/PR 成功不意味着软件可运行**。关于 Godot API 兼容性、GDScript 类型推断、真实 UI/无障碍、键盘可达性和算法正确性，只能提出未来检查项目，不能宣称已验证。

仓库范围：本 N21 只新增 `candidates/game_web_region_021_r1/` 内的五份 Markdown 文件及本 README，不复制私有数据、不修改 #25–#28、`main` 或任何共享接口。所有估计工时、数量上限、门槛均为**设计候选**，非实测。
