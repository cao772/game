# SOURCE_REVIEW｜固定 PR #26 与 PR #31 源级阅读

**审查时 GitHub 实际状态，非 Godot 实测：**
- `cao772/game` [Draft PR #26](https://github.com/cao772/game/pull/26)：Draft/Open，`codex/game-web-region-018-r1`，精确 HEAD **`cd15ec7bc04cceb388f5174b3d8e83e620a23205`**，目标 `main`。
- [Draft PR #31](https://github.com/cao772/game/pull/31)：Draft/Open，`codex/game-web-region-023-r1`，精确 HEAD **`b65ebbb729c67ee94d41778b7d8c996bc5f8235d`**，目标 `main`。
- `main` 审阅时 `533b11f50c0d359cd0a5424d5216b0145727699a`；N24 从该 SHA **独立创建** `codex/game-web-region-024-r1`，不叠加任何旧 Draft 分支。

## PR #26 读取到的真实文件

| 文件与固定行号 | 源码事实 |
| --- | --- |
| [`region_demo.gd` L34–73](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_demo.gd#L34-L73) | Label、Button、OptionButton、白边焦点样式及聚焦 callback |
| [`region_demo.gd` L84–153](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_demo.gd#L84-L153) | A/B/C 选择、缩放/动效选择、方向按钮、文字/回退提示 |
| [`region_demo.gd` L157–171](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_demo.gd#L157-L171) | 字体缩放 100/125/150%，通过本地主题字体大小覆盖 |
| [`region_demo.gd` L227–295](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_demo.gd#L227-L295) | 字符行地图、claim/observed 分层、目前焦点的文本 |
| [`region_demo.gd` L297–326](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/region_demo.gd#L297-L326) | 窗口失焦和松开按键后恢复移动的候选门禁 |
| [`map_view.gd` L60–90](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/map_view.gd#L60-L90) | `# . : S T P` 字符 + 非独占颜色的栅格显示 |
| [`map_view.gd` L92–118](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/map_view.gd#L92-L118) | 网格有焦点时消费 WASD/方向键；Esc 离焦 |
| [`KEYBOARD.md`](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/KEYBOARD.md)、[`DESIGN.md`](https://github.com/cao772/game/blob/cd15ec7bc04cceb388f5174b3d8e83e620a23205/candidates/game_web_region_018_r1/DESIGN.md) | 已标 **NOT_RUN**，键盘/无障碍期望而非实测 |

## PR #31 读取到的真实文件

| 文件与固定行号 | 源码事实 |
| --- | --- |
| [`validated_gateway.gd` L21–120](https://github.com/cao772/game/blob/b65ebbb729c67ee94d41778b7d8c996bc5f8235d/candidates/game_web_region_023_r1/validated_gateway.gd#L21-L120) | 唯一单入口合成校验/回退、`SOURCE_ACCEPTED/FALLBACK_SYNTHETIC/BLOCKED`、拒绝异常字段 |
| [`synthetic_interaction.gd` L126–197](https://github.com/cao772/game/blob/b65ebbb729c67ee94d41778b7d8c996bc5f8235d/candidates/game_web_region_023_r1/synthetic_interaction.gd#L126-L197) | 四邻移动、回退路线、Inspect/Correct/Undo、未核对时 actual 为空 |
| [`catalog_recovery.gd` L62–82](https://github.com/cao772/game/blob/b65ebbb729c67ee94d41778b7d8c996bc5f8235d/candidates/game_web_region_023_r1/catalog_recovery.gd#L62-L82) | 唯一本地可选合成 JSON 读取、读取前大小检查与合成 fallback |
| [`integration_demo.gd` L176–232](https://github.com/cao772/game/blob/b65ebbb729c67ee94d41778b7d8c996bc5f8235d/candidates/game_web_region_023_r1/integration_demo.gd#L176-L232) | 字段级错误展示、只读地图及诊断文本、“未核对”提示、数据来源 |
| [`RESOURCE_PATHS.md`](https://github.com/cao772/game/blob/b65ebbb729c67ee94d41778b7d8c996bc5f8235d/candidates/game_web_region_023_r1/RESOURCE_PATHS.md) | 独立子目录应作为 Godot 根；必需脚本缺失为导入阻塞，不是成功 fallback |

**N24 精确复用的六个 Git blob：**
- `validated_gateway.gd`: `679d4668b54eb31663455dca4190c25a08c3d3f1`
- `synthetic_interaction.gd`: `6ef3f76aa45e25c74ef0479112f87be3cc7ffdb2`
- `catalog_recovery.gd`: `1e40cbe9bb28f75f32fc24ca97c3575cf062ce7e`
- `region_validator.gd`: `6b10b8a305cca07e27080406b8e205985334296b`
- `synthetic_cases.gd`: `f83a842f6ee6082d136513460993dd788ecf5806`
- `synthetic_regions.json`: `2c336868a30f6c247a1a8f04c5d5a5fe5e31bed5`

**设计与事实边界：** N24 的新 UI 并不是 #26 的 `region_demo.gd` 或 `map_view.gd` 直接复制，而是根据两个来源的公开机制**新建适配版**。没有读取非公开作品、聊天证据或故事地图；没有运行任何源码、解析器或 Godot。源文件存在不能证明其能编译、Tab 焦点与屏幕阅读器通过。统一状态 **NOT_RUN**。
