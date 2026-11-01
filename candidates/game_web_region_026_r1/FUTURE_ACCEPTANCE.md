# FUTURE_ACCEPTANCE｜GAME-WEB-REGION-026 r1

**当前所有案例均为 NOT_RUN。** 没有执行 Godot、GDScript、Python、CLI、JSON 解析器、自动化测试、CI 或 GUI 操作。下面是未来授权后才可执行的验收计划，不是本轮 PASS 记录。

| ID | 未来操作 | 预期 / 必须记录 |
| --- | --- | --- |
| S01 | 将 N26 子目录单独作为 Godot 工程根导入 | main、menu、region、event 场景与全部依赖可解析；否则 BLOCKED |
| S02 | 核对 Git diff | 所有新增文件只在 `candidates/game_web_region_026_r1/`；0 修改/删除 main、PR18、PR33 或共享接口 |
| S03 | 比对 9 个区域文件 Git blob | 与 PR #33 HEAD 指定 blob 完全相同 |
| S04 | 比对 3 个事件 fixture Git blob | 与 PR #18 HEAD 指定 blob 完全相同 |
| M01 | menu/home 直接打开 event preview | event 页面成功挂载；起始 event ID 显式可选 |
| M02 | 从 menu/status 打开 event 后 Back | 返回 status，不丢菜单模拟状态 |
| M03 | 从 menu/home 进入 region，再打开 event | region holder 隐藏但 region 实例保持挂载 |
| M04 | 从 event Back to origin（来源 region） | 恢复同一个 region 实例；区域位置/claim/inspect/undo 状态未被事件页读取或改变 |
| M05 | 从 event Return to menu（来源 region） | event 与 region 两个实例销毁，回 menu/home |
| M06 | 从 event Return to menu（来源 menu/status） | event 销毁，回 menu/home；无残留事件 session |
| M07 | event 返回后再次进入 event | 新 event model、无旧 observation/history |
| M08 | 区域 A/B/C 分别操作后进入 event | event 起点仍由 event picker 选择；不得自动映射 A/B/C 到 event ID |
| E01 | 固定 fixture 全部有效时读取 | 本地守卫仅接受三份固定文件；显示 source SHA 与 JSON pointer，不声称 PR #9 PASS |
| E02 | EVENT_START 未注入 observation 时尝试选择 | gate BLOCKED，所有分支禁用，reason OBSERVATION_NOT_SUPPLIED |
| E03 | 手动注入 EVENT_START 的匹配 signal/FLAG_READY | 当前 gate READY，展示 ACTION_TO_NEXT、ACTION_END、@ignore |
| E04 | 注入错误 signal | SIGNAL_MISMATCH；无分支可选，错误不改变路径 |
| E05 | 注入缺少 FLAG_READY 的 conditions | REQUIRED_CONDITIONS_MISSING；不自动补齐 |
| E06 | 选择 ACTION_TO_NEXT | 只进入 EVENT_NEXT 预览位置；EVENT_NEXT 需要单独的手动 observation |
| E07 | 在 EVENT_NEXT 查看分支 | 显示 ACTION_FINISH/ACTION_STOP；不显示未定义的 @ignore |
| E08 | 选择 ACTION_END 或 EVENT_NEXT 的 ACTION_STOP | 当前变为终止；不能再 choose；back/rollback 可返回 |
| E09 | EVENT_START 选择 @ignore | 只沿 fixture 显式引用进入 EVENT_END；无其他语义推断 |
| E10 | EVENT_END 查看 ignore | 因 on_ignore_event_id 字段存在且为 null，展示 @ignore→terminal |
| E11 | 未观察 EVENT_NEXT 就尝试 choose | CONDITIONS_NOT_MET，状态 hash/游标/路径不变 |
| E12 | 对未配置 action_id 发起选择 | UNKNOWN_CHOICE；不创建虚构分支 |
| E13 | Back 后 Forward | redo 保留，快照回到原已记录位置 |
| E14 | Back 后选择另一分支 | 原 redo 后缀被截断，新的分支追加 |
| E15 | rollback 到当前或更早 cursor | 截断 suffix；rollback 到未来 cursor 必须拒绝 |
| E16 | 修改已应用路径中某事件的 observation | 从该事件首次依赖步骤前保留安全前缀，受影响 suffix 丢弃 |
| E17 | 修改只出现在 redo 或未访问事件的 observation | 当前 active prefix 保留，redo 丢弃 |
| E18 | 重复注入完全相同 observation | no-op，不改变 snapshot |
| E19 | 发出字段多余/缺失、错误类型、负 cursor 或超限命令 | REJECTED、source_state_changed=false、auto_repair=false |
| E20 | 尝试超过 24 个显式选择步骤 | STEP_LIMIT；没有自动循环或重放 |
| E21 | 对 snapshot/observations 返回副本进行外部改写 | 内部 model 不受调用方修改影响 |
| F01 | 隔离副本移除 event_preview_screen.tscn | 从 menu/region 打开事件被拒绝，来源 route 不变 |
| F02 | 将 event scene 根节点改为非 Control | 拒绝挂载，释放临时节点，来源 route 不变 |
| F03 | 删除任一固定 event JSON | event UI BLOCKED，分支禁用，外层 Back 可用 |
| F04 | 损坏 JSON / UTF-8 / schema / event ID / reference | BLOCKED，不换目录、不回退到 region 数据 |
| F05 | 在 EVENT_START fixture 引用一个不存在 event ID | local guard 拒绝整个目录，不给部分分支 |
| F06 | fixture 修复后点击“重新读取固定事件夹具” | 只重新初始化 event preview model；不改变 region/menu |
| F07 | 删除必需 GDScript | 记录 Godot import/parse BLOCKED，不冒充 UI 恢复 |
| F08 | region Gateway 自身显示 FALLBACK/BLOCKED 时打开 event | event preview 仍只读自己的 fixtures；外层 Back 可返回 |
| K01 | 仅键盘 menu→event→menu | Tab/Shift+Tab/Enter/Space 路径明确，焦点不被自动抢占 |
| K02 | 仅键盘 region→event→region | 事件返回后 region 焦点/键盘网格状态符合预期，无残留输入 |
| B01 | 检查公开数据与 UI | 仅 synthetic EVENT_* 与 A/B/C fixtures，无私人内容、故事或真实地点 |
| B02 | 对照 PR #18 Python preview | 在未来授权、同时具备 PR #18 + PR #9 checker 的环境中，对同一固定 fixture 比较可选分支、门禁、back/redo/rollback、安全前缀；差异逐项记录，不预设等价 |
| B03 | 复查 GitHub 状态 | PR18/PR33/main 未变；N26 Draft；不合并 main |
| B04 | 审计本任务执行证据 | 无 Godot、代码执行、Python CLI、解析器、测试或 CI；全部保持 NOT_RUN |

## 未来证据字段

`case_id`、`exact_head`、`Godot_version`、`OS`、`expected`、`observed`、`result (PASS|FAIL|BLOCKED|NOT_RUN)`、`logs`、`fixture_SHA256`、`notes`。PR #18 对照必须另记录 PR #9 checker exact SHA、Python 版本、完整命令/退出码和差异。

**停止条件：** 从 A/B/C 自动推断 event ID；事件页改动区域状态；错误后自动选分支/自动补条件；返回后残留 event session；将 N26 本地守卫称为 PR #9 checker PASS；将 GDScript 适配器称为 PR #18 Python 实现；修改私有/共享接口或 main。当前所有案例 NOT_RUN。
