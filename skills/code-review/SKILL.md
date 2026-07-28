---
name: code-review
description: "独立审查已有 working diff 的需求符合性和代码缺陷。Use when implementation artifacts already exist and need review before integration; use the platform's PR review capability for GitHub pull requests."
---

# 评审 Working Diff

优先使用平台原生的 working-diff review 能力；否则交给干净上下文的只读 reviewer。

输入需求、验收标准、目标 diff 和核实所需的最少上下文，不输入实现者的完整思考过程。Reviewer 不得修改 working tree、index、HEAD 或 branch。

先逐条判断需求是否满足，再寻找会导致错误结果、崩溃、安全问题或明显回归的代码缺陷。无法从 diff 和代码库证据核实的事项明确标为无法验证，不猜。

Finding 必须包含：

- 具体文件和位置；
- 可触发问题的输入或状态；
- 实际错误结果；
- 简洁修正方向。

按严重度排序。没有具体失败场景的风格偏好、假设性风险和任务外优化不报 finding。

处理已有评审意见时，只核实每条 finding 是否成立并给出代码或测试证据。本 Skill 止于只读 findings，不修改文件；修复作为后续实现任务执行。
