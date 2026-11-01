# FUTURE_ACCEPTANCE｜N22 条件验收表

**全部 = NOT_RUN。没有执行代码、Godot、解析器、测试、GUI、CI、无障碍评测或跑分。** 以下案例是未来在作者另行授权后才可以开始的验收方案，预期结果不等于通过结论。

| ID | 对应 N21 风险 | 未来授权步骤 | 预期结论；若不满足须记录失败 |
| --- | --- | --- | --- |
| G01 | R01/R12 | 按 `candidates/game_web_region_022_r1/` 独立项目根导入 Godot 4 | `main.tscn` / preload 都存在且能导入；否则 BLOCK |
| G02 | R01 | 对比 PR #28/#29 的所有原目录和 N22 项目树 | 没有覆盖原脚本/主场景/共享接口 |
| G03 | R02 | 加载固定合法合成 fixture | 单个 PR28 recovery 入口报告 `SOURCE_ACCEPTED`，模型接收 A/B/C |
| G04 | R02/R07 | 缺失本地可选 JSON | `FILE_MISSING` + `FALLBACK_SYNTHETIC`；没有第二套 fallback |
| G05 | R02/R07 | 输入坏版本 / 重复 ID / 缺 T | 保留原 issue 代码、路径/处理建议；回退明确标记 |
| G06 | R07 | 使内置合成后备也不合法 | `BLOCKED`，模型清零，所有动作无效果 |
| G07 | R02 | 人为传未知 `mode`（仅隔离副本） | 网关阻断；没有自动打开 A |
| G08 | R06 | 注入额外字段并保持结构合法 | 上游显示 Warning，但下游模型只得到 id/grid/claimed |
| G09 | R03 | 选择结构合法且目标隔断的 C | `SOURCE_ACCEPTED` 不等于“可达”，T 路线不可用 |
| G10 | R03/R05 | 在 A 从 S 观察障碍并预览 T | BFS 与示意 LOS 结果分开；没有宣称物理安全 |
| G11 | R03 | B 的 claim 故意与模拟结果不一致 | 需要 Inspect 才揭示观察，Correct 必须另点击 |
| G12 | R04 | 未按 Inspect 看 `snapshot().actual` | 必须是空字典；界面写“未核对” |
| G13 | R04 | Inspect 后合法移动一格 | 旧观察失效；更正前必须再 Inspect |
| G14 | R04/R11 | Inspect→Correct→Undo | 仅内存 claim 回退，核对状态失效，fixture SHA 不变 |
| G15 | R11 | 选择 A→B→A | 位置/更正/撤销不跨场景继承 |
| G16 | R03/R05 | 点击向墙或地图边界移动 | 模型拒绝；原坐标不变，返回 S 可独立请求 |
| G17 | R11 | 超过 16 次撤销快照、12 条日志（候选限额） | 资源有界、不跨场景，不宣称性能预算达标 |
| G18 | R08 | 全键盘 Tab/Shift+Tab/Enter/Space | 按钮能完成场景切换、移动、核对、更正、撤销 |
| G19 | R08 | 焦点在文本框/选择器时按箭头 | 不能误触交互移动；无全局 InputMap 冲突 |
| G20 | R09 | 窄视窗、大字、长诊断、无声/无色 | 所有错误/来源/当前状态可阅读；记录实际失败 |
| G21 | R10 | 文本输入超过 PR28 16000 字候选限额 | 被上游拒绝；不得冒充真实容量跑分 |
| G22 | R10 | 输入 Variant 有深层附加字段（纯合成） | 检查上游限额差异；不声明与文本入口等价 |
| G23 | R10 | 诊断超出 48 条 | 显示已截断，原数据不能被判合格 |
| G24 | R12 | 真实运行时采集版本/耗时/内存/截图 | 只有授权且真实取证才允许填数；不得编造 |
| G25 | 隔离 | GitHub compare `main...N22` 与其他 PR heads | N22 只新增自己目录；`main`、#28/#29 保持独立 Draft |
| G26 | 隔离 | 逐文件检查数据内容 | 仅公开合成 A/B/C；没有真实剧情、地点、人物、私密材料 |

**建议未来执行报告结构（仅文档，非当前文件生成结果）：** `case_id`、`commit_sha`、`Godot_version`、`OS`、`executed_at`、`input_case`、`expected`、`observed`、`status: PASS|FAIL|BLOCKED|NOT_RUN`、`evidence`、`notes`。本轮所有条目仅 `NOT_RUN`，不能填写编造的运行时间、通过率、FPS、资源占用或 CI。

**不能进入正式合并的条件：** 缺少原始来源/回退说明、无效结构仍可操作、未核对即展示 actual、额外字段直接进入模型、源目录被覆盖、必需脚本找不到但宣称已恢复，或 Godot 未运行却宣称功能 PASS。默认保持 Draft，**绝不自动合并 main**。
