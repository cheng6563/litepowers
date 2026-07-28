---
name: tdd
description: "用最小测试或可重复证据约束实现。Use after align has selected tests-first because the user requested TDD, a regression test, or a failing reproduction, or because the execution contract otherwise requires it."
---

# 轻量测试先行

仅在用户明确要求，或执行合同已经选择测试先行时启用；不在本 Skill 内重新询问开发模式。

1. 写能表达目标行为的最小测试或可重复证据。
2. 实现满足该证据的最小改动，不夹带额外功能或无关重构。
3. 运行目标测试和必要回归，根据实际输出判断结果。

默认不为形式完整而单独运行 RED。只有用户要求严格 TDD，或必须证明回归测试确实能捕获原缺陷时，才在修改生产行为前运行一次聚焦测试确认失败；不要先跑整套测试。

测试验证可观察行为，不只验证 mock 调用顺序。已有可靠测试入口就沿用；环境不能运行时如实说明，不为单个改动新建测试基础设施。
