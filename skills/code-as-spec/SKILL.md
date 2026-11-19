---
name: code-as-spec
description: "Use when deciding whether to add, update, or remove project documentation, including documentation changes within implementation tasks, or where to place durable project rules. Skip wording-only edits."
---

# 代码即核心业务文档

已实现的业务以代码、SQL、schema、配置、测试及日志为准；就近注释补充业务语义。

## 内容取舍

增补文档前，先明确谁会读、读完要做什么。新旧内容都只留完成这个用途所需的信息。使用入口写清用途和如何开始；运维、集成和合规文档保留完成相应操作或满足要求所需的信息。

内部细节以代码、测试和就近注释承载。跨模块规则、边界或协作关系确需长期说明时，简述并指向源码。命令入口、帮助或源码已能满足读者用途时，直接指向入口。

整理限于授权文档范围。整份文档无独立用途时可删除；可能损失无法恢复的知识时先指出疑点。只读检查返回判断和建议。

## 放在哪里

优先使用已有位置；项目没有文档体系时，由代码和必要注释承载，不新建持久文档目录、模板或治理体系。

- Agent 高频遵守的稳定项目约定：`CLAUDE.md` / `AGENTS.md`。
- 需长期保留且无法由代码表达的跨模块决定或关系：已有 spec / 项目文档。
- 可机械判断的约束：test、lint、type 或 CI。
- 须在特定生命周期自动发生或即时反馈的动作：hook。

说明层与执行层各自提供独立价值，避免重复维护。
