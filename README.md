# litepowers

[![release](https://img.shields.io/github/v/release/cheng6563/litepowers)](https://github.com/cheng6563/litepowers/releases)

通用方法论 skill 集，**按需触发、轻量执行**。

## 设计取向

- **按需触发**：每个 skill 靠 `description` 自动触发，需要时也能 `/litepowers:<name>` 手动启动。
- **轻量执行**：以执行合同、必要证据和明确交付终点组织任务，每个 skill 保留影响决策的核心规则。
- **跨项目使用**：方法保持通用，具体技术栈与业务约定由项目提供。

## Skills

| Skill | 触发方式 | 作用 |
|-------|----------|------|
| `align` | `/litepowers:align` 或自动 | 确定范围、实现路线、验证与交付；快速推进默认只做 diff 与文本检查，已有验证授权继续有效；独立 review 仅按当前任务选择执行 |
| `systematic-debugging` | `align` 选定、任务内失败或显式只诊断 | 根因未知时用复现、数据流和单一假设定位源头，不在诊断中修改生产行为 |
| `tdd` | `align` 选定或用户显式调用 | 执行合同选择测试先行时，用最小测试约束实现；仅必要时单独确认 RED |
| `code-review` | `/litepowers:code-review` 或自动 | 只读审查工作区、暂存区或固定提交范围，分别给出需求与质量结论；无法隔离时如实标明独立性限制 |
| `code-as-spec` | `/litepowers:code-as-spec` 或自动 | 业务信息采用最小承载层；对齐推进选择独立 review 时建立当前有效验收输入，保留到同次问题处置结束 |
| `content-maintenance` | `/litepowers:content-maintenance` 或自动 | 以明确需求和可靠基线维护内容，纠偏直接归位，主动精简重复与失效信息，保留必要约束和有独立价值的内容 |
| `git-worktrees` | 显式请求或项目要求隔离时 | 定位并锚定 worktree、创建前处理上级仓库的忽略规则，防改动落错仓；优先平台原生工具，无则退回手动 git worktree |

## 验证

`python3 scripts/validate.py` 只检查结构、引用和用例格式，不证明模型遵循提示词。`tests/behavior-fixtures.json` 定义行为预期；真实触发、授权继承和输出质量按 [行为评测说明](tests/README.md) 在目标 Agent 上验证，并保留轨迹、结果与成本。

## 安装（Claude Code）

```shell
/plugin marketplace add https://github.com/cheng6563/litepowers.git
/plugin install litepowers@litepowers
/reload-plugins
```

本地开发测试：

```shell
claude --plugin-dir ./litepowers
```

改完用 `/reload-plugins` 热加载。

## 在 Codex / 其他 agent 中使用

`SKILL.md` 采用开放的 Agent Skills 结构，可被多种 Agent 读取。不同平台的工具调用、审批、自动触发、安装目录和 UI 能力并不相同；平台专有增强应按能力降级，并在目标 Agent 上分别验证。

**原生安装（推荐）**——用 GitHub CLI 的跨 agent skill 安装器，会注入来源元数据，之后 `gh skill update` 可更新：

```shell
# --agent 填目标工具：codex / claude-code / cursor ...
gh skill install cheng6563/litepowers align --agent codex --scope user
```

> **务必带 `--scope user`**：`gh skill install` 默认是 `--scope project`，只在当前 repo 生效。litepowers 是通用方法论，全局装一次、所有项目可用才合理。

逐个安装（按 skill 名，7 个名见上表）。Codex 会话内也可用 `$skill-installer`。

**手动兜底（无 gh CLI 时）**——按目标 agent 的用户级 skill 目录，把各个 skill 目录软链过去，一份内容多 agent 共用。Codex 用户级目录是 `~/.codex/skills/`（Windows 为 `%USERPROFILE%\.codex\skills\`）：

```shell
# Codex（每个 skill 一个软链，逐个建）
for s in align systematic-debugging tdd code-review code-as-spec content-maintenance git-worktrees; do
  ln -s "/abs/path/to/litepowers/skills/$s" "$HOME/.codex/skills/$s"
done
```

```powershell
# Codex on Windows（管理员 PowerShell）
'align','systematic-debugging','tdd','code-review','code-as-spec','content-maintenance','git-worktrees' | ForEach-Object {
  New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.codex\skills\$_" -Target "C:\abs\path\to\litepowers\skills\$_"
}
```

其它 agent 换成各自的用户级 skill 目录即可；不要软链到项目级的 `.agents/skills`（那只在当前 repo 生效，和"全局装一次"相悖）。

## 与上游 superpowers 的关系

本项目以 superpowers **5.1.0** 为参考独立重写，采用按需触发和轻量任务合同。上游变化以 5.1.0 为基线比较，按方法价值选择性吸收；当前已吸收 Superpowers 6.x 的只读 reviewer、需求／质量双结论和任务接口等改进。

### Skill 来源映射

| litepowers | 上游来源 |
|---|---|
| `align` | `brainstorming` |
| `systematic-debugging` | 同名 |
| `tdd` | `test-driven-development` |
| `code-review` | `requesting-code-review` + `receiving-code-review` |
| `code-as-spec` | litepowers 原创 |
| `content-maintenance` | litepowers 原创 |

## License

MIT
