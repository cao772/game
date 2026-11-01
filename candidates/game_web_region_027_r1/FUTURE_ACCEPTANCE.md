# FUTURE_ACCEPTANCE｜GAME-WEB-REGION-027 r1

**本文件是未来验收计划，不是执行记录。所有用例当前 NOT_RUN。**

测试输入只用公开 placeholder：
- EVENT_START / SIGNAL_START / FLAG_READY
- EVENT_NEXT / SIGNAL_NEXT / FLAG_READY
- EVENT_END / SIGNAL_END / FLAG_READY
- ACTION_TO_NEXT / ACTION_END / ACTION_FINISH / ACTION_STOP / ACTION_COMPLETE / @ignore

详细数据在 `fixtures/synthetic_acceptance_cases.json`。

| ID | 范围 | 合成操作 | 预期 |
|---|---|---|---|
| R027-01 | 起点 | 打开事件预览但不选择 event | 不自动 begin；显示“请选择起始事件”，observe/choose/navigation 禁用 |
| R027-02 | 起点 | 明确选择 EVENT_START | current=EVENT_START，cursor=0 |
| R027-03 | 起点 fallback | 夹具集合不含 EVENT_START | 不自动选第一个；要求显式选择 |
| R027-04 | observation | 用户输入 SIGNAL_START + FLAG_READY | READY，出现 ACTION_TO_NEXT/ACTION_END/@ignore |
| R027-05 | observation | 用户输入 SIGNAL_WRONG + FLAG_READY | SIGNAL_MISMATCH，分支禁用 |
| R027-06 | observation | 用户输入 SIGNAL_START + 空 conditions | REQUIRED_CONDITIONS_MISSING，missing 包含 FLAG_READY |
| R027-07 | observation | 用户输入 SIGNAL_START + FLAG_READY,FLAG_EXTRA | READY；FLAG_EXTRA 只作 informational |
| R027-08 | observation | 用户输入重复 FLAG_READY 两次 | INVALID_CONDITIONS；snapshot hash/cursor/history 不变 |
| R027-09 | observation | 用户输入小写或非法 signal ID | INVALID_SIGNAL；状态不变 |
| R027-10 | oracle 防护 | 不点击演示样本按钮，只使用手工输入 | 门禁结果仅依赖 caller 输入，不读取 trigger 填充输入字段 |
| R027-11 | branch | EVENT_START 选择 ACTION_TO_NEXT | 进入 EVENT_NEXT；记录 action source、reference source、target definition |
| R027-12 | branch | EVENT_START 选择 ACTION_END | current terminal；后续 choose 为 TERMINAL_LOCKED |
| R027-13 | branch | EVENT_START 选择 @ignore | 仅因字段存在而出现；链接 EVENT_END |
| R027-14 | branch | EVENT_NEXT | 不出现 @ignore，因为 fixture 未提供 on_ignore_event_id |
| R027-15 | branch | EVENT_END | 出现 @ignore，目标 null，语义为 terminal |
| R027-16 | branch | 对当前事件选择不存在的 action ID | UNKNOWN_CHOICE；状态不变 |
| R027-17 | gate per event | 选 ACTION_TO_NEXT 后未给 EVENT_NEXT observation | 不提供 EVENT_NEXT 分支；不能沿用 EVENT_START 的 observation |
| R027-18 | back/redo | choose 到 EVENT_NEXT，back，再 forward | cursor 往返；redo 保留；source trace 不变 |
| R027-19 | branch after back | back 后选择另一分支 | 旧 redo 被截断，新分支追加 |
| R027-20 | rollback | cursor=1 时 rollback 0 | 历史 suffix 清空，cursor=0 |
| R027-21 | rollback | cursor=0 时 rollback 1 | ROLLBACK_FORWARD_FORBIDDEN，状态不变 |
| R027-22 | safe prefix | 修改 EVENT_NEXT observation，且已选择 ACTION_TO_NEXT | 回退到 ACTION_TO_NEXT 之前的安全前缀 |
| R027-23 | safe prefix | 修改未访问 EVENT_END observation | 当前 applied prefix 保留；redo 清除 |
| R027-24 | error | 错误命令字段、多余字段、错误类型 | structured error、原 snapshot hash 保持不变 |
| R027-25 | error source | CONDITIONS_NOT_MET | UI 展示 reason code、source file、JSON pointer；无 line/column 时不伪造 |
| R027-26 | error branch | UNKNOWN_CHOICE | UI 显示允许的 available choices |
| R027-27 | source trace | 选择 ACTION_TO_NEXT | trace 包含 /actions/0、/actions/0/next_event_id、EVENT_NEXT /event_id 来源 |
| R027-28 | duplicate JSON key | 合成 JSON 对象重复 event_id 或嵌套 signal key | 选定的本地 guard/checker 方案拒绝；不得 last-key-wins |
| R027-29 | invalid JSON | UTF-8 错误、语法错误、NaN/Infinity | BLOCKED，错误可追踪，绝不部分加载 |
| R027-30 | reload | 已有 observation/history 后点击 reload | 若 destructive reset：UI 事前明确告知；若 atomic reload：失败保留 stale/read-only snapshot |
| R027-31 | scene failure | event scene missing / wrong type / non-Control root | 保留来源 menu/region route，可返回/重试 |
| R027-32 | fixture failure | 任一固定 fixture 缺失/损坏/引用未知 | event page BLOCKED；outer Back 仍可用；不 fallback 到区域数据 |
| R027-33 | region preservation | 从 region 打开 event 后 Back | 同一 region instance 恢复；位置/claim/inspect/undo 状态保持 |
| R027-34 | region isolation | event 内切换 event/branch/rollback | region 业务状态不变；无 A/B/C→EVENT 映射 |
| R027-35 | region focus | region grid 有焦点时打开 event | grid focus 释放；event 控件可聚焦；Back 后焦点落在 region event entry button |
| R027-36 | hidden input | event 页显示时按方向键/WASD/Enter | hidden region 不执行 GUI grid 操作；窗口 focus notification 不改业务状态 |
| R027-37 | return menu | event 来自 region，选择 Return to menu | event 与 region instance 销毁，route=menu/home |
| R027-38 | return menu | event 来自 menu/status，Back | 返回原菜单页；临时 event session 销毁 |
| R027-39 | re-entry | 退出 event 后重新打开 | 新 session；旧 observation/history 不残留 |
| R027-40 | hash contract | 两实现对同一 fixtures 计算 source/state hash | 先记录 canonical spec；未定义互通前不要求 hash 相等，只要求各自 deterministic |
| R027-41 | source boundary | 与 PR #18 同一固定 fixture 对照 | 对比 gate/choices/navigation/error semantics；列出差异，不以 UI 文案相似判定等价 |
| R027-42 | isolation | 审核 Git diff | 新 PR 仅新增本任务目录；PR #34/#18/#9/#33/main 与共享接口不变 |
| R027-43 | execution record | 执行未来授权的测试 | 每案记录 exact HEAD、Godot/Python 版本、命令、exit code、result、log、fixture SHA256；不能以源码 readback 替代 |

## 验收证据字段

`case_id`、`input_fixture_sha256`、`exact_head`、`expected`、`observed`、`result (PASS|FAIL|BLOCKED|NOT_RUN)`、`error_code`、`snapshot_sha256`、`source_pointer`、`log_ref`、`notes`。

## 停止条件

- UI 自动从 trigger 派生 observation，却标记为 caller/manual input。
- 自动选择 EVENT_START 或自动 fallback 到第一个 event。
- 缺少/重复/无效 observation 仍可选分支。
- branch trace 丢失 source reference 或 target definition。
- rejected command 改变 history/cursor/observation。
- hidden region 接收事件页期间的 GUI 操作。
- 返回 event origin 后创建新 region 而非恢复原实例。
- 以 N26 local guard 冒充 PR #9 checker PASS。
- 将 GDScript snapshot hash 宣称与 PR #18 Python hash 等价但未冻结 canonical spec。

**当前所有 43 项均 NOT_RUN。**
