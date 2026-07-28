---
name: align
description: "为非显然开发任务确定范围、实现路线、验证证据和交付终点。Use as the first skill for non-trivial implementation, debugging, tests-first, migration, or delivery work when the execution contract is not already fully determined; skip for explicit, low-risk local changes."
---

# 执行前对齐

先从用户请求、spec 和项目事实形成轻量执行合同：

- **Scope**：目标、非目标和可观察的完成标准；
- **Approach**：直接实现、先设计、先定位根因或测试先行；
- **Evidence**：用哪些测试、构建、复现或其他证据判断结果；
- **Delivery**：本地完成、提交、推送、合并、部署或发布到哪一级。

能可靠推断的直接采用，**只询问答案会改变执行路线且无法从现有事实确定的事项**。用户已经明确的决定不重复确认；明确、局部、可逆且无外部副作用的任务，内部确定合同后直接执行，不展示问卷。

## 智能收敛

- 先读相关代码、spec 和项目约定；没有真实方案取舍时不凑选项。
- Evidence 能由可靠的现有测试框架和项目约定确定时，直接采用匹配的目标测试和必要回归，不询问“要不要测试”。例如已有 Testcontainers 集成测试覆盖所改边界时，按现有模式验证。
- 非 Git 项目不询问提交、推送或合并；无远端不询问推送；目标分支或集成流程不明时不猜合并。
- 项目有已确认可用的测试部署入口，非显然改动的 Delivery 又未指定时，前置询问是否部署测试环境；这是外部动作，不因入口存在就自动执行。
- 生产部署或发版仅在用户请求、spec 明确要求，或任务本身属于发布工作时纳入 Delivery；否则不主动询问。没有明确入口时也不猜测部署能力。
- 是否新增测试、是否严格确认 RED 只有在现有事实无法决定且会显著影响成本或置信度时才询问。严格 RED→GREEN 仅在用户明确要求，或必须证明回归测试能捕获原缺陷时采用。

本 Skill 是非显然实现、调试和测试先行任务的统一首入口；即使合同可从事实自动形成，也先确定合同再进入专项方法。根因未知时转 `skill:systematic-debugging`；合同选择测试先行时转 `skill:tdd`。两者返回后继续按合同执行，不再二次询问 Approach、Evidence 或 Delivery。明确、低风险且用户已完整指定本地执行方式的小改动仍可跳过本 Skill。

高层 Delivery 包含项目约定的必要前置步骤，但推送、合并、部署和发布等外部动作仍按用户授权边界执行。不自动创建计划、spec、ADR 或新的测试/发布体系。
