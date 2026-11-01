# GAME-WEB-REGION-027 r1｜PR #34 × PR #18 静态审查与独立修复候选

**STATIC REVIEW ONLY · NOT_RUN · SYNTHETIC DATA ONLY · NO PRIVATE CONTENT · NO EXISTING PR / MAIN / SHARED INTERFACE CHANGES**

## 固定输入版本

| 对象 | 固定版本 | 说明 |
|---|---|---|
| PR #34 | `ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a` | N26 菜单 / 区域 / GDScript 事件预览桥 |
| PR #34 base | `533b11f50c0d359cd0a5424d5216b0145727699a` | main |
| PR #18 | `31bee7fa4a130186c6b889b918712fafa2de84c8` | Python 静态预览 / 条件门禁 / 导航 / 诊断 |
| PR #18 base | `cfd28c5cd30a3c4c163abfde7a3eb9ebcd23eb50` | PR #9 checker/source-indexer 候选 |

PR #34 和 PR #18 在审查时均为 Open / Draft。审查以固定 commit 文件内容为准，不把后续分支变化混入结论。

## 结论摘要

1. **条件门禁核心判定一致**：两边都要求 signal 精确匹配且所有必需 conditions 均出现；额外 condition 不阻断。
2. **分支和终止语义基本一致**：只从配置 actions 生成分支；只有存在 `on_ignore_event_id` 字段才展示 `@ignore`；null 目标为终止；必须显式选择。
3. **回退语义基本一致**：back/forward/jump 保留 redo；rollback 截断后缀且不允许前进；修改已应用路径所依赖的 observation 时保留安全前缀。
4. **发现两项明显 UI 语义偏差**：N26 启动时自动选中并开始 EVENT_START（找不到则自动选第一个）；“手动注入匹配观察值”按钮实际从事件定义自动读取 expected observation，并非用户输入。
5. **诊断与来源追溯缩水**：N26 UI 只显示错误码/消息/建议，不呈现 PR #18 的 related source；N26 trace 缺少 reference source 和 target definition。
6. **本地结构守卫不是 PR #9 checker**：固定三文件、16 KiB 上限、无重复 JSON key 侦测、无精确行列索引；这是明确的实现边界，不应宣称完整 checker parity。
7. **菜单/区域生命周期静态设计合理**：region 来源进入 event 时保留原 region 实例、隐藏 holder、释放区域子树 GUI 焦点；返回来源恢复同一实例；返回菜单显式销毁。仍需未来 Godot 验收隐藏页面输入与焦点恢复。

## 建议修复优先级

- **P1**：改为真正 caller-supplied observation 输入；取消默认起始事件自动选择；补齐分支 provenance；错误 UI 显示结构化 details/source pointer。
- **P1（边界决策）**：duplicate JSON key 检测必须明确：实现 Godot 侧重复键感知扫描器，或经作者批准引入 PR #9 checker 的本地预检依赖。不能静默宣称等价。
- **P2**：把“重新读取”明确标成会清空 session，或调整为 staged/atomic reload；定义 source/state hash 的跨实现兼容契约。
- **保持不改**：不改 main、PR #18、PR #34、PR #9、PR #33 或任何共享接口；本 PR 只提交审查报告、修复提案和合成未来验收材料。

## 交付

- [SOURCE_AUDIT.md](SOURCE_AUDIT.md)：逐文件、逐行审查依据。
- [DIFFERENCE_MATRIX.md](DIFFERENCE_MATRIX.md)：门禁、分支、回退、错误、生命周期和 loader 差异矩阵。
- [REPAIR_CANDIDATE.md](REPAIR_CANDIDATE.md)：独立修复候选与建议改动，不应用到既有 PR。
- [FUTURE_ACCEPTANCE.md](FUTURE_ACCEPTANCE.md)：未来人工/自动验收计划。
- [fixtures/synthetic_acceptance_cases.json](fixtures/synthetic_acceptance_cases.json)：只使用 PR #18 的公开合成 EVENT_* / SIGNAL_* / FLAG_* / ACTION_* 标识符。

**本任务 NOT_RUN。** 只读 GitHub 源码并做静态行号审查；未运行任何项目代码、GDScript、Python、Godot、JSON parser、测试或 CI。此 PR 不修改既有 PR 或 main。
