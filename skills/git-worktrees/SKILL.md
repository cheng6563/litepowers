---
name: git-worktrees
description: "为隔离开发创建、进入和清理 Git worktree。只要用户提到 worktree、隔离分支、独立工作目录，或项目指令要求隔离工作，就使用本技能；尤其用于外层套壳仓包含多个独立子 Git 仓的场景，确保原生 worktree 工具锚定到真正要修改的子仓。"
---

# 使用 Git Worktrees

核心只有一件事：**先定位本次要修改代码所属的 Git 仓，再从该仓创建 worktree。**

`.claude/worktrees`、`.worktrees` 等目录名本身不是问题。真正会造成错误的是：目标代码属于子 Git 仓，但创建工具仍锚定在外层套壳仓。

## 1. 定位目标子仓

不要直接以会话启动目录或当前外层仓创建 worktree。先从本次要修改的文件或代码目录反查 Git 根。路径可能是尚不存在的新文件，因此先取一个已存在的祖先目录：

```bash
CODE_PATH='<本次要修改的代码目录或文件>'
START="$CODE_PATH"
[ -d "$START" ] || START=$(dirname -- "$START")
while [ ! -d "$START" ]; do
  NEXT=$(dirname -- "$START")
  [ "$NEXT" != "$START" ] || { echo '错误：找不到代码路径的已存在祖先目录' >&2; exit 1; }
  START="$NEXT"
done
SOURCE_ROOT=$(git -C "$START" rev-parse --show-toplevel) || {
  echo '错误：代码路径不属于 Git 仓库' >&2
  exit 1
}
printf '代码路径: %s\n目标 Git 仓: %s\n' "$CODE_PATH" "$SOURCE_ROOT"
```

在套壳仓中，必须区分外层仓和实际代码子仓。例如：

```text
外层套壳仓：C:/Users/leicheng/Desktop/scprod
实际代码仓：C:/Users/leicheng/Desktop/scprod/sc-git-repo/cf-core/fendan-mgt
```

修改 `fendan-mgt` 时，`SOURCE_ROOT` 必须是第二条路径。修改其他独立子仓（如 `business-engine`）时，也必须定位到该子仓自己的 Git 根，不能停在 `scprod`。

如果 `SOURCE_ROOT` 与预期项目不符，停止创建并重新定位 `CODE_PATH`。

## 2. 原生工具优先，但先验证活动仓库上下文

优先使用平台原生 worktree 工具，例如 Claude Code 的 `EnterWorktree`。**不要因为它使用 `.claude/worktrees` 就禁用或绕过它。**

但原生工具通常依据当前 Claude Code 会话/工作目录决定“哪个仓库”创建 worktree；`git -C "$SOURCE_ROOT"` 只改变一条 Git 命令的目录，不会改变原生工具的活动仓库。因此调用原生工具前必须实际切换上下文，而不是只在文字中声明目标仓：

```bash
CURRENT_ROOT=$(git rev-parse --show-toplevel) || {
  echo '错误：当前会话目录不在 Git 仓库中' >&2
  exit 1
}

canon_dir() { (cd -- "$1" && pwd -P); }
CURRENT_ROOT=$(canon_dir "$CURRENT_ROOT")
SOURCE_ROOT=$(canon_dir "$SOURCE_ROOT")
printf '当前会话 Git 仓: %s\n目标 Git 仓: %s\n' "$CURRENT_ROOT" "$SOURCE_ROOT"

[ "$CURRENT_ROOT" = "$SOURCE_ROOT" ] || {
  echo '错误：当前会话仍位于外层仓或其他仓库；不得调用原生 worktree 工具' >&2
  echo '请先以目标 Git 仓作为项目上下文重新进入/启动会话，再重试 EnterWorktree；不要仅执行 git -C' >&2
  exit 1
}
```

如果平台提供项目/仓库切换能力，先切到 `SOURCE_ROOT`，再重新执行上面的校验；如果平台依据会话工作目录识别仓库，应从 `SOURCE_ROOT` 启动或重新进入会话后再调用原生工具。**没有通过校验就不能调用 `EnterWorktree`。**只有原生工具无法绑定到该子仓时，才退回手动 `git worktree add`。

调用前同时明确预期位置。位置由平台或项目约定决定，不要因为看到外层仓已有目录就套用外层路径：

```text
目标仓：<SOURCE_ROOT>
预期 worktree：<SOURCE_ROOT>/.claude/worktrees/<name>
```

例如 `business-engine` 是独立子仓时：

```text
错误：C:/Users/leicheng/Desktop/scprod/.claude/worktrees/business-engine-upstream-or
正确：<business-engine 子仓根>/.claude/worktrees/business-engine-upstream-or
```

错误路径说明原生工具创建的是 `scprod` 的 worktree，而不是 `business-engine` 的 worktree；问题在仓库上下文，不在 `.claude/worktrees` 目录名。

## 3. 创建后立即验证原生 worktree 归属

原生工具返回路径后，先验证，不要直接修改代码。比较 Git common dir，并同时确认 worktree 根目录：

