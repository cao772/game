# FUTURE_ACCEPTANCE｜GAME-WEB-REGION-028 r1

**计划用例，当前全部 NOT_RUN。只允许公开合成 placeholder 数据。**

| ID | 范围 | 输入 / 操作 | 预期 |
|---|---|---|---|
| R028-01 | 起点 | 首次读取成功 | fixture ready，picker 未选中，started=false |
| R028-02 | 起点 | 不选择 event，尝试提交 observation | START_EVENT_REQUIRED；无状态变化 |
| R028-03 | 起点 | 明确选择 EVENT_START 但不点开始 | current event 仍为空，started=false |
| R028-04 | 起点 | 选择 EVENT_START 并点击开始 | current=EVENT_START，cursor=0 |
| R028-05 | fallback | 固定夹具缺少 EVENT_START | 不自动选其他事件；由操作者选择现有 ID |
| R028-06 | observation | 手动输入 SIGNAL_START + FLAG_READY | gate READY；展示 EVENT_START 的三个配置选项 |
| R028-07 | observation | 输入 SIGNAL_WRONG + FLAG_READY | SIGNAL_MISMATCH；分支禁用 |
| R028-08 | observation | 输入 SIGNAL_START + 空 conditions | REQUIRED_CONDITIONS_MISSING；缺少 FLAG_READY |
| R028-09 | observation | 输入 SIGNAL_START + FLAG_EXTRA,FLAG_READY | gate READY；FLAG_EXTRA informational |
| R028-10 | observation | 输入 FLAG_READY,FLAG_READY | INVALID_CONDITIONS；观察值与 history 不变 |
| R028-11 | observation | 输入 FLAG_READY,,FLAG_EXTRA | 空 token 被保留并拒绝，不静默过滤 |
| R028-12 | observation | signal 输入小写或非法字符 | INVALID_SIGNAL；状态不变 |
| R028-13 | observation | 切换至 EVENT_NEXT 后不提交新 observation | 不沿用 EVENT_START 的观察值；gate blocked |
| R028-14 | branch | EVENT_START 选择 ACTION_TO_NEXT | 进入 EVENT_NEXT；记录 action/ref/target definition 来源 |
| R028-15 | branch | EVENT_START 选择 ACTION_END | terminal；后续 choose 被 TERMINAL_LOCKED 拒绝 |
| R028-16 | branch | EVENT_START 选择 @ignore | 仅因 on_ignore_event_id 字段存在而展示；target=EVENT_END |
| R028-17 | provenance | 选择 ACTION_TO_NEXT | source=/actions/0，reference=/actions/0/next_event_id，target=/event_id |
| R028-18 | provenance | 选择 null 目标 ACTION_END | source/ref 存在；target_definition=null |
| R028-19 | navigation | choose 后 back 再 forward | cursor 变化；redo 与 provenance 保留 |
| R028-20 | navigation | back 后选择另一分支 | 原 redo suffix 被截断；新分支来源完整 |
| R028-21 | reload confirm | 有 observation/history 时点击 reload | 先出现确认框；取消不改变任何状态 |
| R028-22 | reload success | 确认重载且所有 fixture 有效 | 原子替换成功；session 清空；started=false；要求重新选起点 |
| R028-23 | reload failure | 一个 fixture 缺失或 JSON 损坏 | 旧 snapshot/history 保留；stale=true；所有修改控件禁用 |
| R028-24 | stale guard | stale 后调用 begin/observe/choose/back/forward | 全部拒绝；旧 snapshot hash 与 history 不变 |
| R028-25 | recovery | 修复 fixture 后再次成功 reload | stale 清除；新 fixture commit；旧 session 不恢复 |
| R028-26 | first-load failure | 首次加载失败，无旧 snapshot | BLOCKED；无事件、无起点、无可选分支 |
| R028-27 | source gate | CONDITIONS_NOT_MET | UI 显示 reason code、fixture file、JSON pointer、SHA256 |
| R028-28 | source trace | trace 已有分支 | UI 同时显示 action source、reference source、target definition |
| R028-29 | duplicate key boundary | JSON 对象含重复 event_id | 当前 local guard 不得宣称 PR9 checker PASS；若未来增加 scanner 再验收拒绝行为 |
| R028-30 | isolation | 检查 Git diff | 只新增 candidates/game_web_region_028_r1；PR34/PR35/main/共享接口不变 |

## 未来证据字段

\`case_id\`、\`exact_head\`、\`fixture_sha256\`、\`input\`、\`expected\`、\`observed\`、\`result\`、\`error_code\`、\`before_snapshot_sha256\`、\`after_snapshot_sha256\`、\`source_pointer\`、\`log_ref\`。

## 停止条件

- 夹具加载后自动开始或静默选择首个事件。
- observation 输入由 trigger 自动填充或隐藏地补齐。
- 缺条件 / 错误 signal / 重复条件仍可选分支。
- trace 缺 action source、reference source 或 target definition。
- reload 失败覆盖或清空旧 session。
- stale 状态仍允许修改。
- 以本地守卫冒充 PR #9 checker，或伪造行列号。
- 未运行却记录 PASS。

**所有用例当前 NOT_RUN。**
