# DIFFERENCE_MATRIX｜PR #34 vs PR #18

| 审查维度 | PR #18（Python） | PR #34（GDScript） | 结论 / 风险 |
|---|---|---|---|
| 起始事件 | CLI `--event-id` 必填；`SyntheticPlaySession` 构造时验证该 ID（flow L263-L274；play L52-L69） | UI 自动优先选 EVENT_START，缺失时自动选排序首项，并立即 begin（screen L113-L133） | **行为差异**。自动 fallback 不符合“起点由用户显式选择”的说明；P1 修复。 |
| observation 输入 | caller 必须提供 signal/conditions（play L178-L209） | “匹配观察”按钮从 expected_observation() 读取 trigger 要求并直接提交；负例只改 signal（screen L162-L189） | **行为差异**。UI 自己从 oracle 取答案，无法真正测试 arbitrary caller input / missing conditions；P1 修复。 |
| gate.signal | exact equality | exact equality | 一致。 |
| gate.conditions | 所有 required 条件必须出现；额外 valid conditions 仅 informational（play L82-L103；diag L52-L78） | 同样检查 missing；extra 列出并排序（model L311-L330、L369-L385） | 核心 eligibility 一致；N26 structured mismatch reason 少 required/observed 值。 |
| observation 类型与数量 | signal 符合 ID；conditions 为 0..16 个唯一 ID（play L187-L205） | 同样要求 signal ID，conditions array 0..16、唯一（model L520-L535） | 一致（按静态逻辑）。 |
| action options | actions 按源顺序；只有字段存在才提供 ignore；null 为 terminal（flow L231-L261） | 同样规则（model L275-L301） | 一致。 |
| branch gate | choose 前 gate ready，否则 CONDITIONS_NOT_MET（play L292-L323） | choose 前 gate ready，否则 CONDITIONS_NOT_MET（model L607-L630） | 一致。 |
| branch trace | source + reference_source + target_definition（flow L310-L325） | history/trace 只保留 selected source；未保留 reference_source / target_definition（model L635-L642、snapshot L423-L435） | **可追溯性缺口**；P1 修复。 |
| terminal handling | terminal 后 choose 被拒绝；静态 preview 额外选择也拒绝（flow L291-L297；play L298-L303） | current_event_id 为空时 choose 返回 TERMINAL_LOCKED（model L611-L614） | 一致。 |
| back / forward / jump | cursor 导航，不截断 redo（play L382-L417） | cursor 导航，不截断 redo（model L675-L700） | 一致。 |
| choose after back | 截断 redo 再追加新分支（play L329-L347） | 截断 redo 再追加新分支（model L633-L650） | 一致。 |
| rollback | 仅允许 0..current cursor，截断全部 suffix（play L349-L380） | 同样禁止前进并截断 suffix（model L652-L673） | 一致。 |
| changed observation | 找到首次从该 event 出发的 applied step，保留之前 safe prefix；否则清 redo（play L217-L252；diag L113-L122） | 同样从 cursor 前 history 查找并截断（model L542-L573） | 一致（按静态逻辑）。 |
| rejected command | changed=false，返回原 snapshot + structured error view（play L149-L163） | changed=false，返回 snapshot + 简化 error_view（model L493-L506） | 状态不变原则一致；错误信息完整度不同。 |
| error presentation | category/title/suggestion/related_sources/cursor/hash（diag L193-L230） | code/message/suggestion/cursor/hash；部分 code 专属提示，其余 generic（model L467-L490） | **诊断缩水**；P1 修复。 |
| UI error details | CLI text/JSON 输出包含 error 与 related source（play L430-L538） | UI 只显示 code/message/suggestion（screen L145-L159） | **可操作诊断缺口**；P1 修复。 |
| source validation | 复用 PR #9 checker + SourceIndex；duplicate keys、strict UTF-8、symlink/目录选择、line/column（flow L96-L204；PR9 checker L31-L45、L282-L397） | 固定三文件、本地 JSON parse、16 KiB、ID/结构/reference；无 duplicate key-aware parser 和 line/column（model L6-L16、L150-L227） | **刻意窄化但不等价**；必须保持显式声明。 |
| source provenance | file/hash/pointer/line-column；trace 有 target definition（flow L84-L90、L310-L325） | file/hash/pointer；trace 少 target/reference pointer（model L265-L273、L635-L642） | 需要补齐 trace，不应声称 SourceIndex 等价。 |
| source snapshot hash | Python sorted compact JSON、ensure_ascii=True（flow L69-L73、L196-L204） | Godot JSON.stringify sort_keys（model L38-L40、L209-L217） | 需定义是否要求跨语言相同；目前不应比较/宣称一致。 |
| state hash | Python compact sorted JSON fingerprint（play L33-L37、L146） | Godot JSON.stringify fingerprint；snapshot schema 本身不同且没有 trace_sha256（model L416-L465） | **不具备 parity 依据**；只可视为各自实现内部摘要。 |
| reload failure | CLI 每次构造新 checked/session；没有 UI 中覆盖旧 session 的 reload 按钮 | load_fixed_fixtures 先清空旧 model，再尝试 staged load；失败后旧 observation/history 已丢（model L150-L159、L77-L93） | P2：明确这是 destructive reset，或 staged success 后再替换。 |
| menu / region | PR #18 是 CLI，无菜单/区域 UI 生命周期 | N26 coordinator 独立持有 route；region 隐藏保留，event 独立挂载（menu L209-L253、L273-L290） | 不是等价功能；N26 自己的生命周期设计静态合理，需未来场景验收。 |
| region keyboard/focus | 无对应 UI | region 打开 event 前释放 region 子树 GUI focus；返回焦点到区域事件入口按钮（menu L237-L253、L277-L284） | 不恢复原 grid focus；属于显式焦点策略，未来需键盘验收。 |

## 风险分级

- **P1 / 输入真实性**：自动默认起点 + 从 trigger 自取 expected observation，容易让演示变成自证通过。
- **P1 / 诊断与追溯**：branch reference/target provenance 丢失；UI 隐藏结构化错误与 source pointer。
- **P1 / checker 边界**：本地 parser 未覆盖 PR #9 duplicate JSON key 检查；必须不宣称等价。
- **P2 / 恢复体验**：reload 失败会清空原 session；需要确认/命名或原子替换。
- **P2 / 跨语言摘要**：source/state hash 的 canonicalization 和 schema 不同，不能用于跨实现一致性判定。
- **P2 / 生命周期实测**：隐藏 region 的 GUI input、window notification、focus 恢复和 event scene failure recovery 未运行验证。

## 总体判定

PR #34 的模型层核心 gate、branch、redo、rollback、安全前缀逻辑与 PR #18 公开候选语义基本一致；不应把这结论扩展为完整实现等价。当前最需要修复的是 UI 输入真实性、起始事件显式选择、branch provenance 和 error/source 展示。
