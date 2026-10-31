# GAME-WEB-PERF-006 r1｜独立性能证据来源追踪与缺测分类候选

**状态：NOT_RUN。** 作者本轮只批准研发：未执行任何Python、JavaScript、Node测试、Godot、浏览器预览、真实或合成跑分。只通过GitHub接口读取、提交并回读公开技术候选。

## 1. 实际代码输入与边界

读取时确认仓库 `cao772/game` 的 Draft PR [#22](https://github.com/cao772/game/pull/22) 为 `open/draft`，HEAD：

```text
36fe0aa8a040f17ea227f201b6636785e14a9809
```

本次直接基于该HEAD的 `codex/perf-evidence-browser-r1` 分支继续。实际已读取 `tools/perf_evidence_browser/model.js`、`cohort.js`、`app.js`、`index.html`，并核对现有 `docs/perf-evidence-browser-candidate.md` 和未来验收测试结构。

既有浏览器能导入PERF-002分析器、PR #12 单次摘要和多run摘要，用同一份候选预算展示观测和缺测；此前已能按2–12份报告比较，却缺少独立的、结构化**来源证据阶段**及分类完备的缺测汇总。故本次以新增纯模型方式补充，不重写其他窗口的采样器和分析器。

**不修改：** `main`、PR#2/PR#12对应文件、Godot脚本、小说正文、原稿、已批准正史、任何共享API和真实私有证据。

## 2. 模块交付与接口（候选，不是批准的共享接口）

| 路径 | 职责 |
|---|---|
| `tools/perf_evidence_browser/trace.js` | 新增纯数据模块：缺测类别、报告内部证据链阶段、各run缺口、来源元信息与会话质量概览 |
| `tools/perf_evidence_browser/model.js` | 仍只负责原JSON规范化；新增 `missingKind` 区分空/null与非数值、负数或布尔 |
| `tools/perf_evidence_browser/cohort.js` | 仍按2–12份独立报告描述性比较；新增每格的`missingCategory`与缺测索引类别 |
| `tools/perf_evidence_browser/index.html` | 通过`model.js → trace.js → cohort.js → app.js`加载本地脚本；增设单独来源追踪区 |
| `tools/perf_evidence_browser/app.js` | 单次详情显示证据链、来源声明、指标缺测分类、整体场景待测；多报告页面同时显示缺测类别概览和逐格原因 |
| `tests/test_perf_evidence_trace_candidate.js` | PF01–PF17未来验收样本（仅合成字典，未执行） |
| `tests/test_perf_evidence_browser_cohort_candidate.js` | PB20–PB21新增未来比较覆盖测试（未执行） |
| 本文档 | 模块级设计、集成、缺测与真实性约束、未来验收标准 |

`trace.js` 的主要纯函数（仅**内部候选**）为 `traceReport(normalizedReport)`、`traceSelection(normalizedReports)`、`metricGaps(report)`。它们只读取 `model.js`已规范化的内存对象，不打开额外文件、不调用后端、不取本机进程、不做网络请求，也不向第三方发送任何内容。不是新正式JSON Schema；不修改上游协议。

### 浏览器本地集成（未来验收时使用，本轮没有执行）

```text
tools/perf_evidence_browser/index.html
```

页面原有选文件/拖入`.json`、最多40份、2–12份横向比较、无上传、无持久化的行为保留。新区域「来源追踪与缺测分类」与既有详细报告并行呈现，不执行新的采样、分析或存档操作。全部来源文本由`textContent`安全渲染；原CSP禁止网络连接。

### 未来可运行验收命令（NOT_RUN）

```text
node --test tests/test_perf_evidence_trace_candidate.js
node --test tests/test_perf_evidence_browser_candidate.js
node --test tests/test_perf_evidence_browser_cohort_candidate.js
```

最终作者决定是否授权执行。现阶段GitHub中新建的测试只是**未来验收用例**，其存在不代表PASS；即便仓库自动运行CI，也不应写成本任务完成验收。

## 3. 缺测分类：值、格式与来源是不同维度

本候选建立如下固定分类，保留相应原因及run/报告标识，不以0代替：

| 类别 | 严格含义 | 展示原则 |
|---|---|---|
| `NOT_MEASURED` | 没有有效观测（字段缺失、null或某组所有run未测） | 显示「未测」，观测值null |
| `INVALID_VALUE` | 字段存在，但非数字、布尔、负数或非有限 | 明示非法值，不自动修正 |
| `INCONSISTENT_INPUT` | 来源状态、指标定义、预算口径、重复字段、检查与统计不一致等导致不可采信 | 保留数值作可见原声明，禁止把它当可信观测与其他结果聚合 |
| `PARTIAL_COVERAGE` | 同组仅有部分run具备合法数值 | 保留有效数量与缺失run IDs，不称全量 |
| `SOURCE_CONFLICT` | 来源声明冲突（如合成/非合成混合、headless/dummy环境被用作GPU对照） | 不进行真实性能结论 |
| `UNVERIFIED_ORIGIN` | 可以阅读报告，但无法核对原CSV、采集标识/时间窗口/场景文件或运行环境 | 始终标「未经独立验真」 |
| `OUT_OF_SCOPE` | 全场景所需冷启动、场景切换、灯光、NPC等尚未从当前报告获得 | 显示为待独立测量，而非超出预算或已经通过 |

**关键语义：** `NOT_MEASURED`和`INVALID_VALUE`不是同一回事；一项数值存在但校验失败属于`INCONSISTENT_INPUT`，不是将原数值改成0；`SOURCE_CONFLICT`及`UNVERIFIED_ORIGIN`则是来源可信度，不是每一帧的CPU/GPU观测值。所有预算上限为此前PERF-001/r1**未经批准的提案**，没有任何来源被本模块提升为正式性能通过。

## 4. 来源追踪采用「证据阶段」而非伪造哈希

每个导入对象只提供四个明确的**证据阶段**：

1. `RAW_CAPTURE / NOT_VERIFIED`：尚未核验真实CSV字节、采样设备、进程创建身份、帧与CPU时间口径。
2. `PERF_002_ANALYZER / DECLARED_REPORT_INPUT | NOT_LINKED`：导入分析器JSON时只确认其字段结构与来源声明，下游摘要未直接关联原分析结果。
3. `PR12_REPORT / DECLARED_REPORT_INPUT | NOT_APPLICABLE`：导入单次/series摘要时只看得到其报告结构，不声称已拿到全部上游证据。
4. `LOCAL_BROWSER / PARSED_UNVERIFIED`：浏览器仅解析了用户手动选择的本地文件；**解析成功不等于可信原件验证**。

同时展示 `reportTaskId`、报告类型、用户选择文件名、来源类别、声明的Godot引擎版本、后端及场景SHA256。如果字段未提供，直接写「未提供」。绝不生成随机或假设的哈希，更不声称已核验场景、GPU驱动、采样时序或报告独立性。

所有 `sceneHashVerified`、`rawCsvSha256Verified`、`binaryExeVerified`、`captureAssociationVerified`、`independentRepeatVerified`均为**false**，后续只有新的、经过作者授权的原始证据验证流程才能改变这些结论。本模块不提供篡改这些标记的接口。

**隐私理由：** 不把PERF-002 `source`原始路径、Windows进程命令行、私密剧情、聊天内容或环境变量复制到追踪结果；只处理现有摘要的声明字段和当前文件名。浏览器无需文件系统访问权、服务端或认证配置。

## 5. 多报告比较的保守边界

- 与上一阶段一致：按用户勾选的2–12份独立单次报告显示逐项观测和对照，不对多个P95/P99拼接逐帧数据。默认基准必须由用户选定。
- 通过 `cohort.js` 将每个不可用单元格标为`NOT_MEASURED`、`INVALID_VALUE`或`INCONSISTENT_INPUT`，在横向矩阵的对应文件/指标列附加分类与原有原因；分类是浏览器内审阅语义，**不是原CSV的真实测量事件**。
- 同一套浏览器会话可汇总不同报告的缺测类别出现次数；这些次数是「缺口或未验证声明计数」，不应变成「测试通过数」。
- 若来源冲突、预算不一致或缺测，已有保守比较逻辑仍以`NOT_COMPARABLE`、`null`阻止不正当差值；就算算得delta，也只能标为`NUMERIC_ONLY`。
- **相同场景哈希不等于独立采样**；不同文件名、相同大小/修改时间也不能构成哈希证明。既有`seenFiles`仅是UI重复选择保护，不是内容去重或可靠证据鉴定。
- Windows进程工作集与private commit仍是独立旁路，不给逐帧`ram_gib`补值；脚本CPU、VRAM和真实GPU执行时间缺测时保持缺测。

## 6. 未来验收矩阵与待决（全部NOT_RUN）

| ID | 待验收条件 | 预期 |
|---|---|---|
| PF01 | 合成来源报告导入 | 标SYNTHETIC，不可能成为真实GPU通过 |
| PF02 | 指标值为null | NOT_MEASURED，不填0 |
| PF03 | 布尔、负数、字符串观测 | INVALID_VALUE，与未测区分 |
| PF04 | 已有值但预算不一致 | INCONSISTENT_INPUT，不采信差值 |
| PF05 | 下游摘要有报告声明、无CSV | RAW_CAPTURE仍NOT_VERIFIED |
| PF06 | 声明引擎/场景SHA | 只展示，验证标志依然false |
| PF07 | 场景SHA缺失 | 标UNVERIFIED_ORIGIN，显示未提供 |
| PF08 | headless/dummy | SOURCE_CONFLICT，不算GPU跑分 |
| PF09 | 冷启动/切换/灯光/NPC | OUT_OF_SCOPE，不判通过 |
| PF10 | 多份报告导入 | 汇总缺口，不把报告数作为测试数 |
| PF11 | 超过40份 | 拒绝计算，不扫描文件 |
| PF12 | 未知对象 | 拒绝，不猜测格式 |
| PF13 | 构建追踪信息 | 原对象保持不变 |
| PF14 | 输入报告含私密本机路径 | 追踪对象不得拷贝该路径 |
| PF15 | series完整/部分/缺测 | 分类不混淆，正确保留run状态 |
| PF16 | 页面包含trace.js | CSP无外联且仅文本安全插入 |
| PF17 | 两个报告相同场景哈希 | 独立采样验证仍false |
| PB20 | 跨报告出现未测指标 | 对应记录附缺测类别、理由，median为null |
| PB21 | 跨报告存在不可采信数值 | 分类INCONSISTENT_INPUT，不生成delta |

还须未来浏览器人工核验：加载脚本顺序、单次/series/横向对照呈现、语义化表格与移动窄屏、拖入错误文件时拒导入、CSP实际执行情况、各字段缺失显示、刷新/清空会话是否不保留数据。

### 明确缺少的关键输入

本任务没有被提供且不自行索取或上传真实Godot采集的原始CSV、采样窗口、机器驱动/设备清单、散列绑定、Windows进程身份、脚本CPU可靠计时、显存真实观测及其他全场景指标。因此无从核实真正的场景预算是否通过。之前PERF-003提到的OpenGL 62帧只能作为用户报告的背景，不是本模块实际复现的跑分。

## 7. 交付记录包与归档

```text
task_id: GAME-WEB-PERF-006
version: r1
input_version: Draft PR #22 initial HEAD 36fe0aa8 + PR #12 dependencies
scope: only codex/perf-evidence-browser-r1
deliverable: trace.js + model/cohort/app/index updates + future tests + documentation
acceptance: PF01..PF17, PB20..PB21 and browser manual review; NOT_RUN
status: NOT_RUN / AUTHOR_FINAL_REVIEW_PENDING
GitHub: Draft PR #22, no merge
Notion: NOT_UPDATED
Drive: NOT_UPDATED
main: NOT_CHANGED
other PRs: NOT_CHANGED
private data: NOT_UPLOADED
```

不得将实现候选认定为已验收软件、已批准共享接口、已批准正史或实际GPU/CPU性能结论。
