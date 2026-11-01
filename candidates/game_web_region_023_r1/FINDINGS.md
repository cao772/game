# FINDINGS｜PR #30 源文件级静态风险与隔离修复

**审查基准：** `cao772/game` Draft PR #30 `3806fbf289dbe5bcb89bca11a98971c616ce6ab8`。审查日期为任务所在轮次。每个链接固定 SHA，不引用浮动分支作为事实来源。**所有“后果”均为静态推断，NOT_RUN。**

## F01｜阻断原因被覆盖（高；已在独立候选修复）

**源证据：** [PR #30 `validated_gateway.gd` L36–42](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/validated_gateway.gd#L36-L42) 先接收 `response.message`，随后将任何未知/阻断状态改为统一“校验或回退被阻塞”。而 [`catalog_recovery.gd` L29–40](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/catalog_recovery.gd#L29-L40) 对无效内置回退已提供独立的根因文案和 `fallback_report`。

**风险：** 主状态文案丢失内置失败/上游诊断的区分，虽然后备报告仍在 snapshot 内，读者可能只见模糊 BLOCKED。

**独立修复：** N23 `validated_gateway.gd` 保留原始 `message` 并加阻断前缀；`report` 与 `fallback_report` 保留而不合并。**未通过真实运行验证。**

## F02｜网关直接索引上游字典（高；已隔离修复）

**源证据：** [PR #30 `validated_gateway.gd` L55–70](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/validated_gateway.gd#L55-L70) 验 `original is Dictionary` 和 `id`，却直接对 `original["grid"].duplicate(true)` 与 `original["claimed"][...]` 索引，没有在映射处验证字段类型和返回的 `report.ok` 一致性。正常由 PR28 validator 接口保证完整性，此问题的触发前提是异常/被误用的返回对象，**不是已证实当前合成 JSON 会崩溃**。

**风险：** 上游合同漂移/后续复用时产生脚本异常，不能真正 fail-closed。

**独立修复：** N23 Gateway 先检查 `SOURCE_ACCEPTED` 对应 `report.ok`、`FALLBACK_SYNTHETIC` 对应 `fallback_report.ok`，再检查局部 `grid` Array、`claimed` Dictionary 与布尔字段、A/B/C 完整性。若矛盾返回 `BLOCKED`，保留原诊断，不做**第二套** JSON 校验和 fallback。防御式检查是局部合同检查，**不代替 PR28 结构验证**。

## F03｜reset 后向量残留（中；已隔离修复）

**源证据：** [PR #30 `synthetic_interaction.gd` L8–30](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/synthetic_interaction.gd#L8-L30) 定义 `_start/_target/_player`，`reset()` 只清 `_grid/_id/_claim`、历史等，未重置三个向量；[`snapshot()` L181–194](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/synthetic_interaction.gd#L181-L194) 仍返回其值。

**风险：** 即便 `ready=false`，旧坐标也可能残留在只读快照中，使后续 UI 或调用者混淆阻断前后状态。

**独立修复：** N23 `reset()` 将三个向量同时置零，且依然清除核对/预览/撤销/日志。UI 应继续以 `ready` 为唯一活动状态指示，零向量**不表示**有效的起点。

## F04｜资源读取前缺文件字节上限（中；已隔离修复）

**源证据：** [PR #30 `catalog_recovery.gd` L60–74](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/catalog_recovery.gd#L60-L74) 对固定可选资源采用 `file.get_as_text()` 全文读取；实际 `region_validator.gd` [L34–50](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/region_validator.gd#L34-L50) 的 16000 字符上限发生在读取完成之后。

**风险：** 资源被错误替换成大文件时，长度拒绝不能限制此前的读取成本；当前仓库原 fixture 很小，**不是当前已经发生的资源超用**。

**独立修复：** N23 在单一 `catalog_recovery` 文件入口增加候选读取前检查 `file.get_length() > 65536` 字节，返回 `FILE_TOO_LARGE` 和清楚的 `FALLBACK_SYNTHETIC` 源报告；后续仍由 PR28 原 16000 字符检查拦截文本。65536 为**候选假设上限，非测试/性能测量**。不寻找替代真实文件。

## F05｜诊断省略问题原因（中；已隔离修复）

**源证据：** [PR #30 `integration_demo.gd` L176–204](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/integration_demo.gd#L176-L204) 使用 `code/path/action` 展示诊断；源 `region_validator.gd` [L12–17](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/region_validator.gd#L12-L17) 还定义了 `message`，但 UI 未输出该字段。

**风险：** 错误列表缺少“为什么失败”的解释；即使能看到修复动作也不易理解。

**独立修复：** N23 UI 逐项显示“级别、代码、路径、原因、处理”，内置 fallback 的错误也同样展示原因。无颜色专属信息。

## F06｜只读诊断区反复重绘（中；已隔离修复但需实机验证）

**源证据：** [PR #30 `integration_demo.gd` L207–221](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/integration_demo.gd#L207-L221) 每个本地动作都重新给两个 `TextEdit.text` 赋值。

**风险：** 即使诊断来源没有变化，刷新也可能打断阅读位置或选择状态。

**独立修复：** N23 添加本地 `_set_readonly_text`：内容不变则不重设；内容改变时尝试保留 `scroll_vertical` 行。**特别注意：Godot 实际焦点、滚动和 TextEdit 行为完全未验证，此项不能宣称已解决屏幕阅读器问题。**

## F07｜独立 Godot 根路径的调用前提（中；仅标注未来验收）

**源证据：** [PR #30 `project.godot` L4–14](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/project.godot#L4-L14)、[`main.tscn` L1–12](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/main.tscn#L1-L12) 与 [`validated_gateway.gd` L5–6](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/validated_gateway.gd#L5-L6) 指向 `res://` 根资源；[`catalog_recovery.gd` L3–4](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/catalog_recovery.gd#L3-L4) 固定 `res://synthetic_regions.json`。

**风险：** 如果把仓库根错误地当作 Godot 项目根（或将文件平铺到其他候选工程），则绝对 res 路径将找不到资源/产生重名。此处**不是已观察到路径缺失**，因为原代码按独立子目录为根设计。

**处理：** N23 继续提供完整独立项目，不动任何共享资源根。详见 `RESOURCE_PATHS.md`；未来应分别用正确/错误根验证失败特征。默认缺必需脚本为 BLOCK，不伪造降级成功。

## F08｜仍未解决、不能从源码确认的质量问题

- 原样沿用的 PR28 `region_validator.gd` 和结构报错路径 **没有运行证据**；静态存在并不能保证 Godot 4 解析或某些内置 API 可用。
- `synthetic_interaction.gd` 的 BFS 与网格取样 LOS 不是 NavMesh/真实物理/无障碍安全路径，角落、贴墙和移动体碰撞仍未知。
- `undo()` 是**有界内存栈**，不是长期存档、事件重放或跨场景审计。见 [PR #30 `synthetic_interaction.gd` L113–121、L169–179](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/synthetic_interaction.gd#L113-L179)。
- 验证器的 `validate_variant` 入口不承诺与文本入口相同的原始文件大小限制。新补的字节门禁只保护固定本地文件读取。
- UI 字体、窗口缩放、屏幕阅读器、Godot 版本和性能均没有实测；所有指标未知。
- 本次代码更改完全是**未执行候选修复**，不能把 F01–F06 标为“实测修复已通过”。

**全体结论状态：NOT_RUN。**
