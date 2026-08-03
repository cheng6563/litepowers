---
name: git-worktrees
description: "为隔离工作确定 worktree 位置并处理上级仓库的忽略规则。Use when the user explicitly requests a worktree or project instructions require isolated work in a separate directory."
---

# 使用 Git Worktrees

只解决两件靠常识补不上的事：**worktree 建在哪并锚定它**、**创建前别让目标被上级仓库当普通内容跟踪**。**优先用平台原生 worktree 工具**（如 Claude Code 的 `EnterWorktree`，落点由它自己管，别覆盖）；没有原生工具才退回 `git worktree add`。

## 1. 定位与锚定

手动创建时按此优先级定落点，用户显式指定永远优先于观察到的现状：

1. **用户或项目指令已指定** worktree 目录 → 直接用，不问。
2. **仓库内已存在** `.worktrees/` 或 `worktrees/` → 用它（两者都在则 `.worktrees/` 优先）。
3. **都没有** → 默认用项目根的 `.worktrees/<branch>`。

目标绝对路径定好后创建，立刻锚定为根，之后一切操作以它为根：

```bash
WT_TARGET="<按上面优先级得到的绝对路径，默认 <主仓根>/.worktrees/$BRANCH>"
git worktree add "$WT_TARGET" -b "$BRANCH"     # 平台有原生 worktree 工具时优先用之
WT=$(git -C "$WT_TARGET" rev-parse --show-toplevel)   # 锚定，记住它
```

- **所有文件操作用以 `$WT/` 开头的路径**，别用记忆里的主仓路径。
- **不 `cd` 回主仓**；需要主仓信息用 `git -C <主仓路径> …`，不切目录。

否则改动会落进主仓当前分支，而新建的 worktree 分支是空的。

## 2. ignore：创建前阻止目标被上级仓库跟踪

目标目录可能落在某个更上级仓库的工作树内（哪怕看起来在“项目外”）。创建前先找出承载它的仓库：

```bash
PARENT="$WT_TARGET"; while [ ! -d "$PARENT" ]; do PARENT=$(dirname "$PARENT"); done
HOST_ROOT=$(git -C "$PARENT" rev-parse --show-toplevel 2>/dev/null || true)
```

`HOST_ROOT` 为空即可直接创建。非空则先复验目标是否已被忽略（默认落点 `.worktrees/` 常已在项目 `.gitignore` 里，命中就直接创建）：

```bash
git -C "$HOST_ROOT" check-ignore -q -- "$WT_TARGET/.probe"
```

未命中才补忽略规则：默认把稳定的父目录规则写入 `$(git -C "$HOST_ROOT" rev-parse --git-common-dir)/info/exclude`（仅团队需共享该约定时才改 `.gitignore`），写完再复验命中，仍未命中不得创建。

沙箱权限拦截写入 → 告知用户并改为原地工作。

用完按项目约定回流后清理：原生工具建的用原生清理，手动建的用 `git -C "<主仓路径>" worktree remove "$WT"`。
