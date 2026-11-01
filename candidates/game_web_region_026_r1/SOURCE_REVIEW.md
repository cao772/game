# SOURCE_REVIEW｜PR #18 + PR #33 只读源码依据

**本轮读取的固定版本；源内容只用于界定候选，不代表通过运行验收。**

## PR #18｜合成事件预览

- [Draft PR #18](https://github.com/cao772/game/pull/18)，open/Draft，branch `codex/game-web-flow-event-004-r1`，HEAD **`31bee7fa4a130186c6b889b918712fafa2de84c8`**，base `codex/game-web-module-event-001-r1`，base commit **`cfd28c5cd30a3c4c163abfde7a3eb9ebcd23eb50`**。
- 实际读取 PR body 的 EVENT-004/PLAY-EVENT-005/EVENT-006 范围，`README.md`、`event_flow_preview_candidate.py`、`event_play_preview_candidate.py`、`event_preview_diagnostics_006_candidate.py`、`integration_event_006.md`、`acceptance_event_006.md` 和三份 placeholder fixture。
- PR #18 是**叠加在 PR #9 checker 分支上的 Draft**，不是以 main 为 base 的独立分支。其 `event_flow_preview_candidate.py` 从同级目录导入 PR #9 的 `event_data_check_candidate.py` 和 `event_source_diagnostics_candidate.py`，Python 预览需 PR #9 的 checker/source-indexer 依赖。PR #18 README 明确声明只对 public synthetic placeholder contract，不是 private EVENT001 schema 或正式 runtime。

### PR #18 源码对应事实

| 固定源文件 | 静态事实 |
| --- | --- |
| [`event_flow_preview_candidate.py` L93–206](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_flow_preview_candidate.py#L93-L206) | 所选文件经 PR #9 checker gate 后构造每次调用的内存快照；没有持久事件状态 |
| [`event_flow_preview_candidate.py` L209–260](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_flow_preview_candidate.py#L209-L260) | `requirements_for/options_for` 从 trigger/actions 提取公开元数据；只有 on_ignore 字段存在才提供 ignore |
| [`event_flow_preview_candidate.py` L263–355](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_flow_preview_candidate.py#L263-L355) | 静态分支需显式选择；terminal/null 没有后续选项；有 step cap 与来源指针/哈希 |
| [`event_play_preview_candidate.py` L44–149](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_play_preview_candidate.py#L44-L149) | 合成观察值、条件 gate、snapshot、back/redo breadcrumbs |
| [`event_play_preview_candidate.py` L178–253](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_play_preview_candidate.py#L178-L253) | observation 改变时清除 redo 或回退到首个受影响步骤之前的 safe prefix |
| [`event_play_preview_candidate.py` L254–419](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_play_preview_candidate.py#L254-L419) | 显式 choose/back/forward/jump/rollback；rollback 不允许向前；错误不改变 snapshot |
| [`event_preview_diagnostics_006_candidate.py` L1–178](https://github.com/cao772/game/blob/31bee7fa4a130186c6b889b918712fafa2de84c8/candidates/game_web_flow_event_004_r1/event_preview_diagnostics_006_candidate.py#L1-L178) | 条件 reason codes、source locations、navigation breadcrumbs 和 review-only error presentation |

### 三份 PR #18 固定 fixture

| 文件 | 事件定义（仅公开合成字段） | Git blob |
| --- | --- | --- |
| `placeholder_start.json` | EVENT_START / SIGNAL_START / FLAG_READY；ACTION_TO_NEXT→EVENT_NEXT、ACTION_END→null、ignore→EVENT_END | `bdae5dc05477379feff330ae6e7290a0eee906e0` |
| `placeholder_next.json` | EVENT_NEXT / SIGNAL_NEXT / FLAG_READY；ACTION_FINISH→EVENT_END、ACTION_STOP→null；无 on_ignore 字段 | `c1c318dd9f2102d67e40e6dabe6feaba55a0b229` |
| `placeholder_end.json` | EVENT_END / SIGNAL_END / FLAG_READY；ACTION_COMPLETE→null；on_ignore 存在且为 null | `5406a6a6035a661eaa110bdfa7f3cd34eeed39be` |

## PR #33｜菜单与 A/B/C 区域

- [Draft PR #33](https://github.com/cao772/game/pull/33)，open/Draft，branch `codex/game-web-region-025-r1`，HEAD **`8394140bccd34918a98c43762fe184f8f0517d55`**，base main `533b11f50c0d359cd0a5424d5216b0145727699a`。
- 实际读取 PR body、`menu_flow_owner.gd`、`accessible_demo.gd`、`STATE_OWNERSHIP.md`、`DESIGN.md`、`FUTURE_ACCEPTANCE.md`；核对区域 9 份源文件的 blob。
- PR #33 的 menu coordinator 只负责 menu/region；区域本身是 Control，A/B/C Gateway 与 Interaction 自己管理状态。其区域外层没有 event preview route。
- N26 不改写 #33 的菜单或区域接口；复制 9 个原样区域 blob，另建自己的 menu/event coordinator。

### PR #33 九份区域原样 Git blob

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

## N26 自身实现边界

N26 新增 `menu_flow_owner.gd`、`event_preview_model_candidate.gd`、`event_preview_screen.gd` 和独立场景。事件模型是**GDScript 固定夹具适配器**，不是 PR #18 Python 代码复用；不复制 PR #9 checker，不宣称 PR #9 checker PASS。仅保留 fixture SHA256 与 JSON pointer，缺少 PR #18 SourceIndex 的精确 line/column 诊断和完整重复 JSON key 检查。未来验收必须记录这项差异，不能以静态相似冒充等价。

**源文件 readback / blob identity ≠ Godot 导入或功能 PASS。全部 NOT_RUN。**
