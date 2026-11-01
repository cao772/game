# DIFFERENCE_MATRIX｜PR #34 / PR #35 → GAME-WEB-REGION-028

| 维度 | PR #34 ecb9c6f | PR #35 0272b3a 审查结论 | N28 独立实现 |
|---|---|---|---|
| 加载后起点 | UI 自动优先 EVENT_START，缺失时选首个 ID 并 begin（screen L113-L133） | P1：必须显式选择，不允许 fallback | load 只填 picker；不选中、不 begin；独立 Start 按钮调用 begin |
| observation 输入 | “匹配”按钮从 expected_observation() 读取 trigger；负例只改 signal（screen L162-L189） | P1：caller 输入真实性不足 | 两个 LineEdit；signal 原样提交；conditions 逗号拆分；空数组和空 token 分开处理；模型做格式/重复校验 |
| gate | signal 精确匹配 + required conditions 全部存在（model L304-L330） | 核心语义与 PR18 一致 | 保留判定逻辑；additional conditions 仅展示，不阻断 |
| branch provenance | options 有 source/reference_source（model L275-L301），history 只存 source（L635-L642） | P1：reference 与 target definition 丢失 | history/trace 保留 source、reference_source、target_definition |
| UI source | 仅显示当前 event 来源及 SHA（screen L257-L258） | P1：reason / branch source 展示不足 | gate reason 显示 requirement source；每个 branch 显示 action/reference/target 来源 |
| errors | 简化 code/message/suggestion（model L467-L490；screen L145-L159） | P1：缺结构化错误类别与相关来源 | error_view 增加 category/title/details/related_sources；UI 显示来源 |
| reload | 先清空 active state，再读取固定 fixture（model L150-L159） | P2：失败时旧 session 丢失 | stage all → validate all → atomic commit；失败保留旧快照并设 stale/read-only |
| reload UI | 直接点击 reload，无 session reset 确认 | 建议明确 reset / staged atomic | 有 session 时 ConfirmationDialog；成功重载清空 session，失败不覆盖旧状态 |
| stale guard | 无旧快照 stale 模式 | 建议失败后不冒充最新 | stale 时所有修改命令被阻断，页面只读显示旧 snapshot 和失败原因 |
| 起点未选状态 | 无 | 要求显式等待用户动作 | \`not_started\` / \`START_EVENT_REQUIRED\`，observe/choose/nav 禁用 |
| duplicate JSON key | Godot JSON parser 无 duplicate-key-aware guard | PR35 明确不得冒充 PR9 checker | **未解决且显式声明**：本地守卫仍不等价于 PR9 checker |
| line/column | 仅 file/hash/pointer | 不得编造 SourceIndex 定位 | 继续提供 file/hash/JSON pointer，不输出虚构行列号 |
| hash | Godot stringify 摘要 | 不宣称与 Python canonical hash 等价 | 只标记为 N28 内部摘要，不跨语言比较 |
| menu / region | PR34 coordinator 管理实例和路由 | PR35 静态判断合理，运行未验收 | 本轮不改 menu_flow_owner 或任何共享接口；保持独立最小预览工程 |

## 关键安全属性

- 加载完成不自动开始；起点必须由用户明确选定。
- caller observation 不从 trigger 派生；未匹配/缺条件时没有可选分支。
- 失败 reload 不覆盖旧 committed snapshot；旧状态进入只读 stale。
- 成功 reload 才替换数据并 reset session。
- branch trace 保留 action、reference、target definition 三个来源点。
- 不写源 fixture、不持久化、不触发游戏事件。
