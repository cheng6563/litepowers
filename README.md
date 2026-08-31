# litepowers

[![release](https://img.shields.io/github/v/release/cheng6563/litepowers)](https://github.com/cheng6563/litepowers/releases)

精简版方法论 skill 集。superpowers 的瘦身骨架 + 去项目化的治理理念，**按需触发、无全局强制门**。

## 设计取向

- **无 SessionStart 强制门**：不注入"1% 沾边就必须用 skill"那套全局指令。每个 skill 靠 `description` 自动按需触发（model-invoked），需要时也能 `/litepowers:<name>` 手动启动。
- **砍掉重型流程**：不含 `writing-plans` / `executing-plans` / `subagent-driven-development` / 并行 subagent 编排——慢且费 token。
- **瘦身**：每个 skill 只留判断核心，去掉冗长的恐吓话术和重复 rationalization 表。
- **去项目化**：不绑定任何具体技术栈 / 表名 / 框架。

## Skills

| Skill | 触发方式 | 作用 |
|-------|----------|------|
| `align` | `/litepowers:align` 或自动 | 从请求、spec 与项目事实确定范围、实现路线、验证证据和交付终点；选择对齐推进时询问是否独立 review，仅按肯定选择路由临时 review 需求文档 |
| `systematic-debugging` | `align` 选定后 | 根因未知时用复现、数据流和单一假设定位源头，再返回执行合同修复 |
| `tdd` | `align` 选定后 | 执行合同选择测试先行时，用最小测试约束实现；仅必要时单独确认 RED |
| `code-review` | `/litepowers:code-review` 或自动 | 独立、只读地审查已有 working diff 的需求符合性和具体代码缺陷 |
| `code-as-spec` | `/litepowers:code-as-spec` 或自动 | 代码与就近注释优先承载业务；持久业务文档只保留代码无法充分表达的关键跨模块信息，并按 align 已确认的独立 review 创建临时验收式需求文档 |
| `content-maintenance` | `/litepowers:content-maintenance` 或自动 | 将文档、注释、提示词和模板等非编程内容直接整理为面向读者的最终状态，清除编辑叙述与失效残留 |
| `git-worktrees` | 显式请求或项目要求隔离时 | 定位并锚定 worktree、创建前处理上级仓库的忽略规则，防改动落错仓；优先平台原生工具，无则退回手动 git worktree |

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

本仓是基于 superpowers **5.1.0** 的一次观点鲜明的**重写**（去项目化 / 砍 SessionStart 强制门 / 砍 plan+subagent 重型流程 / 瘦身 / brainstorming 改名 align / 加原创治理 skill），**不是 fork，无 git 血缘**。

上游更新**不机械合并**——把它当灵感源按需吸收：偶尔扫一眼 changelog，遇到值得的方法论洞察就手动提炼进对应 skill、保持精简；遇到“更多流程 / 功能 / 强制门”则忽略（那正是本仓要砍的）。基线锁在 5.1.0，将来只 diff `5.1.0 → 新版` 看增量。两者持续分叉是预期，不是落后。

### Skill 来源映射

| litepowers | 上游来源 |
|---|---|
| `align` | `brainstorming` |
| `systematic-debugging` | 同名 |
| `tdd` | `test-driven-development` |
| `code-review` | `requesting-code-review` + `receiving-code-review` |
| `code-as-spec` | litepowers 原创 |
| `content-maintenance` | litepowers 原创 |

本仓按方法价值选择性吸收 Superpowers 6.x 的轻量改进，例如 reviewer 只读、需求/质量双 verdict 和任务接口；不会恢复完整 SDD 或 SessionStart 强制门。

## License

MIT
