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

## 步骤 1.5：锚定工作区路径（最易致命的坑）

AI 在 worktree 里最常犯、代价最大的错：**建了 worktree，后续却用主仓路径干活**——Read/Write/Edit 用了主仓的绝对路径（记忆里的老路径），或 `cd` 回了主仓。结果所有改动落进**主仓的当前分支**，你新建的 worktree 分支空空如也，主仓还被意外污染。等到"工作树干净、文件却不见"才发现，已经绕了很久。

建完/进入 worktree 后，**立刻锚定它的绝对路径，之后一切操作以它为根**：

```bash
WT=$(git rev-parse --show-toplevel)   # 当前 worktree 根，记住它
git worktree list                     # 看清每个目录对应哪个分支
echo "已锚定工作区：$WT"
```

铁律：
- **所有文件操作用以 `$WT/` 开头的路径**。每次 Write/Edit 前确认目标路径在 worktree 里，别用记忆里的主仓路径（如 `…/Desktop/<repo>/…`）。
- **绝不 `cd` 回主仓**。需要主仓信息用 `git -C <主仓路径> …`，不切目录。
- 工具默认工作目录可能仍是主仓——**靠绝对路径锚定，不靠"当前目录"**。

## 步骤 2：项目 setup

自动探测并装依赖（有哪个装哪个）：`package.json`→装包 / `Cargo.toml`→build / `requirements.txt`/`pyproject.toml`→装 / `go.mod`→download / `pom.xml`→依赖解析 等。

## 步骤 3：验证干净基线

跑项目对应的测试命令。失败 → 报告并问是否继续（区分新 bug 和既有问题）。通过 → 报告就绪。

## 困惑时：查地面真相，别猜

出现"改了文件却找不到 / git status 干净但改动没了 / 新建的分支是空的" → 几乎一定是改动落错了目录。**别猜，直接对比两个工作区各自的真相**：

```bash
git worktree list                       # 每个目录 + 它的分支 + HEAD，一眼看清谁是谁
git -C "$WT" status --short             # worktree 的改动
git -C "<主仓路径>" status --short      # 主仓的改动
ls "$WT/<你以为改过的文件>" 2>/dev/null || echo "worktree 里没有这个文件"
```

改动出现在主仓而非 `$WT` = 路径根用错了。停手，把改动迁到 worktree 重做，别在主仓继续叠。**撞到第二次困惑就立刻查这个，别再猜第三次。**

完成时同样验证：提交前确认改动在 worktree 分支可见、主仓 `status` 干净。

## 常见错误

- **改动落错仓**：建了 worktree 却用主仓绝对路径 Read/Write/Edit，或 cd 回主仓 → 改动落主仓当前分支、worktree 分支空、主仓被污染。→ 建完锚定 `$WT`，所有路径以它为根，绝不 cd 回主仓（步骤 1.5）。
- **和 harness 较劲**：有原生隔离还手建 worktree。→ 步骤 0/1a 先探测、先用原生。
- **跳过探测**：在已有 worktree 里又套一个。→ 永远先跑步骤 0。
- **跳过 ignore 校验**：worktree 内容被 git 跟踪污染状态。→ 项目内目录先 `git check-ignore`。
- **带着失败的基线往下做**：分不清新旧 bug。→ 先报告，拿到明确许可再继续。
