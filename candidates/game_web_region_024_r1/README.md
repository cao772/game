# GAME-WEB-REGION-024 r1｜合成校验/回退交互的键盘与文本可达候选

**DRAFT · NOT_RUN · PUBLIC SYNTHETIC A/B/C ONLY · NOT CANON · NO MAIN OR SHARED INTERFACE CHANGE**

这是一份**完整、独立的 Godot 4 源码候选工程**；没有运行 Godot、代码、解析器、测试、CI、GUI、屏幕阅读器或性能评估。它不适配真实游戏输入、存档、角色、地点或小说内容。

## 只读来源

- [Draft PR #26](https://github.com/cao772/game/pull/26) `cd15ec7bc04cceb388f5174b3d8e83e620a23205`：从实际 `region_demo.gd`、`map_view.gd`、`region_model.gd`、`KEYBOARD.md` 和 `DESIGN.md` 参考 **Tab/Shift+Tab + 方向按钮 + 聚焦地图的 WASD/方向键 + Esc、焦点文字、100/125/150% 字号和无颜色字符状态**。原 PR 中动效 Off/Slow/Normal 为候选，N24 **默认完全不提供动画**，避免再增交互维度。
- [Draft PR #31](https://github.com/cao772/game/pull/31) `b65ebbb729c67ee94d41778b7d8c996bc5f8235d`：按 Git blob **原样**复用单一结构校验/安全回退网关与合成交互模型，以及固定 A/B/C 夹具。没有复制 PR #26 的第二套 Boolean loader。
- 当前新分支从 `main` `533b11f50c0d359cd0a5424d5216b0145727699a` 独立创建，**未在 PR #26 或 #31 分支上继续提交**。

## 文件分层

| 文件 | 责任 |
| --- | --- |
| `region_validator.gd` | **原样复制 #31**：结构校验与字段级报错 |
| `catalog_recovery.gd` | **原样复制 #31**：唯一固定资源读取与合成回退 |
| `validated_gateway.gd` | **原样复制 #31**：`SOURCE_ACCEPTED/FALLBACK_SYNTHETIC/BLOCKED` 门禁、字段白名单 |
| `synthetic_interaction.gd` | **原样复制 #31**：纯内存 A/B/C 模拟移动/核对/更正/撤销 |
| `synthetic_cases.gd`、`synthetic_regions.json` | 原样复制的合成案例和唯一 JSON 夹具 |
| `semantic_status.gd` | **N24 新增**：单独呈现来源、回退、阻断、claim/actual、错误原因及角色坐标的非颜色文本 |
| `keyboard_grid.gd` | **N24 新增**：只有该控件聚焦时接收非重复 WASD/箭头，一次发出一格移动请求；Esc 释放 |
| `accessible_demo.gd` | **N24 新增**：全键盘可达的原生按钮与选择器、焦点文字、移动失焦门禁、文字大小选项和只读文字地图 |
| `project.godot`、`main.tscn` | 唯一独立候选项目根与入口 |
| `DESIGN.md`、`KEYBOARD_PATHS.md`、`SOURCE_REVIEW.md`、`RESOURCE_BOUNDARY.md`、`FUTURE_ACCEPTANCE.md` | 设计取舍、静态依赖与未来授权验收 |

## 拟议操作（未执行）

1. 原生 Tab / Shift+Tab 进入所有按钮、A/B/C 选择器、文字大小选择器、文本区与独立网格；Enter/Space 启动按钮。无需任何鼠标/触屏或颜色提示。
2. 用四个可见方向按钮移动 P；也可键盘选中“焦点转到网格”再使用 WASD/方向键，一次仅处理非重复的键盘事件，Esc 退出网格。网格只发出请求，实际能否移动始终由 #31 网关/内存模型决定。
3. 文字缩放可选 100%、125%、150%；文本区仍允许滚动/选择。**不加动画、声音、图片或自定义字体**。
4. 文本中明确区分 `SOURCE_ACCEPTED`（原合成结构接受）、`FALLBACK_SYNTHETIC`（原输入被拒，使用内置合成副本）、`BLOCKED`（交互不可用），保持源错误代码、字段路径、原因与修复建议。
5. 主张 `claim` 与模拟核对 `actual` 分开；只有执行“1. 核对”后才显示观察；之后点击“2. 明确更正内存记录”才改变主张。移动/撤销/换场须重新核对。
6. 如果失去原生窗口焦点，键盘移动暂停直到重新聚焦且释放所有八个移动键；绝不自动更正、读档或切换场景。**实际平台表现尚待测试。**
7. `BLOCKED` 时禁用场景/操作按钮；“重新读取固定合成数据”和纯合成错误样本入口仍可使用，用于显示来源与恢复。缺必需脚本/引擎不是可自动降级的资源缺失。

## 结论边界

本候选的“无障碍”含义是**为键盘、文字放大和非颜色识别设计的可测源码**，不是 WCAG、平台辅助技术或屏幕阅读器的达标声明。真实焦点顺序、OS 缩放、窄窗口、中文字体与长文阅读、Alt+Tab、Godot 语法及性能全都 **NOT_RUN**。本任务绝不合并 `main`，没有改变 #26、#31 或任何共享接口。
