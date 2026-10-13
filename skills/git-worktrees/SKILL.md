---
name: git-worktrees
description: "Use when worktrees, isolated branches/work directories, or project-required isolation are involved; create, enter and clean up Git worktrees."
---

# 使用 Git Worktrees

**从目标代码定位所属仓库 → 工作分支基于最新远端主干 → 创建后校验 common dir。定位、创建、校验、清理一律调用配套脚本，禁止手写 `git worktree add/remove`。**

## 0. 找到配套脚本

`SKILL_DIR` = **你刚读取的这个 SKILL.md 所在的目录**（平台加载技能时给出的 base directory，或技能列表里 SKILL.md 路径的父目录）。脚本固定在 `SKILL_DIR/scripts/` 下。调用时一律拼成绝对路径；相对路径会按当前工作目录解析，不能用。

按你当前所在的 shell 直接调用，**不要套一层新的 shell 进程**：

- 当前是 PowerShell 7（pwsh）：用调用运算符直接执行：`& "$SKILL_DIR/scripts/worktree.ps1" <子命令> ...`
- 当前是 bash / Git Bash：`bash "$SKILL_DIR/scripts/worktree.sh" <子命令> ...`

禁止 `pwsh -File ...`、`powershell -File ...`，也禁止从 bash 再启动 pwsh 去调用 `.ps1`。只支持 PowerShell 7，不支持 Windows PowerShell 5.1。PowerShell 中的退出码看 `$LASTEXITCODE`。

如果拿不到这个 SKILL.md 的路径，按以下顺序找，找到第一个即停：

1. 环境变量 `LITEPOWERS_SKILL_DIR`（指向本技能目录）；
2. 在已知技能根目录下找 `git-worktrees/scripts/worktree.sh`：项目内 `.agents/skills`、`.claude/skills`、`.cursor/skills`；用户目录下 `~/.agents/skills`、`~/.claude/skills`、`~/.claude/plugins`、`~/.codex/skills`、`~/.pi/agent/skills`、`~/.cursor/skills`。

确认用的是哪一份：执行 `worktree where`，看输出的 `skill_dir`。仍然找不到就停止并告知用户，不要退回手写命令。

## 输出约定

输出为 `key=value` 行；失败时 stderr 输出 `error=...` 且退出码为 1。退出码 3 仅用于 `remove` 留有残留文件的情况，见第 4 步。**任何非 0 退出都立即停止，向用户报告 error 原文，不要自行绕过或改用手写命令。**

`<代码路径>` 传本次要修改的文件或目录（可以不存在，脚本会往上找已存在的祖先目录）。嵌套仓库（外层仓里有被忽略的独立子仓）时，务必传子仓里的路径，不要传外层根目录。

## 1. 定位

```
worktree locate <代码路径>
```

关键字段：`source_root`（目标仓主检出根）、`session_matches`（当前会话目录是否就在该仓）、`outer_repo`（有值说明是嵌套子仓）。`source_root` 与预期项目不符时停止，换正确的代码路径。

## 2. 创建

平台若提供原生 worktree 工具，可以使用，但它不一定以 `source_root` 为目标仓（`git -C` 不会改变它的上下文）。用完必须执行第 3 步校验。其余情况用脚本创建：

```
worktree create <代码路径> <分支名> [--base origin/xxx] [--parent <目录>]
```

（PowerShell 参数写法为 `-Base` / `-Parent` / `-NoFetch`。）

脚本会做这些事：先 fetch，再基于 `origin/master`（没有就用 `origin/main`）切出新分支；创建后自动校验。

创建位置为 `<父目录>/<分支名>`，父目录按以下优先级确定（输出里的 `parent_source` 会标明用的是哪一级）：

1. 参数 `--parent <目录>`：用户明确指定位置时才传；
2. 环境变量 `LITEPOWERS_WORKTREE_DIR`；
3. 项目约定：目标仓的 `git config litepowers.worktreeDir`；
4. 默认：`source_root/.worktrees`。

后两级的相对路径都相对于 `source_root`。父目录在仓内且尚未被忽略时，脚本会把它写入该仓的 `.git/info/exclude`，不会修改 `.gitignore`。`.claude/worktrees` 只是 Claude Code 自带工具的约定，脚本不使用它。

创建成功后，后续所有读写和 Git 操作都以输出的 `worktree` 为根。

## 3. 校验（原生工具创建后必做）

```
worktree verify <worktree路径> <代码路径>
```

输出 `status=ok` 才能继续。校验失败说明建到了错误的仓：不要在里面改代码；报告目标仓、实际路径和 common dir；有未提交改动时先和用户确认，不要自动删除。

## 4. 清理

原生工具创建的，优先用原生工具清理。其他情况：

```
worktree remove <worktree路径> <代码路径> [--force]
```

脚本会先校验归属；有未提交改动时拒绝删除（`--force` 需用户明确同意）。只用 `git worktree remove` 删除一次，不会重试；分支不会被删除。

退出码 3、输出 `status=removed_with_residue` 表示 worktree 已从 Git 注销，但 `residue` 指向的目录还有文件残留（通常是 Windows 上文件被其他程序占用）。这时把 `residue` 路径告诉用户并停止：不要重试，不要手动删除，不要结束任何进程。
