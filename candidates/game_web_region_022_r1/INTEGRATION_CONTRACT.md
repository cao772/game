# INTEGRATION_CONTRACT｜仅本目录本候选有效的接线契约

**合同性质：N22 新增提案，不是现有共享 API，不改变 PR #28/29。全部 NOT_RUN。**

## 数据所有权和类型边界

1. `catalog_recovery.gd` 是**唯一允许读取文件和生成 fallback 的组件**。调用 `load_optional_fixture()` 只能读固定 `res://synthetic_regions.json`；合成边界输入从 `examine_variant()` 进入，不提供用户任意路径选择。不允许模型自己加载第二份 JSON，不调用 PR #26 的 `region_model.load_catalog`。
2. 原返回 `mode` 的合法值：`SOURCE_ACCEPTED`、`FALLBACK_SYNTHETIC`、`BLOCKED`。`report` 记录**原文件/原输入**问题，`fallback_report` 独立记录内置回退自检；二者不能合并为一个 PASS。
3. `validated_gateway.gd` 首先清除先前活动模型与撤销/核对状态，再读取本次原结果。如果是 `BLOCKED` 或未知 mode，**停止**；如果源声明可用却缺少完整 A/B/C 或 ID 重复，也停止。不能通过“自动换成 B/C”掩盖错误。
4. 网关只将已被 PR #28 Validator 结构检查过的记录映射为 `{id, grid, claimed:{reachable,visible}}`。原始额外字段仅允许在上游诊断中作为 Warning；**不会流入交互模型**。
5. `synthetic_interaction.gd` 只接收上述经门禁的纯合成记录。它不会读/写文件、没有自动 fallback、没有游戏事件/存档，也不能调用其他项目脚本。
6. UI 展示**数据来源模式 / 原始诊断 / 后备诊断 / 模拟记录主张 / 是否显式核对 / 核对观察**五种不同层次信息。结构合法不代表主张真实；T 不可达也可是一张合法的合成网格。
7. 场景 A/B/C 更换时用 `configure` 清空局部移动、日志、撤销、`inspected`；移动和撤销让旧的核对过期。`snapshot().actual` 在 `inspected=false` 时为空字典，而不是隐藏一个“已验证真值”。
8. 此接口仅是两个 GDScript 类之间的**局部代码边界**，没有改变公共项目外的任何接口。不承诺对 #25–#29 兼容，也不代表已批准生产 Schema。

## 自治状态（N22 设计值，非性能实测）

| 状态 | UI 可以显示 | 禁止行为 |
| --- | --- | --- |
| `SOURCE_ACCEPTED` | 结构接受、原输入文件来源、A/B/C 字母、局部模拟交互 | 宣称“可达已证明”“真实测试通过” |
| `FALLBACK_SYNTHETIC` | 原输入错误列表、合成后备目录、独立说明 | 把回退伪装为原文件已修复 |
| `BLOCKED` | 原因、无可交互地图、下一步检查必需依赖 | 任何移动、自动改记录、自动选一个无来源场景 |
| `inspected=false` | 原始 `claimed`、地图、可选路线预览 | 显示 `actual` 为玩家已经核对的结果 |
| `inspected=true` | 四向路线和采样 LOS 的模拟观察、冲突提示 | 将采样结果说成真实世界/物理安全结论 |

## 迁移可反悔路径

未来如要接 #26 模型/键盘 UI、#27 只读卡，应当在**其他新授权的隔离分支**上设计明确的适配层，不能直接复制互相冲突的 `res://project.godot` 根和 `main.tscn`；当前 N22 只证明（设计上）数据校验→模型状态的第一段边界。必要时删掉整份 N22 候选目录即可，不会改变 PR #28/29、真实主游戏或存档。
