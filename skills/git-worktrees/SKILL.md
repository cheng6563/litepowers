---
name: git-worktrees
description: "Use when worktrees, isolated branches/work directories, or project-required isolation are involved; create, enter and clean up Git worktrees."
---

# 使用 Git Worktrees

按目标代码定位仓库，默认基于最新远端主干创建工作分支，再校验和清理。定位与校验使用配套脚本；创建、清理可选平台原生工具，其余使用脚本。禁止手写 `git worktree add/remove`。

## 调用

`SKILL_DIR` 为本技能绝对路径；在当前 shell 直接调用：

- PowerShell 5.1 / 7：`& "$SKILL_DIR/scripts/worktree.ps1" <子命令与参数>`，检查 `$LASTEXITCODE`。
- bash / Git Bash：`bash "$SKILL_DIR/scripts/worktree.sh" <子命令与参数>`。

下表使用 PowerShell 参数；bash 对应为 `--base`、`--parent`、`--no-fetch`、`--force`。

| 步骤 | 子命令与参数 | 判断与后续 |
|---|---|---|
| 定位 | `locate <代码路径>` | 核对 `source_root` 是否为目标仓主检出根；不符时停止并纠正路径 |
| 创建 | `create <代码路径> <分支名> [-Base <ref>] [-Parent <目录>] [-NoFetch]` | 默认 fetch 后基于 `origin/master`（无则 `origin/main`）创建并自动校验；后续读写与 Git 操作以输出的 `worktree` 为根 |
| 校验 | `verify <worktree路径> <代码路径>` | 原生工具创建后必做，确认 common dir 归属且返回 `status=ok` 才继续 |
| 清理 | `remove <worktree路径> <代码路径> [-Force]` | 原生工具创建的优先原生清理；脚本先校验归属，有未提交改动时拒绝删除，Force 须用户明确同意；只删除一次，保留分支 |

`<代码路径>` 传本次要修改的文件或目录，可尚不存在；嵌套仓库必须传子仓内路径。原生工具的目标仓不随 `git -C` 改变，仍需上述校验。归属校验失败时停止修改，报告目标仓、实际路径及 common dir；有未提交改动时先请用户确认清理。

创建目录优先级为显式 Parent、`LITEPOWERS_WORKTREE_DIR`、目标仓配置 `litepowers.worktreeDir`、`source_root/.worktrees`。Parent 仅在用户指定位置时传；环境变量和项目配置的相对目录基于 `source_root`。仓内父目录由脚本写入本地忽略配置。

## 结果与失败

输出为 `key=value`。非 0 退出立即停止，不绕过脚本：

- 退出码 1：转述 stderr 的 `error` 原文。
- 清理退出码 3、`status=removed_with_residue`：Git 已注销 worktree，但目录尚有文件；报告 `residue` 路径，不重试、不手动删除、不结束进程。
