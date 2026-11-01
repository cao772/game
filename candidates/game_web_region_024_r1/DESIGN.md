# DESIGN｜PR #26 的无障碍输入思想如何适配 PR #31 的校验/回退

**[源]** 是读到的 GitHub 源码事实，**[N24 设计]** 是本轮新候选；所有运行效果 **NOT_RUN**。

| 维度 | 源侧事实 | N24 取舍与原因 | 已知局限 |
| --- | --- | --- | --- |
| 数据所有权 | [#31 gateway](https://github.com/cao772/game/blob/b65ebbb729c67ee94d41778b7d8c996bc5f8235d/candidates/game_web_region_023_r1/validated_gateway.gd#L21-L120) 独立连接校验/回退/模型 | 六个 .gd/.json 数据文件保留 Git blob；N24 **只新增界面/文字投影**，避免双重 fallback | 结构校验器不等于地图实际可走/安全 |
| 只键盘输入 | [#26 UI L130–146](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_demo.gd#L130-L146) 显式方向按钮；[#26 map_view L92–118](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/map_view.gd#L92-L118) 有网格聚焦按键 | 原生 Button/OptionButton 为主，另建 `keyboard_grid.gd` 专有焦点域，只发方向请求；不用 UI 读取模型私有字段 | 不宣称原生 Tab/按钮在所有 OS 一致 |
| 焦点表达 | [#26 UI L46–73](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_demo.gd#L46-L73) 的白边焦点框；[L284–295](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_demo.gd#L284-L295) 使用焦点文字 | 焦点样式 + **当前焦点文字**双路，视觉边框不独占信息；保留 PR31 TextEdit 只读内容 | 没有屏幕阅读器事件/语音播报证明 |
| 文字缩放 | [#26 UI L157–166](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_demo.gd#L157-L166) 用本地字体覆盖为 100/125/150% | N24 提供相同三个档位，作用于所有展示文字；整体容器可滚动；不同字体/宽度需实机核查 | 不保证 150% 在狭窄窗口无水平溢出 |
| 不依赖颜色 | [#26 map_view L60–90](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/map_view.gd#L60-L90) 使用 # . : S T P 字符 | 纯文本行、起终点/当前位置坐标、源模式**中文+英文状态**、错误代码/原因/修复动作 | 字符宽度可能与视觉列宽不完全一致；需验屏幕阅读器 |
| 动效 | #26 提供 Off/Slow/Normal（候选） | N24 **完全无动效**，避免更改事实或额外引擎帧更新 | 没有独立动效选择器，这是有意缩小范围 |
| 失焦门禁 | [#26 UI L297–326](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_demo.gd#L297-L326) 检测窗口焦点和按键释放 | 只阻止移动；切回前需松开所有方向键；不自动抢焦点/更正 | 输入设备、组合键、窗口消息准确性未测试 |
| BLOCKED | [#31 gateway L32–120](https://github.com/cao772/game/blob/b65ebbb729c67ee94d41778b7d8c996bc5f8235d/candidates/game_web_region_023_r1/validated_gateway.gd#L32-L120) 阻断后的模型不能响应操作 | 场景选择和变化动作按钮禁用，来源重载/错误示例可访问；网格焦点放开 | 如果脚本根依赖缺失，Godot 无法启动 UI，也就无法显示 BLOCKED |
| 状态隐私 | [#31 model L184–197](https://github.com/cao772/game/blob/b65ebbb729c67ee94d41778b7d8c996bc5f8235d/candidates/game_web_region_023_r1/synthetic_interaction.gd#L184-L197) 明确 `actual={}` 直到 inspect | `semantic_status.gd` 拆开“记录主张/核对结果/下一步”，防止把内部模拟推断写成已实测事实 | Model 的视线仅离散采样、BFS 仅四向格网；无物理安全保证 |
| UI 重绘 | [#31 UI L176–182](https://github.com/cao772/game/blob/b65ebbb729c67ee94d41778b7d8c996bc5f8235d/candidates/game_web_region_023_r1/integration_demo.gd#L176-L182) 仅内容不同才更新 TextEdit | 沿用局部策略，不覆盖新数据层；缩放后仍尽量保持文本阅读位置 | 选择范围/滚动位置在真实 Godot 上待验证 |

## 内部依赖链（建议实现）

```text
res://synthetic_regions.json  （固定公开合成 A/B/C；可选）
    ↓
catalog_recovery.gd → region_validator.gd
    ↓ SOURCE_ACCEPTED / FALLBACK_SYNTHETIC / BLOCKED + 原始诊断
validated_gateway.gd（本地状态门禁）
    ↓
synthetic_interaction.gd（四向格网、显式 inspect/correct、仅内存 undo）
    ↓ snapshot: mode, source_report, fallback_report, synthetic
semantic_status.gd（仅文字，不修改模型）
    ↓
accessible_demo.gd（按钮/字号/可读状态）→ keyboard_grid.gd（聚焦才发动作）
```

## 不做的事与未决边界

- 不复制 PR #26 的 `region_model.load_catalog()`；它有自己独立的加载/回退策略，与 PR #31 的单一入口会发生语义重叠。
- 不引入 PR #26 的动画/鼠标点击地图预览；地图焦点只用于按键移动，避免错误承诺“点击任意格会走过去”。
- 不添加全局 `InputMap`、存档、任务、角色、真实地区/故事、统一产品事件、第三方服务或其他 PR 修改。
- 键盘焦点、OS 的 Enter/Space 行为、窗口失焦和输入门禁、TextEdit 放大后的可滚动性皆必须由后续获授权的人真实验证。可能的 Godot 4 API/类型错误也必须完整记录失败，不能写 PASS。
- `MAX_LOCAL_FIXTURE_BYTES=65536`、`MAX_UNDO=16`、结构诊断数量限制都是先前候选设计值，未测得性能或稳定性边界。

**N24 为新设计和代码候选，不是作者已批准的共享架构。状态：NOT_RUN。**
