# SYNTHETIC_SCENARIOS｜纯合成输入与失败恢复预期（NOT_RUN）

样本只包含匿名的字母 A/B/C 与 `# . S T` 网格；所有数据来自 PR #28 的公开合成 fixture/内置样本。**没有执行任何用例，也没有生成 PASS。**

| 样本入口 | 合成输入 | 未来预期来源模式 | 未来交互/恢复预期 |
| --- | --- | --- | --- |
| `load_local_synthetic` | 仅固定项目内的 `synthetic_regions.json` | 结构合法时 `SOURCE_ACCEPTED` | 允许切 A/B/C；原始 claim 与模拟观察分开 |
| `BAD_VERSION` | 改合成字典的版本为 unsupported | `FALLBACK_SYNTHETIC` | 原始 VERSION 错误仍可读；界面明确“内置后备”，不修原文件 |
| `DUPLICATE_ID` | 将 B 的字母改为 A | `FALLBACK_SYNTHETIC` | 原数据被拒绝，不能只加载半套 A/B/C |
| `MISSING_T` | A 场景移除唯一 T | `FALLBACK_SYNTHETIC` | 原输入的 `TARGET_COUNT` 诊断仍在；后备 A/B/C 有合法 T |
| `VALID_DISCONNECTED_C` | 固定完整合成目录，C 的目标被墙隔断 | `SOURCE_ACCEPTED` | C 仍是结构合法；走 T 路线应显示不可达，返回 S 可预览 |
| `BAD_CLAIM`（代码内有，但未接默认 UI） | 把 B 的 `claimed.reachable` 改成文字 `"false"` | `FALLBACK_SYNTHETIC` | 不能把字符串变成 Boolean 并悄悄通过 |
| 缺失固定可选 JSON（未来隔离副本） | 不存在 `res://synthetic_regions.json` | `FALLBACK_SYNTHETIC` | 原报告保留 `FILE_MISSING`；内置目录经自检才生效 |
| 损坏 JSON（未来隔离副本） | 固定合成文件语法错误 | `FALLBACK_SYNTHETIC` | 保留语法错误行/建议；禁止声称原文件已修 |
| 内置目录也无效（未来隔离副本） | 损坏 fallback，且原数据无效 | `BLOCKED` | 空目录、无活动场景，不允许移动、核对、更正 |

**不代表实测的业务结果：** “A 能否直视 T”“B 是否能绕行”“C 的返程是否可见”等均属于**待实际执行的模拟交互行为**；结构有效不能替代 BFS/遮挡验收，BFS 又不能替代真实 Godot 物理导航。

**参数说明：** `MAX_UNDO=16`、`MAX_LOG=12`、PR28 `MAX_INPUT_CHARS=16000` 和 `MAX_ISSUES=48` 是候选源码限制，非容量或性能实测，不可当生产指标。
