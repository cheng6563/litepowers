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
| `align` | `/litepowers:align` 或自动 | 高不确定性或高影响任务动手前，收敛目标、边界、方案与完成标准 |
| `systematic-debugging` | 自动 | 根因未知的故障先复现、取证、定位，再进入修复 |
| `tdd` | 自动 | 预期行为已知、准备改生产行为时，先取得失败或可比较证据 |
| `verification` | 自动 | 处理完实现与评审问题后，用新鲜证据判断能否声明完成 |
| `code-review` | `/litepowers:code-review` 或自动 | 对已有 diff 做需求符合性与质量双审查，并理性处理反馈 |
| `git-worktrees` | 自动 | 明确要求隔离工作区时，安全创建、锚定和回收 worktree |
| `writing-skills` | 自动 | 创建或修改可复用 Skill，保持克制并验证触发边界 |
| `decision-layering` | 自动 | 已有候选持久规则时，选择 ADR、文档、测试、lint、hook 或 CI |
| `code-as-spec` | `/litepowers:code-as-spec` 或自动 | 代码即业务：文档只做索引、业务进就近注释、doc/code 漂移检查，并把改动代码清理到可读为业务 |
| `docs-over-memory` | 自动 | 答版本/API/配置/依赖行为前，先查官方文档核对当前版本并评估来源，不靠过时记忆 |

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

一次装一个（按 skill 名，10 个名见上表）。Codex 会话内也可用 `$skill-installer`。

**手动兜底（无 gh CLI 时）**——把整个 `skills/` 软链成共享目录，一份内容多 agent 共用：

```shell
ln -s /abs/path/to/litepowers/skills ~/.agents/skills
```

## 与上游 superpowers 的关系

本仓是基于 superpowers **5.1.0** 的一次观点鲜明的**重写**（去项目化 / 砍 SessionStart 强制门 / 砍 plan+subagent 重型流程 / 瘦身 / brainstorming 改名 align / 加原创治理 skill），**不是 fork，无 git 血缘**。

上游更新**不机械合并**——把它当灵感源按需吸收：偶尔扫一眼 changelog，遇到值得的方法论洞察就手动提炼进对应 skill、保持精简；遇到“更多流程 / 功能 / 强制门”则忽略（那正是本仓要砍的）。基线锁在 5.1.0，将来只 diff `5.1.0 → 新版` 看增量。两者持续分叉是预期，不是落后。

### Skill 来源映射

| litepowers | 上游来源 |
|---|---|
| `align` | `brainstorming` |
| `systematic-debugging` | 同名 |
| `tdd` | `test-driven-development` |
| `verification` | `verification-before-completion` |
| `git-worktrees` | `using-git-worktrees` |
| `code-review` | `requesting-code-review` + `receiving-code-review` |
| `writing-skills` | 同名 |
| `decision-layering` | litepowers 原创 |
| `code-as-spec` | litepowers 原创 + 吸收 `simplify` 的清理判据 |
| `docs-over-memory` | litepowers 原创 |

本仓按方法价值选择性吸收 Superpowers 6.x 的轻量改进，例如 reviewer 只读、需求/质量双 verdict 和任务接口；不会恢复完整 SDD 或 SessionStart 强制门。

## License

MIT
