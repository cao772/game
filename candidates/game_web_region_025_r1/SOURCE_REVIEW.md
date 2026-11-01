# SOURCE_REVIEW｜仅公开 GitHub Draft PR #24 与 #32

**本轮实际 GitHub 只读读取，固定 HEAD，全部 NOT_RUN：**

- [PR #24](https://github.com/cao772/game/pull/24)，Draft/Open，`codex/game-web-flow-shell-004-r1`，HEAD **`5768eeef65fe5d54b1c5a692c44400332da61506`**，base `main`。文件列表含 `shell_candidate.gd`、`flow_root.gd`、`play_005/play_shell.gd`、`play_006/target_event_bridge_candidate.gd`、独立 `project.godot`、`flow_entry.tscn` 等。实际读取上述关键源码以及设计文档。
- [PR #32](https://github.com/cao772/game/pull/32)，Draft/Open，`codex/game-web-region-024-r1`，HEAD **`cc70e20dbf916bb15c1844c1efb749adb6c14b4d`**，base `main`。实际读取整个九份区域 `.gd/.json` 源码，以及变更文件清单。
- main 当次 HEAD：**`533b11f50c0d359cd0a5424d5216b0145727699a`**，tree `68cbdca4bf8824ca428a204e205945edfc48ae5d`。N25 从该提交建立新分支，**没有**在 PR #24 / #32 之上提交。

## 源码行号对应的静态事实

| 源文件（精确提交固定链接） | 本轮使用的事实/边界 |
| --- | --- |
| [#24 `shell_candidate.gd` L11–31](https://github.com/cao772/game/blob/5768eeef65fe5d54b1c5a692c44400332da61506/candidates/game_web_flow_shell_004_r1/shell_candidate.gd#L11-L31) | shell 页和 missing/disabled/pending/degraded 候选状态 |
| [#24 `shell_candidate.gd` L120–159](https://github.com/cao772/game/blob/5768eeef65fe5d54b1c5a692c44400332da61506/candidates/game_web_flow_shell_004_r1/shell_candidate.gd#L120-L159) | 私有 `show_page/go_back`、最多 24 条菜单历史 |
| [#24 `play_005/play_shell.gd` L72–108](https://github.com/cao772/game/blob/5768eeef65fe5d54b1c5a692c44400332da61506/candidates/game_web_flow_shell_004_r1/play_005/play_shell.gd#L72-L108) | `return_menu/return_previous` 清理原来的区域/事件上下文 |
| [#24 `play_005/play_shell.gd` L178–247](https://github.com/cao772/game/blob/5768eeef65fe5d54b1c5a692c44400332da61506/candidates/game_web_flow_shell_004_r1/play_005/play_shell.gd#L178-L247) | 资源存在/类型检查、缺失时 BLOCKED、不自动替换 |
| [#24 `play_005/play_shell.gd` L244–333](https://github.com/cao772/game/blob/5768eeef65fe5d54b1c5a692c44400332da61506/candidates/game_web_flow_shell_004_r1/play_005/play_shell.gd#L244-L333) | 原“region”是真实代码层面的**合成 Node3D + `flow_snapshot`**，并有独立 target→event 映射；与 #32 的 UI Control **不兼容直接替换** |
| [#32 `accessible_demo.gd` L5–37](https://github.com/cao772/game/blob/cc70e20dbf916bb15c1844c1efb749adb6c14b4d/candidates/game_web_region_024_r1/accessible_demo.gd#L5-L37) | region Control 自己预加载 Gateway/Case/Status/Grid，并在 `_ready` 读取固定合成源 |
| [#32 `accessible_demo.gd` L92–152](https://github.com/cao772/game/blob/cc70e20dbf916bb15c1844c1efb749adb6c14b4d/candidates/game_web_region_024_r1/accessible_demo.gd#L92-L152) | 区域自身的独立 UI 与原生 Tab、A/B/C、移动按钮、缩放、诊断 |
| [#32 `validated_gateway.gd` L21–120](https://github.com/cao772/game/blob/cc70e20dbf916bb15c1844c1efb749adb6c14b4d/candidates/game_web_region_024_r1/validated_gateway.gd#L21-L120) | 区域独占校验/回退/阻断状态，无共同“菜单 route”合同 |
| [#32 `synthetic_interaction.gd` L21–61](https://github.com/cao772/game/blob/cc70e20dbf916bb15c1844c1efb749adb6c14b4d/candidates/game_web_region_024_r1/synthetic_interaction.gd#L21-L61) | `reset/configure` 维护起终点/玩家坐标与主张 |
| [#32 `synthetic_interaction.gd` L126–197](https://github.com/cao772/game/blob/cc70e20dbf916bb15c1844c1efb749adb6c14b4d/candidates/game_web_region_024_r1/synthetic_interaction.gd#L126-L197) | 模拟移动、核对、更正、撤销、无核对时 actual 为空 |
| [#32 `catalog_recovery.gd` L62–82](https://github.com/cao772/game/blob/cc70e20dbf916bb15c1844c1efb749adb6c14b4d/candidates/game_web_region_024_r1/catalog_recovery.gd#L62-L82) | 唯一可选固定合成 JSON，缺失/损坏时 PR #32 自有的合成 fallback |
| [#32 `keyboard_grid.gd` L42–60](https://github.com/cao772/game/blob/cc70e20dbf916bb15c1844c1efb749adb6c14b4d/candidates/game_web_region_024_r1/keyboard_grid.gd#L42-L60) | 网格焦点下才处理非重复 WASD/方向键，Esc 离开 |

## 九个 PR #32 原始 blob（N25 未作任何更改）

| 文件 | Git blob |
| --- | --- |
| `accessible_demo.gd` | `14c51a3fa0d8061f59cfe3befef50133bb7fe5a1` |
| `keyboard_grid.gd` | `b69c748a98800c7b2c952dd59d9d2ab060b5b140` |
| `semantic_status.gd` | `63c200e9fbedab878f5179cbf13a3e6ecdcc851f` |
| `validated_gateway.gd` | `679d4668b54eb31663455dca4190c25a08c3d3f1` |
| `synthetic_interaction.gd` | `6ef3f76aa45e25c74ef0479112f87be3cc7ffdb2` |
| `catalog_recovery.gd` | `1e40cbe9bb28f75f32fc24ca97c3575cf062ce7e` |
| `region_validator.gd` | `6b10b8a305cca07e27080406b8e205985334296b` |
| `synthetic_cases.gd` | `f83a842f6ee6082d136513460993dd788ecf5806` |
| `synthetic_regions.json` | `2c336868a30f6c247a1a8f04c5d5a5fe5e31bed5` |

**注意：** 原 PR #24 的菜单区域目标与事件映射不是 N25 的输入。N25 只借鉴其公开菜单行为；没有把两者之间的 `flow_snapshot/Node3D` 强行转换为未批准的新共享接口。

**审查证明的是文件结构和候选语义，不证明任何 Godot 导入、GDScript 解析、菜单操作、回退或返回成功。所有源码/验收状态：NOT_RUN。**
