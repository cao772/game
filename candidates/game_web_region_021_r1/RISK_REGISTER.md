# RISK_REGISTER｜PR #25–#28 源码级风险与消解计划

**性质声明：** 以下“已发现”只指源码文本里的结构/分支/数值；“风险”是静态推断，不是已实际触发的 bug。**所有问题均未运行 Godot、解析器、脚本、测试或 CI：NOT_RUN。**

**优先级定义（N21 建议）：** `BLOCKER`＝无批准前不可直接合并；`HIGH`＝可能影响正确性/数据可追溯性，后续接线前必改或验证；`MEDIUM`＝交互质量/辅助使用风险；`LOW`＝可后置的文档或一致性约束。优先级是候选审查结论，不是生产事故统计。

## R01｜不同 Godot project 根路径相撞 — BLOCKER

- **[源]** 四个项目均有 `project.godot`（`run/main_scene="res://main.tscn"`）和独立 `main.tscn`。#25–#27 通过 `res://region_demo.gd` 等加载本地同名脚本；#28 `main.tscn` 则加载 `res://diagnostics_demo.gd`。见 [#25 main.tscn L3](https://github.com/cao772/game/blob/8372c1fe5f6471ec6af788b65b68fa54fe7db65a/candidates/game_web_region_017_r1/main.tscn#L3)、[#27 region_demo.gd L5–7](https://github.com/cao772/game/blob/fdbb6688d07a6a7cebe36b999b82482987362499/candidates/game_web_region_019_r1/region_demo.gd#L5-L7)、[#28 main.tscn L3](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/main.tscn#L3)。
- **[静态风险]** 直接把四份文件平铺到一个项目根目录会冲突/覆盖，独立 res 路径也不能自动指向同一资源目录。
- **[N21 对策]** 后续先在隔离候选目录设计唯一入口与明确的路径映射，并保留原四个 PR 可独立重建；不在此 PR 改任何资源路径。
- **未来核验**：实际授权后检查所有 preload/scene refs，并让独立/合并候选分别完成导入；任何覆盖即停止（A01、A02）。

## R02｜#28 的诊断器未接入 #26/#27 — BLOCKER

