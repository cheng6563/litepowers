# Skills 行为评测

`behavior-fixtures.json` 是预期集合，不是通过记录。`scripts/validate.py` 只检查格式、名称、引用和主要路由检查点；不会执行提示词或自然语言断言。

## 最小有效评测

1. 固定目标 Agent、模型、工具能力、全局／项目指令和输入文件版本。将其中的授权规则与运行环境一并加载，不能只测孤立的 SKILL.md。
2. 从真实失败中选择少量用例，至少覆盖应该触发、相近但不该触发、任务续接和权限边界。用例提到的 spec、diff、临时文档、base/head 和历史任务状态必须实际准备好，不能把“已提供”当作真实输入。
3. 对同一输入运行当前版本与基线版本；基线取 Git 提交，不维护额外源码备份。两组使用相同环境、独立会话和独立可丢弃的测试目录，禁止使用真实凭据、共享业务数据或真实发布目标。
4. 触发评测只提供可发现的 skill 元数据，观察是否加载；执行质量评测可以显式加载目标 skill。两种结果分开报告，不能用强制加载证明自动触发正确。
5. 检查实际轨迹及产物：是否越权写入、是否漏审提交或新文件、是否保留已取消要求、是否重复询问、是否把未验证说成通过。优先用文件状态与工具记录判定，再用明确 rubric 和人工抽查判断语义。
6. 对关键用例重复运行，记录逐次结果、波动、耗时和 token；失败时先区分提示词缺陷、缺少输入、环境故障与断言错误，再调整一个规则并重跑相关用例。

## 断言边界

- `expected_initial_skills` 与 `expected_sequence` 只约束主要路由检查点；没有被禁止的辅助 skill 可以按需加载，不要求轨迹完全一致。
- 必须严格检查的顺序是授权、只读边界、用户明确要求的 RED 等真实约束，不是某一种命令编排或固定回复措辞。
- “无 finding”“静态检查通过”“Agent 自述完成”不能代替需求满足、真实独立 review 或运行时验证。
- 不把快速模式默认不测试、非严格 TDD 不单独跑 RED 等明确产品选择当成模型失败。

## 结果记录

每次记录至少包含：用例 ID、版本提交、Agent／模型、全局指令版本、输入与轨迹路径、逐项结论及证据、未验证项、耗时与 token。没有实际运行时记为未测，不填写通过率。

评测记录放在运行环境约定的临时目录或现有测试产物目录；提示词只保留有效决策规则，不把每次评测过程追加进 SKILL.md。模型或平台变化后重新检查关键用例；收益不再成立的规则优先删除，而非继续叠加流程。

## 方法参考

- [Agent Skills：创作最佳实践](https://agentskills.io/skill-creation/best-practices)
- [Agent Skills：输出质量评测](https://agentskills.io/skill-creation/evaluating-skills)
- [Anthropic：Demystifying evals for AI agents，2026-01-09](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)
- [OpenAI：Harness engineering，2026-02-11](https://openai.com/index/harness-engineering/)
- [Anthropic：Harness design for long-running application development，2026-03-24](https://www.anthropic.com/engineering/harness-design-long-running-apps)

资料用于校准方法，不代表本项目必须采用其完整文档体系或多 Agent 流程；具体规则是否有增益以目标 Agent 的实测为准。
