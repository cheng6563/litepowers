#!/usr/bin/env bash
# git-worktrees 脚本回归测试。用法: bash tests/git-worktrees/run.sh [bash|pwsh|powershell]
# 环境变量: WT_SCRIPTS_DIR 指定被测 scripts 目录（默认仓内 skills/git-worktrees/scripts）;
#           FIX 指定 fixture 目录（默认新建临时目录）。
set -uo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd -- "$HERE/../.." && pwd)
SCRIPTS=${WT_SCRIPTS_DIR:-$REPO/skills/git-worktrees/scripts}
SCRIPTS=$(cd -- "$SCRIPTS" && pwd) || { echo "scripts dir not found: $SCRIPTS" >&2; exit 2; }
SHELL_KIND=${1:-bash}
case $SHELL_KIND in
  bash) RUNNER=(bash "$SCRIPTS/worktree.sh");;
  pwsh|powershell) RUNNER=(env WT_POWERSHELL="$SHELL_KIND" PS1_SCRIPT="$SCRIPTS/worktree.ps1" bash "$HERE/ps-shim.sh");;
  *) echo "usage: run.sh [bash|pwsh|powershell]" >&2; exit 2;;
esac
B=${FIX:-$(mktemp -d "${TMPDIR:-/tmp}/wt-fixture.XXXXXX")}
O=$(bash "$HERE/fixture.sh" "$B" | tail -1) || { echo "fixture failed" >&2; exit 2; }
case "$(uname -s)" in MSYS*|MINGW*) O=$(cygpath -m "$O");; esac
W=("${RUNNER[@]}"); pass=0; fail=0
t() { local name=$1 expect=$2; shift 2; local o; o=$("$@" 2>&1); local rc=$?
  if { [ "$expect" = ok ] && [ $rc -eq 0 ]; } || { [ "$expect" = err ] && [ $rc -ne 0 ]; } || [ "$expect" = "$rc" ]; then pass=$((pass+1)); echo "PASS $name"; else fail=$((fail+1)); echo "FAIL $name rc=$rc"; echo "$o"; fi; LAST=$o; }
