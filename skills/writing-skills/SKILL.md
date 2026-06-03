---
name: writing-skills
description: "创建新 skill、修改已有 skill、或判断某条经验该不该做成 skill 时。Use when authoring or editing a skill. TRIGGER: 写个 skill / 加个 skill / 改 skill / 固化成 skill / write a skill / create a skill / edit this skill / turn this into a skill."
---

# 写 Skill

skill 是给未来 AI 看的**复用参考指南**（技术、模式、流程），不是"我这次怎么解决的"叙事。

## 第一原则：克制

**你能想到的，工作中的 AI 也能想到。** skill 只写**非显而易见、需要判断、跨场景复用**的提示。能靠别处承载的，就别塞进 skill：

| 这类内容 | 该放哪 | 别放 skill |
|----------|--------|-----------|
| 显而易见的常识 / 标准做法 | AI 本来就会 | ✅ 别写 |
| 某项目特有的约定、路径、表名 | 该项目的 CLAUDE.md / 项目文档 | ✅ 别写进通用 skill |
| 能用正则 / lint / 校验自动拦的机械约束 | hook / CI | ✅ 别写成文档 |
| 跨项目复用的判断、流程、易错点 | **skill** | ← 只有这类才写 |

写之前问：删掉这段，AI 会不会就做错？不会 → 删。

## 何时该建 skill

**建**：技巧对你都不是一眼能想到 / 会跨项目反复用到 / 易被合理化绕过的纪律。

**别建**：一次性方案 / 别处已有充分文档的标准实践 / 项目特定约定（进 CLAUDE.md）/ 能自动校验的机械约束 / 6 个月后就不存在的临时规则。

## SKILL.md 结构

frontmatter（YAML，`name` + `description` 必需，总长 < 1024 字符）：

- `name`：只用字母数字连字符。
- `description`：**只写"何时用"，不要概括"做什么"**。这是关键——

> 描述里一旦概括了工作流，AI 会照着描述走、跳过 skill 正文。实测：描述写"任务间做 code review"导致只审一次，而正文流程图明明要审两次；改成纯触发条件（"执行带独立任务的计划时"）后才正确读正文走完整流程。

```yaml
# ❌ 概括了流程——AI 可能照描述走，不读正文
description: 执行计划时——每个任务派 subagent 并在任务间 review

# ✅ 只有触发条件
description: 执行含独立任务的实现计划时
```

正文按需写：Overview（核心原则 1-2 句）→ 何时用 → 核心模式 / 流程 → 速查表 → 常见错误。每段按复杂度给量，能短则短。

## 触发优化（让未来 AI 找得到）

- **description 富含触发词**：具体症状、场景、报错信息、同义词（超时/卡死/挂起）、工具名。第三人称写（会注入系统提示）。
- **命名用动词、主动语态**：`condition-based-waiting` 优于 `async-test-helpers`；`root-cause-tracing` 优于 `debugging-techniques`。
- **token 效率**：常被加载的 skill 每 token 都算。细节挪到 `--help` / 交叉引用其他 skill（用名字，别用 `@` 强加载——`@` 会立刻吃满上下文）。

## 流程图只用于

非显而易见的决策点 / 容易过早停止的循环 / "A 还是 B"的判断。参考材料用表格、代码用代码块、线性步骤用编号列表——**别**用流程图。

## 验证（轻量）

skill 写完拿不准好不好用时，可选：找个干净上下文的 AI，不给 skill 先看它怎么做（baseline），再给 skill 看行为是否改善。纪律类 skill 尤其值得这样压一压，把 AI 找出的新借口补进"红旗"清单。**但别为此搞重型 subagent 编排**——简单 skill 直接读一遍自检即可。

## 反模式

- ❌ 叙事化（"在 X 月 X 日那次我们发现……"）——太具体、不可复用。
- ❌ 多语言堆例子——一个优秀例子胜过五个平庸的。
- ❌ 流程图里塞代码 / 用 step1 helper2 这种无语义标签。
- ❌ 把项目特定约定写进通用 skill——那是 CLAUDE.md 的活。
