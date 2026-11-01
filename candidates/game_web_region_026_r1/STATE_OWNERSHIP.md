# STATE_OWNERSHIP｜N26 菜单 / 区域 / 事件预览的状态边界

**候选私有状态图，不构成共享接口批准。NOT_RUN。**

```text
menu_flow_owner.gd  [唯一顶层路由 owner]
  route / menu_page / region_return_page
  event_origin_route / event_return_page
  availability(simulated) / attempts / notice
  _region_instance reference / _event_instance reference
        │                         │
        │ instantiate / hide      │ instantiate / dispose
        ▼                         ▼
PR #33 accessible_demo.gd    event_preview_screen.gd
  owns A/B/C local state        owns UI controls + temporary model
  grid / position / claim              │
  inspect / correction / undo          ▼
                                event_preview_model_candidate.gd
                                  fixed event definitions
                                  synthetic observations
                                  path history / cursor
                                  diagnostics / error view
```

## 菜单 owner

只拥有：
- 当前顶层路由 `menu / region / event`；
- 菜单来源页与事件来源路由标签；
- 模拟装配状态、进入尝试计数、最近提示；
- 两个独立 Control 实例的生命周期引用。

不拥有事件 definitions、条件 observation、事件路径或区域网格状态。只把 `origin_route` 字符串传给 event screen。

## 区域 owner

PR #33 的九份区域源码原样复制。区域拥有自己的固定 A/B/C 目录校验/回退、选择、位置、核对、更正、撤销、字号和焦点。N26 外层工具栏与区域内部没有共享字段、signal 或快照读取。

- 从 region 打开 event：region 实例仍挂在 `_region_stage`，其父 holder 隐藏，不复制内部 state。
- 返回来源页：先销毁 event instance，再重新显示原 region holder；预期恢复同一地区实例与临时状态。
- Return to menu：显式销毁 event 和 region 两个实例。

## 事件预览 owner

事件屏幕拥有：
- 三份固定公开事件定义及其 source file/hash/pointer；
- 当前起始 event ID；
- caller-injected synthetic observation；
- branch history、cursor、redo、rollback；
- 当前诊断、错误和临时 snapshot。

事件屏幕不读取区域的 A/B/C 当前选择，也不将事件结果交给区域。进入下一个 event 不自动注入 observation。由 region 打开事件时，菜单只检查 GUI focus owner 是否属于 region 子树并释放该焦点，防止隐藏区域继续响应键盘；这不是读取区域内部状态。返回 region 时将焦点放到外层事件入口按钮，不声称恢复之前的网格焦点。退出/销毁事件屏幕时，所有 observation 与路径历史随对象释放，不写入菜单、区域、文件或存档。

## Back 与 rollback 的区别

- 顶层 **Back to origin**：销毁事件预览 Control，恢复 menu 或原 region；若回到 region，region 仍是同一个实例。
- 事件内 **back/forward/jump**：只改变事件 preview cursor，保留 redo。
- 事件内 **rollback(cursor)**：截断 cursor 之后的历史，不能前进。
- observation 改变：如果当前已选路径使用该 event 的 gate，退回首次受影响选择之前的安全前缀；无已应用依赖时仅清除 redo。
- 区域自己的 Undo：只影响区域内存，不影响事件预览。

## 禁止隐式共享

不允许通过菜单路由标签暗示事件已由区域触发；不允许将 A/B/C 的 A/B/C ID 映射成 EVENT_START/NEXT/END；不允许事件分支修改区域坐标、玩家、claim、inspect、correct、undo；不允许事件预览改动菜单 availability 或正式存档。