has() { if grep -qF -- "$2" <<<"$LAST"; then pass=$((pass+1)); echo "PASS   $1"; else fail=$((fail+1)); echo "FAIL   $1 (want '$2')"; echo "$LAST"; fi; }
cd "$O"   # session sits in OUTER repo, like the bug
t locate-fd ok "${W[@]}" locate "$O/fd-git-repo/src/main/App.java"; has root "source_root=$O/fd-git-repo"; has nomatch "session_matches=no"
t locate-newfile ok "${W[@]}" locate "$O/sc-git-repo/src/new/dir/New.java"; has root2 "source_root=$O/sc-git-repo"
t locate-outer ok "${W[@]}" locate "$O/a.txt"; has outer "session_matches=yes"
t create-fd ok "${W[@]}" create "$O/fd-git-repo/src" feat/x; has wt "worktree=$O/fd-git-repo/.worktrees/feat/x"; has base "base=origin/master"; has psrc-default "parent_source=default"; has excl-fd "exclude_added=/.worktrees/"
t excl-file ok grep -qxF "/.worktrees/" "$O/fd-git-repo/.git/info/exclude"
t no-gitignore ok test ! -e "$O/fd-git-repo/.gitignore"
t create-sc-main ok "${W[@]}" create "$O/sc-git-repo/a.txt" fix-1; has base2 "base=origin/main"; t excl-ignored ok git -C "$O/sc-git-repo" check-ignore -q --no-index -- .worktrees/fix-1/a.txt
t sc-outer-clean ok bash -c "test -z \"\$(git -C '$O' status --porcelain)\""
t sc-inner-clean ok bash -c "test -z \"\$(git -C '$O/sc-git-repo' status --porcelain)\""
t dup-branch err "${W[@]}" create "$O/fd-git-repo" feat/x
t bad-branch err "${W[@]}" create "$O/fd-git-repo" "bad..name"
t verify-ok ok "${W[@]}" verify "$O/fd-git-repo/.worktrees/feat/x" "$O/fd-git-repo/src"
t verify-wrong err "${W[@]}" verify "$O/fd-git-repo/.worktrees/feat/x" "$O/sc-git-repo"
t verify-main err "${W[@]}" verify "$O/fd-git-repo" "$O/fd-git-repo"
t locate-from-wt ok "${W[@]}" locate "$O/fd-git-repo/.worktrees/feat/x/a.txt"; has mainroot "source_root=$O/fd-git-repo"; has inwt "in_worktree=yes"
echo dirty > "$O/fd-git-repo/.worktrees/feat/x/a.txt"
t remove-dirty err "${W[@]}" remove "$O/fd-git-repo/.worktrees/feat/x" "$O/fd-git-repo"
t remove-force ok "${W[@]}" remove "$O/fd-git-repo/.worktrees/feat/x" "$O/fd-git-repo" --force
t remove-clean ok "${W[@]}" remove "$O/sc-git-repo/.worktrees/fix-1" "$O/sc-git-repo"
t no-repo err "${W[@]}" locate "/"
t no-remote-base err "${W[@]}" create "$O/fd-git-repo" y --base origin/nope
# location overrides: arg > env > project (git config litepowers.worktreeDir) > default
ENVD="$O/env wt 目录"
git -C "$O/fd-git-repo" config litepowers.worktreeDir wt-proj
t ovr-project ok "${W[@]}" create "$O/fd-git-repo" o-proj; has proj-path "worktree=$O/fd-git-repo/wt-proj/o-proj"; has proj-src "parent_source=project"; has proj-excl "exclude_added=/wt-proj/"
t ovr-env ok env LITEPOWERS_WORKTREE_DIR="$ENVD" "${W[@]}" create "$O/fd-git-repo" o-env; has env-path "worktree=$ENVD/o-env"; has env-src "parent_source=env"
t ovr-arg ok env LITEPOWERS_WORKTREE_DIR="$ENVD" "${W[@]}" create "$O/fd-git-repo" o-arg --parent "$O/fd-git-repo/wt-arg"; has arg-path "worktree=$O/fd-git-repo/wt-arg/o-arg"; has arg-src "parent_source=arg"; has arg-excl "exclude_added=/wt-arg/"
t ovr-env-rel ok env LITEPOWERS_WORKTREE_DIR=wt-envrel "${W[@]}" create "$O/fd-git-repo" o-envrel; has envrel-path "worktree=$O/fd-git-repo/wt-envrel/o-envrel"
git -C "$O/fd-git-repo" config --unset litepowers.worktreeDir
t ovr-fd-clean ok bash -c "test -z \"\$(git -C '$O/fd-git-repo' status --porcelain)\""
t excl-once ok bash -c "[ \$(grep -cxF '/.worktrees/' '$O/fd-git-repo/.git/info/exclude') -eq 1 ]"
# residue: a non-deletable subdir simulates a Windows file lock; expect exit 3, unregistered, files left
RW="$O/fd-git-repo/.worktrees/res-1"
t create-res ok "${W[@]}" create "$O/fd-git-repo" res-1
chmod 555 "$RW/src/main"
t remove-residue 3 "${W[@]}" remove "$RW" "$O/fd-git-repo"; has residue-status "status=removed_with_residue"; has residue-path "residue=$RW"; has residue-note "note=leftover files"
t residue-unregistered ok bash -c "! git -C '$O/fd-git-repo' worktree list --porcelain | grep -qF 'res-1'"
t residue-left ok test -e "$RW/src/main/App.java"
t residue-branch-kept ok git -C "$O/fd-git-repo" show-ref --verify --quiet refs/heads/res-1
chmod 755 "$RW/src/main"; rm -rf -- "$RW"
echo "TOTAL pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
