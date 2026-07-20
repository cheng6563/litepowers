---
name: code-review
description: "对已有 diff 或评审意见做独立的需求符合性与代码质量审查。Use when implementation artifacts already exist, before integration, or when technically evaluating reviewer feedback; use verification afterward for fresh execution evidence."
---

# 代码评审

评审已有产物，不替代需求对齐，也不替代完成前运行验证。

## 独立 reviewer 契约

优先使用项目原生 review 能力；否则让一个干净上下文 reviewer 审查：

- **输入**：requirements、acceptance criteria、目标 diff，以及验证所需的最少上下文；
- **不输入**：实现者完整思考过程、希望忽略的 finding、预设严重度；
- **只读**：不得修改 working tree、index、HEAD 或 branch；
- **证据边界**：无法从 diff 和给定证据核实时，明确写 `Cannot verify from diff`，不能猜；
- 实现者的 rationale 可解释意图，但不是实现正确的免责证据。

## 双 Verdict

一次 review 同时返回：

1. **Requirement verdict**：逐条说明满足、缺失、偏离或无法验证。
2. **Quality verdict**：正确性、边界条件、安全、可维护性、测试质量和范围控制。

finding 应给出具体文件/位置、失败场景和修正方向，按实际严重度排序。仅当前序审查是分任务/增量的，且之后发生组合或修复时，再做最终 whole-change broad review。

## 约束与语义检查

以 diff 和验收标准建立证据地图：先查最近的项目规则、直接调用方和测试；只有具体语义无法确认时，才扩展到 ADR、历史、schema/migration、配置、日志或兼容行为。对照证据检查默认路径、批量处理、复用抽象或降级是否跨过业务语义边界；对外行为和跨模块接口重点核对租户、权限、状态、数据归属、幂等、外部系统和生命周期。

规则是否需要长期固化属于后续 `skill:decision-layering` 问题，不因 review 发现风险就默认要求 ADR。证据分级：文档/测试/强代码约束为强，多处一致用法为中，命名和直觉为弱；弱证据只报告风险或待确认。

## 接收反馈

1. 读完整反馈并复述技术要求。
2. 对照代码库核验适用性。
3. 不清楚且会影响实现顺序时先澄清。
4. 成立则逐项修复并验证；不成立则用代码和约束说明原因。

禁止表演式同意，也不要因 reviewer 身份就盲从。外部反馈是待验证建议；同样不能因为实现者有理由就自动驳回 finding。

修完 findings 后调用 `skill:verification`，取得新鲜且匹配声明的证据再声称 ready。
