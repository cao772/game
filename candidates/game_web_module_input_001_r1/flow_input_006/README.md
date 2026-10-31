# GAME-WEB-INPUT-006 r1｜冲突交换、撤销、无障碍焦点

**独立技术候选 · NOT_RUN · 不批准正史与共享接口。**

## 源码依据

已读取 cao772/game Draft PR #19 的实际 HEAD bccdc930735e1d55afcc8eb906370a3991e552f0；确认存在上一版 flow_input_005 的完整设置面板、005 验收脚本，flow_input_004 的后端，以及 PR #15 提供的五动作配置、严格配置校验、冲突反馈、V1/V2 迁移和持久化。此增量只在 flow_input_006 新建文件，不编辑这些依赖。

本轮模块：

- input_change_planner_006.gd：纯内存双动作互换预览、整图检查、至多十条变更历史与撤销前置校验。
- input_settings_panel_006.gd：继承现有 005 完整界面，新增交换、撤销和可见键盘焦点管理。
- input_settings_panel_006.tscn：独立可实例化的 Godot Control 场景。
- verify_input_settings_006.gd：未来有限 SceneTree 验收脚本（NOT_RUN）。
- README.md、INTEGRATION.md、ACCEPTANCE.md：设计、接入、验收文档。

在原独立项目的场景路径：res://flow_input_006/input_settings_panel_006.tscn。

## 冲突解决

1. 保留已有五项动作，默认键位不改变。
2. 原有冲突提示和建议空闲键保留；若新键只被另一项动作占用，额外显示“预览交换占用键”按钮。
3. 用户须先按交换按钮，再审阅两项动作旧/新键；之后才能选“仅本次应用”或“保存后应用”。
4. 双方键码在同一份完整 profile 中替换，并交给 PR #15 的 inspect_profile 检验；不产生临时重复键，也不自动抢占键。
5. 单项恢复默认遇到占用时同样允许明确交换。全量恢复默认仍是一次整体变更，不依序写入。
6. 内存、配置文件路径或待审预览改变时拒绝使用旧预览；取消永远不提交。
7. 多所有者、未知动作或无合法候选时直接拒绝，不推断或修复未知配置。

**设计理由：**双向互换是可明确解释的解冲突方案；独立的二次确认避免悄悄改变另一动作。继续复用既有 V2 配置结构，不新造存储协议。

## 撤销

- 保存至多十次成功改变 live bindings 的完整前后 profile，单实例临时历史，不存盘。
- 每次先预览最后一项历史，确认当前内存与当时 after 状态一致。
- 内存变更仅可“仅本次应用”撤销，不触碰磁盘。
- 原先保存到磁盘的变更只能“保存后应用”撤销：先经原有 V2 校验、磁盘 digest/外部修改检测、同目录临时文件与读回，再恢复内存。
- 保存失败时不弹出历史；临时错误保留待确认方案并要求手动重试。外部修改、损坏文件、疑似已提交写入时禁止盲目重试。
- 撤销本身不加入历史栈；取消不消耗历史。
- 成功显式“保存当前配置”、加载外部 V2、完成 V1→V2 迁移后清空旧历史；迁移不支持自动删除新文件来模拟撤销。
- 不提供 redo、跨会话撤销、跨进程历史同步。磁盘操作是单进程协作候选，不保证 OS 层事务或掉电安全。

**设计理由：**记录整体映射比单个按键更能准确恢复彼此占用关系；明确区分 RAM 与已保存配置可防止产生“撤销了但磁盘仍旧”的错误反馈。

## 键盘与可达焦点

- 遍历本面板已有与新增的 Button 控件，设为 FOCUS_ALL，指定可循环的 focus_next/focus_previous；建议空闲键按钮动态加入。
- 既有动作按钮添加说明性 tooltip；焦点变化更新界面可见 AccessibleFocusHint 文本。
- 打开面板尝试焦点移至第一项；关闭时尝试恢复打开前合法宿主焦点。面板关闭仍调用既有候选路由暂停恢复。
- 键位捕获阶段可使用 Backspace 取消。Backspace 不在现有可绑定逻辑键白名单内，不会抢走合法动作；Escape 仍是可重绑定键。
- 保留 005 对键盘 release、echo、组合键、暂停、失焦的既有过滤。

**设计理由：**不添加任何 InputMap 全局动作；使用 Godot 原生 Control 焦点、tooltip 和可见说明，并给不用鼠标的用户提供一个不与可绑定 Escape 冲突的取消入口。

**能力边界：**上述措施不证明屏幕阅读器兼容、WCAG 符合性、高对比度或 IME 实际表现。无真实游戏场景树和宿主路由实例，因此只提供可选独立模块，不宣称生产集成成功。

## 错误和恢复约束

交换/撤销持久化使用 PR #19 现有 backend 的候选内部 _commit_candidate 方法，后者调用已有 V2 校验、保存和读回；不会重写原稿或存档核心。TEMP_OCCUPIED/WRITE_FAILED/RENAME_FAILED/MISSING_DIRECTORY 可显式重试；LOAD_REQUIRED/EXTERNAL_CHANGE/EXTERNAL_DELETE/INVALID_PROFILE 等需外部复核；POST_WRITE_VERIFY_FAILED/COMMITTED_NEEDS_RELOAD 等可能已写入的情况不得假装自动回滚。

此内部调用关系是 PR 之间的草稿技术依赖，**不是已批准的共享 API**。用户未提供真实主场景、外观规范、屏幕阅读器测试基线、跨进程锁机制与具体目标平台；本轮保守停留在独立候选内，所有未知点明确 NOT_RUN。

## 未来验收（此次未执行）

未来 Godot 4 headless 命令（当前 NOT_RUN）：

    godot --headless --path candidates/game_web_module_input_001_r1 --script res://flow_input_006/verify_input_settings_006.gd
    echo $?

未来独立桌面场景（当前 NOT_RUN）：

    godot --path candidates/game_web_module_input_001_r1 res://flow_input_006/input_settings_panel_006.tscn

实际 Godot 版本、OS、最终 HEAD、命令、stdout/stderr、退出码、真实交互和失败注入证据都待后续授权。提交源码不等于编译或测试通过。未运行任何程序、测试或 CI。