```bash
WT='<原生工具返回的 worktree 路径>'
WT_TOP=$(git -C "$WT" rev-parse --show-toplevel) || exit 1
ACTUAL_COMMON=$(git -C "$WT" rev-parse --git-common-dir) || exit 1
SOURCE_COMMON=$(git -C "$SOURCE_ROOT" rev-parse --git-common-dir) || exit 1
WT_TOP=$(canon_dir "$WT_TOP")
ACTUAL_COMMON=$(cd -- "$WT" && cd -- "$ACTUAL_COMMON" && pwd -P)
SOURCE_COMMON=$(cd -- "$SOURCE_ROOT" && cd -- "$SOURCE_COMMON" && pwd -P)

if [ "$ACTUAL_COMMON" != "$SOURCE_COMMON" ]; then
  printf '错误：worktree 创建到了错误的 Git 仓\n目标仓: %s\n实际 worktree: %s\n实际所属 common dir: %s\n' \
    "$SOURCE_ROOT" "$WT_TOP" "$ACTUAL_COMMON" >&2
  echo '停止后续修改；先检查该 worktree 的状态和分支，再决定是否用原生工具清理。' >&2
  exit 1
fi
printf 'worktree 已验证: %s\n' "$WT_TOP"
```

检查失败后：

1. 不在该 worktree 中继续读写代码；
2. 报告目标仓、实际 worktree 路径和实际所属 common dir；
3. 检查该 worktree 的分支及未提交改动；
4. 有改动时不要自动删除，先确认迁移/保留方案；
5. 无改动且获得清理许可后，使用**实际所属仓**的原生清理能力；
6. 回到 `SOURCE_ROOT` 上下文，重新调用原生工具。

`git-common-dir` 校验用于发现已经发生的错仓创建，不能替代第 2 节的调用前上下文校验。

## 4. 原生工具不可用时的手动 fallback

手动 fallback 也必须使用同一个 `SOURCE_ROOT`，但不能无视已确定的 worktree 位置。按以下优先级确定 `WT_PARENT`：

1. 用户明确指定的位置；
2. 项目明确指定的位置；
3. 已确认的平台原生工具位置（例如 Claude Code 约定的 `SOURCE_ROOT/.claude/worktrees`）；
4. 没有任何约定时，才使用 `SOURCE_ROOT/.worktrees`。

**已有目录或历史 worktree 只能作为线索，不能单独证明位置约定。**若是为了替代原生 Claude Code 工具，且预期位置是 `.claude/worktrees`，必须显式设置：

```bash
WT_PARENT="$SOURCE_ROOT/.claude/worktrees"
```

然后只把规范化后的绝对路径传给 Git：

```bash
BRANCH='<工作分支名>'
WT_TARGET="$WT_PARENT/$BRANCH"
case "$(uname -s)" in
  MSYS*|MINGW*) WT_TARGET=$(cygpath -am -- "$WT_TARGET") ;;
  *)            WT_TARGET=$(realpath -m -- "$WT_TARGET") ;;
esac
printf '目标 Git 仓: %s\n即将创建: %s\n' "$SOURCE_ROOT" "$WT_TARGET"

[ "$WT_TARGET" != "$SOURCE_ROOT" ] || { echo '错误：不能把源仓根作为 worktree 目标' >&2; exit 1; }
[ ! -e "$WT_TARGET" ] || { echo "错误：目标已存在：$WT_TARGET" >&2; exit 1; }
git -C "$SOURCE_ROOT" worktree add "$WT_TARGET" -b "$BRANCH"
```

不要在 `SOURCE_ROOT` 内执行命令时，又传入带项目展示前缀的相对路径。例如在
`.../sc-git-repo/cf-core/fendan-mgt` 中传入：

```text
sc-git-repo/cf-core/fendan-mgt/.worktrees/<branch>
```

会被重复解析成：

```text
.../fendan-mgt/sc-git-repo/cf-core/fendan-mgt/.worktrees/<branch>
```

因此手动目标必须由 `SOURCE_ROOT` 直接生成绝对路径，不从聊天记录或文件树复制“看起来完整”的相对路径。

## 5. 手动创建前的 ignore 检查

原生工具自行管理其 `.claude/worktrees` 和忽略规则，不要覆盖。手动创建时，先确认目标父目录被目标子仓忽略：

```bash
git -C "$SOURCE_ROOT" check-ignore -q -- "$WT_TARGET/.probe" || {
  echo '错误：目标父目录未被目标子仓忽略；先写入该仓的 .git/info/exclude 并复验' >&2
  exit 1
}
```

只有团队需要共享约定时才修改 `.gitignore`。如果子仓位于外层套壳仓中，还要确认外层仓不会跟踪同一个绝对目标路径；套壳仓通常已整体忽略 `sc-git-repo/` 之类的 checkout 容器目录。

## 6. 创建后锚定并操作

无论原生还是手动创建，创建后都必须确认：

1. worktree 的 `--git-common-dir` 与 `SOURCE_ROOT` 一致；
2. `git -C "$WT" rev-parse --show-toplevel` 返回新 worktree 路径；
3. 后续文件和 Git 操作都以新 worktree 为根。

不要仅凭分支名、目录名或 `git worktree list` 中存在记录就判断仓库归属正确。

## 7. 清理

原生工具创建的 worktree 优先使用原生工具清理。手动创建的由对应子仓清理：

```bash
git -C "$SOURCE_ROOT" worktree remove "$WT"
```

发现历史错误 worktree 时不要直接删除；先确认未提交改动、分支和真正所属仓库，再按项目的高风险操作规则处理。清理前必须再次通过 `git-common-dir` 确认 `$WT` 属于要操作的仓库。
