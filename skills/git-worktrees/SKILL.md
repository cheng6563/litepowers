---
name: git-worktrees
description: "为隔离开发创建、进入和清理 Git worktree。只要用户提到 worktree、隔离分支、独立工作目录，或项目指令要求隔离工作，就使用本技能；尤其用于外层套壳仓包含多个独立子 Git 仓的场景，确保原生 worktree 工具锚定到真正要修改的子仓。Use when creating, entering, or cleaning an isolated Git worktree, or when project instructions require isolated work."
---

# 使用 Git Worktrees

**从目标代码定位所属仓库，绑定创建工具的活动上下文，创建后校验 Git common dir。**

## 1. 定位目标子仓

从本次要修改的文件或代码目录反查 Git 根。新文件尚不存在时，先取一个已存在的祖先目录：

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

嵌套仓库示例：

```text
workspace/          外层仓
└── services/app/   独立子仓
```

修改 app 的代码时，`SOURCE_ROOT` 指向 app 子仓根目录。结果与预期项目不符时，停止创建并重新定位 `CODE_PATH`。

## 2. 绑定原生工具的活动仓库

优先使用平台原生 worktree 工具，例如 Claude Code 的 `EnterWorktree`。调用前将其活动仓库切换到 `SOURCE_ROOT` 并校验；`git -C` 只影响单条命令，不能切换原生工具的上下文：

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

平台支持切换项目时，切换后重新校验；否则从 `SOURCE_ROOT` 重新进入会话。校验通过后才调用原生工具；无法绑定目标子仓时，退回手动 `git worktree add`。

创建前明确目标仓与预期绝对路径，位置按用户、项目或平台的约定确定。

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

## 4. 原生工具不可用时的手动 fallback

手动创建使用已确认的 `SOURCE_ROOT`，按以下优先级确定 `WT_PARENT`：

1. 用户明确指定的位置；
2. 项目明确指定的位置；
3. 已确认的平台原生工具位置（例如 Claude Code 约定的 `SOURCE_ROOT/.claude/worktrees`）；
4. 没有任何约定时，才使用 `SOURCE_ROOT/.worktrees`。

**已有目录或历史 worktree 只能作为线索，不能单独证明位置约定。**若是为了替代原生 Claude Code 工具，且预期位置是 `.claude/worktrees`，必须显式设置：

```bash
WT_PARENT="$SOURCE_ROOT/.claude/worktrees"
```

由已确认的父目录与分支名生成规范化绝对路径，再传给 Git：

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

## 5. 手动创建前的 ignore 检查

原生工具自行管理其 `.claude/worktrees` 和忽略规则，不要覆盖。手动创建时，先确认目标父目录被目标子仓忽略：

```bash
git -C "$SOURCE_ROOT" check-ignore -q -- "$WT_TARGET/.probe" || {
  echo '错误：目标父目录未被目标子仓忽略；先写入该仓的 .git/info/exclude 并复验' >&2
  exit 1
}
```

只有团队需要共享约定时才修改 `.gitignore`。子仓位于外层仓中时，还要确认外层仓不会跟踪同一个绝对目标路径。

## 6. 创建后锚定并操作

无论原生还是手动创建，创建后都必须确认：

1. worktree 的 `--git-common-dir` 与 `SOURCE_ROOT` 一致；
2. `git -C "$WT" rev-parse --show-toplevel` 返回新 worktree 路径；
3. 后续文件和 Git 操作都以新 worktree 为根。

## 7. 清理

原生工具创建的 worktree 优先使用原生工具清理。手动创建的由对应子仓清理：

```bash
git -C "$SOURCE_ROOT" worktree remove "$WT"
```

发现历史错误 worktree 时不要直接删除；先确认未提交改动、分支和真正所属仓库，再按项目的高风险操作规则处理。清理前必须再次通过 `git-common-dir` 确认 `$WT` 属于要操作的仓库。
