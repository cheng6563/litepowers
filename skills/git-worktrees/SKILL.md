---
name: git-worktrees
description: "Use when worktrees, isolated branches/work directories, or project-required isolation are involved; create, enter and clean up Git worktrees."
---

# 使用 Git Worktrees

**从目标代码定位所属仓库 → 工作分支基于最新远端主干 → 创建后校验 common dir。定位、创建、校验、清理一律调用配套脚本，禁止手写 `git worktree add/remove`。**

## 0. 找到配套脚本

`SKILL_DIR` = **你刚读取的这个 SKILL.md 所在的目录**（平台加载技能时给出的 base directory，或技能列表里 SKILL.md 路径的父目录）。脚本固定在 `SKILL_DIR/scripts/` 下。调用时一律拼成绝对路径；相对路径会按当前工作目录解析，不能用。

- bash / Git Bash：`bash "$SKILL_DIR/scripts/worktree.sh" <子命令> ...`
- PowerShell 5.1 / 7：`pwsh -NoProfile -File "$SKILL_DIR\scripts\worktree.ps1" <子命令> ...`（没有 pwsh 时用 `powershell -NoProfile -ExecutionPolicy Bypass -File ...`）

如果拿不到这个 SKILL.md 的路径，按以下顺序找，找到第一个即停：

1. 环境变量 `LITEPOWERS_SKILL_DIR`（指向本技能目录）；
2. 在已知技能根目录下找 `git-worktrees/scripts/worktree.sh`：项目内 `.agents/skills`、`.claude/skills`、`.cursor/skills`；用户目录下 `~/.agents/skills`、`~/.claude/skills`、`~/.claude/plugins`、`~/.codex/skills`、`~/.pi/agent/skills`、`~/.cursor/skills`。

确认用的是哪一份：执行 `worktree where`，看输出的 `skill_dir`。仍然找不到就停止并告知用户，不要退回手写命令。

## 输出约定

输出为 `key=value` 行；失败时 stderr 输出 `error=...` 且退出码非 0。**任何非 0 退出都立即停止，向用户报告 error 原文，不要自行绕过或改用手写命令。**

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

脚本会做这些事：在 `source_root/.claude/worktrees/<分支名>` 创建；必要时写入该仓的 `.git/info/exclude`；先 fetch，再基于 `origin/master`（没有就用 `origin/main`）切出新分支；创建后自动校验。用户或项目另有约定位置时才传 `--parent`。

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

脚本会先校验归属；有未提交改动时拒绝删除（`--force` 需用户明确同意）。如果设置了 `LITEPOWERS_RECYCLE`（回收站工具路径，如 `rm_win.exe`），或 PATH 中有 `rm_win`，目录会先移入回收站再执行 `git worktree prune`，可以恢复；分支不会被删除。
