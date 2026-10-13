#!/usr/bin/env bash
# usage: run.sh <script-runner...>   e.g. run.sh bash scripts/worktree.sh
set -uo pipefail
B=${FIX:-/tmp/wtfix}; O=$(bash "$(dirname "$0")/fixture.sh" "$B" | tail -1)
case "$(uname -s)" in MSYS*|MINGW*) O=$(cygpath -m "$O");; esac
W=("$@"); pass=0; fail=0
t() { local name=$1 expect=$2; shift 2; local o; o=$("$@" 2>&1); local rc=$?
  if { [ "$expect" = ok ] && [ $rc -eq 0 ]; } || { [ "$expect" = err ] && [ $rc -ne 0 ]; }; then pass=$((pass+1)); echo "PASS $name"; else fail=$((fail+1)); echo "FAIL $name rc=$rc"; echo "$o"; fi; LAST=$o; }
has() { if grep -qF -- "$2" <<<"$LAST"; then pass=$((pass+1)); echo "PASS   $1"; else fail=$((fail+1)); echo "FAIL   $1 (want '$2')"; echo "$LAST"; fi; }
cd "$O"   # session sits in OUTER repo, like the bug
t locate-fd ok "${W[@]}" locate "$O/fd-git-repo/src/main/App.java"; has root "source_root=$O/fd-git-repo"; has nomatch "session_matches=no"
t locate-newfile ok "${W[@]}" locate "$O/sc-git-repo/src/new/dir/New.java"; has root2 "source_root=$O/sc-git-repo"
t locate-outer ok "${W[@]}" locate "$O/a.txt"; has outer "session_matches=yes"
t create-fd ok "${W[@]}" create "$O/fd-git-repo/src" feat/x; has wt "worktree=$O/fd-git-repo/.claude/worktrees/feat/x"; has base "base=origin/master"
t create-sc-main ok "${W[@]}" create "$O/sc-git-repo/a.txt" fix-1; has base2 "base=origin/main"; t excl-ignored ok git -C "$O/sc-git-repo" check-ignore -q --no-index -- .claude/worktrees/fix-1/a.txt
t sc-outer-clean ok bash -c "test -z \"\$(git -C '$O' status --porcelain)\""
t sc-inner-clean ok bash -c "test -z \"\$(git -C '$O/sc-git-repo' status --porcelain)\""
t dup-branch err "${W[@]}" create "$O/fd-git-repo" feat/x
t bad-branch err "${W[@]}" create "$O/fd-git-repo" "bad..name"
t verify-ok ok "${W[@]}" verify "$O/fd-git-repo/.claude/worktrees/feat/x" "$O/fd-git-repo/src"
t verify-wrong err "${W[@]}" verify "$O/fd-git-repo/.claude/worktrees/feat/x" "$O/sc-git-repo"
t verify-main err "${W[@]}" verify "$O/fd-git-repo" "$O/fd-git-repo"
t locate-from-wt ok "${W[@]}" locate "$O/fd-git-repo/.claude/worktrees/feat/x/a.txt"; has mainroot "source_root=$O/fd-git-repo"; has inwt "in_worktree=yes"
echo dirty > "$O/fd-git-repo/.claude/worktrees/feat/x/a.txt"
t remove-dirty err "${W[@]}" remove "$O/fd-git-repo/.claude/worktrees/feat/x" "$O/fd-git-repo"
t remove-force ok "${W[@]}" remove "$O/fd-git-repo/.claude/worktrees/feat/x" "$O/fd-git-repo" --force
t remove-clean ok "${W[@]}" remove "$O/sc-git-repo/.claude/worktrees/fix-1" "$O/sc-git-repo"
t no-repo err "${W[@]}" locate "/"
t no-remote-base err "${W[@]}" create "$O/fd-git-repo" y --base origin/nope
echo "TOTAL pass=$pass fail=$fail"
