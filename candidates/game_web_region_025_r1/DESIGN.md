# DESIGN｜菜单与区域之间的最窄安全桥（N25 自拟方案）

**原始事实**引用固定 GitHub HEAD；**候选决策**不等于原 PR 已批准接口；**NOT_RUN**，不把源审查当成実测。

## 源码兼容事实

- PR #24 的 [`shell_candidate.gd` L120–159](https://github.com/cao772/game/blob/5768eeef65fe5d54b1c5a692c44400332da61506/candidates/game_web_flow_shell_004_r1/shell_candidate.gd#L120-L159) 有本地菜单 `show_page/go_back` 和有限历史；[`play_005/play_shell.gd` L72–108](https://github.com/cao772/game/blob/5768eeef65fe5d54b1c5a692c44400332da61506/candidates/game_web_flow_shell_004_r1/play_005/play_shell.gd#L72-L108) 有返回菜单、返回上一模块时清理区域/事件上下文；[L178–247](https://github.com/cao772/game/blob/5768eeef65fe5d54b1c5a692c44400332da61506/candidates/game_web_flow_shell_004_r1/play_005/play_shell.gd#L178-L247) 有资源检查、拒绝错误类型与模块挂载。
- 但是原 PR #24 [`play_shell.gd` L244–333](https://github.com/cao772/game/blob/5768eeef65fe5d54b1c5a692c44400332da61506/candidates/game_web_flow_shell_004_r1/play_005/play_shell.gd#L244-L333) 的区域依赖 `Node3D`、`flow_snapshot()`、SubViewport 和独立 target→event 规则；PR #32 是 `Control` 且通过 `validated_gateway` 管理 A/B/C；**两者不能简单换 `REGION_SCENE` 路径直接集成**。
- PR #32 [`accessible_demo.gd`](https://github.com/cao772/game/blob/cc70e20dbf916bb15c1844c1efb749adb6c14b4d/candidates/game_web_region_024_r1/accessible_demo.gd) 自有键盘/字号/错误与状态文本；[`validated_gateway.gd`](https://github.com/cao772/game/blob/cc70e20dbf916bb15c1844c1efb749adb6c14b4d/candidates/game_web_region_024_r1/validated_gateway.gd) 独占验证回退。无菜单返回 API，N25 的返回控件须存在于它的实例**外面**。

## N25 方案与取舍

| 决策 | 原因 | 静态剩余风险 |
| --- | --- | --- |
| **不复制 PR #24 整套 Shell**；仅模仿 home/status/明确返回和资源检查 | 避免把 PR #24 的私有 Node3D 与游戏事件映射误用于 PR #32，也避免两份主场景冲突 | 不是 PR #24 原生导航功能全兼容；属于另一个更小的菜单候选 |
| 菜单 `menu_flow_owner.gd` 只管理 `route, menu_page, return_page, availability, attempts, notice` | 防止菜单窥探区域模型/修改校验回退；返回时无隐式复制区域内部状态 | 不能把菜单的 `ready` 模拟标签当成实际可用性 |
| 区域入口只使用本地固定 `res://region_screen.tscn` 并检查 `ResourceLoader.exists/load` | 找不到子场景时菜单留在原页面、文字可恢复；不扫描其他 PR 或外部目录 | 必需脚本解析失败可能在资源加载时阻塞；不能保证所有错误可被 GUI 捕获 |
| 实例化前保持当前菜单；**挂载完成后才提交 route** | 模拟“失败不切页”的事务式导航，用户可重复显式重试 | Godot 挂载执行 `_ready` 中发生的解析/脚本错误无法当成普通可返回的字典处理 |
| 新区域每次进入都重新创建、返回时移除/释放 | 避免旧 A/B/C 坐标、核对、更正、撤销被错误继承；没有对存档做任何写入 | Godot 销毁、输入焦点与排队释放的真实时序未验证 |
| 区域顶栏 Return 控件属于菜单，而非 N24 `accessible_demo.gd` | 即使区域内部 `BLOCKED` 仍能返回菜单，而不需修改 PR #32 源 | 如果必需脚本使整个项目无法启动，顶栏也不存在，这种错误必须记 BLOCKED |
| 失效状态 `ready/missing/disabled/pending/degraded` 仅作菜单**模拟** | 覆盖 PR #24 的缺失/禁用/待审/降级概念，显式恢复后重试 | 不等于动态移除真实模块，也不是 PR #24 Registry |
| **不做**实际 target→event 或其他流程迁移 | PR #24 的 target/event 映射与 PR #32 的 A/B/C 字母格网没有被定义为同一格式 | 若将来要跨到真正事件/存档，需新作者决策和接口合同 |

## 状态表（设计期预期，NOT_RUN）

| 触发 | 页面路由 | 谁保留状态 | 谁丢弃状态 | 提示 |
| --- | --- | --- | --- | --- |
| 启动 | `menu/home` | 菜单模拟状态 ready | 无 | 仅合成占位 |
| `home → status` | `menu/status` | menu_page 与 availability | 区域从未创建 | 模块状态非真实 |
| 允许进入 | `region` | menu.return_page；新区域自身数据 | 无旧区域 | 新建 A/B/C，不读真实游戏 |
| 模拟 missing/disabled/pending/degraded 时进入 | 保留 menu 原页 | 原 availability 与拒绝原因 | 不创建区域 | BLOCKED + 手动恢复 |
| 缺失/无效固定区域 scene | 保留 menu 原页 | 原 availability 与资源错误 | 不创建区域 | BLOCKED，不自动换源 |
| 区域内 validator 回退 | 仍 `region` | 区域自己的 `FALLBACK_SYNTHETIC`/错误 | 不动菜单状态 | 顶栏 Return 永远在区域外 |
| `region → return_previous` | 恢复来源 menu 页 | availability、attempts、返回说明 | 整个区域节点/内存 | 回到原菜单上下文 |
| `region → return_home` | `menu/home` | 菜单模拟状态 | 区域与 return_page | 无自动事件或读档 |
| 重试 | 只有在 menu 上 | availability 明确改 ready，attempts+1 | 原失败不能假称修好 | 重新检查固定区域 scene |

## 执行限制

Godot 4 API、`PackedScene` 资源载入、窗口焦点、布局与 Tab 顺序、实例销毁队列、中文字体、滚动/150% 缩放、嵌套 ScrollContainer 的尺寸均未进行运行验证。N25 不产生真实世界或持久存档，不覆盖任何已有源码。**全部 NOT_RUN。**
