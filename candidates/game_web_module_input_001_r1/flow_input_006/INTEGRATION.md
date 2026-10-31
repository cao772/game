# GAME-WEB-INPUT-006 r1｜候选接入与安全边界

**NOT_RUN。** 仅面向 cao772/game Draft PR #19 的独立 Godot 工程，非正式游戏场景/共享接口。PR #19 当前父级依赖为 Draft PR #15；PR #15 上游为 Draft PR #6。

## 接入前置

阅读与复核的源码基础：PR #19 起始 HEAD bccdc930735e1d55afcc8eb906370a3991e552f0。006 在自己的 flow_input_006 子目录中新增两份 GDScript、scene、未来测试和文档；没有改变 004/005、PR #15 或 main。

新界面可独立实例化，路径为 res://flow_input_006/input_settings_panel_006.tscn。必须使用同一套已有的 Godot 项目 res:// 根目录。此 scene 包含 005/004 所有功能并扩展解冲突、撤销、焦点：

    var panel = preload("res://flow_input_006/input_settings_panel_006.tscn").instantiate()
    panel.v2_profile_path = "user://input_bindings_candidate_v2.json"
    panel.legacy_profile_path = "user://input_bindings_candidate.json"
    add_child(panel)

上述是未来宿主参考，不是本轮运行证据。

只有宿主已有真实 PR #15 键盘适配器且作者授权联动时，才让 UI 与适配器共享同一个 bindings 实例：

    input_adapter.bindings = panel.backend.workflow.settings.bindings
    panel.open_for_router(input_adapter)

面板打开期间，既有逻辑仅暂时关闭这个明确提供的 router Node 的 unhandled key processing，关闭后恢复其原处理标志；不是全局 InputMap 设置，也不会更改其他未知输入脚本。宿主未提供 adapter 时仅作为独立配置编辑器，无法保证普通非捕获按键不会进入游戏。全局和原稿一律不更改。

## 重要入口和决策

1. begin_rebind(action_id) 开始单键捕获；preview_key_candidate(keycode) 产生现有冲突与建议；成功预览调用 apply_memory() 或 apply_and_save()。
2. 预览冲突后，若明确为另一项占用该键，新增“预览交换占用键”按钮，亦可调用 choose_swap()。只产生完整映射候选，需再次确认；无 silent overwrite。
3. preview_reset_action(action_id) 继续用原有规则拒绝被占用的默认键，此时可显式改选交换。preview_restore_all() 仍可预览全量恢复，无中间不一致状态。
4. preview_undo() 只查看最后成功项。内存变更仅用 apply_memory() 撤销；磁盘变更仅用 apply_and_save() 撤销。撤销必须与当前内存 SHA-256 配置快照及原目标路径匹配；外部磁盘变化由旧 backend 复核。
5. cancel_preview() 丢弃当前待操作，不删除历史。close_panel() 还原已连接 router 的处理状态并尝试还原原宿主焦点。
6. ui_state_006() 提供现有状态之外的 swap_available、undo_available、undo_depth、undo_scope、focused_control，方便未来测试及外部界面联动。
7. 仅 Backspace 作为键位捕获时的取消入口；Escape 可被绑定，不能硬编码为取消。原有点击“取消操作”继续可用。

新 planner 只生成、验证纯内存整图，不拥有磁盘。新的 panel 通过既有 backend 进行 V2 的显式存储和更新，不另造一个竞争式 schema。任何已有 V2 必须按旧 candidate 先读取建立 digest 基线。可恢复保存失败的 RetrySave 继续适用；失败不能降级为仅内存的自动成功。

## 撤销边界 / 为什么如此设计

- 单实例最多 10 次、仅成功映射变化的 history。每项保存完整 before/after、scope（memory/disk）和 V2 路径。
- 读取 V2/显式保存当前 V2/完成 V1→V2 迁移后清空历史：这些步骤改变了与磁盘配置的关系，不能依靠旧内存快照推断如何安全复原旧文件。
- 持久化撤销只恢复先前的完整 V2 目标；不自动删除通过迁移新建的文件，也不重写 V1 或正式存档。
- 持久化尝试失败时历史仍在；不存在自动重试或跨进程锁。若磁盘可能已提交，禁止宣称成功撤销或数据回滚。
- 当前撤销栈不持久化，不跨进程/会话，也不含 redo；具体 UX、并发与恢复策略仍是待最终验收的技术候选。

## 无障碍焦点范围 / 约束

界面使用 Godot Control 原生 focus_mode、focus_next、focus_previous、tooltip 与可见焦点标签；循环内含动态“建议空闲键”及新交换/撤销按钮。面板开启将焦点尝试移动到第一项，完成/取消后尝试回到发起动作；关闭时尝试返回原宿主控件。没有任何全局 action 或 InputMap 变更。

真实键盘导航、焦点抢占、屏幕阅读器、输入法、游戏手柄、不同系统和窗口失焦都**未测试**，需要未来提供实际场景和运行证据；不可将静态焦点逻辑表述为无障碍验收通过。

## 缺失的前置输入与处理方式

用户没有提供正式游戏 UI 规范、真实场景结构、可使用的宿主 router 实例、目标可访问性标准和平台文件竞争模型。本轮保守实现独立模块，不对任何缺失的具体接口自行编造约定。所有产品语义、接口名和存储扩展仍为提案，不批准共享接口及正史。

未来从仓库根目录、使用实际 Godot 版本执行：

    godot --headless --path candidates/game_web_module_input_001_r1 --script res://flow_input_006/verify_input_settings_006.gd
    echo $?

本轮严格 NOT_RUN：无任何 Godot、脚本、测试、CI、GUI 或性能执行。未来留存 SHA、引擎版本、命令、退出码及 stderr/stdout，才能完成作者最终验收。
