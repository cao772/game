# FUTURE_ACCEPTANCE｜GAME-WEB-REGION-025 r1

**全部案例状态 = NOT_RUN。当前仅源码提交和静态设计，未运行 Godot、GDScript/JSON 解析器、任何代码或测试。** 以下步骤需作者**将来重新授权**，可按真实执行记录 PASS/FAIL/BLOCKED，但本轮绝不填 PASS。

| 编号 | 未来授权操作 | 预期行为与故障记录 |
| --- | --- | --- |
| S01 | 用 `candidates/game_web_region_025_r1/` 作为项目根导入 Godot | main scene、菜单脚本、子场景和 9 个区域固定源均可解析；失败记 BLOCKED |
| S02 | 检查独立分支 GitHub diff | 全部为本目录新文件；PR #24/#32、main、共享接口均无改动 |
| S03 | 对比 9 份区域代码/fixture Git blob | N25 的每份与 PR #32 指定 HEAD 完全一致；没有第二套 loader |
| N01 | 从默认 menu/home 按“进入区域” | 只有 ready、未暂停、有窗口焦点且 scene 可用时才进入 region |
| N02 | 从 menu/status 按“进入区域”，随后返回上层 | 回到 status 页，而非无条件回 home；模拟装配状态保留 |
| N03 | 从 menu/home 进入，再选择“返回上层菜单” | 回到 home，区域实例被移除，菜单 focus 可返回进入按钮 |
| N04 | 从 region 选择“回到菜单概览” | 回 home，旧来源页与区域临时状态不继承 |
| N05 | 从 menu/status 选择“返回上一层” | 返回 home；重复返回保持 home 且给文字说明 |
| N06 | 连续重复进入/返回 A/B/C（新建区域） | 每次区域位置、核对、更正、Undo、焦点和回退状态重新初始化；不携带旧快照 |
| N07 | 区域中 Inspect→Correct→Undo 后返回并重新进入 | 原内存主张/位置不能被菜单再注入；原始固定 JSON 不被写入 |
| F01 | 在 menu/status 选择 `missing` 再进入 | 原页不变，无区域实例，显示 `BLOCKED` 及显式恢复提示 |
| F02 | 分别选择 `disabled/pending/degraded` 再进入 | 三种均拒绝；不会自动启用其它模块，也不宣称真实模块失效 |
| F03 | 失败后按“显式恢复模拟就绪并重试” | 仅菜单 availability 变 ready；重新检查原固定 scene；若仍缺 scene 继续 BLOCKED |
| F04 | 隔离副本中移走 `region_screen.tscn` | ResourceLoader.exists 失败后仍在菜单，显示资源文件名与可恢复说明 |
| F05 | 隔离副本将场景替成非 PackedScene | 不切路由；说明资源类型错误，当前菜单状态不变 |
| F06 | 隔离副本的 region 根不是 Control | 拒绝挂载并释放异常节点；不留下半路由/旧地区状态 |
| F07 | 将任意必需区域脚本删除或故意破坏（隔离副本） | 导入/解析可能直接失败，禁止将此情形报成“已在 UI 安全降级” |
| F08 | 区域内可选合成 JSON 损坏 | PR #32 内部展示 `FALLBACK_SYNTHETIC` 与原错误；外层 Return 仍可用 |
| F09 | 区域内 fallback 自身无效 | 区域展示 `BLOCKED`，外层 Return 仍可用；不得说原文件修复成功 |
| F10 | 暂停 Godot 场景树后尝试新进入 | 拒绝，且不增加当前已挂载区域的副作用；能否操作 UI 依赖引擎 pause 设置需真实记载 |
| F11 | 窗口失焦后尝试显式进入 | 拒绝进入；再次聚焦不会自动进入，需要再点击 |
| F12 | 在菜单 ready 与模拟缺失状态来回切换 | 不改变其它 PR 的 Registry、Godot 全局 InputMap、持久文件或真实模块 |
| K01 | 从菜单一直用 Tab/Shift+Tab、Enter/Space 操作 | 主页→status→region→返回的路径可用，无鼠标依赖，焦点位置清楚 |
| K02 | 在区域格网焦点下 WASD/方向键，然后从外层返回 | 不向菜单页面误发移动键，返回后旧区域无法再响应键盘 |
| K03 | 进入区域后缩放 100/125/150%，再返回 | 区域字号不影响菜单所有权；再次进入重新使用区域初始选项 |
| K04 | 在窄窗口/中文输入法/辅助技术下操作 | 页面可滚动、提示可读；如不能应记录真实 FAIL，不推断合规 |
| B01 | 核查源内容 | 只有匿名合成 A/B/C 与菜单示例；无真实剧情、人物、地点、原稿、聊天证据 |
| B02 | 复查 PR #24/#32 当前 HEAD 和 main | 来源分支未被修改；新 PR 保持 Draft，绝不 merge main |
| B03 | 审计本轮执行记录 | 无 Godot、源代码、解析器、测试或 CI 运行；全部保持 NOT_RUN |

**未来执行证据字段（仅建议，非本轮填报）：** `case_id`、`exact_head`、`Godot_version`、`OS`、`expected`、`observed`、`result (PASS|FAIL|BLOCKED|NOT_RUN)`、`notes`、`evidence`。测试人员、时间、日志、性能/无障碍数据均不能凭设计生成。

**硬停止线：** 把 #24 的 Node3D/flow_snapshot 误用于 #32；菜单读取/回写区域临时内存；失败却切页；返回后保留旧事件/位置/撤销；缺必需源码宣称安全 fallback；PR #24/#32 或 main 被改写；写入真实故事、地点、人物或聊天证据。**本轮 NOT_RUN。**
