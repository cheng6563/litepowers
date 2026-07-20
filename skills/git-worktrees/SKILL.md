---
name: git-worktrees
description: "安全创建、锚定和回收 Git worktree 隔离工作区。Use when the user explicitly requests a worktree or project instructions require isolated work; first detect whether the current session is already inside one."
---

# 使用 Git Worktrees

确保工作发生在隔离工作区。**优先用平台原生 worktree 工具，没有再退回手动 git worktree。**

核心顺序：**先探测已有隔离 → 选原生或手动路径 → 创建前阻止目标被任何上级 Git 仓库跟踪 → 创建并锚定 → 别和 harness 较劲。**

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

先选创建器：当前会话有 `EnterWorktree` 就优先使用；它不可用或不能满足用户指定路径时，才用 `git worktree add`。原生创建交给平台管理，不复刻其目录和清理逻辑。

无论用哪种创建器，**创建前都要确认目标目录不会被承载它的 Git 工作树当作普通内容跟踪**。尤其不能因为目标在“当前项目外”就跳过：它仍可能位于更上级仓库中。

```bash
WT_TARGET="<计划创建的绝对路径>"
PARENT="$WT_TARGET"
while [ ! -d "$PARENT" ]; do PARENT=$(dirname "$PARENT"); done
HOST_ROOT=$(git -C "$PARENT" rev-parse --show-toplevel 2>/dev/null || true)
```

`HOST_ROOT` 为空即可创建；非空则先让该仓库忽略目标目录，或把目标移到其工作树之外。默认把相对 `HOST_ROOT` 的稳定目录规则写入：

```bash
$(git -C "$HOST_ROOT" rev-parse --git-common-dir)/info/exclude
```

只有团队需要共享该目录约定时才修改 `.gitignore`。无论规则已存在还是刚写入，都用尚不存在的子路径复验；未命中不得创建：

```bash
PROBE="$WT_TARGET/.gitignore-probe"
git -C "$HOST_ROOT" check-ignore -q -- "$PROBE"
```

然后用已选创建器创建；手动退路为：

```bash
git worktree add "$WT_TARGET" -b "$BRANCH"
cd "$WT_TARGET"
```

尊重用户指定路径。优先写稳定的父目录 ignore 规则，避免为每个临时 worktree 积累一次性规则。权限错误（沙箱拦截）→ 告诉用户并改为原地工作。

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

## 步骤 1.6：钉死在隔离分支（第二条致命铁律）

路径锚定只防"文件落错仓"；还有一类同样致命的错位是**分支 checkout 错位**。

**心智模型：分支是仓库级单例。** master / main 这类分支同一时刻只能被一个工作区 checkout——你在 worktree 里 `git checkout master`，就把主干的唯一 checkout 位挪进了这个临时目录，**主仓和所有其他会话立刻切不到 master**，直到你归还。干完不归还，主干就被这个临时 worktree 占死。

铁律：
- **worktree 内绝不 `git checkout` / `git switch` 到 master / main 等共享主干。** 这个 worktree 自始至终待在自己的隔离分支上。
- **要把活合进主干，别在 worktree 内切主干来 merge**，改用下列之一：① 走 PR 回流；② 在主仓执行 `git -C "<主仓路径>" merge "$BRANCH"`（让 merge 发生在主仓，当前 worktree 不切分支）。
- 万不得已在 worktree 内切过主干，**merge 完第一时间 `git checkout -` 切回隔离分支归还**，绝不停在主干上（见步骤 3c）。

## 步骤 2：建立项目基线

按项目既有 setup 与验证入口准备必要环境并建立与任务范围匹配的基线；失败时报告并确认是否继续，未建立基线前不要把后续失败归因于本次改动。

## 步骤 3：回流前检查

worktree 只提供隔离，不决定合并拓扑；但回流应优先让工作分支按项目约定正常合并。别为了省事把 diff/apply、复制文件、cherry-pick 当默认回流方式——这会绕过分支语义，让 worktree 分支变成废分支。

### 3a：确认目标 base

需要远端新鲜度时只 fetch 目标 remote/ref，再比较目标 base：
```bash
BASE_REF="<目标主干或 PR base>"
git -C "$WT" fetch "<remote>" "<base>"   # 仅在需要刷新远端证据时
git -C "$WT" diff --name-only "$BASE_REF"...HEAD
```

### 3b：扫 Git 无法发现的语义冲突

git 只发现同一区块文本冲突。上一步涉及共享命名空间、唯一标识或顺序资源时，按项目规则核对冲突并在本分支修正。

### 3c：正常回流，再清理

优先把 `$BRANCH` 按项目 / 平台约定回流（PR merge / `git merge`；具体 merge commit、squash merge、rebase merge 听项目约定）。只有用户明确要求挑提交 / 补丁提取，或分支无法合并且说明原因时，才用 cherry-pick / patch。

**别在 worktree 内 checkout 主干来 merge**（步骤 1.6）——要本地合就 `git -C "<主仓路径>" merge "$BRANCH"`，让 merge 发生在主仓、当前 worktree 不切分支。万一已经在 worktree 内切到主干合过，**先 `git checkout -` 归还隔离分支再往下清理**；停在主干上不归还 = 主干被这个临时目录占死，主仓和其他会话都切不过去。

回流后清理 worktree。原生工具创建的优先用原生清理；手动 `git worktree` 用已锚定路径：
```bash
git -C "<主仓路径>" worktree remove "$WT"
git -C "<主仓路径>" branch -d "$BRANCH"   # 仅真实 merge 后可靠；squash/rebase 回流后按项目约定删分支
```

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
