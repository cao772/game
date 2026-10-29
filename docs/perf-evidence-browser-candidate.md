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

---

# GAME-WEB-PLAY-PERF-005｜多结果横向对比与缺测解释增量 r1

> **最终验收前状态：NOT_RUN。** 本节是对原 Draft PR #22 的代码级增量，不更改PR #12的Python工具/报告格式，不执行任何代码、测试、浏览器预览或跑分，不合并main。本任务只提供可公开技术候选，且不批准共享接口、性能预算、剧情正史。

## 10. 本轮真实代码基线与分工

本轮首先读取 [Draft PR #22](https://github.com/cao772/game/pull/22) 当前 HEAD `37bbe8d65b98f6a8c187a92046fe19f952dc1516`，核对：
`tools/perf_evidence_browser/model.js`、`app.js`、`index.html`、`style.css`，
`tests/test_perf_evidence_browser_candidate.js`、
`docs/perf-evidence-browser-candidate.md`。PR #22 的上游仍为PR #12 `codex/perf-report-module-r1`，包含PERF-002分析器、离线单次及多次汇总候选。无须额外现实场景/真实用户证据即可编写**结构验证与离线浏览**功能；但缺少实际场景CSV、采样原始哈希、GPU计数器、CPU脚本分离证据，**不能完成真实性证明或整体验收**。

本轮新增 `tools/perf_evidence_browser/cohort.js`（只读纯JS多报告对照模型），直接升级原 `index.html`、`app.js`、`style.css`、`model.js`，继续沿用其浏览器本地File API和现有单次/两份显示方式。没有改动游戏代码、上传设定或其他窗口PR文件。

## 11. 常规设计取舍及原因

- **多文件选择采用「左侧勾选2–12份 + 指定其中一份为基准」**，不自动按文件名、时间顺序或导入顺序断言哪份更早。允许最多40份进入浏览库，但单次横向对照限制12份，使离线页面、表格列和内存占用可控。
- **坚持只读来自现有JSON的数值**：沿用`model.normalize`先统一判定，增加任务ID/版本/预算状态校验，以及重复指标键、组级覆盖自相矛盾的保守降级。报告外的输入缺少可信字段时明示缺测/不完整，不调用Godot或Python进行“自动补全”。
- **多文件不接纳已聚合series当作独立run**：原series摘要已经是多个run级统计量，若与单份报告再求中位数会出现二次聚合、重复计数和样本独立性不明。多轮series仍单独在详情页展示run级min/median/max及各run来源，不参加跨文件逐帧对照。
- **不同报告的逐指标数值表优先**，不是光凭折线漂亮就宣称趋势：每个单元格同时显示导入值、是否可核对、相对基准delta；并展示每份来源的引擎、渲染器、场景哈希、原声明子集状态和警告数量。实际真实性一律`UNVERIFIED`。
- **完整覆盖才汇总各报告中位数**：对某指标若12份中有任一缺测、不合法或失配，则显示有效数量与逐份缺测原因，整项的跨报告中位数、min/max置`null`；避免仅用少量有效样本掩盖缺失。有上下文冲突时，统计汇总和delta亦置`null`，但保留每份原始声明数值供追溯。
- **支持合成样本的数学对照，却绝不把合成显示为真实跑分**。同一组全为`SYNTHETIC`时可计算纯数学差异；合成与非合成混合、headless/dummy、已声明的引擎/渲染器/场景哈希不一致时标记`CONFLICT`并抑制delta。即使无已知冲突，未知设备、VSync、分辨率和真实源文件绑定仍为`UNVERIFIED`，结果只标`NUMERIC_ONLY`。
- **明确原因而非猜测0**：来源没有合法的`script_p95_ms`、`vram_delta_peak_gib`、`ram_peak_gib`、绘制数或其他指标时，以`NOT_MEASURED`或`INCOMPLETE`显示数值缺口、run/文件名和原因。不能由相邻帧时间推GPU/脚本CPU，也不能拿Windows `working_set_gib`、`private_bytes_gib`替代逐帧RAM。此策略避免用“0”使任何提案预算看似通过。
- **不持久化也不上传**：保留本地File API、无网络/CSP、纯DOM文本渲染；会话勾选和多个报告只保存在当前页面的JS对象中；不引入CDN、统计服务、后端共享接口或自动运行。
- **不计算统计显著性**：多个原报告只给run/文件级等权中位数（且覆盖完整时），不合并逐帧样本、不推断置信区间、不说性能提升。未来如要正式对照需单独取得相同负载与环境的完整原始采样、授权审查和可验证证据关联。

## 12. 新增的浏览器交互

1. 从本地选择或拖入多份 `.json`。同一页面支持PERF-002 `analyzer`、PR #12 `single` 和 `series` 三类既有结构；**本轮不发明第四类外部数据来源接口**。
2. 详情页新增「缺测与口径说明」。显示八项指标中未测/异常的明确原因，并单列脚本CPU、GPU执行时长、VRAM、Windows工作集/private commit与整个场景未测事项的区别。
3. 系列摘要详情继续显示每个run的帧数、来源声明、版本、渲染器、场景哈希及各指标`missing_runs`。系列报告既可以导入浏览，又不能冒充单次逐帧观测。
4. 在报告清单勾选**2–12份非series报告**，选择基准，点击「比较已勾选报告」；生成一张横向指标数值矩阵，以及逐文件来源元数据、有效覆盖总数与各文件缺测原因。输出仅在页面显示，没有导出/上传动作。
5. 旧两份数值对照保留。点击「取消勾选」只清空横向比较选择，不删除任何已导入报告；「清空会话」才清除整个页面证据引用。已声明来源冲突时对照显示不可比较。

这里的“有效覆盖”只代表**报告内的数值结构和预算对照可读取**，绝不能被解释成有多少次真实游戏测试已验证；来源类别和预算身份单独列出。多个报告可能指向同一原始CSV，本工具没有源文件哈希与审计信息，因此**不证明它们是独立重复实验**。

## 13. 集成说明（未来执行，当前禁止运行）

全部文件位于当前PR独立分支 `codex/perf-evidence-browser-r1`：

```text
tools/perf_evidence_browser/
  index.html              浏览器入口
  style.css               既有样式及新多报告布局
  model.js                已知JSON格式规范化和缺测判别
  cohort.js               新增跨2–12份报告纯计算模型
  app.js                  既有导入/详情 + 多报告勾选/对照交互
tests/
  test_perf_evidence_browser_candidate.js         原有未来契约测试，扩展边界
  test_perf_evidence_browser_cohort_candidate.js  新增未来横向比较验收
docs/
  perf-evidence-browser-candidate.md              本说明
```

页面`index.html`按`model.js`→`cohort.js`→`app.js`加载；所有路径相对浏览器入口。不得复制或覆盖上游PR #12的Python源码、真实证据目录或游戏原稿。任何未来本地预览都须保持CSP和无外部请求约束。若 `file://` 模式的浏览器安全策略阻止脚本加载，应在授权后单独确认只监听回环地址的离线静态文件服务，不允许改成公网站点或上传真实证据。

预留的未来纯逻辑验收命令（**本任务没有执行**）：

```text
node --test tests/test_perf_evidence_browser_candidate.js
node --test tests/test_perf_evidence_browser_cohort_candidate.js
```

浏览器人工验收后续须覆盖：多选／取消、单份详情和两份旧模式不回归、2/12/13份边界、重复ID、单个缺测/全部缺测、含合成与非合成、headless/dummy、来源引擎和场景哈希冲突、移动端宽表横向滚动、无网络请求、无内容注入、未知版本保守处理。现在**只提交未来测试源码，不执行**，状态`NOT_RUN`。

## 14. 新增未来验收用例（全部NOT_RUN）

`tests/test_perf_evidence_browser_cohort_candidate.js` 中的 PB01–PB17：三份run级中位数与覆盖；非默认基准delta；单项缺测与全缺测；混合来源抑制差值；合成保留声明；非GPU后端禁止GPU对照；场景哈希冲突；预算不匹配；分母为0百分比null；拒绝把系列摘要当独立run；报告数量2至12边界；重复ID、基准非法；逐份来源元信息；不可用指标零差值禁止；CSP与本地只读约束；无副作用的纯计算。

原 `tests/test_perf_evidence_browser_candidate.js` 新增 FB25–FB29：单次报告任务ID/版本/预算声明异常；同指标重复；series契约异常；series覆盖声明与实际次数冲突；来源声称子集PASS但个别指标缺测时整体降级INCOMPLETE。原有FB01–FB24为之前任务未来测试定义，仍未执行。

**限制及已知缺输入**：没有本轮真实Windows/Godot实测，缺少可核验的原始CSV SHA256绑定、真实GPU时间、脚本CPU分离、VRAM增量、完整场景动作与最低目标机数据。因此任何`WITHIN_PROPOSAL`仅是导入结构所声明数值与**未经批准预算**的比较，不是官方通过；任何`NUMERIC_ONLY`仅是描述性差值，不是性能优化结论。既有分析器代码与共享接口未获批准，本模块不将其偷偷升级为正式标准。

## 15. 记录包

`task_id=GAME-WEB-PLAY-PERF-005`；`version=r1`；
`input_version=Draft PR #22 HEAD 37bbe8d / Draft PR #12 依赖`；
`scope=仅改PR#22独立浏览器及自有未来测试、文档`；
`deliverable=cohort.js + 既有模块升级 + PB01..PB19 + FB25..FB29 + 集成说明`；
`acceptance=全部NOT_RUN，交作者最终验收`；
`status=NOT_RUN`。

不改main；不上传小说正史、私密设定、聊天证据；不合并Draft PR；不批准性能预算、共享接口或任何游戏正史。

### 增补：浏览器导入的并发与重复选择保护（仅设计候选）

- 读取文件期间设置当前会话`busy`标志，拒绝并行导入及正在读取时清空，防止两个异步File API操作交错造成报告条数或选择状态混乱。
- 依据选择的本地文件名、大小、修改时间组合，**仅防止用户无意再次导入同一文件**。这不是SHA256，不足以证明不同文件、不同报告或多个run来自独立采样；不应用于证据真实性结论。清空会话会清除这些临时索引。
- 缺测详情在单次、series和横向矩阵中分别展示；对多报告最多12×8个指标缺口，全部保留展示，超过固定UI展示上限时明确提示尚有未展开项，不会静默把错误隐藏成“无缺测”。
- 增补未来测试PB18–PB19：异步导入并发保护与重复选择提示；缺测说明、每run的渲染后端/场景哈希/来源警告展示检查。**这两个仅为未来静态契约测试，未执行浏览器或测试。**

即使导入不同JSON，若它们均由同一原始CSV生成，依旧可能被重复作为文件级比较项；由于没有获得原始SHA256、采集窗口和进程身份的完整绑定，本模块不能确认实验独立性。这一缺输入须在作者最终验收时由真实证据链解决，当前不编造。
