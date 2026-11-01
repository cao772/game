# STATE_OWNERSHIP｜明确谁拥有哪一份状态

**只针对 N25 独立候选目录，不是共享接口批准，也没有运行验证。**

```text
[N25 menu_flow_owner.gd]
 _route / _menu_page / _return_page / _availability
 _attempts / _notice / _region_instance（仅 Node 引用）
       │ 只实例化或销毁 Control；不访问区域 _gateway / _model
       ▼
[N25 region_screen.tscn -> 原样 PR32 accessible_demo.gd]
 _font_scale / _window_focused / _release_gate / UI focus
       │
       ▼
[原样 PR32 validated_gateway.gd]   ← SOURCE_ACCEPTED / FALLBACK_SYNTHETIC / BLOCKED
 _catalog / _result / _mode / _active
       │
       ▼
[原样 PR32 synthetic_interaction.gd]
 grid / player / start / target / claimed / inspected / preview
 undo / local log
```

## 保留 / 清理条件

- **菜单拥有**：当前菜单页、从哪页进入、可用性模拟模式、进入尝试次数与最近说明。菜单不存 A/B/C 的任何 Player/Claim、诊断报告或区域 snapshot，不允许从另一个 PR 的事件/存档接口恢复。
- **区域拥有**：固定公开合成 JSON 的载入、结构诊断和 fallback，A/B/C 选择、网格位置、显式核对、更正、撤销、字号和焦点。本层与菜单没有 event bus、共享存档、跨模块 ID 映射或数据库。
- **返回**：菜单控制器先 `remove_child` 区域节点，再 `queue_free`。导航回到来源页或 home，并保留菜单模拟状态；区域内部状态**没有迁移通道**。队列释放的真实时序要在未来验收中检查，不能保证已经无泄漏。
- **下一次进入**：重新从固定 `region_screen.tscn` 实例化 Control，区域内部重新加载同一公开合成数据（有错则自己显示回退）；**旧区域记录不能按菜单历史还原**。
- **被拒绝进入**：不变更路由、不创建区域、不猜测新资源，只在菜单显示 `BLOCKED: reason`；显式恢复按钮只将**菜单模拟**的 availability 置 ready，然后重试固定 scene。
- **区域内部 BLOCKED**：它仍然是有效挂载的 Control，但网格模型阻断；菜单不读取其私有网关，外层 Return 始终作为逃生出口。
- **必需源码失效**：该候选项目无法解析/导入，超出运行期 UI 能修复的范围，不应宣称“安全返回成功”。

## 与 PR #24 之间的断言边界

PR #24 的内部 `_history`、`_region: Node3D`、`flow_snapshot`、`_target_bridge` 和 `_event_model` 均**没有被读写或替换**。N25 是基于其公开菜单语义开发的**新局部独立路由**，不是把 PR #24 的 `return_previous` 重绑定，也不改变其所有权。所有“未运行”状态均 **NOT_RUN**。
