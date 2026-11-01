# GAME-WEB-REGION-026 r1｜菜单 / A-B-C 区域 / 合成事件预览桥

**DRAFT CANDIDATE · NOT_RUN · SYNTHETIC FIXTURES ONLY · NO PRIVATE CONTENT · NO SHARED INTERFACE CHANGES**

N26 在一个新建的独立 Godot 项目目录中，增加从菜单和 A/B/C 区域进入固定合成事件预览的路径。它保留 PR #33 区域实例，事件预览作为单独临时子页；返回来源时恢复同一地区实例。菜单也可直接打开事件预览。事件预览只读取 PR #18 的三个公开 placeholder JSON fixture，不能触发真实事件或改变正式存档。

## 源版本

- [Draft PR #18](https://github.com/cao772/game/pull/18)：HEAD `31bee7fa4a130186c6b889b918712fafa2de84c8`，base 是 `codex/game-web-module-event-001-r1`，base commit `cfd28c5cd30a3c4c163abfde7a3eb9ebcd23eb50`。包含 PR #9 checker 之上的静态分支预览、条件观察门禁、回退/redo、安全前缀和错误诊断候选。
- [Draft PR #33](https://github.com/cao772/game/pull/33)：HEAD `8394140bccd34918a98c43762fe184f8f0517d55`，base main `533b11f50c0d359cd0a5424d5216b0145727699a`。包含菜单→A/B/C 可访问区域独立工程。
- N26 从 main `533b11f50c0d359cd0a5424d5216b0145727699a` 单独创建，不以 PR #18 或 #33 为 base，不修改它们。

## 新增桥接

```text
menu/home ──────→ event preview ──────→ menu/home
    │                  ↑
    │                  │ Back to origin
    ▼                  │
 A/B/C region ─────────┘
    │
    └── Back to menu

event preview:
 fixed EVENT_START / EVENT_NEXT / EVENT_END
      → local fixed-fixture guard
      → caller-injected synthetic observation
      → explicit branch choice
      → preview-only back / forward / rollback
```

- **菜单入口**：菜单概览或状态页可直接打开事件预览；返回回到原菜单页。
- **区域入口**：区域外层工具栏有“打开独立合成事件预览”。事件页打开时原区域实例保持挂载并隐藏；“返回事件预览来源页”恢复同一个区域实例，因此区域的临时位置、核对/更正/撤销状态不会被事件预览读取或覆盖。
- **无 A/B/C→事件自动映射**：事件起点必须由事件页下拉框明确选择。区域入口只传入 `origin_route="region"`，不传区域快照、目标 ID、模型状态或诊断。
- **固定事件图**：复制 PR #18 的三个公开 fixture blob，不改内容。只有当前事件手动注入的合成 signal 与 conditions 匹配时，分支才可选；每次进入下一事件都要为它单独注入观察值。分支必须明确点击；终止链接为 null。
- **返回/销毁**：事件页返回来源时销毁事件预览实例，恢复原来源页；返回菜单概览时销毁事件预览，若事件从区域进入则同时销毁区域。

## PR #18 兼容边界（必须理解）

PR #18 是 Python 3.12+ 标准库 CLI，导入其 stacked base PR #9 的公开 checker 和 SourceIndex。N26 **没有直接启动 Python，也没有复制/改动 PR #9 checker**。新 `event_preview_model_candidate.gd` 是 Godot 侧对公开三份 fixture 的**窄范围重新表达**，用于提供同一类显式预览交互，不是 PR #18 Python 代码的包装，也不宣称 checker/诊断/哈希行为完全等价。

本地守卫只读取三个固定 `res://fixtures/placeholder_*.json`，做受限结构、ID、分支引用和大小检查。它不提供 PR #9 的完整目录扫描、重复 JSON key 侦测、TOCTOU 检查或 SourceIndex 精确行列位置。来源信息保留 fixture 文件名、JSON pointer 和文件 SHA256。要宣称与 PR #18 一致，未来必须在两端同一 fixture 上做独立对照验收。

## 新增文件

- `menu_flow_owner.gd`：唯一拥有 menu / region / event 三种顶层路由的 N26 私有协调器。
- `event_preview_model_candidate.gd`：固定 fixture 守卫、合成观察门禁、显式分支、back/forward/jump/rollback、安全前缀失效、不可变错误回显。
- `event_preview_screen.gd`：事件选择、手动观察注入、分支按钮、诊断与路径展示。
- `main.tscn`、`region_screen.tscn`、`event_preview_screen.tscn`、`project.godot`：独立 Godot 工程入口。
- `accessible_demo.gd` 等九个区域脚本/fixture：与 PR #33 指定 HEAD 相同 Git blob。
- `fixtures/placeholder_start.json`、`placeholder_next.json`、`placeholder_end.json`：与 PR #18 指定 HEAD 相同 Git blob。
- `DESIGN.md`、`STATE_OWNERSHIP.md`、`SOURCE_REVIEW.md`、`RESOURCE_PATHS.md`、`FUTURE_ACCEPTANCE.md`：设计、状态、来源、恢复和未来验收。

## 重要限制

- 所有 ID、signal、condition、action 都是公开合成占位符；没有故事、角色、地点、手稿或私有数据。
- 不读取区域的内部 `_gateway`、快照、坐标或诊断；不创建 A/B/C 与事件的关系。
- 不执行 event bus、游戏效果、世界时钟、存档、输入映射、网络、文件写回或自动修复。
- 事件 fixture 失效时显示 BLOCKED，不换用其它目录、不猜测数据、不自动 fallback；可显式重新读取固定 fixture 或返回来源。
- 必需脚本缺失/解析错误可能导致 Godot 导入失败，不能承诺由页面内按钮恢复。
- 本地结构守卫不是 PR #9 checker，也不能把运行时显示的本地接受状态称为 PR #9 PASS。

**本任务状态：NOT_RUN。** 没有运行 Godot、GDScript、Python、CLI、解析器、测试、CI、截图或性能测量。GitHub 源码提交/回读仅证明文件存在与变更范围。
