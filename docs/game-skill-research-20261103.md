# Game Skill v1：来源筛选与整合记录

2026-11-03。六个模块来自四个固定版本的开源仓库，重写为一个中文项目 Skill。实际效果尚无独立比较评测；星标是关注度，不能代替质量评分。

# 来源、选型与适用限制

采样日期：2026-11-03，Asia/Shanghai。元数据来自 GitHub API，当日数值可变；完整 commit、许可文件见 ../sources-lock.json。未找到统一、可信的 Skill 用户评分，本次不宣称“公认最佳”。选型结合关注度、正文可用性、维护记录、公开问题与项目适配。

## 纳入的六个模块

| 仓库与模块 | 仓库关注度 | 纳入理由 | 限制与处理 |
| --- | --- | --- | --- |
| [qiaomu-novel-generator](https://github.com/joeseesun/qiaomu-novel-generator) | 396 星／46 forks | 中文故事愿望、冲突、悬念、对白、开篇清晰度 | 面向短篇；不采用默认篇幅和逐步确认，改成长篇章节及游戏场景 |
| [creative-writing-skills](https://github.com/haowjy/creative-writing-skills)：story-planning | 558 星／77 forks | 长篇结构、章节与场景功能 | 不安装其多代理运行器，不迁移现有资料树 |
| 同仓库：creative-writing-craft | 同上，不能重复相加 | 场景进入、对白潜台词、节奏与视角 | 只纳入可移植写作方法 |
| 同仓库：story-review | 同上 | 结构先于文字、连续性定位、编辑层次 | [Issue #8](https://github.com/haowjy/creative-writing-skills/issues/8) 指出路径及宿主依赖问题；本包不调用这些脚本 |
| [agentic-awesome-skills](https://github.com/sickn33/agentic-awesome-skills)：game-development/game-design | 49,052 星／7,120 forks | 核心循环、GDD、成长与反馈基础 | 星数属于大型合集，不是单项评分；方法简洁，辅以原始设计资料 |
| [game-dev-agent-skills](https://github.com/ncdlek/game-dev-agent-skills)：game-quest-narrative-architect | 3 星／1 fork | 状态持久化、分支后果与非顺序任务检查很贴合本项目 | 仅补充参考，无足够口碑；删去武断阈值、普遍化 NPC 死亡规则及自动执行要求 |

以上模块已按固定 commit 拉取到项目研究目录；实际启用的是整合重写的 game Skill。既有 qiaomu 本机版本保留，没有覆盖更新。

## 审阅到的质量证据

乔木仓库提供样例和检查脚本，发布 PR 自报结构检查通过；这是作者自报，不是独立写作效果实证。Creative Writing Skills 有具体的外部审阅反馈，既有认可也有缺陷；本次阅读了场景、章节、连续性正文和公开 Issue #8。大型游戏合集提供基础清单，无法单凭热度证明作品质量。

补充任务 Skill 细致，但有“低完成率直接等于损坏”等过强断言；整合版将其改为待调查信号。未复制其验证脚本，也未执行下载源中的命令。

## 未打包的候选

- [Yuki001/game-dev-skills](https://github.com/Yuki001/game-dev-skills)：107 星／13 forks，内容方向相关；所查树与 API 未发现明确仓库许可，故仅记录入口，不复制其内容。
- [morbeo/ai-skills](https://github.com/morbeo/ai-skills)：0 星，CC0；没有足够社区信号，未优先采用。
- [oleg-riazantsev/skills-saschb](https://github.com/oleg-riazantsev/skills-saschb)：0 星，MIT；有拆解框架，但未优先于已有来源纳入。

## 非 Skill 资料

详见 [研究与拆解](research-teardown.md)。MDA 论文、ink 官方资料、GDC 开发者演讲简介和可访问性指南用于交叉核对；Ghidra 仅为逆向工具入口。只对实际读到的材料负责，不声称观看完整视频、运行 ink 或用 Ghidra 逆向过任何游戏。

## 更新方式

升级时核对来源 commit、许可、方法变化与开放问题，保留旧版本。不要因上游多了代理、云服务或安装脚本而自动启用。对本项目的有价值改进应写具体原因，并以实际内容检查确认；星数变化不构成升级理由。

## 其他参考与逆向工具


- [MDA 原论文](https://users.cs.northwestern.edu/~hunicke/MDA.pdf)：规则、动态行为与体验之间的分析语言。作为设计假设工具，不当评分标准。
- [ink 官方入口](https://www.inklestudios.com/ink/)：交互叙事语言、写作手册、示例及编辑器。用于研究分支内容组织；本次不迁移引擎或引入运行时依赖。
- [Outer Wilds 开发者演讲页](https://www.gdcvault.com/play/1027368/Independent-Games-Summit-Sparking-Curiosity)：好奇心驱动探索。当前依据公开简介；未观看完整演讲。
- [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/basic/)：文本阅读、字幕、输入和感知信息的设计参考，按目标玩家与机制选择。
- [Ghidra 官方仓库](https://github.com/NationalSecurityAgency/ghidra)：软件逆向工具，作为将来已授权源码／二进制研究的工具入口；未安装，未运行，不是游戏设计 Skill。

保存短摘要、来源和本项目启发，不将受版权保护书籍、完整演讲字幕或商业游戏资产复制到公开仓库。研究引用和设计推断分开写。

## 本次交付

- 一个 game Skill，六个工作方法文档、来源记录与三个模板。
- 上游许可、固定 commit 和模块路径随包保留。
- 未启用上游代理、脚本、安装器、云服务或后台定时。
- 文档静态校验与代表性场景审阅；游戏代码、性能和玩家测试均未执行。
- 公开内容只含通用方法、公开来源和合成规则示例，不包含原稿、私密剧情、项目来源链接或聊天证据。
