# PATCH_SCOPE｜独立修复如何与 PR #30 隔离

- 来源：`cao772/game` [Draft PR #30](https://github.com/cao772/game/pull/30)，固定 HEAD `3806fbf289dbe5bcb89bca11a98971c616ce6ab8`。
- 目标分支：`codex/game-web-region-023-r1`，**直接从 main** `533b11f50c0d359cd0a5424d5216b0145727699a` 建立。新文件只允许 `candidates/game_web_region_023_r1/`。
- 新目录包含一套完整独立 Godot 4 候选所需的源：`project.godot`、`main.tscn`、`integration_demo.gd`、`validated_gateway.gd`、`synthetic_interaction.gd`、`catalog_recovery.gd`、`region_validator.gd`、`synthetic_cases.gd`、`synthetic_regions.json`。这是**复制候选 + 本目录改进**，不是修改原 PR 30 的代码。
- 原样 Git blob 引用：`region_validator.gd = 6b10b8a305cca07e27080406b8e205985334296b`；`synthetic_cases.gd = f83a842f6ee6082d136513460993dd788ecf5806`；`synthetic_regions.json = 2c336868a30f6c247a1a8f04c5d5a5fe5e31bed5`。这些文件**未擅改**。
- 四个本目录内的隔离修订：`validated_gateway.gd`（保留根因、防御结构检查）、`synthetic_interaction.gd`（清空过期坐标）、`catalog_recovery.gd`（读取前大小门禁）、`integration_demo.gd`（诊断原因与只读文本刷新）。
- `project.godot` 和 `main.tscn` 仅修改 N23 的独立候选名称，保留所需 `res://` 相对项目根路径。
- 旧 PR #30 保留 Draft；**不写入 #30、其他 PR、`main`、共享接口**；不合并任何代码；不依赖真实剧情/地点/人物/私有资料。
- 不声称“代码可直接在产品替换”或“修复已经完成运行验收”。未来要验证再另行授权。

**回退路径：** 如果 N23 的修复候选以后被否决，保持原 PR30 不变，关闭/废弃 N23 Draft 即可，不需要更改 `main`。没有文件输出、数据库迁移、事件队列或历史存档转换。

**全部 NOT_RUN。**
