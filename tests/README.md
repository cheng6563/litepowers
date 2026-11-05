# git-worktrees 脚本回归测试

`tests/git-worktrees/` 是确定性的 shell 测试，不涉及模型。它会在临时目录里搭一个仿嵌套仓库的 fixture：外层仓包含被忽略的独立子仓，分别用 master 和 main，路径带空格和中文，每个仓配一个本地裸仓库当 origin。然后逐项断言 `skills/git-worktrees/scripts` 下脚本的 locate/create/verify/remove 行为。

```bash
bash tests/git-worktrees/run.sh              # bash 版 worktree.sh
bash tests/git-worktrees/run.sh pwsh         # PowerShell 7 版 worktree.ps1
bash tests/git-worktrees/run.sh powershell   # Windows PowerShell 5.1 版 worktree.ps1
```

可选环境变量：`WT_SCRIPTS_DIR` 指定其他被测脚本目录，用于验证复制或链接后的技能目录；`FIX` 指定 fixture 目录。退出码 0 表示全部通过。bash 测试运行器每次调用都要启动一个所选版本的 PowerShell 宿主，这是测试框架自身的需要；在宿主内部仍用 `& worktree.ps1 ...` 直接调用，与 Agent 的用法一致。位置用例覆盖默认 `.worktrees`、`--parent`、`LITEPOWERS_WORKTREE_DIR`、`git config litepowers.worktreeDir` 四级优先级，以及 `.git/info/exclude` 只写入一次、不生成 `.gitignore`。残留场景通过把 worktree 内某个子目录设为只读（`chmod 555`）来模拟 Windows 文件占用，断言 `remove` 退出码为 3、worktree 已注销、文件仍在。
