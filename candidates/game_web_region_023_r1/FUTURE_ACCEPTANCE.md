# FUTURE_ACCEPTANCE｜N23 原码修订候选验收清单

**全表状态：NOT_RUN。所有步骤均只供作者将来另行授权后执行。没有运行 Godot、项目代码、解析器、单元/集成/GUI 测试、CI 或性能采样；期望结果不是实际 PASS。**

| 编号 | 对应问题 | 未来获授权后的操作 | 预期结果及失败判据 |
| --- | --- | --- | --- |
| I01 | F07 | 以 `candidates/game_web_region_023_r1/` 为 Godot 工程根导入 | `main.tscn` 及 7 个 GDScript（含直接/间接预载）均被解析；任何导入错误都记录 BLOCKED |
| I02 | F07 | 核对所有 `res://` 的依赖路径 | 必需脚本均解析到 N23 子项目自身，不引用 #30/main 的同名文件 |
| I03 | F07 | 以错误的仓库根尝试导入（隔离环境） | 明确显示缺项目文件或资源路径错误，不误判为游戏可运行 |
| V01 | F02 | 从固定公开 A/B/C JSON 加载 | `SOURCE_ACCEPTED`，三场景可选择，原报告 `ok=true`；结构接受不等于可达性 PASS |
| V02 | F02 | 传仅合成数据的缺 `grid` / 缺 `claimed` 异常返回（需授权隔离测试夹具） | 网关 `BLOCKED` 而非越过类型门禁，清空旧场景和撤销历史 |
| V03 | F02 | 构造 `SOURCE_ACCEPTED` 但 `report.ok=false` 的异常返回 | 按上游合同矛盾阻断；绝不使用旧已加载 A/B/C |
| V04 | F02 | 构造 `FALLBACK_SYNTHETIC` 但 `fallback_report.ok=false` 的异常返回 | 进入 BLOCKED，保留诊断，不重新执行第二套 fallback |
| V05 | F02 | 构造来源模式为未知字符串 | 按 BLOCKED 处理，不启动场景，不吞掉原说明 |
| V06 | F01 | 让内置合成后备自行校验失败（隔离副本） | 主文案指出后备失败，`fallback_report` 显示原代码/路径/修复动作，不只显示模糊阻断 |
| V07 | F01 | 错版本、重复 ID 和缺 T 三份合成例各输入一次 | 原始 `report` 不被 fallback 覆盖；显示错误原因与来源 |
| V08 | F04 | 取消可选 `synthetic_regions.json`（隔离副本） | `FILE_MISSING` 之后仅使用明示后备合成 A/B/C，不改源文件 |
| V09 | F04 | 将固定可选合成 JSON 文件替换成超候选 `65536` 字节的合成内容 | 读正文前拒绝，显示 `FILE_TOO_LARGE`；此阈值不是实测安全容量 |
| V10 | F04 | 字节数不超限而 JSON 字符数超 PR28 原 `16000` 字符限额 | 后续结构校验拒绝且回退可区分；不能将字符/字节两套上限混称 |
| V11 | F04 | 让可选本地文件不可读（隔离副本） | 有 `FILE_UNREADABLE`，不搜索其他路径、私有文件、外部 URL |
| M01 | F03 | 在 A 里移动并加载新的坏版本，触发回退/阻断切换 | `ready=false` 时旧起点/目标/玩家坐标已清空；UI 不引用旧已核对坐标 |
| M02 | F03 | 执行 Inspect → 有效移动 → 查看 snapshot | `inspected=false`，`actual={}`；无需顾虑旧观察残留 |
| M03 | F03 | Inspect → Correct → Undo → 查看 snapshot | 只撤销最近一次内存更正，旧观察失效；原 JSON SHA 不变 |
| M04 | F03 | 切换 A→C→B，保存内存快照对照 | 三个场景的坐标、主张与撤销队列均不互相继承 |
| M05 | 仍未知 | 对断路的 C 执行“到 T”与“返回 S” | C 结构合法但 T 不可达；路线/观察不得冒充物理安全论证 |
| D01 | F05 | 用合成数据触发 `VERSION` / `DUPLICATE_ID` / `TARGET_COUNT` | 每条 UI 诊断含级别、代码、字段路径、**原因**、可操作修复建议 |
| D02 | F05 | 让后备自检失败（隔离副本） | 除主文案外，还能读到后备报告的原因与修复建议 |
| D03 | F06 | 打开长错误列表，滚动后仅移动当前合成 P | 若报告文本未变化，不应重新赋值打断阅读位置；记录真实焦点/滚动 |
| D04 | F06 | 更换错误输入后重新刷新文本框 | 有变化时尽量保留滚动行，不遮蔽新的阻断提示；若失败记 FAIL |
| D05 | F06 | 在窄窗口、文本放大和键盘 Tab 导航下读完错误原因 | 焦点和滚动均可到达；不得凭 Label/TextEdit 存在宣称无障碍合格 |
| B01 | 隔离 | 比对新分支与 main 的 changed files | 全部为 `candidates/game_web_region_023_r1/` 的新增文件，0 原文件覆盖 |
| B02 | 隔离 | 对比源 PR #30 HEAD | HEAD 保持 `3806fbf...` 不变；N23 不叠加其分支 |
| B03 | 隔离 | 对比 `region_validator.gd` 与原 PR #30 Git blob | 同一字节内容，原结构规则没有被默改 |
| B04 | 隔离 | 搜查全部 N23 新提交 | 仅公开合成 A/B/C；不含真实剧情、地点、人物、原稿或聊天资料 |
| B05 | 用户限制 | 审查本轮交付状态 | 全部标 `NOT_RUN`；不得把源码成功提交、GitHub compare 或手写用例宣称运行通过 |

## 实际未来验收证据模板（仅提议，未生成任何实测记录）

`case_id`、`exact_commit_sha`、`Godot_version`、`platform`、`date`、`input_source`、`expected`、`observed`、`result (PASS|FAIL|BLOCKED|NOT_RUN)`、`notes`、`evidence`。所有这些实际字段目前除 `case_id` 和 `expected` 外都不能擅自填写“运行成功”。

## 重要验收边界

构造的异常 return response 不是 PR #30 当前公开 JSON 的正常输入路径；它用于未来故障注入检查防御语义。没有这类真实执行，F01–F06 **只能标源码修订候选，不能宣称 bug 复现或修复验收通过**。若发现 Godot API/类型/资源路径问题，应在后续授权窗口修订独立 PR，保持旧原件和当前审查记录。**全部 NOT_RUN。**
