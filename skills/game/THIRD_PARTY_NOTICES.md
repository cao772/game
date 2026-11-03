# 第三方来源与修改说明

本 Skill 为本项目重写整合的中文方法，不是任何上游作者的官方版本。上游完整快照单独保留作研究；本机启用的是一个 game Skill，没有批量启用上游运行器、代理或脚本。

使用与参考的开源资料：
- 向阳乔木 / joeseesun/qiaomu-novel-generator，MIT。
- haowjy/creative-writing-skills，Apache-2.0。
- sickn33/agentic-awesome-skills 的 game-development/game-design，MIT。
- ncdlek/game-dev-agent-skills 的 game-quest-narrative-architect，MIT。

原许可原文保存在 licenses/，固定版本见 sources-lock.json。原作者的权利与许可保持不变。

改动：中文整合、按任务渐进读取、长篇与互动叙事衔接、项目来源适配、候选状态管理、现有流程接入。移除了上游固定长度、反复审批、特定宿主命令、自动运行脚本和测试等默认行为。未采用单凭完成率判坏、强制全部 NPC 可杀、固定任务数量触发架构、固定资源百分比等通则。

本包不包含上游小说示例、宣传图片、用户小说、未公开剧情、账号数据或聊天证据。参考资料中的示例规范不是自动批准的游戏共享接口。
