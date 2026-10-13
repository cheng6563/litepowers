#!/usr/bin/env bash
# build scprod-like fixture in $1
set -euo pipefail
B=$1; rm -rf "$B"; mkdir -p "$B"
g() { git -c user.name=t -c user.email=t@t -c init.defaultBranch="$1" "${@:2}"; }
mkrepo() { # dir defaultbranch
  local d=$1 br=$2
  g "$br" init -q --bare "$B/remotes/$(basename "$d").git"
  g "$br" init -q "$d"; echo hi > "$d/a.txt"; mkdir -p "$d/src/main"; echo x > "$d/src/main/App.java"
  g "$br" -C "$d" add -A; g "$br" -C "$d" commit -qm init
  git -C "$d" remote add origin "$B/remotes/$(basename "$d").git"; git -C "$d" push -q origin "$br"
}
O="$B/sc prod 中文"
mkrepo "$O" master
printf 'fd-git-repo/\nsc-git-repo/\n.claude/worktrees/\n' > "$O/.gitignore"
git -C "$O" add .gitignore; git -c user.name=t -c user.email=t@t -C "$O" commit -qm ign; git -C "$O" push -q origin master
mkrepo "$O/fd-git-repo" master
mkrepo "$O/sc-git-repo" main
git -C "$O/sc-git-repo" checkout -qb stale-local   # local non-trunk branch checked out
echo "$O"