- **[源]** [#26 region_model.gd L40–61](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_model.gd#L40-L61) 在自己的 `load_catalog` 调 `_valid_catalog`；[#28 catalog_recovery.gd L29–75](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/catalog_recovery.gd#L29-L75) 在另一个独立类里用 `region_validator.gd`。
- **[静态风险]** 这两条数据加载链没有被当前源文本连接；不能声称 #26/#27 已有 #28 字段级错误诊断，或把其 fallback 当共同加载事实。
- **[N21 对策]** 下一阶段先确定一个**被授权的单一加载策略**及来源标记，其他 loader 保留只读适配，不允许两条链先后静默回退。
- **未来核验**：分别注入只有合成字段的无效 JSON，能准确追溯是原文件拒绝还是内置回退；不可生成“原文件修复成功”消息（A03、A04）。

## R03｜“结构 ACCEPTED”与玩家实际可达/可见混淆 — HIGH

- **[源]** [#28 region_validator.gd L59–179](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/region_validator.gd#L59-L179) 检查形状、边界及 S/T 数量，不做 BFS 或视线验证；[#26 region_model.gd L159–203](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_model.gd#L159-L203) 的 BFS/LOS 是**另一层**。
- **[静态风险]** C 的 T 隔断并不使结构无效；A/B 的合成 `claimed` 可故意写错，仍可能通过结构检查。
- **[N21 对策]** 人工接口约定至少分成“原始主张 / 结构是否合法 / 实际模拟核对结果 / 是否核对过”四个不同名词；不使用一个笼统 `valid` 代表它们。
- **未来核验**：结构有效的隔断 C 必须可接受，但路线提示不可假称通行（A05、A06）。

## R04｜模型 snapshot 在“未核对”状态依然计算实际字段 — HIGH

- **[源]** [#26 region_model.gd L300–311](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_model.gd#L300-L311) 中 `snapshot()` 无论 `_inspected` 是否为真都会返回 `actual_reachable` 和 `actual_visible`；[#27 state_guide.gd L14–28](https://github.com/cao772/game/blob/fdbb6688d07a6a7cebe36b999b82482987362499/candidates/game_web_region_019_r1/state_guide.gd#L14-L28) 通过 `inspected` 保护读者不要误判观察已发生。
- **[静态风险]** 后续若绕过 `state_guide` 直接显示 `snapshot.actual_*`，就会把未经玩家核对的内部估算说成实际完成调查。
- **[N21 对策]** 保留 `inspected` 门控，且在迁移提案里明确位置变化、撤销、换场应使旧观察失效；考虑未来定义只读观察投影（仅建议，不创建字段）。
- **未来核验**：无 Inspect 时证据卡必须明确“未核对”；移动后不能继续显示旧观察已通过（A07、A08）。

## R05｜BFS 与 LOS 是合成代理，非真实导航/物理遮挡 — HIGH

- **[源]** [#25 region_model.gd L156–200](https://github.com/cao772/game/blob/8372c1fe5f6471ec6af788b65b68fa54fe7db65a/candidates/game_web_region_017_r1/region_model.gd#L156-L200) 使用格网四邻 BFS 和对取样点进行墙判断的“explanatory occlusion proxy”；#26/#27 沿用该类型方法。
- **[静态风险]** 角部取整采样、实际玩家宽度/碰撞、地形拓扑、动态障碍物与视线体积都没有被证明；不能用于生产游戏中的真实“安全/可及”通行结论。
- **[N21 对策]** 维持明示“合成网格规则”；若未来升级 Godot 物理导航，应另立验证合同并保持旧模拟值可对照。
- **未来核验**：已授权后的格角样本/狭路/边界与真实物理代理比较，记录差异而非默认相同（A09、A10）。

## R06｜同源固定 Fixture 与额外字段放行的边界 — HIGH

- **[源]** 四份 `synthetic_regions.json` 同 SHA；[#26 region_model.gd L62–116](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_model.gd#L62-L116) 只验必需字段，不禁止额外字段；[#28 region_validator.gd L59–129](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/region_validator.gd#L59-L129) 对未知字段只给 Warning 并返回源字典副本。
- **[静态风险]** 如果未来允许任意 JSON 导入，未定义字段仍留在返回对象里；单靠“结构 ACCEPTED”不能证明内容合成性、隐私安全或下游字段白名单。
- **[N21 对策]** 当前仅允许 Git 固定合成 fixture 与程序内置合成样本；未来扩大输入范围前必须获批单独的来源/过滤策略，不继承“只警告即可任意发布”的假设。
- **未来核验**：额外字段仅警告且不得触发真实资源加载；未来公用 loader 要明确字段处理（A11、A12）。

## R07｜来源回退状态与“已修复”文案不等价 — HIGH

- **[源]** [#26 region_model.gd L40–59](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_model.gd#L40-L59) 直接选内置 fallback 并显示一次概括文字；[#28 catalog_recovery.gd L29–75](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/catalog_recovery.gd#L29-L75) 有 `SOURCE_ACCEPTED/FALLBACK_SYNTHETIC/BLOCKED` 三态，回退前核自身合成数据。
- **[静态风险]** 用户可能看到三个正常 A/B/C 而不知道外部 fixture 已失败；两套 message 也不是可直接互换的响应结构。
- **[N21 对策]** 后续一个页面始终展示：原始输入结果、最终显示数据来源、是否回退、是否阻塞；保留原错误不覆盖，不把 `SOURCE_ACCEPTED` 叫“通过游戏 QA”。
- **未来核验**：缺文件、坏 JSON、坏 fallback 三条完全不同的解释（A13、A14、A15）。

## R08｜键盘焦点、失焦和选择器在真实平台仍未知 — MEDIUM

- **[源]** [#26 region_demo.gd L211–225](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_demo.gd#L211-L225) 以窗口焦点与释放门禁判断移动；[#26 region_demo.gd L284–326](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_demo.gd#L284-L326) 将焦点文字主要识别为网格或 Button，`OptionButton` 尚未单独显示名称；#27 在其宿主新增了选择器/只读卡焦点文字类型。
- **[静态风险]** Godot 与操作系统的 Tab 顺序、Alt+Tab、持键、IME、辅助设备焦点传递未运行；不能把“源码写了防护”称真实键盘验收。
- **[N21 对策]** 后续单独授权各 OS 的键盘与无鼠标验收；合并时避免两个宿主同时获取 W/A/S/D。
- **未来核验**：窗口切回期间不自动移动、更正、吞 UI 按键，焦点文本与实际焦点一致（A16–A19）。

## R09｜高度/宽度、字号与只读卡重绘可能造成访问障碍 — MEDIUM

- **[源]** [#26 region_demo.gd L85–153](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_demo.gd#L85-L153) 左右面板设有最小宽度；[#26 map_view.gd L46–91](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/map_view.gd#L46-L91) 有最小格宽；[#27 region_demo.gd L285–320](https://github.com/cao772/game/blob/fdbb6688d07a6a7cebe36b999b82482987362499/candidates/game_web_region_019_r1/region_demo.gd#L285-L320) 在每次 `_refresh` 给 `TextEdit.text` 重新赋值。
- **[静态风险]** 在窄窗口/150% 字号时可能被裁切、滚动位置丢失或焦点跳转；`TextEdit` 即使标只读也尚无屏幕阅读器实际证据。
- **[N21 对策]** 保留 #26 字符网格和文本状态，未来先核“纯键盘读完一张长卡”与重绘前后焦点/滚动，再评估布局方案。
- **未来核验**：窄屏、放大、失焦、证据卡更新时所有操作可达（A20、A21）。

## R10｜静态结构诊断器的输入/错误限额只是候选，不是容量证明 — MEDIUM

- **[源]** [#28 region_validator.gd L4–52](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/region_validator.gd#L4-L52) 定 `MAX_INPUT_CHARS=16000`、`MAX_ISSUES=48`，其 raw string 入口会检查输入大小；[`validate_variant` L52–113](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/region_validator.gd#L52-L113) 的 Dictionary 路径不再经过该文本长度门槛。
- **[静态风险]** 如未来新增 Variant/外部输入，原先的字符数限额不能自然覆盖所有入口；错误条数截断只说明更多错误未列，不能称安全/性能完成。
- **[N21 对策]** 后续仅使用固定合成数据，迁移设计要列出各入口的大小/深度/诊断数量与拒绝策略，不从“16000”推断实测资源消耗。
- **未来核验**：超长文本、深层额外字段、满额诊断、两种入口等价性（A22–A24）。

## R11｜内存更正、撤销与固定卡不是长久审计或存档 — MEDIUM

- **[源]** [#26 region_model.gd L247–311](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_model.gd#L247-L311) 维护最多 16 步撤销与 12 条日志；[#27 region_demo.gd L178–220](https://github.com/cao772/game/blob/fdbb6688d07a6a7cebe36b999b82482987362499/candidates/game_web_region_019_r1/region_demo.gd#L178-L220) 将卡固定为内存字符串，换场/重置即清理。
- **[静态风险]** 容易被误解为“可跨地区追责证据”或与真正存档互通；目前没有批准的文件持久化/重放/事务 ID。
- **[N21 对策]** 后续 UI 必须写“只在当前会话内存，非原始数据回写”；如需正式存档，另开独立权限/版本合同任务。
- **未来核验**：撤销与重选后的主张回退、固定卡清除、关闭项目后不残留（A25、A26）。

## R12｜项目是否真的可解析/运行无法由静态审查证明 — BLOCKER（集成发布前）

- **[源]** 四个 README/ACCEPTANCE 均标 `NOT_RUN`，本次也只做 GitHub 源码回读；无法从文件存在推断 Godot 版本、GDScript 类型推断、API、控件行为或导入成功。
- **[静态风险]** 开发者若直接合并到产品并宣称可玩，将跳过第一道最基本的实际导入与回归门槛。
- **[N21 对策]** 只有作者**另行明确授权执行**时，才按 [ACCEPTANCE_PLAN.md](ACCEPTANCE_PLAN.md) 记录真实执行证据；未通过保持 Draft，不能合并 main。
- **未来核验**：Godot 实机/解析/焦点/回退/独立运行，全部由未来授权人完成；**本次一项也没有运行**（A27–A32）。

## 结论与停止条件

**可在本轮声明的唯一硬结果**是“源文件及其关系已被 GitHub 只读核对、风险与迁移候选已记录”。**不得声明**四个模块已互通、当前代码能运行、无障碍合格、结构诊断精确或可进入正式游戏。任何范围扩大到正式世界状态、共享接口、真实区域/人物或 `main` 修改都必须停止并获得新授权。
