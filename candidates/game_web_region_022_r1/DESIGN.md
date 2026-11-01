# DESIGN｜落实 PR #29 风险并说明取舍（source-level only）

**输入已读：** PR #28 `region_validator.gd`、`catalog_recovery.gd`、`synthetic_regions.json`；PR #29 `COMPATIBILITY_MATRIX.md`、`RISK_REGISTER.md`、`STAGED_MIGRATION.md`、`ACCEPTANCE_PLAN.md`。以下是依据与新候选设计的分界，不是运行报告。

| N21 风险 | 源证据（固定 SHA 见 SOURCE_REVIEW） | N22 独立候选处理 | 未解决/未来门槛 |
| --- | --- | --- | --- |
| **R01** Godot 根资源重名 | #29 R01：所有独立 PR 都有 `res://main.tscn` 和本地 script path | 只建立一份**新的** `project.godot/main.tscn` 于 N22，复制 PR28 源为新目录 local 文件，不去平铺其余根 | 真正导入 Godot 仍 NOT_RUN |
| **R02** 诊断链没有连接模型 | #28 `catalog_recovery.gd` 与 #29 R02 | 新 `validated_gateway.gd` 明确调用 recovery → allowlist → `synthetic_interaction.configure` | 需要将来执行确认 |
| **R03** 结构不等于可达 | #28 `region_validator.gd` 只验结构；#29 R03 | 模型单独提供 BFS 与 LOS 候选，结构接受仍允许 C 断路和错误 `claimed` | BFS/LOS 和真实物理差异未验证 |
| **R04** 未检查即有 actual | #29 R04 警惕 #26 的 `snapshot` 在未核对时计算 actual | N22 本地模型 `snapshot().actual={}` 直到显式 `inspect`；移动/撤销/换场清除旧核对 | 无任何实机状态验证 |
| **R05** 网格代理非物理导航 | #29 R05 | 四邻 BFS、采样遮挡只给合成提示，禁称 NavMesh/安全放行 | 不接真实地形 |
| **R06** 未知额外字段 | #28 Validator 未知字段 Warning；#29 R06 | 仅 Gateway 映射 `id/grid/claimed`，丢弃未知字段，保留来源诊断 | 未来用户外部输入及隐私过滤未获授权 |
| **R07** 双重回退语义 | #28 三态/回退；#29 R07 | 只保留 PR28 `catalog_recovery` 作为 loader，模型没有第二份 fallback；界面显示来源/回退差异 | PR28 原始复制源码语法与自检均未执行 |
| **R08** 输入/焦点争夺 | #29 R08 | N22 仅用按钮与 Godot 原生焦点控件，**不监听全局 WASD、Esc**，没有共享 InputMap | UI/Tab/缩放与无障碍仍未验证 |
| **R09** UI 大字/文本流动 | #29 R09 | 字符图与错误源使用只读文本框，全部必需信息文字呈现 | 文本框滚动在刷新后是否保持，待测 |
| **R10** Validator 上限/双入口 | #28 `MAX_INPUT_CHARS=16000/MAX_ISSUES=48` 为候选；#29 R10 | 在 UI 中只使用固定合成 JSON 与受控小型本地合成 Variant；不将限额冒充性能证明 | Variant 入口绕过字符上限，未来对不可信输入必须另设拒绝策略 |
| **R11** 撤销非持久审计 | #29 R11 | 单场最多 16 个候选撤销快照和 12 条本地日志；更正只改内存 `claim` | 不支持长期审计、回放或存档 |
| **R12** 缺少真实运行证据 | #29 R12、#28 README | 全源和文档 **NOT_RUN**，不填 PASS | 只有后续单独授权才执行 Godot 与验收 |

## 选型理由

**选择“小闭环”的独立模型，不复制 #26 模型：** N22 需要展示“合法化的目录如何进入纯内存交互”，而 #26 的 `region_model.load_catalog()` 会再次决定回退，违反单一来源原则；因此新建无 I/O `synthetic_interaction.gd`。这不是替换 #26 的正式 API，也不表示 #26 本身有 bug。

**选择原样复制 #28 的核心校验与回退源码：** Git blob 可回查，避免在 N22 偷改既有验证逻辑。它们位于独立 Godot 根目录，原 PR HEAD 不变。若未来发现校验器自身问题，只能在 N22 的新版本或后续授权分支修，不回写 #28。

**选择白名单映射而不是直接透传整个 JSON：** 兼容“额外字段仅 Warning”，同时尽量不把未知元数据带入模型，但这种边界并不能证明动态内容天然安全。当前仅内嵌/固定公开合成 A/B/C。

**选择纯按钮 + 文字输出而不是未经授权的游戏内键盘路由：** 降低焦点冲突，允许未来单独验证键盘。没有模拟 FPS、内存、毫秒、可访问性评级或“已通过”标志。

## 仍需作者批准的事项

- 是否允许后续执行 Godot 4 导入/解析、真实 A/B/C 操作和 fallback 故障注入；
- PR #28 的诊断结果未来是否允许作为唯一正式输入前置；
- 是否需要另外一个只读 UI Adapter 接入 #27 的证据卡；
- 是否允许持久化审计、接口和真实地图——**当前均不允许**。

**本轮状态：NOT_RUN；没有运行脚本、解析器、Godot、GUI 或测试。**
