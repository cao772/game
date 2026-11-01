# SOURCE_REVIEW｜PR #30 事实边界和精确 Git 证据

本轮通过 GitHub 只读连接器实际读取 [Draft PR #30](https://github.com/cao772/game/pull/30) 元数据、完整 15 文件名、下列源码全文与对应固定行号段。PR #30 审阅时：Draft/Open，head `codex/game-web-region-022-r1`，**HEAD `3806fbf289dbe5bcb89bca11a98971c616ce6ab8`**，base `main` `533b11f50c0d359cd0a5424d5216b0145727699a`。

## 已读取的来源文件与静态功能定位

| PR #30 文件（该 SHA 下） | 固定源 Git blob | 静态审查重点 |
| --- | --- | --- |
| [`validated_gateway.gd`](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/validated_gateway.gd) | `2ae336133413d69138fb328498415240ae0114bd` | 单入口回退、目录白名单、三态阻断、snapshot |
| [`synthetic_interaction.gd`](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/synthetic_interaction.gd) | `388abc4fda34937009687554fae067944ca352c8` | reset、坐标、BFS、采样 LOS、Inspect/Correct/Undo |
| [`catalog_recovery.gd`](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/catalog_recovery.gd) | `f3e9bd6aab7e9965e93b3139a4f66453b816a7b4` | 固定合成资源、三态回退、读取前大小风险 |
| [`integration_demo.gd`](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/integration_demo.gd) | `d438781d95327947db3660b48ebce6c95b50ff7e` | 只读诊断文本、原因丢失、刷新滚动状态 |
| [`region_validator.gd`](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/region_validator.gd) | `6b10b8a305cca07e27080406b8e205985334296b` | 结构规则、16000 字符与 48 诊断候选上限 |
| [`synthetic_cases.gd`](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/synthetic_cases.gd) | `f83a842f6ee6082d136513460993dd788ecf5806` | 纯合成错误样本，不是运行测试 |
| [`synthetic_regions.json`](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/synthetic_regions.json) | `2c336868a30f6c247a1a8f04c5d5a5fe5e31bed5` | 公开固定 A/B/C，不涉私有设定 |
| [`project.godot`](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/project.godot) | `0d5d189cf8d7ae4e76a2f3a4afb4d3b66d537cda` | Godot 根、`res://main.tscn` |
| [`main.tscn`](https://github.com/cao772/game/blob/3806fbf289dbe5bcb89bca11a98971c616ce6ab8/candidates/game_web_region_022_r1/main.tscn) | `bc6abd3cb9697d00c62a28f8f5d5c46e32255da2` | 主场景到 `res://integration_demo.gd` |

完整源码观察已经分层记录在 [FINDINGS.md](FINDINGS.md)：明确引用的 L21–30、L36–42、L55–70、L60–74、L176–221 等都是 PR30 的**原始行号**。N23 修改源后对应行号会移动；请勿把 N23 新文件行号误归因到 PR30。

## 变更不等于验证

本轮只对读到的源码按文本进行独立候选修订并上传 GitHub。没有调用 Godot、没有执行 GDScript/JSON 解析、没有开展单元/端到端测试或 GUI 操作。没有获授权的自动化 CI 主张。编译、滚动条 API、资源异常条件、四向 BFS 行为、撤销正确性、引擎运行与视觉/键盘无障碍都属于**未来验收**。

本次 PR 应仅包含独立新目录，不得修改 #30、本项目 `main` 或共享接口。**审阅与修订状态：NOT_RUN。**
