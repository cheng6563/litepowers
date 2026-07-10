---
name: writing-skills
description: "创建、修改或审查已经确定要交付的可复用 Agent Skill。Use when the requested deliverable is a SKILL.md; if the storage or enforcement layer is still undecided, use decision-layering first."
---

# 写 Skill

Skill 是给未来 AI 的**可复用参考指南**，不是“这次怎么解决”的叙事。

## 第一原则：克制

**AI 本来就能想到的内容不要写。** 只保留非显而易见、需要判断、跨场景复用且容易做错的提示。

| 内容 | 更合适的位置 |
|---|---|
| 常识或标准做法 | 不写 |
| 项目特有路径、表名、约定 | CLAUDE.md / 项目文档 |
| 可机械判断的约束 | lint / test / hook / CI |
| 跨项目复用的判断、流程、易错点 | Skill |

写之前问：删掉这段，AI 会不会因此更容易做错？不会就删。

## 何时创建

**创建**：方法跨项目反复出现、不是一眼可得、或容易被合理化绕过。

**不创建**：一次性方案、已有权威文档的标准实践、项目特定约定、能自动校验的机械规则、短期临时规则。

## Frontmatter

`SKILL.md` 必须包含 YAML frontmatter：

- `name`：小写字母、数字和连字符，且与目录名一致。
- `description`：同时简要说明 **what + when**，让路由器能区分相邻 Skill；不要把完整步骤压进 description。
- 可按 Agent Skills 规范使用 `license`、`compatibility`、字符串映射 `metadata` 和实验性的 `allowed-tools`。Claude Code 还扩展了 invocation、arguments、model/context、paths、hooks 等字段；只在目标平台确有需要时添加，并分别验证兼容性。

推荐模式：

```yaml
description: "<提供的能力或结果>。Use when <高区分度的阶段、场景或症状>."
```

反例：

```yaml
# 只写触发词，没有能力边界
description: "Use when coding."
# 把整套流程压进描述，正文容易失去价值
description: "先做 A，再派 agent 做 B，然后逐项审 C，最后运行 D。"
```

正文按需要组织：核心原则 → 适用边界 → 非显然流程/决策 → 常见错误。线性步骤用列表，流程图只用于非显然分支或循环。

## 触发边界

- 用阶段和意图区分相邻 Skill，而不是堆共享关键词。
- 正例、负例和组合顺序应从真实冲突中提炼。
- 常加载的 Skill 要短；大段参考资料拆到按需读取的文件。
- 跨平台 Skill 用动作语义；平台专有工具放明确的增强小节，并给通用降级行为。

## 发布前验证

每次修改至少：

1. 运行仓库的静态 validator；
2. 检查一个明确正例、一个明确负例和最接近的竞争 Skill；
3. 行为变化较大时，用干净上下文比较 baseline 与 skill-on，记录模型、日期和结果；
4. 用真实失败更新规则，不凭想象堆“红旗”。

不必为简单 Skill 建重型多 Agent 编排，但不能只凭作者自读就宣称触发行为正确。

## 反模式

- 叙事化的一次性经验。
- 多语言堆重复例子。
- 流程图塞代码或无语义标签。
- 把项目特定约定写进通用 Skill。
- description 堆触发词，导致多个 Skill 同时抢占。
