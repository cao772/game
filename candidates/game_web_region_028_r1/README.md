# GAME-WEB-REGION-028 r1｜合成事件预览修复候选

**INDEPENDENT IMPLEMENTATION · DRAFT · SYNTHETIC DATA ONLY · NOT_RUN**

## 固定输入与隔离

- PR #34 source: \`ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a\`（事件模型 / UI / 三个公开 placeholder fixture）。
- PR #35 audit: \`0272b3a374ca2d3a524caf06cc5c7f52eaea2c49\`（静态审查、差异矩阵、修复候选、43 项未来验收）。
- 新分支从 main \`533b11f50c0d359cd0a5424d5216b0145727699a\` 独立创建；不以 PR #34/#35 为 base，不修改原 PR、main、PR #18/#9/#33 或共享接口。
- 所有输入均为公开合成 EVENT_* / SIGNAL_* / FLAG_* / ACTION_* 夹具；不包含私密内容。

## 本轮实际实现

### 1. 显式起始事件

加载成功只返回 \`FIXTURE_READY_AWAITING_START\`，不选择 EVENT_START，不自动 fallback 到首个 ID，也不调用 begin。操作者从 OptionButton 选择事件，再点击“开始 / 重置为所选起点”。开始前 observe / choose / navigation 全部被 \`START_EVENT_REQUIRED\` 门禁拒绝。

### 2. caller-supplied observation

UI 提供 signal 与 conditions 两个 LineEdit。conditions 以逗号分隔，空输入表达空数组；连续逗号会保留空 token 并由模型拒绝。提交值直接进入 model 的 ID / 重复值校验和 gate 判定。删除原来的 \`expected_observation()\` helper，不从 trigger 自动复制正确答案，也不再提供自动注入“匹配观察值”按钮。

### 3. 三段来源追溯

每个 branch choice 保存：
- \`source\`：被选 action 定义位置；
- \`reference_source\`：\`next_event_id\` 引用位置；
- \`target_definition\`：目标事件的 \`/event_id\` 定义位置（终止目标为 null）。

history 和 trace 均保留这三项；UI 在分支列表与已选路径中显示 file / JSON pointer / SHA256 前缀。Gate reason 与 signal / conditions 要求也显示来源 pointer。

### 4. 安全重载

重载先在局部 staged dictionaries 中读取、解析、结构校验并检查所有跨事件引用。只有全部成功才进入 atomic commit point；成功时替换 fixture 并清空旧 session。存在 session 时 UI 先要求确认。

失败时不清空旧 events / observations / history / cursor；若此前有已提交快照，则将它标记 \`STALE_BLOCKED\` 并锁定为只读，禁止 begin / observe / choose / navigation。首次加载失败则维持 BLOCKED，不生成伪快照。成功重载后 stale 标志清除。

## 来源与校验边界

本地守卫仍只处理三个固定文件、每文件 16 KiB、有限事件/分支/条件；它**不是 PR #9 checker**，没有 duplicate JSON key 感知扫描、SourceIndex 行列定位或 Python CLI 依赖。来源坐标是文件名 + SHA256 + JSON Pointer，不伪造行列号。source/state hash 只作本候选内部摘要，不宣称与 PR #18 Python hash 互通。

## 文件

- \`event_preview_model_candidate.gd\`：显式 start、caller observation、trace provenance、atomic reload / stale read-only。
- \`event_preview_screen.gd\`：显式选择与开始、手动输入、错误/来源展示、安全重载确认。
- \`event_preview_screen.tscn\`、\`project.godot\`：隔离的最小预览工程入口。
- \`fixtures/placeholder_*.json\`：复制 PR #34 指定 HEAD 的公开合成 fixture。
- \`DIFFERENCE_MATRIX.md\`：PR34 / PR35 与 N28 实现差异。
- \`FUTURE_ACCEPTANCE.md\`、\`fixtures/synthetic_acceptance_cases.json\`：未来验收计划和合成数据。

## NOT_RUN

未运行 GDScript、Godot、JSON parser、项目、场景、测试或 CI；没有实测任何控件或故障路径。此次只做源码读取、独立候选编写、Git 提交和源码回读。不要将本 PR 描述为运行通过或已合并。
