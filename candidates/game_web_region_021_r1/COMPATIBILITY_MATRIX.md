# COMPATIBILITY_MATRIX｜四个独立候选之间的源级互操作关系

**图例**：S＝相同公开合成来源；C＝源码语义可作为未来适配**候选**；X＝不能直接合并/存在结构冲突；U＝未运行，兼容性未知；—＝该 PR 不提供此功能。**所有 C 均不代表已实际集成。**

## 1｜功能与结构矩阵

| 维度 | #25 / 017 | #26 / 018 | #27 / 019 | #28 / 020 | 源级结论／未来选择 |
| --- | --- | --- | --- | --- | --- |
| 合成 JSON blob | **S** 同 SHA | **S** 同 SHA | **S** 同 SHA | **S** 同 SHA | 固定数据源兼容；保留样本，不上升正式产品 schema |
| 版本号 | `public-synthetic-region-017-v1` | 相同 | 相同 | 相同 | 字符串一致，仍属于合成候选；没有版本迁移协议 |
| 主要输入形状 | 3 个 `id,title,grid,claimed` | 相同 | 相同 | Validator 用同一形状 | 结构可静态比较 **C**；并不意味着诊断器已拦截前三者 |
| 内存模型 | 基础 `region_model.gd` | 增加 undo/clear preview | 与 #26 blob 相同 | 独立 validator/recovery，无移动模型 | 25→26 语义扩展；27 复用 26；28 **不是**模型替换 |
| 路径/视线 | 四向 BFS + 采样视线 | 同方法 | 同 #26 模型 | **—** 只验证结构 | 运行正确性 U，**不能由 #28 的 ACCEPTED 推断可达** |
| 可撤销记录 | **—** | 内存撤销栈，默认候选上限 16 | 同 #26 | **—** | 如保留撤销，未来可选择 #26/27 候选状态语义 |
| 文本地图/键盘 | 基础按键/网格 | 方向按钮、状态文字、文字大小与动效 | 来源于 #26 | 只有诊断控件 | 26→27 方案 C；跨工程焦点/Tab 依然 U |
| 证据卡/下一步提示 | **—** | 一般文字状态 | `state_guide.gd` 和只读 TextEdit 卡 | **—** | 27 源只读 `snapshot` 输出；并非审计接口 |
| 数据结构诊断 | 布尔 `_valid_catalog` | 同布尔 | 同 #26 | `region_validator.gd` 返回结构 issue 列表 | **X/U**：需要显式适配层，不能说现成对接 |
| 资源缺失 | `load_catalog` 回内置 A/B/C | 同样布尔回退 | 同 #26 | `catalog_recovery` 显式三态 | **X**：提示/结果结构不同，不能双重回退后抹掉来源 |
| 场景根路径 | `res://main.tscn`，相对根文件 | 同路径 | 同路径 | 同路径（诊断 scene） | **X**：独立 `project.godot` 不能直接平铺为一项目 |
| 游戏事件/存档/世界状态 | 无已批准接口 | 无 | 无 | 无 | 统一“不接入/不改” |
| 真实场景/位置/人物 | 无 | 无 | 无 | 无 | 只保留 A/B/C 合成语义 |
| Godot 导入与脚本运行 | **U / NOT_RUN** | **U / NOT_RUN** | **U / NOT_RUN** | **U / NOT_RUN** | 任一不可宣称 PASS |
| 现行仓库关系 | 从 main 独立 Draft | 从 main 独立 Draft | 从 main 独立 Draft | 从 main 独立 Draft | 是候选集合，不是可直接合并的组合栈 |

## 2｜源级依赖草图（不是运行依赖图）

- **#25:** `project.godot → main.tscn → region_demo.gd → region_model.gd + map_view.gd → synthetic_regions.json?`，问号表示 JSON 可选，布尔校验失败会用内置合成数据。证据：[25 `region_demo.gd` L4–5](https://github.com/cao772/game/blob/8372c1fe5f6471ec6af788b65b68fa54fe7db65a/candidates/game_web_region_017_r1/region_demo.gd#L4-L5)、[25 `region_model.gd` L38–59](https://github.com/cao772/game/blob/8372c1fe5f6471ec6af788b65b68fa54fe7db65a/candidates/game_web_region_017_r1/region_model.gd#L38-L59)。
- **#26:** 相同形状独立项目，`region_model` 加撤销与文本输出；[26 `region_model.gd` L247–311](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_model.gd#L247-L311)。
- **#27:** `region_demo.gd` 额外 `preload("res://state_guide.gd")`，guide 从 model snapshot 衍生只读文本，但不执行更正；[27 `region_demo.gd` L5–7](https://github.com/cao772/game/blob/fdbb6688d07a6a7cebe36b999b82482987362499/candidates/game_web_region_019_r1/region_demo.gd#L5-L7)、[27 `state_guide.gd` L8–46](https://github.com/cao772/game/blob/fdbb6688d07a6a7cebe36b999b82482987362499/candidates/game_web_region_019_r1/state_guide.gd#L8-L46)。
- **#28:** `diagnostics_demo.gd → catalog_recovery.gd → region_validator.gd`，同时用 `synthetic_boundary_cases.gd` 生成内存例；没有到 `region_model.gd` 的引用。[28 `diagnostics_demo.gd` L4–5](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/diagnostics_demo.gd#L4-L5)、[28 `catalog_recovery.gd` L3–4](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/catalog_recovery.gd#L3-L4)。

## 3｜未来集成时应当先讨论的合同（**N21 建议，不是已批准代码**）

| 候选合同 | 最小人工审批问题 | 选择该边界的理由 |
| --- | --- | --- |
| **Loader 策略** | 是保留 #26 内部 Bool 校验，还是在隔离适配层接入 #28 诊断？ | 避免同一错误既提示合成回退又被下游判“已通过” |
| **来源枚举（文档层）** | 清楚分开“原合成数据合格/原合成数据拒绝、采用回退/回退不可用” | 不把 `FALLBACK_SYNTHETIC` 冒充原文件已修复 |
| **报告语义** | 标 `recorded_claim`、`observed_at_position` 与 `inspected` 是否三者可区分？ | #26 snapshot 在未核对时也计算 `actual_*`；#27 会用 `inspected` 门控 |
| **位置和场景隔离** | 切换 A/B/C 时哪些状态必须清零？ | #26 每次选择会重置观测/撤销；#27 还清除固定证据卡 |
| **交互焦点** | 游戏 UI 谁拥有 W/A/S/D、Tab、Esc；是否要隔离焦点上下文？ | 四个 PR 都没有被批准接进真实游戏 InputMap |
| **版本与资源路径** | 如何组织唯一资源入口、避免多个 `res://region_demo.gd`/主场景相撞？ | 这是四个独立项目，不能按文件名混入同一根目录 |
| **持久性与权限** | 是否永远只允许内存；若需要存档须另开授权？ | 当前来源全是合成内存行为，没有产品读写合同 |

**推荐兼容方向**：保留 #26/27 的**候选交互与状态语义**、选择 #27 的**只读呈现候选**作为可选显示层、让 #28 **仅候选地在加载前输出诊断**。但这些只是下一次开发窗口的接口讨论基线，本文**不调用、不复制、不改写任何原脚本**。
