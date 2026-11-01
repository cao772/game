# SOURCE_AUDIT｜GAME-WEB-REGION-027 r1

**审查类型：只读静态源码审查。所有结论以固定 HEAD 的可见源码为依据；NOT_RUN。**

## 1. 固定版本与依赖关系

- PR #34：`ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a`，Draft / Open，base main `533b11f50c0d359cd0a5424d5216b0145727699a`。
- PR #18：`31bee7fa4a130186c6b889b918712fafa2de84c8`，Draft / Open，base `codex/game-web-module-event-001-r1`，base commit `cfd28c5cd30a3c4c163abfde7a3eb9ebcd23eb50`。
- PR #18 的 `event_flow_preview_candidate.py` / `event_play_preview_candidate.py` 依赖 stacked base 中的 PR #9 checker 与 SourceIndex。PR #34 没有调用 Python CLI，而是用 GDScript 对三份固定 fixture 做窄范围重新表达。

## 2. PR #34｜事件模型

| 行号 | 静态观察 |
|---|---|
| [L6-L16](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_model_candidate.gd#L6-L16) | 只读三个固定 `res://fixtures/placeholder_*.json`；单文件 16 KiB、最多 16 events/actions/conditions、24 次选择。 |
| [L29-L67](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_model_candidate.gd#L29-L67) | SHA256、JSON stringify canonical helper、ID 与精确字段检查。 |
| [L96-L147](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_model_candidate.gd#L96-L147) | 检查 event/trigger/actions/on_ignore 字段、ID、数量、重复 action/condition；没有重复 JSON key 级别的 parser 检查。 |
| [L150-L227](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_model_candidate.gd#L150-L227) | 加载固定三文件，验证 UTF-8/JSON/结构/ID/引用；加载前先清空当前 session，失败由 `_fail` 清空并 BLOCKED。 |
| [L255-L262](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_model_candidate.gd#L255-L262) | `expected_observation(event_id)` 直接从 trigger 返回要求值；这本身是演示便利函数，UI 后续将其当作“手动注入”来源。 |
| [L275-L301](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_model_candidate.gd#L275-L301) | actions 原样成为选项；只有字段存在才加 `@ignore`；null 为 terminal；保留 source/reference_source 元数据。 |
| [L304-L330](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_model_candidate.gd#L304-L330) | 门禁：必须有 observation Dictionary、signal 精确相等、required conditions 全部出现。 |
| [L333-L385](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_model_candidate.gd#L333-L385) | 生成未提供/信号不匹配/缺条件/未知阻断原因；reason source 有 file/hash/pointer，但 signal mismatch reason 未附 required/observed 值。 |
| [L388-L415](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_model_candidate.gd#L388-L415) | breadcrumbs 保留 selected prefix 与 redo，rollback 范围为 0..cursor。 |
| [L416-L465](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_model_candidate.gd#L416-L465) | snapshot 只把已应用前缀放入 selected_path/trace；state hash 由 GDScript JSON stringify 计算；未输出 PR #18 的 trace_sha256。 |
| [L467-L517](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_model_candidate.gd#L467-L517) | rejected 返回 changed=false 与旧 snapshot；error_view 只含 code/message/suggestion/cursor/hash 和安全标志，未实现 PR #18 的 category/title/related_sources。 |
| [L520-L574](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_model_candidate.gd#L520-L574) | observation 验证、重复输入 no-op、首次受影响步骤前安全前缀回退、否则清除 redo。 |
| [L576-L700](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_model_candidate.gd#L576-L700) | 命令字段精确校验；choose 先 gate 后 branch；rollback 禁止向前；back/forward/jump 不截断历史。 |
| [L703-L711](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_model_candidate.gd#L703-L711) | 公开加载状态与当前 event source helper。 |

## 3. PR #34｜事件 UI

| 行号 | 静态观察 |
|---|---|
| [L60-L110](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_screen.gd#L60-L110) | 构建事件下拉、匹配/错误 signal 按钮、清除观察、分支和导航按钮；没有可编辑 signal/conditions 输入控件。 |
| [L113-L133](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_screen.gd#L113-L133) | 加载后自动优先选 `EVENT_START`，否则选排序后第一个 ID，并立即 `begin()`；与 PR #18 必须传入 `--event-id` 的显式起点流程不同。 |
| [L136-L143](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_screen.gd#L136-L143) | 用户更改 picker 后重置起点、观察和历史。 |
| [L145-L159](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_screen.gd#L145-L159) | UI 仅显示 error code/message/suggestion；没有显示 error 的结构化 details、related source pointer 或 snapshot hash。 |
| [L162-L190](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_screen.gd#L162-L190) | “手动注入匹配观察值”调用 `expected_observation()`，从被测 trigger 直接读取正确 signal/conditions；负例只固定改错 signal，无法输入缺条件/额外条件/任意 observation。 |
| [L192-L212](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_screen.gd#L192-L212) | 清除 observation、choose、back/forward/rollback 都通过 model 命令接口。 |
| [L215-L258](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_screen.gd#L215-L258) | 显示 gate 状态和缺少条件，但 reason 只显示 code 与 next step；没有显示 reason 自带 source file/pointer。 |
| [L260-L292](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/event_preview_screen.gd#L260-L292) | 选项只有 available 时可点；back/forward/rollback 按 cursor/history 状态启用；路径显示 selected/redo。 |

## 4. PR #34｜菜单与区域生命周期

| 行号 | 静态观察 |
|---|---|
| [L16-L44](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/menu_flow_owner.gd#L16-L44) | 菜单 coordinator 单独持有 route、来源页、availability 与 region/event instance 引用。 |
| [L152-L198](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/menu_flow_owner.gd#L152-L198) | 进入区域前检查 route/tree/pause/window focus/模拟 availability；加载并实例化成功后才提交 route。 |
| [L209-L253](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/menu_flow_owner.gd#L209-L253) | 事件场景先检查资源并实例化；来源 region 时只读取 GUI focus owner 是否属于 region 子树并释放焦点；事件页只收到 `origin_route` 标签；region 保留挂载但被 holder 隐藏。 |
| [L256-L271](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/menu_flow_owner.gd#L256-L271) | event/region 清理通过 remove_child + queue_free，清空 instance 引用。 |
| [L273-L290](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/menu_flow_owner.gd#L273-L290) | 返回来源时先销毁 event；region 仍有效则恢复同一实例并把焦点给区域事件入口按钮，否则退回 menu。 |
| [L293-L328](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/menu_flow_owner.gd#L293-L328) | region 返回 menu 会销毁 region；event “返回菜单概览”会销毁 event，并在原来源为 region 时销毁 region。 |
| [L340-L360](https://github.com/cao772/game/blob/ecb9c6fcd1928eba8e0a7c071da5a5b413aa065a/candidates/game_web_region_026_r1/menu_flow_owner.gd#L340-L360) | 通过三个 holder 的 visible 切换顶层页面；route 与实例生命周期由同一个 coordinator 控制。 |

### PR #33 区域隐藏时的输入/处理依据

N26 复制的区域脚本与 PR #33 固定 HEAD 相同 blob：
- `accessible_demo.gd` L37 在 ready 时关闭常规 process；L266-L284 的 process 仅在窗口焦点丢失时等待移动键释放并更新焦点说明。
- `keyboard_grid.gd` L42 使用 `_gui_input`，未发现 `_input` / `_unhandled_input` 全局键盘分发。
- 静态搜索没有发现区域脚本把事件预览结果写入区域状态的入口。

因此隐藏 region 的持续处理风险偏低，但 window notification / focus / input 的实际行为仍需 Godot 验收；不能只凭 `visible=false` 认定所有 process 自动暂停。

## 5. PR #18｜Python 预览实现

| 行号 | 静态观察 |
|---|---|
| [event_flow_preview_candidate.py L69-L90](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_flow_preview_candidate.py#L69-L90) | canonical SHA 使用 `json.dumps(sort_keys=True, ensure_ascii=True, separators=(',', ':'))`；EventSource location 返回 file/hash/pointer/line-column。 |
| [L96-L204](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_flow_preview_candidate.py#L96-L204) | 显式输入路径收集；受 PR #9 checker 检查；校验前后字节一致；UTF-8、重复 key、source index；建立固定输入快照。 |
| [L209-L229](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_flow_preview_candidate.py#L209-L229) | 通过 `requirements_for` 返回 signal/conditions 与各自来源。 |
| [L231-L261](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_flow_preview_candidate.py#L231-L261) | 分支与 ignore 规则；保留 branch source 与 reference source。 |
| [L263-L353](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_flow_preview_candidate.py#L263-L353) | `preview(start_event_id, choices)` 要求显式起点；分支只能从当前 checked event 提供的选项中选择；记录 selected/reference/target definition；terminal 后额外选择被拒绝。 |
| [event_play_preview_candidate.py L33-L37](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_play_preview_candidate.py#L33-L37) | state fingerprint 使用 Python compact sorted JSON。 |
| [L52-L103](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_play_preview_candidate.py#L52-L103) | session 要求 caller 提供 start event；observation 存储独立于事件状态；signal 精确匹配且 required conditions 不缺。 |
| [L105-L147](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_play_preview_candidate.py#L105-L147) | snapshot 包含 detached history、condition diagnostics、breadcrumbs、trace_sha256、no_persistence。 |
| [L149-L176](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_play_preview_candidate.py#L149-L176) | rejected 返回完全未变 snapshot；accepted 统一生成 snapshot。 |
| [L178-L253](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_play_preview_candidate.py#L178-L253) | observation 由 caller 输入；重复输入 no-op；变更已应用 event 时回退首个受影响步骤前；只影响 redo/unvisited 时清 redo。 |
| [L254-L347](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_play_preview_candidate.py#L254-L347) | 严格命令字段；choose 先 gate 后 branch；terminal、unknown branch、step limit 拒绝。 |
| [L349-L417](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_play_preview_candidate.py#L349-L417) | rollback 不前进；back/forward/jump 只移动 cursor，保留 redo。 |
| [event_preview_diagnostics_006_candidate.py L12-L78](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_preview_diagnostics_006_candidate.py#L12-L78) | 诊断未提供 observation、signal mismatch、missing conditions、unknown blocked gate，并提供 reason source。 |
| [L81-L122](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_preview_diagnostics_006_candidate.py#L81-L122) | detached breadcrumbs 与 first changed step 定位。 |
| [L125-L230](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_preview_diagnostics_006_candidate.py#L125-L230) | error category/title/suggestion/related_sources/cursor/hash，禁止自动修复。 |

## 6. PR #9 checker 的相关事实（PR #18 的上游依赖）

PR #18 README/integration 明确说明其 checked preview 依赖 PR #9。审查 PR #9 base commit `cfd28c5...`：
- `event_data_check_candidate.py` L24-L28：1 MiB/file、最多 1024 files、actions/conditions 各 16。
- L31-L45：duplicate JSON key 和非标准 numeric constant 的拒绝。
- L121-L206：event/trigger/action/on_ignore schema、ID、数量、重复 action/condition、reference 校验。
- L210-L279：显式文件/目录收集、符号链接拒绝、JSON 文件选择与数量限制。
- L282-L397：strict UTF-8、JSON、SourceIndex、重复 JSON key 的精确位置、跨文件引用和 checker report。

PR #34 的 GDScript guard 不能替代这些 checker 保障；它只处理自己固定的三个小型公开 placeholder 文件。此差异在 PR #34 README 中已部分披露。

## 7. 静态审查限制

- 行号针对上述固定 commit；若分支更新，行号需重新核对。
- 只做源码读取、行号提取与逻辑推演；没有解析 GDScript/Python、导入 Godot、执行 CLI、运行测试、启动场景、模拟按键或验证文件系统故障。
- “静态未发现”不等于运行时不存在。
- 不推断 PR #34/PR #18 任何测试、CI 或用户可见运行状态为通过。
