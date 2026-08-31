---
name: code-review
description: "独立审查已有 working diff 的需求符合性和代码缺陷。Use when implementation artifacts already exist and need review before integration; use the platform's PR review capability for GitHub pull requests."
---

# 评审 Working Diff

优先使用平台原生的 working-diff review 能力；否则交给干净上下文的只读 reviewer。

输入需求、验收标准、目标 diff 和核实所需的最少上下文，不输入实现者的完整思考过程。若上游在对齐推进中选择了独立 review，则使用其开发前建立、并含开发中用户确认的追加项的临时 review 需求文档作为需求与验收输入；按初始正文再按追加顺序阅读，同一事项以后追加且明确标为替换或废止的条目为准：替换项按其更新后的要求判断，废止项不再作为验收要求。reviewer 不自行扫描临时目录寻找文件。Reviewer 不得修改 working tree、index、HEAD 或 branch。

先逐条判断需求是否满足，再寻找会导致错误结果、崩溃、安全问题或明显回归的代码缺陷。无法从 diff 和代码库证据核实的事项明确标为无法验证，不猜。

Finding 必须包含：

- 具体文件和位置；
- 可触发问题的输入或状态；
- 实际错误结果；
- 简洁修正方向。

按严重度排序。没有具体失败场景的风格偏好、假设性风险和任务外优化不报 finding。

处理已有评审意见时，只核实每条 finding 是否成立并给出代码或测试证据。本 Skill 止于只读 findings，不修改文件；修复作为后续实现任务执行。
