# GAME-WEB-MODULE-PERF-001｜离线性能报告组件候选 r1

> 状态：**开发候选、尚未执行代码或测试、未验收、未经批准**。基于 [PR #2](https://github.com/cao772/game/pull/2) 的实际源码；独立分支递进，不修改分析器、Windows采样器、Godot场景、存档或 main。仅技术方案与程序代码，可公开；不得导入未公开场景、小说、对话、设备个人资料。

## 组成与边界

- `tools/perf_report_candidate.py`：Python标准库离线组件。只读取 PERF-002 的 JSON 分析结果，可选读取 PERF-003 采集元数据、PERF-004 Windows进程级观测JSON。
- `tests/test_perf_report_candidate.py`：使用纯合成对象、未来执行的unittest验收用例；目前**未运行**。
- 本文档：输入契约、数据口径、人工验收检查清单。

不调用分析器、不运行Godot、不扫描机器、不进行网络请求；只创建两份新的 `.html`、`.summary.json` 输出，且以排他创建方式拒绝覆盖旧文件。静态HTML无JS/外部字体/远程资源，所有来源文字HTML转义。处理超过2MB的单个JSON时拒绝读取。

## 与PR #2的已读取接口

实际 `tools/perf_analyze_candidate.py` 的 JSON 输出有：`task_id=GAME-WEB-PERF-002`、`sample_count`、`error_count`、`percentile_definition`、`checks`、`measured_subset_status`、`not_measured`，以及始终 `status=incomplete`、`full_scene_pass=false`。单项 `checks[key]` 提供 `value`、`upper_inclusive`、`status`。其最近秩分位数定义为排序后 `ceil(p*n)`，无插值。空表、坏数值、缺列、非有限值使已测子集 `INCOMPLETE`，而非PASS。

依赖 PR #2 原有八项临时预算（不是已批准指标）：

| 分析器键 | 提案上限 |
|---|---:|
| frame_p50_ms | 12 ms |
| frame_p95_ms | 16.7 ms |
| frame_p99_ms | 24 ms |
| script_p95_ms | 2 ms |
| ram_peak_gib | 1.2 GiB |
| vram_delta_peak_gib | 1.0 GiB |
| draw_calls_peak | 200 /帧 |
| triangles_peak | 150000 /帧 |

显示为三列：**观测值、提案预算、单项比对状态**。没数据时观测值保持 `null`（HTML显示「未测」），不能默认为0；预算不能被写到观测值；不将 `PASS` 解释为整个场景完成。采用保守判定：原报告与固定预算口径冲突、缺少正数样本数、异常计数、错误的状态/数值组合，单项判定降级为INCOMPLETE。 `measured_subset_status` 还必须与原分析器状态一致，否则降级。

## 可选证据

1. `--capture`：读取 PERF-003 场景采样元数据的 `is_synthetic`、`engine_version`、`rendering_driver`、`display_server`、`capture_complete`、`scene_sha256`。未提供则为来源未核实；声明合成则明确写「不是游戏跑分」；headless/dummy不得算GPU跑分；声明真实也只能标记为**待校验原始CSV/场景哈希绑定**，不直接采信为验收。
2. `--memory`：读取 PERF-004 进程观测输出，仅在独立旁路区展示 `working_set_peak_observed_gib`（包含共享页）和 `private_bytes_peak_observed_gib`（私有提交）；带PID、进程创建时间、采样状态和数量，但不展示完整路径/命令行。**不自动把这些数值写回PERF-002的ram_gib，不跨采样时钟按行拼接，不将进程CPU冒充脚本CPU，不推断显存。**
3. 缺少冷启动、区域切换、动态灯、阴影灯、NPC等观测时，固定 `NOT_MEASURED`，完整场景永远为 `INCOMPLETE`，`full_scene_pass=false`。

## 未来运行命令（未运行）

在仓库根目录，输入须为有权限使用且无私密内容的技术采样证据：

```text
python tools/perf_report_candidate.py --analysis evidence/analyzer_A.json --out-prefix evidence/report_A
python tools/perf_report_candidate.py --analysis evidence/analyzer_A.json --memory evidence/memory_A.json --capture evidence/capture_A.json --out-prefix evidence/report_B
python -m unittest discover -s tests -p "test_perf_report_candidate.py"
```

输出 `report_A.html` 与 `report_A.summary.json`。必须使用新前缀；若任一同名文件已存在，拒绝覆盖并清理本次创建的另一文件。工具返回0仅表示报告文件创建成功，**并不表示已达到性能预算**。错误返回2。读入路径不回显至HTML；使用本地隐私数据时保留在私有环境，勿提交到公开GitHub。

## 未来验收矩阵（均待执行）

| ID | 用例 | 期望 |
|---|---|---|
| R01 | 纯合成数据恰好等于八项上限 | 已测子集PASS；整体INCOMPLETE |
| R02 | P99超过24ms | 已测子集FAIL；不冒充整体验收 |
| R03 | 必测项null或缺键 | NOT_MEASURED，整体不得PASS |
| R04 | 分析器异常计数非零 | 所有预算比较不得PASS |
| R05 | 报告PASS但数值超标/预算不匹配 | 降级INCOMPLETE并告警 |
| R06 | 样本为0或NaN | 不得PASS |
| R07 | 采集声明为合成/headless/dummy | 明确非真实GPU跑分 |
| R08 | Windows观察值存在但逐帧RAM缺测 | 进程证据单列、逐帧RAM仍为null |
| R09 | 来自JSON的恶意HTML标记 | 正确转义，且页面无网络依赖 |
| R10 | HTML/JSON任一目标已存在 | 拒覆盖、不损坏已有文件 |

## 作者与验收边界

- PR #2 最新已读取参考 HEAD：`cb0026ec668b96832efed5bf452a90548bc31c20`（读取时为Draft）。
- 本模块及JSON概要格式仅为**独立试验提案**，不是共享接口、工程规范或已批准性能预算。
- 作者本轮只授权开发，未授权运行任何代码或测试；严禁将本轮CI、单元测试、页面预览、真实Godot性能结果写作PASS。
- 正式上线前需由Codex核查输入JSON与采样文件之间的哈希绑定、跨时钟对应关系、Windows内存预算口径和真实Godot视觉/渲染数据；未经审核不合并main。
- 未来验证后应独立记录task_id、版本、输入版本、文件哈希、采样环境、结果和缺失原因，保留证据原件。

记录包：`task_id=GAME-WEB-MODULE-PERF-001`；`version=r1`；`input_version=PR#2 HEAD cb0026e / PERF-002 r1`；`scope=offline static report candidate`；`deliverable=module+future tests+documentation`；`acceptance=R01..R10 pending`；`status=NOT_RUN / REVIEW_REQUIRED`。

---

# GAME-WEB-MODULE-PERF-002｜离线报告比较与异常输入加固 r1

**状态：NOT_RUN。只提交源码、说明和未来验收用例，没有执行代码、单测或Godot跑分。**
本节是前述 PERFMODULE-001 的增量候选；保留PR #12草稿、独立分支和PR #2分析器依赖，不修改任何已有分析器/采样器/游戏文件，也不批准共享接口或性能预算。

## 新增比较能力与使用说明（未来执行，尚未运行）

保留单次报告用法，增加可选基线报告及可选基线采集元信息：

```text
python tools/perf_report_candidate.py --analysis evidence/current.json --out-prefix evidence/report_current
python tools/perf_report_candidate.py --analysis evidence/current.json --capture evidence/current_capture.json --baseline-analysis evidence/baseline.json --baseline-capture evidence/baseline_capture.json --out-prefix evidence/report_compare
python -m unittest discover -s tests -p "test_perf_report_candidate.py"
```

输入均为本地 **PERF-002 r1 JSON分析结果**；`--capture` 和 `--baseline-capture` 均只是可选 **PERF-003** 元信息（不是用来自动导出真实性）。`--baseline-capture` 单独使用会报告参数错误。仍可选 `--memory` 单列展示 **PERF-004** 进程内存，绝不按行合并到逐帧数据。

输出文件固定为一个**新路径前缀**对应的 `<prefix>.html` 与 `<prefix>.summary.json`；任一已存在就拒绝覆盖；两者是本地静态报告和机器可读候选摘要，**不是已批准的共享接口**。

### 报告字段如何阅读

- **预算**：所有上限依旧来自 PERF-001/r1 的**待批准提案**，不是实际测量。
- **本次观测**：仅显示PERF-002输入中对应 `checks` 和 `stats` 相互一致且数值有限、非负的指标。空、坏、非有限、遗漏值为 `null` / 未测，不能当成0。
- **单项状态**：`PASS` / `FAIL` 仅代表输入数据与提案阈值的比较；统计缺失、异常或者两处值不一致则 `INCOMPLETE` 或 `NOT_MEASURED`。
- **已测子集**：严格要求分析器task_id、r1版本、正样本量、0错误和空错误明细、固定最近秩分位数定义，以及 `status=incomplete`、`full_scene_pass=false`。任何异常均不接收PASS；`checks`与`stats`不一致同理。
- **场景整体**：始终 `INCOMPLETE`、`full_scene_pass=false`；加载、切换、灯光、NPC依旧 `NOT_MEASURED`。
- **两次比较**：`--baseline-analysis` 开启数值对照，按 `本次－基线` 计算 `delta`、当基线不为0时计算百分比。负号仅表示数值下降，**绝不直接判断性能改善**。当任一侧无效、缺测、预算不一致，或声明的引擎/渲染器/场景哈希冲突时，该指标 `NOT_COMPARABLE`。有效行也仅标 `NUMERIC_ONLY`；`comparison_is_verified_benchmark=false`，机器、渲染分辨率、场景哈希、采样条件和真实运行证据未独立核实。
- **进程内存**：工作集含共享页，Private Bytes是私有提交；不混入逐帧RAM，不从进程CPU推断脚本CPU，不将未测GPU/显存写0。

### 异常输入处理

| 条件 | 处理原则 |
|---|---|
| 重复JSON键、JSON NaN/Infinity、非对象顶层、无效UTF-8 | 拒绝输入；不得创建成功报告 |
| 单份JSON超过2,000,000字节 | 拒绝，避免无界载入 |
| 非法task_id/版本、样本数≤0、错误列表丢失、分位数定义不符 | 本次子集不得PASS |
| 数值为负、布尔、字符串、非有限、null、预算不一致 | 不产生该项PASS；缺测显示为未测 |
| `checks` / `stats` 不一致、源声明PASS但数值越界 | `INCOMPLETE`，报告需要复核 |
| 两次数据背景不同或有指标缺失 | 数值变化不可比；不发布改善结论 |
| 同名输出存在 | 拒绝覆盖，不破坏旧报告 |

`read_object` 使用读入字节上限与重复键检测，不读取私密环境变量、无网络访问、不调用任何系统命令。

### 新增未来验收用例（均待执行、无PASS）

- **R11** 两份完整合成分析对象比较：delta和变化率正确，`comparison_is_verified_benchmark=false`。
- **R12** 基线某指标缺失：该指标 `NOT_COMPARABLE`，不得填零。
- **R13** 声明场景哈希不同：上下文 `CONFLICT`，禁止同条件数值比较。
- **R14** 基线为0：可给数值delta但百分比为null。
- **R15** `checks`与`stats`矛盾：不接受PASS。
- **R16** 分析器版本、分位数、错误明细或整体状态不匹配：降级INCOMPLETE。
- **R17** 重复JSON键、NaN/Infinity：输入拒绝。
- **R18** 输入超字节上限及顶层非对象：输入拒绝。
- **R19** 比较页有恶意标签：HTML转义、离线安全边界保留。

## 交付限制与归档记录

`task_id=GAME-WEB-MODULE-PERF-002`；`version=r1`；
`input_version=PR#12当前源码 + PR#2 PERF-002/r1`；
`scope=只改PR#12内报告组件、未来测试与文档`；
`deliverable=报告对比、缺测/异常加固、离线中文说明、R11..R19`；
`acceptance=全部未来执行，当前NOT_RUN`；
`status=NOT_RUN / REVIEW_REQUIRED`。

需Codex后续在批准的测试阶段独立核查实际报告效果、异常输入、两次采样对齐与完整链路；本轮不执行、不将CI状态充当验收，不公开私人场景或原稿，不合并main。

---

# GAME-WEB-CONTINUE-PERF-003｜多次采样分组与缺测报告 r1

**开发状态：NOT_RUN；未运行任何程序、测试、视觉预览或基准采集。** 本增量只涉及 PR #12 的报告工具和技术说明，依赖 PR #2 PERF-002/r1 原有JSON。作者负责最终验收，技术取舍在此明确记录，**不批准共享接口**。

## 一、选择的方案及原因

**采用显式本地manifest，按每一次独立PERF-002结果做分组描述统计。** 这是独立候选协议，不修改PERF-002分析器，不重新计算每帧P99，不依赖Godot或第三方库。

- 每次采样的 `frame_p50_ms`、`frame_p95_ms`、`frame_p99_ms` 等，来自原分析器的 `checks + stats` 一致校验。**先校验单次，再比较多次**。原始CSV需保留在Codex的私有证据位置，不进入本公开PR。
- **不拼接**各次的逐帧值、不以单次帧数对各次统计量加权，因为没有可验证的相同采样窗口、设备、FPS限制和原始帧分布；不能将「多个P99的中位数」称作「总P99」。
- 每组对每项指标展示 `min`、**各次结果的中位数**（unweighted median）、`max`、有有效数值次数 / 总次数。中位数选为默认中心趋势，避免把少数极高帧间隔值直接平均稀释；它是多次run级**统计量的中位数**，不是合并帧统计。
- 空值、无效值、原分析器不一致、缺失列不参加有效数值聚合，但必须计入分母并单列具体 **run ID、状态、原因**。不填0、不把缺测忽略成全覆盖。
- 组间比较定义 `delta_median = current_group_median - baseline_group_median`，比率以基线中位数为分母。**任一组存在不完整覆盖、预算不同、或已声明版本/后端/场景哈希冲突时不计算差值**；基线值为0时百分比保持null。即使都有效，也只叫 `NUMERIC_ONLY`，绝不推断「优化成功」「真实性能改善」。
- 不同组数可能不同；组级中位数对比只为描述性对照，不构成配对试验、置信区间或显著性结论。真实设备、分辨率、采样流程和来源哈希尚无可核验输入，此时 `context_status=UNVERIFIED`。
- 如果一份证据声明为合成而另一份声明为真实，标 `CONFLICT`；headless/dummy与有窗口渲染来源混合时也标为来源冲突，并阻止跨组差值。即使两组都声称真实，只能作为数字描述，不能验证GPU。没有完整真实性证明时，整个报告始终 `INCOMPLETE`。
- 有独立 PERF-004 进程工作集证据时，仍只允许旧单次模式单列展示，不自动替代 `ram_gib`，不拿私有提交当物理内存，也不拿累计进程CPU当脚本CPU或推算VRAM。
- 安全与隐私：manifest仅引用其所在目录及子目录的相对POSIX路径，拒绝绝对、父级穿越、符号链接逃逸、网络URL与重复输入文件；run ID限ASCII字母数字、下划线、连字符，最长32位。输出JSON/HTML不包含原始路径、小说设定、进程命令行或私有内容。HTML纯静态并HTML转义。
- 为避免大型或恶意证据拖垮离线工具，每份输入JSON沿用2,000,000字节限制，最多12次/run组、最多2组和24次总采样；仅标准库。以上都是**试验提案**。

## 二、输入manifest与调用示例（待未来执行）

manifest位于私有证据目录，格式如下，文件内容为**结构示例而不是跑分**：

```json
{
  "schema": "perf-report-series-v1",
  "groups": [
    {
      "name": "baseline",
      "runs": [
        {"id": "A_01", "analysis": "baseline/a01_analyzer.json", "capture": "baseline/a01_capture.json"},
        {"id": "A_02", "analysis": "baseline/a02_analyzer.json"}
      ]
    },
    {
      "name": "current",
      "runs": [
        {"id": "B_01", "analysis": "current/b01_analyzer.json", "capture": "current/b01_capture.json"},
        {"id": "B_02", "analysis": "current/b02_analyzer.json"}
      ]
    }
  ]
}
```

- `groups` 允许单组 `current`（必须至少2次）或有序双组 `baseline`、`current`（每组1–12次）；总数不超过24。
- `analysis` 必填，对应PERF-002 JSON；`capture` 可选，对应PERF-003元数据。缺输入文件不假造；在命令执行时明确报错。run ID全局唯一，文件不可跨run重复引用。
- 输入路径均相对manifest所在目录，采用 `/` 分隔。manifest示例纯公开结构，不包含任何真实采样路径、场景名或个人资料。
- `--series-manifest` **不可**与旧 `--analysis`、`--memory`、`--capture`、`--baseline-analysis`、`--baseline-capture` 同时使用；避免对齐不明数据混用。
- 不要求编辑已有单次报告或原分析器；旧单次/两次命令行模式保留。

仅供后续获批准的Codex本地执行，**本任务不执行以下任何命令**：

```text
python tools/perf_report_candidate.py --series-manifest private_evidence/series.json --out-prefix private_evidence/report_series_001
python tools/perf_report_candidate.py --analysis private_evidence/a01_analyzer.json --out-prefix private_evidence/report_single_001
python -m unittest discover -s tests -p "test_perf_series_candidate.py"
```

输出 `report_series_001.html` + `report_series_001.summary.json`，必须是新文件，拒绝覆盖已有证据；成功创建输出文件不意味着通过任何性能阈值。

## 三、怎样读报告，特别是缺测

| 字段 | 解释 | 不允许的推断 |
|---|---|---|
| `budget` | PERF-001/r1临时提案上限 | 不是实测、不是已批准预算 |
| `min / median / max` | 各次**有效**PERF-002统计量的run级汇总 | 不等于合并逐帧数据后的P95/P99 |
| `n_observed / n_total` | 有效数值次数 / 该组总采样次数 | 只看有效部分就说全量PASS |
| `missing_runs` | 逐项缺失的run及原因 | null不得转换为0 |
| `coverage=COMPLETE_NUMERIC` | 仅8指标之一的数字在每次采样都齐全 | 不代表场景或来源已验证 |
| `coverage=PARTIAL` | 有部分有效数值，同时有明确缺测 | 不允许无条件跨组比较 |
| `coverage=NOT_MEASURED` | 本指标没有有效可采信数值 | 不代表性能消耗为0 |
| `group_comparison.status` | 始终 `DESCRIPTIVE_ONLY` | 不作真实性能进步结论 |
| `NUMERIC_ONLY` | 两组完整且无已声明上下文冲突，仅计算数值差 | 不代表配置完全一致或性能达标 |
| `context_status=UNVERIFIED` | 尚未完成来源/设备/条件证明 | 不视为等价环境 |
| `whole_scene_status` | 一律 `INCOMPLETE` | 不批准整体性能验收 |

**重点缺测**：脚本CPU、GPU实际执行、VRAM基线增量、灯光、NPC、冷启动、场景切换等凡未采集者全部不能从帧间隔或Windows进程内存数据反推。每次真实Godot测量前仍需单独记录渲染方式、硬件型号、帧率限制、VSync与采样动作并在私有证据系统关联原始CSV和哈希。

## 四、未来验收矩阵（所有用例NOT_RUN）

| ID | 条件 | 预期 |
|---|---|---|
| R20 | 同组3次run的P50数值9/12/10 | 中位数10，覆盖3/3，非合并帧P50 |
| R21 | 一次run的脚本时间缺失 | 覆盖1/2，明确run ID与原因，不填0 |
| R22 | 两次run的脚本时间都缺失 | min/median/max均为null，NOT_MEASURED |
| R23 | baseline两次11/12、current两次9/10 | 组中位数11.5/9.5，delta -2，仅NUMERIC_ONLY |
| R24 | 组中一项缺测 | 该项跨组delta=null、NOT_COMPARABLE |
| R25 | 基线组中位数0 | 可有delta，但变化率null |
| R26 | 声明的渲染器/场景哈希不一致 | CONFLICT且差值禁止计算 |
| R27 | 合成与真实声明混合 | CONFLICT，不产生真实游戏跑分 |
| R28 | HTML有恶意字符串 | HTML转义，无脚本/外链，仍标NOT_RUN |
| R29 | 读取2个独立私有JSON路径 | 可汇总，输出不泄露实际输入目录 |
| R30 | 重复run ID或重复input | 拒绝，不能伪造独立多轮样本 |
| R31 | `../`、绝对路径、URL、Windows盘符 | 全部拒绝，不读取越权文件 |
| R32 | 每组超12次、组为空 | 拒绝，资源上限生效 |
| R33 | HTML/summary同名文件已存在 | 拒绝覆盖，旧结果字节不变 |
| R34 | 现有单次/成对模式 | 参数仍兼容；未来应与上一阶段回归一起复核 |
| R35 | headless/dummy与有窗口渲染混入跨组比较 | 标为来源冲突，delta=null，不能视为GPU对照 |

所有未来验收必须由作者批准后再由Codex执行，**本次未运行，绝不声称PASS**。如真实证据不齐，只呈现缺失清单与待复核信息。

## 五、记录包

`task_id=GAME-WEB-CONTINUE-PERF-003` / `version=r1`；
`input_version=PR#12 当前 HEAD + PERF-002/r1 (PR#2)`；
`scope=仅PR#12同一独立codex分支的报告模块、CLI、文档、验收候选`；
`deliverable=多run分组汇总、组间数值比较、缺测来源表、离线HTML/JSON、R20..R34`；
`acceptance=NOT_RUN; PENDING_AUTHOR_FINAL_REVIEW`；
`status=NOT_RUN`。

未经作者最终验收，不合并main、不批准性能预算或共享接口、不公开剧情或私密数据。
