---
name: tdd
description: "在用户明确选择测试或证据优先后，以 RED→GREEN 控制已知行为的实现。Use only after the user explicitly chooses tests/evidence first or directly requests TDD, regression tests, or a failing reproduction; if no preference is stated, first ask whether to establish tests/evidence or implement directly, and do not load this skill before the choice."
---

# TDD：用户选择后，证据先于实现

本 Skill 不是所有代码改动的默认门禁。用户明确选择测试或证据优先后，才先证明当前行为不满足目标，再写最小实现。

## 入口门槛

用户尚未表达实现方式时，先用一个简短问题提供两项：

1. **测试 / 证据优先**：先建立失败测试或可比较证据，再实现；
2. **直接实现**：先改代码，再按环境允许的方式检查。

此时不要加载本 Skill。用户已明确要求 TDD、先写测试、失败复现或防回归测试，等同于选择第一项，无需重复询问。用户选择直接实现时，不得再用 RED→GREEN 阻塞实现。

若本地无法运行目标代码或测试，在用户选择前说明限制：可以改用静态检查、远端/CI 验证、可重复手工步骤，或直接实现并暴露未验证风险；不要假装能本地测试，也不要替用户默选。

## 核心门禁

进入本 Skill 后：

```
没有先取得正确失败或可比较证据，不修改生产行为。
```

证据必须能区分“功能缺失/缺陷存在”和“测试自身写错”。若实现已存在，不机械删除用户代码；先建立可证明需求的测试，再决定如何最小化修正。

## 选择证据

| 变更类型 | 优先证据 |
|---|---|
| 领域逻辑、API、bugfix | 自动化失败测试 |
| CLI、集成、脚本 | 可重复命令与期望/实际输出 |
| UI 行为 | 组件/E2E 测试；条件不足时截图或可重复操作路径 |
| 配置、fixture、生成物 | 校验命令或前后 diff |
| 纯文档 | 链接、结构、示例或 validator；不强造单元测试 |

没有测试框架时，使用项目已有入口、最小 characterization/regression 脚本或可重复手工证据。不要为了一个小改动先重建测试基础设施；需要引入新基建时单独说明成本和范围。

## RED → GREEN → REFACTOR

1. **RED**：写一个最小证据描述目标行为。
2. **验证 RED**：运行并确认它因目标行为缺失而失败，而不是语法、环境或断言错误。
3. **GREEN**：写最少代码让证据通过，不夹带额外功能或无关重构。
4. **验证 GREEN**：重新运行目标证据和相关回归，确认输出支持结论。
5. **REFACTOR**：只在绿色状态下清理结构，并保持验证通过。

bugfix 的根因未知时，先用 `skill:systematic-debugging` 定位；根因和预期行为明确后，再询问实现方式或遵循用户已表达的选择。

## 红旗

- 用户未选择测试 / 证据优先，就把本 Skill 当作代码修改的强制前置。
- 明知目标无法在本地运行，仍承诺本地 RED→GREEN。
- 测试第一次运行就通过，却没有解释为何它仍能证明新行为。
- 用大量 mock 只验证调用顺序，得到与真实行为脱节的假绿。
