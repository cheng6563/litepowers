# litepowers

精简版方法论 skill 集。superpowers 的瘦身骨架 + 去项目化的治理理念，**按需触发、无全局强制门**。

## 设计取向

- **无 SessionStart 强制门**：不注入"1% 沾边就必须用 skill"那套全局指令。每个 skill 靠 `description` 自动按需触发（model-invoked），需要时也能 `/litepowers:<name>` 手动启动。
- **砍掉重型流程**：不含 `writing-plans` / `executing-plans` / `subagent-driven-development` / 并行 subagent 编排——慢且费 token。
- **瘦身**：每个 skill 只留判断核心，去掉冗长的恐吓话术和重复 rationalization 表。
- **去项目化**：不绑定任何具体技术栈 / 表名 / 框架。

## Skills

| Skill | 触发方式 | 作用 |
|-------|----------|------|
| `align` | `/litepowers:align` 或自动 | 动手前澄清需求 + 2-3 方案对齐，批准后再写代码 |
| `systematic-debugging` | 自动 | 遇 bug 先定位根因再改 |
| `tdd` | 自动 | 先写失败测试再写实现 |
| `verification` | 自动 | 宣称"完成/通过"前先跑验证拿证据 |
| `code-review` | `/litepowers:code-review` 或自动 | 完成/合并前自审，理性接收反馈 |
| `git-worktrees` | 自动 | 隔离工作区，优先用原生 worktree 工具 |
| `writing-skills` | 自动 | 写/改 skill——核心是**克制**，能靠记忆/CLAUDE.md 承载的别塞 skill |
| `decision-layering` | 自动 | 一条规则该落哪层（ADR / lint-hook / skill / 文档），含基建环境探测 |
| `doc-or-not` | 自动 | 文档该不该写：删掉这段读代码能不能推断出来 |

## 安装（Claude Code）

```shell
/plugin marketplace add cheng6563/litepowers
/plugin install litepowers@litepowers
```

本地开发测试：

```shell
claude --plugin-dir ./litepowers
```

改完用 `/reload-plugins` 热加载。

## 在 Codex / 其他 agent 中使用

`SKILL.md` 是开放标准，`.agents/skills` 是 Codex、Cursor、Copilot、Gemini CLI、Amp 等**共用**的 skill 目录，所以本仓 skill **一字不用改**即可跨 agent 通用。

**原生安装（推荐）**——用 GitHub CLI 的跨 agent skill 安装器，会注入来源元数据，之后 `gh skill update` 可更新：

```shell
# --agent 填目标工具：codex / claude-code / cursor ...
gh skill install cheng6563/litepowers align --agent codex --scope user
```

> **务必带 `--scope user`**：`gh skill install` 默认是 `--scope project`，只在当前 repo 生效。litepowers 是通用方法论，全局装一次、所有项目可用才合理。

一次装一个（按 skill 名，9 个名见上表）。Codex 会话内也可用 `$skill-installer`。

**手动兜底（无 gh CLI 时）**——把整个 `skills/` 软链成共享目录，一份内容多 agent 共用：

```shell
ln -s /abs/path/to/litepowers/skills ~/.agents/skills
```

## License

MIT
