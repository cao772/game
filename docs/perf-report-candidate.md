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
