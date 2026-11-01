# REPAIR_CANDIDATE｜GAME-WEB-REGION-027 r1

**独立提案，不应用于 PR #34，也不改变任何现有接口。所有代码片段仅为待作者确认的修复方向；NOT_RUN。**

## R1｜P1：起始事件必须由用户明确选择

**现状：** `event_preview_screen.gd` L113-L133 在加载后自动选 `EVENT_START`；若不存在则自动选排序第一个 ID，并调用 `begin()`。PR #18 的 `preview()` 要求调用方提供 start_event_id（flow L263-L274），`SyntheticPlaySession` 构造时验证（play L52-L69）。

**建议：**
- 加入独立的 `_session_started` 状态，不把“固定夹具已加载”与“用户已选起点”混为一谈。
- 加载后仅填充 picker，不自动选择、不调用 begin；显示“请选择起始事件”。
- 用户主动选择后才 begin；取消选择/重新加载时回到未开始状态。
- 不使用“找不到 EVENT_START 就取第一项”的静默 fallback。

**建议状态：** `fixtures_loaded=true, session_started=false` 与 `fixtures_loaded=true, session_started=true` 分离。没有 session 时禁用 observe/choose/navigation。

## R2｜P1：真正 caller-supplied observation

**现状：** screen L162-L174 通过 `expected_observation(event_id)` 从被测 trigger 直接拿正确 signal 和 conditions，再提交 observe。L177-L189 只提供错误 signal 负例。模型 L255-L262 暴露 expected trigger，造成 UI 正例从 oracle 直接取答案。

**建议：**
- 新增 `LineEdit`：signal。
- 新增 `LineEdit`：conditions（逗号分隔，允许空串表示空数组；模型仍负责 0..16 唯一 ID 校验）。
- 增加“提交合成观察值”按钮，读取用户实际输入，不从 trigger 自动补齐。
- 原正例按钮如保留，必须命名为“载入夹具匹配演示样本”，且在 UI 上标记该样本由 fixture trigger 派生；不得称“手动输入”。
- 保留 mismatch 演示按钮，并新增缺条件样本。

建议交互示意（不是已写入 PR #34 的代码）：

```gdscript
var conditions: Array = []
var raw_conditions := _conditions_input.text.strip_edges()
if not raw_conditions.is_empty():
    for item in raw_conditions.split(","):
        conditions.append(item.strip_edges())
_apply({
    "op": "observe",
    "event_id": _model.current_event_id(),
    "signal": _signal_input.text.strip_edges(),
    "conditions": conditions,
})
```

模型 `_set_observation` 继续作为唯一验证入口；UI 不预先判断 signal/conditions 是否正确。

## R3｜P1：补齐分支来源追溯

**现状：** `_options_for` 已有 `reference_source`（model L275-L301），但 choose 写入 history 时只存 `source`（L635-L642）；snapshot trace 也只输出 `selected_at`（L423-L435）。PR #18 flow L310-L325 同时记录 `selected_at`、`reference_at` 和 `target_definition`。

**建议：**
- choose 时把 `selected["reference_source"]` 复制到 history。
- 对非 null target，在 history 保存 `_source_at(target_id, "/event_id")`。
- trace 增加 `reference_at` 和 `target_definition`，终止目标两者分别为 reference pointer 与 null definition。
- 维持当前 source SHA 与 JSON pointer；不要伪造 line/column。

## R4｜P1：错误详情与 gate source 在 UI 可见

**现状：** model L467-L490 的 error_view 没有 PR #18 的 category/title/related_sources；screen L145-L159 只显示 code/message/suggestion；screen L248-L258 只显示 reason codes/next step，没有逐条展示 reason.source。

**建议：**
- model 的 signal mismatch reason 增加 `required` / `observed`。
- error_view 加入 `category`、`title`、`related_sources`；对于 CONDITIONS_NOT_MET 从 gate diagnostics 提取 file/hash/pointer。
- UI 展示 `error.details` 中的 `available_choices`、`condition_gate`、`required_fields`；至少保留原始 code/message。
- gate reason 每条显示 reason code + file + JSON pointer；如果无 location，明确写“无行列索引”，不要编造。
- 未知错误仍 fail closed，禁止自动修复。

## R5｜P1：重复 JSON key 的 checker 边界

**现状：** PR #9 checker L31-L45 定义重复 key / 非标准常量处理；L346-L362 用 SourceIndex 拒绝深层重复 JSON key。N26 model L176-L180 直接用 Godot JSON parser，未见 duplicate-key-aware parser。

**建议选项（需要作者决策）：**
1. 保持纯 Godot：增加一个独立、限深度、只读的 JSON lexical pre-scan，检测每层 object 的重复 member；只有 pre-scan 通过才调用 JSON.parse。必须为字符串转义、嵌套对象、数组、unicode escape、重复键提供合成用例。
2. 引入 checker 预检：仅在明确批准 Python 3.12+ 本地依赖后，调用 PR #9 checker 的只读模式；这会改变部署依赖，不能静默加入。

未选定方案前，继续明确写“不是 PR #9 checker”，不宣称 duplicate-key 等价。

## R6｜P2：reload 语义明确

**现状：** model L150-L159 在读取前清空当前 event、observations、history、cursor；失败时 `_fail` 再次清空。UI L85 和 L113 提供“重新读取固定事件夹具”按钮，但未提示会丢弃当前预览 session。

**建议二选一：**
- 最小改动：按钮改为“清空当前预览并重新读取”，并在 notice 中明确 observations/history 将重置。
- 更稳健：在局部 staged dictionary 中完成所有检查，成功后一次性替换当前模型；失败时保留旧 snapshot 但标记为 stale/read-only，禁止继续选择，避免误以为旧数据是最新 fixture。

## R7｜P2：hash 定义明确

PR #18 flow L69-L73 / play L33-L37 使用 Python sorted compact JSON、ensure_ascii=True。PR #34 model L38-L40 使用 Godot JSON.stringify；且 N26 snapshot schema 与 PR #18 不同（缺少 trace_sha256，trace provenance 不全）。建议：
- 当前字段命名继续保持实现内摘要；不声称跨语言 hash 相等。
- 若将来要求互通，先冻结 canonical JSON 编码、Unicode escaping、number formatting、字段集合和 hash input；再用同一公开 fixture 做逐字节对照。
- 不要仅因为两个 SHA256 字符串不同就判业务逻辑失败。

## R8｜菜单/区域生命周期

静态检查未发现必须立即改动的状态所有权错误：
- menu coordinator 唯一拥有顶层 route。
- region 来源只传递 `origin_route`；不传区域 snapshot/target/gateway。
- 返回 region 恢复同一实例，返回 menu 清理实例。
- region GUI focus 在 event 打开前释放，返回时聚焦 region 外层入口按钮。

建议暂不加暂停/恢复私有 region 处理的代码，以免与 PR #33 的窗口焦点 release gate 冲突。未来验收确认 hidden region 不接收 GUI input、window focus notification 不改变区域业务状态即可。

## 独立性约束

本提案只属于 GAME-WEB-REGION-027 新目录。任何修复若未来被作者采纳，应另开实现任务；不得直接修改 PR #34、PR #18、PR #9、PR #33、main 或共享接口。
