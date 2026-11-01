# DESIGN｜N26 独立菜单—区域—事件预览桥

**所有内容为候选设计；源码/运行验证状态 NOT_RUN。**

## 1. 兼容性事实与选择

PR #18 在固定 HEAD `31bee7fa4a130186c6b889b918712fafa2de84c8` 中有三层：
- `event_flow_preview_candidate.py`：经 PR #9 checker PASS 后，读取所选静态事件定义、显示 action / 可选 ignore、显式走链接，不自动触发目标。
- `event_play_preview_candidate.py`：caller-injected signal/conditions 门禁；snapshot、back/forward/jump、rollback；改变已应用步骤依赖的 observation 时，回退到最早受影响步骤前的安全前缀。
- `event_preview_diagnostics_006_candidate.py`：原因码、source pointer、breadcrumbs、review-only error view。
它是 Python 3.12 CLI，导入 PR #9 同级目录的 checker 和 source indexer。PR #18 不是独立于 PR #9 的可移植单目录 Godot 模块。

PR #33 在固定 HEAD `8394140bccd34918a98c43762fe184f8f0517d55` 中是 Godot 4 Control 场景；其 A/B/C 网格、校验回退和内存交互均由区域自己的 Gateway / Interaction 管理。没有事件预览公开接口。

**N26 的取舍：** 新建一个私有 GDScript 事件预览适配器，只读取 PR #18 的三份原样 fixture，复现有限的预览/条件/导航行为。没有 subprocess、Python 安装要求、PR #9 checker 复制、共享接口、事件总线或区域快照桥。这样保持独立，但不冒充调用 PR #18 Python 实现。

## 2. 顶层路由

| 当前路由 | 用户动作 | 成功后路由 | 返回语义 |
| --- | --- | --- | --- |
| `menu/home` 或 `menu/status` | 打开事件预览 | `event` | 销毁事件实例，回到同一菜单页 |
| `menu/home` | 进入区域 | `region` | 区域退出时销毁区域实例，回原菜单页 |
| `region` | 打开事件预览 | `event` | 区域实例继续挂载并隐藏；返回时恢复同一实例 |
| `event` | 返回事件来源页 | `menu` 或 `region` | 事件实例销毁，按来源标签恢复 |
| `event` | 返回菜单概览 | `menu/home` | 事件实例销毁；若来源为 region，区域也销毁 |

事件场景只收到一个 `origin_route` 标签。菜单不传入 region target、grid、gateway、claim 或 event state；事件页面也不能回写它们。从 region 打开事件前，外层只释放当前位于区域子树内的 GUI 焦点，避免隐藏区域继续接收键盘；返回时焦点交给外层事件入口按钮，不恢复隐藏网格的旧焦点。

## 3. 事件预览子状态

- **加载**：仅固定三个路径；文件必须存在、UTF-8、非空且小于 16 KiB。校验顶层/trigger/action 字段、标识符、重复 ID、数量边界和跨文件引用。任何错误都阻断整个事件目录。
- **观察**：每个 event_id 独立保存临时 observation。必须由用户显式点击“手动注入匹配合成观察值”或负例按钮；没有 observation 时不提供可选分支。匹配只对照该事件的 trigger.signal 与 trigger.conditions。
- **分支**：只列出文件内定义的 action_id；只有字段存在才提供 `@ignore`。null 目标是终止，不自动打开下一事件；linked target 也需要用户显式选分支，并对新事件另行注入观察。
- **返回**：back/forward/jump 只移动 cursor，保留 redo；back 后选择新分支会截断 redo；rollback 只能移动到当前 cursor 或更早，丢弃其后记录。
- **观察变更**：若 observation 改变且已应用路径里有从该 event 出发的选择，则只保留首次依赖步骤之前的安全前缀；若只影响 redo/unvisited，则清除 redo、保留当前活动前缀。错误请求不改变 snapshot。
- **错误**：返回稳定 reason code、建议、原 snapshot hash、`source_state_changed=false`、`auto_repair=false`。没有自动补齐条件、修复源文件或自动选择分支。

## 4. 故障恢复

| 故障 | 预期恢复 |
| --- | --- |
| 缺少 event_preview_screen.tscn / 非 PackedScene / 根不是 Control | 不改变 menu/region 路由，显示 BLOCKED；可修复本地资源后再次显式点击 |
| 三份固定 JSON 缺失/损坏/结构错/引用目标未知 | 事件页仍可显示 BLOCKED 和错误，外层返回按钮可用；用户显式“重新读取固定事件夹具” |
| 起始 event_id 不在固定目录 | 拒绝切换，不自动选择其它事件 |
| 无 observation / 错 signal / 缺 conditions | 选择按钮禁用；展示原因和 source pointer；用户可手动注入正确合成 observation 或清除 |
| 非法 action / 终止后选择 / 超 24 步 / 无效 cursor | 返回 REJECTED 与未变更 snapshot；不修复、不跳转 |
| 区域自身 Gateway 进入 FALLBACK/BLOCKED | 由 PR #33 区域自己显示状态；外层事件入口不读取其状态，返回工具仍在 |
| 必需 GDScript 无法解析 | 可能是项目导入级阻断，UI 层无法承诺恢复，必须记录 BLOCKED |

事件 fixture 失败**不使用 PR #33 的 A/B/C fallback**；区域 fallback 也不能为事件提供替代数据。

## 5. 与 PR #18 的差异清单

| PR #18 Python 候选 | N26 Godot 适配器 |
| --- | --- |
| 复用 PR #9 完整 checker 和 SourceIndex | 只对固定三份 fixture 做本地窄守卫 |
| 选定目录/文件集合、最多 1024 文件、每文件 1 MiB | 三个固定 res:// 文件，每个最多 16 KiB |
| duplicate JSON key 检测、line/column、pointer、source hash | Godot JSON parser；不能保证 duplicate key 检测；保留 file/pointer/hash，不提供精确行列 |
| Python CLI、text/JSON output | Godot Control UI |
| EVENT-005/006 的条件、rollback、diagnostics | 重表达所需子集；未来需逐项对照，当前不宣称等价 |
| PR #9 checker status PASS 才能 preview | N26 local guard 状态，不是 PR #9 PASS |

这是一项显式技术折衷：避免跨语言子进程和复制上游 checker，但会产生两套独立预览实现。若将来决定直接复用 Python CLI，必须单独做 Python 版本/路径/子进程超时/打包/输出 schema/错误/性能/安全审查，不在本任务范围。

## 6. 未验证风险

Godot 4 GDScript 静态类型、PackedScene 挂载与销毁时序、Control 焦点、ScrollContainer 尺寸、HashingContext API、JSON parser 对重复键行为、菜单切换时区域输入释放均未实测。源码中的固定上限不是性能实测。全部 NOT_RUN。
