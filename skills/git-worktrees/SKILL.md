---
name: git-worktrees
description: "开始需要和当前工作区隔离的功能开发时建隔离工作区。Use before isolated feature work. TRIGGER: 开个 worktree / 隔离工作区 / 不想弄脏当前分支 / 并行开发 / create a worktree / isolated workspace / don't touch current branch / parallel work."
---

# 使用 Git Worktrees

确保工作发生在隔离工作区。**优先用平台原生 worktree 工具，没有再退回手动 git worktree。**

核心顺序：**先探测已有隔离 → 用原生工具 → 退回 git → 别和 harness 较劲。**

## 步骤 0：先探测是否已隔离

建任何东西之前，先确认你是不是已经在隔离工作区里。

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
# submodule 也会让两者不等，先排除
git rev-parse --show-superproject-working-tree 2>/dev/null
```

- `GIT_DIR != GIT_COMMON` 且非 submodule → 已在 worktree 里，**别再建**，直接去步骤 2。
- 相等（或在 submodule）→ 普通检出。用户没预先表态过偏好的话，先问："要不要建隔离 worktree？保护当前分支不被改动。" 用户拒绝就原地干，跳步骤 2。

## 步骤 1：建隔离工作区

**1a. 原生工具优先** — 有没有 `EnterWorktree` / `WorktreeCreate` / `/worktree` 命令 / `--worktree` 标志之类的？有就用它，跳步骤 2。原生工具自动处理目录、建分支、清理。有原生工具还手敲 `git worktree add` 会制造 harness 看不见的幽灵状态。

**1b. git 退路（仅当无原生工具）**

目录选择优先级：用户声明的偏好 > 已存在的 `.worktrees/`（优先）或 `worktrees/` > 默认 `.worktrees/`。

项目内目录**必须先确认被 ignore**：
```bash
git check-ignore -q .worktrees 2>/dev/null || echo "未 ignore：先加进 .gitignore 并 commit"
```

建：
```bash
git worktree add ".worktrees/$BRANCH" -b "$BRANCH"
cd ".worktrees/$BRANCH"
```

权限错误（沙箱拦截）→ 告诉用户沙箱挡了 worktree 创建，改为原地工作，原地跑 setup 和基线测试。

## 步骤 2：项目 setup

自动探测并装依赖（有哪个装哪个）：`package.json`→装包 / `Cargo.toml`→build / `requirements.txt`/`pyproject.toml`→装 / `go.mod`→download / `pom.xml`→依赖解析 等。

## 步骤 3：验证干净基线

跑项目对应的测试命令。失败 → 报告并问是否继续（区分新 bug 和既有问题）。通过 → 报告就绪。

## 常见错误

- **和 harness 较劲**：有原生隔离还手建 worktree。→ 步骤 0/1a 先探测、先用原生。
- **跳过探测**：在已有 worktree 里又套一个。→ 永远先跑步骤 0。
- **跳过 ignore 校验**：worktree 内容被 git 跟踪污染状态。→ 项目内目录先 `git check-ignore`。
- **带着失败的基线往下做**：分不清新旧 bug。→ 先报告，拿到明确许可再继续。
