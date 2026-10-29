# GAME-WEB-FLOW-PERF-004｜离线性能证据浏览器候选 r1

> **状态：NOT_RUN / 待作者最终验收。** 本任务只开发并提交源码、设计和未来验收用例；不执行任何代码、测试、页面预览或跑分。此处任何字段和页面均为试验提案，不构成批准的共享接口、性能预算、游戏正史或原稿修改。

## 1. 来源与依赖

2026-10-29 读取 `cao772/game` 的 [Draft PR #12](https://github.com/cao772/game/pull/12)，核对其 HEAD `f04726c7e351d4592d7df20d8cacf95803352557` 的真实源码及技术说明：

- `tools/perf_report_candidate.py`：PERF-002 JSON → 单次摘要 `*.summary.json`、HTML；支持一份基线作数值对比，`whole_scene_status=INCOMPLETE`，`full_scene_pass=false`；预算仅为未批准提案。
- `tools/perf_series_candidate.py`：`schema=perf-series-report-v1` 的多次采样分组摘要，按各次统计量再取min/median/max，不能误称合并帧P99；保留各次missing_runs与来源声明。
- `tools/perf_analyze_candidate.py`（PR #12依赖PR #2）：直接输入逐帧CSV分析后可得到 `checks`、`stats`、`sample_count`、`errors`；最近秩分位数无插值；缺列和无效值是INCOMPLETE。
- `docs/perf-report-candidate.md`、已有未来单元测试：明确脚本CPU、VRAM、RAM等不可由帧间隔或Windows工作集猜测，headless/dummy不能冒充GPU跑分。

**新分支 `codex/perf-evidence-browser-r1` 基于PR #12当前HEAD独立创建，Draft PR以PR #12的分支为基线（stacked），不改main、PR #12的既有文件或任何其他候选。**

## 2. 交付范围（独立4文件）

| 文件 | 作用 |
|---|---|
| `tools/perf_evidence_browser/index.html` | 浏览器外壳、选择多个JSON/拖放、搜索、来源筛选、单次详情和两份报告数值对比 |
| `tools/perf_evidence_browser/model.js` | 无副作用的纯规范化模块；保守判定已知格式、指标缺测、来源声明、合成/非GPU限制、数值对比 |
| `tools/perf_evidence_browser/app.js` | 本地File API加载、会话内证据列表、来源元信息、缺测原因/Windows内存旁路展示、对比交互 |
| `tools/perf_evidence_browser/style.css` | 无外部资源的响应式界面 |
| `tests/test_perf_evidence_browser_candidate.js` | 23个未来验收案例（Node内置`node:test`，只含合成结构，不含任何实际游戏结果） |
| 本文档 | 独立使用说明、设计理由、格式契约、局限、验收清单 |

注：上述**实现及测试均未运行**；不应把新增测试文件理解为已通过测试。

## 3. 浏览器使用（只供后续获授权时执行）

用浏览器打开：

```text
tools/perf_evidence_browser/index.html
```

在页面选择多个 `.json` 或拖放文件。无需服务端，不上传，不保存到浏览器存储，不读取未选择的目录。不接收场景文件、对话、小说材料。浏览器原生文件选择后仅使用 `File.text()` 读入所选内容；关闭/刷新后内存会话清空；“清空会话”按钮亦清空当前页面中的已导入对象。最多**40份**，单份文件**2,000,000字节**，解码后也设有字符上限。错误文件单独列出，不伪造替代数据。

前端文件全部本地，CSP：`default-src 'none'`，仅允许同源脚本/样式，`connect-src 'none'`。不依赖CDN、网络字体、图片或遥测。部分浏览器对`file://`同源脚本有额外策略限制，**此处未实测**，需要未来人工检查；受限时应提供授权的仅监听127.0.0.1的本地静态预览，不得为了运行而取消安全边界或调用公网服务。

未来验收用命令（**本轮不执行**）：

```text
node --test tests/test_perf_evidence_browser_candidate.js
```

用户只做最终验收；常规设计取舍见下文，不再逐项询问。

## 4. 已支持的三类真实来源格式

### A. PERF-002分析器JSON

特征：`task_id=GAME-WEB-PERF-002`，含`checks`和`stats`。匹配8项固定字段。先检查`version=r1`、`sample_count>0`、`error_count=0`、`errors=[]`、最近秩分位定义、`status=incomplete`、`full_scene_pass=false`、各项`checks.value`与`stats`同值及预算一致。任一不一致不得判为“在提案范围内”。**仅凭分析器JSON没有来源元数据，来源分类固定为UNVERIFIED**，即使数值看起来漂亮也不是核验的真实跑分。

### B. PR #12 单次 `*.summary.json`

特征：`metrics[]`与`whole_scene_status`。展示每项`observed`、`budget`与来源状态。固定的8项预算在页面上标为`UNAPPROVED_PROPOSAL`，与数值字段严格分列。数据为null、字符串、布尔、负数、无效或来源状态冲突时不能视为完成测量。若包含`capture.origin`、`engine_version`、`renderer`、`scene_sha256`，在单独的来源信息区显示。内存观测`process_memory`（working_set/private_bytes）独立展示，**绝不自动填进逐帧RAM，私有提交也不是物理RAM**。

### C. PR #12 多次 `*.summary.json`（`schema=perf-series-report-v1`）

读取`groups[].runs`和`groups[].metrics`，显示每组每项的min/median/max、有效次数/总次数、`COMPLETE_NUMERIC` / `PARTIAL` / `NOT_MEASURED` / `INCOMPLETE`覆盖状态；同时逐个展示`missing_runs`的run ID、缺失状态和原因，以及每次run的来源声明。

注意：这里的中位数是**每次run级统计量的中位数**，不是逐帧数据拼接后的P95/P99。**不允许**把分组报告像普通单次逐帧报告那样放到两份文件的差值比较中。分组来源混合合成与非合成时标为CONFLICT。

## 5. 来源、预算和观测必须分离

页面的四个关键维度：

1. **来源（provenance）**：
   - `SYNTHETIC`：来源声明合成；不得展示为真实游戏跑分。
   - `DECLARED_REAL_UNVERIFIED`：来源声明不是合成；**并非已经验证实测**，缺少CSV/元数据哈希、进程身份、设备环境等绑定证据。
   - `NOT_GPU_BENCHMARK`：headless/dummy等后端不符合GPU跑分条件。
   - `CONFLICT`：合成/非合成冲突或跨run来源混杂。
   - `UNVERIFIED`：来源缺失或不明。默认保守落在此类。
2. **预算（budget）**：12/16.7/24ms、2ms脚本P95、1.2GiB RAM、1GiB VRAM增量、200绘制调用和15万三角形均来自上一阶段的**未批准预算提案**。这些常数只用于显示旁边的参考预算，不会写入`observed`。
3. **观测（observed）**：导入的有效数值原样展示，缺失/不可信字段保持null并写明原因。零值若确实在原JSON里就是零数值，但**不会据此判定场景通过或来源真实**。
4. **整体状态**：统一固定`wholeSceneStatus=INCOMPLETE`、`fullScenePass=false`、`budgetApproved=false`和`gpuBenchmarkVerified=false`。来源的PASS字样仅作为`sourceStatus`展示，页面用`WITHIN_PROPOSAL`、`OVER_PROPOSAL`、`NOT_MEASURED`、`INCOMPLETE`解释，不显示“整体PASS”。

### 缺失或冲突输入

- 不识别的JSON结构、无效JSON、超长文件：拒绝导入并展示原因。
- 检测到来源声称完整场景PASS：添加警告，页面仍强制INCOMPLETE。
- 分析器缺少P95脚本时间或VRAM：只显示对应缺测；**不能用0、帧间隔、CPU总时间或Windows工作集填补**。
- 系列报告采样次数、指标覆盖计数或最小/中位/最大顺序不一致：该组指标降级INCOMPLETE，不伪造数值。
- 缺少场景哈希或渲染后端：显示“未提供”；即使声明真实也只列“未核实”。
- 本浏览器未读取或独立校验原始CSV、Windows进程身份、GPU/VRAM真实监控；无从保证来源文件没有被修改。**浏览器JSON.parse不验证重复JSON键，也不具备完整加密证据链；任何输入均保持UNVERIFIED_INPUT。** 需要可信证据时未来验收阶段再增加原始哈希与身份核对，不能自动冒充已实现。

## 6. 两份报告的差值功能（试验提案）

仅支持单次候选报告或PERF-002分析器JSON两份之间、相同指标键且有合法观测值时的差值。UI允许指定“基线”和“本次”，不依据文件名猜测时间先后。

```text
delta = 本次有效观测 - 基线有效观测
delta_percent = delta / 基线有效观测 × 100%
```

若基线0，变化率null；若任一项缺测/冲突/来源预算不一致，差值null/`NOT_COMPARABLE`。合成与声明非合成、引擎/渲染器/场景哈希出现已知冲突时禁止计算对应差值。没有可核验的设备、VSync、分辨率与采样窗口，同样**只能称NUMERIC_ONLY，不能称真实性能改善或通过预算**。多次run组合应在PR #12原多次报告模块生成独立分组摘要，浏览器只展示，不重算逐帧分位数。

## 7. 选择纯浏览器端的理由

- 目标是**查看已有报告**，不是再次执行Godot、Python分析或本地PID采样。File API完全离线，只读、无服务器配置，避免意外上传私密场景或聊天证据。
- 将`model.js`与`app.js`分离：前者只有可验证的纯函数，后者负责DOM操作。未来可以在不打开真实游戏数据的情况下，用Node自带`node:test`验收数据契约；不能直接把测试用例存在当作已测试。
- 采用清单＋详情＋两文件描述性对照，避免用漂亮图表掩盖缺测或混合来源；缺测原因和来源声明作为一等字段展示。
- 限制导入数量/大小、转义文本（DOM仅使用`textContent`、`createElement`）并用CSP禁用请求，减少数据泄露、HTML注入和资源消耗风险。
- 明确不实现导出、持久化存储、服务端接入、自动采集或共享协议，这些未经作者批准，不应混进独立技术候选。

## 8. 未来验收（全部NOT_RUN）

`tests/test_perf_evidence_browser_candidate.js` 定义24个未来合成输入用例：FB01原分析器预算与观测分列；FB02缺失脚本时间；FB03错误计数；FB04统计字段矛盾；FB05合成声明；FB06仅声明真实仍未验证；FB07非GPU后端；FB08来源矛盾；FB09预算缺失；FB10非法/零/负/字符串观测；FB11无效JSON；FB12系列run级中位数；FB13全缺测；FB14覆盖与次序异常；FB15混合来源；FB16描述性delta；FB17来源冲突无delta；FB18缺测无delta；FB19分组/单次禁止直接对照；FB20 HTML离线安全边界；FB21输入大小；FB22来源整体PASS声明拒采信；FB23进程内存与逐帧RAM隔离；FB24分组每个run的引擎版本、渲染后端、场景哈希和原始告警保留显示。

后续获授权时还须由Codex进行**真实浏览器人工检查**：多文件选择、重复选择、拖入、键盘操作、窄屏、警告显示、CSP阻止远程请求、Chrome/Edge/Firefox本地文件兼容。当前**不运行、不显示PASS、不以CI成功当成本任务验收**。

## 9. 记录包与范围

`task_id=GAME-WEB-FLOW-PERF-004`，`version=r1`，`input_version=PR#12 HEAD f04726c7 (PR#2 PERF-002/r1)`，`scope=独立离线证据浏览器`，`deliverable=HTML/CSS/JS模型/JS交互/未来测试/设计文档`，`acceptance=FB01..FB23 + 未来浏览器人工验收`，`status=NOT_RUN / OWNER_REVIEW_PENDING`。

不得修改main、PR #12原文件、游戏源码或小说原稿。不得上传私密设定、聊天证据或真实本机采样。只发布经允许公开的技术候选；不批准正史、共享接口或性能预算。
