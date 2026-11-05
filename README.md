# litepowers

[![release](https://img.shields.io/github/v/release/cheng6563/litepowers)](https://github.com/cheng6563/litepowers/releases)

通用方法论 skill 集，**按需触发、轻量执行**。

## 设计取向

- **按需触发**：每个 skill 靠 `description` 自动触发，需要时也能 `/litepowers:<name>` 手动启动。
- **轻量执行**：以需求依据、必要证据和明确交付终点组织任务，每个 skill 保留影响决策的核心规则。
- **跨项目使用**：方法保持通用，具体技术栈与业务约定由项目提供。

## Skills

| Skill | 触发方式 | 作用 |
|-------|----------|------|
| `align` | `/litepowers:align` 或自动 | 新开发与修复任务入口，承接已有调查，保存原话、执行中补充和当前进度；搞快点只做最小修改与文本检查，对齐推进实施前澄清关键需求、探查旧测试，再完成实现、有效验证和独立审核 |
| `systematic-debugging` | `align` 选定、任务内失败或只诊断 | 对照业务期望、实际链路与关键样本定位根因，核实最小修复方向，再续接已授权修复 |
| `tdd` | `align` 选定或用户显式调用 | 用户选择测试先行时，用最小测试约束实现；仅必要时单独确认 RED |
| `delegation` | `/litepowers:delegation` 或自动 | 判断委派收益、准备任务与权限、选择模型并验收结果；按平台能力执行，场景要求按需附加 |
| `deep-research` | 显式要求或模型主动推荐后获确认 | 组织低成本多层研究，复用 `delegation` 执行；缺少低成本或多层派生能力时采用单代理研究，无子代理能力时报告受阻 |
| `code-as-spec` | `/litepowers:code-as-spec` 或自动 | 选择持久业务信息与项目规则的最小承载位置，维护有独立价值的业务文档 |
| `git-worktrees` | 显式请求或项目要求隔离时 | 定位并锚定 worktree、创建前处理上级仓库的忽略规则，防改动落错仓；优先平台原生工具，无则退回手动 git worktree |

## 验证

`python3 scripts/validate.py` 检查技能元数据、引用、插件清单和发布工作流。worktree 脚本的运行方式见[脚本回归测试说明](tests/README.md)。

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

逐个安装（按 skill 名，见上表）；使用 `deep-research` 时同时安装 `delegation`。Codex 会话内也可用 `$skill-installer`。

**手动兜底（无 gh CLI 时）**——按目标 agent 的用户级 skill 目录，把各个 skill 目录软链过去，一份内容多 agent 共用。Codex 用户级目录是 `~/.codex/skills/`（Windows 为 `%USERPROFILE%\.codex\skills\`）：

```shell
# Codex（每个 skill 一个软链，逐个建）
for s in align systematic-debugging tdd delegation deep-research code-as-spec git-worktrees; do
  ln -s "/abs/path/to/litepowers/skills/$s" "$HOME/.codex/skills/$s"
done
```

```powershell
# Codex on Windows（管理员 PowerShell）
'align','systematic-debugging','tdd','delegation','deep-research','code-as-spec','git-worktrees' | ForEach-Object {
  New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.codex\skills\$_" -Target "C:\abs\path\to\litepowers\skills\$_"
}
```

其它 agent 换成各自的用户级 skill 目录即可；不要软链到项目级的 `.agents/skills`（那只在当前 repo 生效，和"全局装一次"相悖）。

## 与上游 superpowers 的关系

本项目以 superpowers **5.1.0** 为参考独立重写，采用按需触发和轻量任务合同。上游变化以 5.1.0 为基线比较，按方法价值选择性吸收；当前已吸收 Superpowers 6.x 的独立审查和任务接口等改进。

### Skill 来源映射

| litepowers | 上游来源 |
|---|---|
| `align` | `brainstorming` |
| `systematic-debugging` | 同名 |
| `tdd` | `test-driven-development` |
| `delegation` | `requesting-code-review` + `receiving-code-review`，扩展为通用任务委派 |
| `deep-research` | litepowers 原创 |
| `code-as-spec` | litepowers 原创 |

## License

MIT
