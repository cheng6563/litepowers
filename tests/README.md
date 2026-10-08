# Skills 行为评测

`behavior-fixtures.json` 是预期集合，不是通过记录。`scripts/validate.py` 只检查格式、名称、引用和主要路由检查点；不会执行提示词或自然语言断言。

## 最小有效评测

1. 固定目标 Agent、模型、工具能力和输入文件版本，分别在基础宿主与加载全局／项目指令的环境中评测。基础宿主保留必要工具和平台约束，不加载 AGENTS.md 或个人行为补丁；两组都提供任务实际所需的 skills 与材料，分开记录结果。
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

## 单文件原生注入与多份执行 MD

定点用例为 `delegation-single-injection-multiple-mds` 和 `delegation-single-injection-extra-md-unavailable`。前者检查一份原生注入、其余两份路径读取；后者检查其中一份路径不可访问时的限制报告。现有“不支持注入”的用例不能替代这两个组合。

先核对目标平台真实工具 schema：执行 MD 注入参数必须只接受一个文件，同时子代理能够读取其他文件。若当前接口没有原生文件注入参数，或不能取得注入加载记录，分别记录能力不匹配或证据不足；不能用消息正文、父会话继承、自制文件读取包装器冒充原生注入通过。

由评测操作者在被测 Agent 会话之外准备输入；每个用例、版本和重复运行各用独立目录。以下脚本输出的绝对路径须在子代理执行环境中确实可用；跨容器时先建立真实挂载并提供子代理侧路径。

```python
from pathlib import Path
from tempfile import mkdtemp

root = Path(mkdtemp(prefix="delegation-multi-md-"))
inputs = {
    "requirements.md": "只读评估给定 payload.txt，统计非空行数。不得修改文件或继续派生。\n",
    "checks.md": "额外检查 payload.txt 是否有一行恰为 beta，区分大小写。\n",
    "output.md": "评估结果只输出 JSON 对象，字段为 nonempty_lines 和 has_beta，分别为整数和布尔值。\n",
    "payload.txt": "alpha\n\nbeta\n",
}
for name, content in inputs.items():
    (root / name).write_text(content, encoding="utf-8")
    print(f"{name}: {root / name}")
```

成功用例保留所有文件；不可访问用例在启动被测主线程前删除该次目录中的 `output.md`，仍提供原路径，不把缺失文件正文交给主线程或子代理。操作者保留输入快照及删除记录。给被测主线程 fixture 的 prompt 与四个绝对路径，不提供 MD 正文、预期答案或下面的判定表；执行质量评测加载当前 delegation Skill。对照基线可用新规则前的 `147301b^`，沿用同一用例与能力条件。

| 检查点 | 真实轨迹中的必要证据 |
|---|---|
| 首份原生注入 | 主线程委派工具调用的实际单文件参数指向 `requirements.md`；平台加载事件或导出的子代理初始上下文证明正文已进入子代理，只有调用参数不足以证明加载成功。 |
| 其余路径交接 | 委派消息含 `checks.md`、`output.md` 的子代理侧路径，并明确要求全部适用 MD 先读取再执行；主线程没有为派发预读正文。 |
| 全部加载及顺序 | 子代理读取工具的成功返回覆盖 `checks.md`、`output.md` 全文；原生加载与两份读取均早于首次读取 `payload.txt` 或其他评估动作。允许批量读取 MD，不要求固定工具名或两份 MD 的读取顺序。 |
| 成功结果 | 子代理只读，返回语义等价于 `{"nonempty_lines": 2, "has_beta": true}` 的 JSON 对象；结果正确仍不能替代上述加载和读取轨迹。 |
| 不可访问分支 | 保留 `output.md` 的真实读取失败及路径；子代理在评估前报告限制，主线程将完整任务记为受阻或未验证，不声称缺失要求已执行。 |

分别记录“静态校验通过”“真实行为断言通过／失败”和“未验证”。不可访问用例的行为断言可以通过，但其委派的完整评估任务仍受阻；不要混为同一结论。至少保留主线程委派调用、平台注入证据、子代理读文件及后续动作的有序记录和最终结果；无法观察的检查点标为未验证，不依据 Agent 自述补全。

## 方法参考

- [Agent Skills：创作最佳实践](https://agentskills.io/skill-creation/best-practices)
- [Agent Skills：输出质量评测](https://agentskills.io/skill-creation/evaluating-skills)
- [Anthropic：Demystifying evals for AI agents，2026-01-09](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)
- [OpenAI：Harness engineering，2026-02-11](https://openai.com/index/harness-engineering/)
- [Anthropic：Harness design for long-running application development，2026-03-24](https://www.anthropic.com/engineering/harness-design-long-running-apps)

资料用于校准方法，不代表本项目必须采用其完整文档体系或多 Agent 流程；具体规则是否有增益以目标 Agent 的实测为准。
