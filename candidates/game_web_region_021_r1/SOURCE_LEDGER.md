# SOURCE_LEDGER｜固定版本与可定位文件索引

**审阅方式：** GitHub 连接器只读查询 PR 元数据、变更文件清单及关键源码；未运行代码、解析器、Godot 或测试。以下直链固定到精确 HEAD 的源文件行号，不用浮动分支代替审计证据。状态截面：2026-11-01，**NOT_RUN**。

## 1. 四份实际 Draft PR

| PR | Repo / head SHA | 按 GitHub 变更清单可确认的新增目录 |
| --- | --- | --- |
| [#25](https://github.com/cao772/game/pull/25) | `codex/game-web-region-017-r1` / `8372c1fe5f6471ec6af788b65b68fa54fe7db65a` | `candidates/game_web_region_017_r1/`：10 文件 |
| [#26](https://github.com/cao772/game/pull/26) | `codex/game-web-region-018-r1` / `cd15ec7bc04cceb388f5174b3d8e83e620a23205` | `candidates/game_web_region_018_r1/`：11 文件 |
| [#27](https://github.com/cao772/game/pull/27) | `codex/game-web-region-019-r1` / `fdbb6688d07a6a7cebe36b999b82482987362499` | `candidates/game_web_region_019_r1/`：11 文件 |
| [#28](https://github.com/cao772/game/pull/28) | `codex/game-web-region-020-r1` / `6eb7ee2f889305ec1211441c7848637bc1c551c1` | `candidates/game_web_region_020_r1/`：13 文件 |

四个 PR 都是 Draft/Open、base `main` 且当时 base SHA 为 `533b11f50c0d359cd0a5424d5216b0145727699a`。**没有**观察到已合并成一个集成分支的证据；此处不能断言未来的 HEAD 不会变化。

## 2. 关键源码（精确行号引用）

### #25 / 017｜基础交互
- [`region_model.gd` L38–114](https://github.com/cao772/game/blob/8372c1fe5f6471ec6af788b65b68fa54fe7db65a/candidates/game_web_region_017_r1/region_model.gd#L38-L114)：`load_catalog` 选外部合成 fixture 或内置合成 fallback、`_valid_catalog` 只返回 Boolean。
- [`region_model.gd` L152–200](https://github.com/cao772/game/blob/8372c1fe5f6471ec6af788b65b68fa54fe7db65a/candidates/game_web_region_017_r1/region_model.gd#L152-L200)：四邻 BFS、采样式 `_visible`。
- [`region_model.gd` L219–257](https://github.com/cao772/game/blob/8372c1fe5f6471ec6af788b65b68fa54fe7db65a/candidates/game_web_region_017_r1/region_model.gd#L219-L257)：合成位置移动、核对、显式更正；**该版本无撤销栈**。
- [`region_demo.gd` L44–95](https://github.com/cao772/game/blob/8372c1fe5f6471ec6af788b65b68fa54fe7db65a/candidates/game_web_region_017_r1/region_demo.gd#L44-L95)：最初的独立 Control 面板。
- [`map_view.gd` L65–96](https://github.com/cao772/game/blob/8372c1fe5f6471ec6af788b65b68fa54fe7db65a/candidates/game_web_region_017_r1/map_view.gd#L65-L96)：点击/键盘焦点处理。

### #26 / 018｜无颜色、键盘、撤销
- [`region_model.gd` L4–22](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_model.gd#L4-L22)：仍是固定合成版本；审计/撤销上限为候选常数 `12/16`。
- [`region_model.gd` L237–311](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_model.gd#L237-L311)：更正、撤销、清预览、snapshot 字段。
- [`region_demo.gd` L85–153](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_demo.gd#L85-L153)：文字 100/125/150%、动效选项、方向按钮、文本图例。
- [`region_demo.gd` L227–326](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_demo.gd#L227-L326)：逐行文本地图、状态/恢复说明、GUI 焦点与窗口失焦。
- [`map_view.gd` L46–121](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/map_view.gd#L46-L121)：字符纹理替代、仅在网格聚焦时消耗方向键、焦点框。

### #27 / 019｜独立证据卡
- [`region_demo.gd` L5–33](https://github.com/cao772/game/blob/fdbb6688d07a6a7cebe36b999b82482987362499/candidates/game_web_region_019_r1/region_demo.gd#L5-L33)：新增 `GuideScript` 与只读卡变量。
- [`region_demo.gd` L155–220](https://github.com/cao772/game/blob/fdbb6688d07a6a7cebe36b999b82482987362499/candidates/game_web_region_019_r1/region_demo.gd#L155-L220)：`TextEdit` 只读卡、固定/清除、换场/重置销毁固定卡。
- [`region_demo.gd` L285–338](https://github.com/cao772/game/blob/fdbb6688d07a6a7cebe36b999b82482987362499/candidates/game_web_region_019_r1/region_demo.gd#L285-L338)：实时证据卡在 `_refresh` 更新、焦点文字。
- [`state_guide.gd` L8–46](https://github.com/cao772/game/blob/fdbb6688d07a6a7cebe36b999b82482987362499/candidates/game_web_region_019_r1/state_guide.gd#L8-L46)：`inspected` 门控，分离“记录主张”与“模拟观察”，只返回文字及建议。
- [`region_model.gd`](https://github.com/cao772/game/blob/fdbb6688d07a6a7cebe36b999b82482987362499/candidates/game_web_region_019_r1/region_model.gd)、[`map_view.gd`](https://github.com/cao772/game/blob/fdbb6688d07a6a7cebe36b999b82482987362499/candidates/game_web_region_019_r1/map_view.gd)：Git blob 分别与 #26 完全一致。

### #28 / 020｜数据结构诊断（**未与前述 Loader 接通**）
- [`region_validator.gd` L1–58](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/region_validator.gd#L1-L58)：候选输入/诊断上限、错误对象及 JSON 解析入口。
- [`region_validator.gd` L59–129](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/region_validator.gd#L59-L129)：版本、三组场景/唯一 ID、字段类型、额外字段警告。
- [`region_validator.gd` L129–179](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/region_validator.gd#L129-L179)：网格行数、字符、周边墙、唯一 S/T。
- [`catalog_recovery.gd` L25–75](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/catalog_recovery.gd#L25-L75)：对独立合成数据执行验证并显式区分 `SOURCE_ACCEPTED/FALLBACK_SYNTHETIC/BLOCKED`。
- [`synthetic_boundary_cases.gd` L4–49](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/synthetic_boundary_cases.gd#L4-L49)：合成结构边界**样例**（并非实际测试结果）。
- [`diagnostics_demo.gd` L61–102](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/diagnostics_demo.gd#L61-L102)：仅展示诊断/恢复，不承担 #26 的移动/记录更正。
- [`INPUT_FORMAT.md`](https://github.com/cao772/game/blob/6eb7ee2f889305ec1211441c7848637bc1c551c1/candidates/game_web_region_020_r1/INPUT_FORMAT.md)：作者已写的候选格式对照，不是权威共享协议。

## 3. 四份相同的纯合成 Fixture

`synthetic_regions.json` 的 Git blob **四份相同**：`2c336868a30f6c247a1a8f04c5d5a5fe5e31bed5`。格式为一项 `schema_version`，三项 A/B/C 字母合成格网，每项包含 `id/title/grid/claimed(reachable,visible)`。版本字面量含 `017` 是沿袭旧候选，不能据此认定所有产品组件被固定为该正式版本。

## 4. 证据边界

以上“存在函数/字段/调用”的判断由只读源文本支持。**不代表** GDScript 语法/API 实际通过、Godot 工程已能启动、BFS/视线完全正确、鼠标或 Tab 行为已验收、结构诊断真的返回所列错误或四模块能够共存。本轮统一状态：**NOT_RUN**。
