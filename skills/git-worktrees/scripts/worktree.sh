#!/usr/bin/env bash
# litepowers git-worktrees helper (bash / Git Bash / MSYS). UTF-8.
# Usage:
#   worktree.sh where              (print own skill/script paths)
#   worktree.sh locate <code-path>
#   worktree.sh create <code-path> <branch> [--base <ref>] [--parent <dir>] [--no-fetch]
#   worktree.sh verify <worktree> <code-path>
#   worktree.sh remove <worktree> <code-path> [--force]
# Output: key=value lines on stdout; errors as "error=<msg>" on stderr, exit 1.
# Exit codes: 0 ok; 1 error; 3 remove: unregistered but leftover files (status=removed_with_residue).
set -euo pipefail
# Self-locate (no hard-coded paths): works via symlink/junction/copy.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SKILL_DIR=$(dirname -- "$SCRIPT_DIR")
export LC_ALL=C.UTF-8 2>/dev/null || true

die() { printf 'error=%s\n' "$*" >&2; exit 1; }
out() { printf '%s=%s\n' "$1" "$2"; }

IS_WIN=0
case "$(uname -s)" in MSYS*|MINGW*|CYGWIN*) IS_WIN=1 ;; esac

# Accept C:\x or C:/x on Windows bash
to_native() {
  local p=$1
  if [ "$IS_WIN" = 1 ] && [[ $p =~ ^[A-Za-z]:[\\/] || $p == *\\* ]]; then p=$(cygpath -u -- "$p"); fi
  printf '%s' "$p"
}
# Canonical string for comparison: let git produce absolute paths, then
# (Windows) mixed form + lowercase, strip trailing slash.
canon() {
  local p=$1
  if [ "$IS_WIN" = 1 ]; then p=$(cygpath -am -- "$p"); p=${p,,}
  else p=$( (cd -- "$p" 2>/dev/null && pwd -P) || realpath -m -- "$p"); fi
  printf '%s' "${p%/}"
}
existing_dir() {
  local s; s=$(to_native "$1")
  [ -d "$s" ] || s=$(dirname -- "$s")
  while [ ! -d "$s" ]; do local n; n=$(dirname -- "$s"); [ "$n" != "$s" ] || die "no existing ancestor for: $1"; s=$n; done
  printf '%s' "$s"
}
toplevel()  { git -C "$1" rev-parse --show-toplevel 2>/dev/null; }
commondir() { git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null; }
# main checkout root of the repo owning dir (works from inside a worktree)
main_root() { local c; c=$(commondir "$1") || return 1; git -C "$c/.." rev-parse --show-toplevel 2>/dev/null || dirname -- "$c"; }

locate() {
  local start top common root outer=""
  start=$(existing_dir "$1")
  top=$(toplevel "$start") || die "not inside a git repo: $1"
  common=$(commondir "$start")
  root=$(main_root "$start")
  local up; up=$(dirname -- "$root")
  outer=$(toplevel "$up" || true)
  SOURCE_ROOT=$root; SOURCE_COMMON=$common
  out source_root "$root"; out code_toplevel "$top"; out common_dir "$common"
  [ "$(canon "$top")" = "$(canon "$root")" ] && out in_worktree no || out in_worktree yes
  out outer_repo "${outer:-}"
  local cwdroot; cwdroot=$(main_root "$PWD" 2>/dev/null || true)
  out session_root "${cwdroot:-}"
  if [ -n "$cwdroot" ] && [ "$(canon "$cwdroot")" = "$(canon "$root")" ]; then out session_matches yes; else out session_matches no; fi
}

verify_wt() { # wt code-path
  local wt; wt=$(to_native "$1"); [ -d "$wt" ] || die "worktree path missing: $1"
  locate "$2" >/dev/null
  local a; a=$(commondir "$wt") || die "not a git dir: $1"
  local wtop; wtop=$(toplevel "$wt")
  [ "$(canon "$a")" = "$(canon "$SOURCE_COMMON")" ] || die "worktree belongs to wrong repo: worktree=$wtop common=$a expected=$SOURCE_COMMON"
  [ "$(canon "$wtop")" != "$(canon "$SOURCE_ROOT")" ] || die "path is the main checkout, not a worktree: $wtop"
  out status ok; out worktree "$wtop"; out source_root "$SOURCE_ROOT"; out branch "$(git -C "$wt" branch --show-current)"; out head "$(git -C "$wt" rev-parse HEAD)"
}

create() {
  local code=$1 branch=$2; shift 2
  local base="" parent="" fetch=1
  while [ $# -gt 0 ]; do case $1 in
    --base) base=$2; shift 2;; --parent) parent=$(to_native "$2"); shift 2;; --no-fetch) fetch=0; shift;;
    *) die "unknown option: $1";; esac; done
  git check-ref-format --branch "$branch" >/dev/null 2>&1 || die "invalid branch name: $branch"
  locate "$code" >/dev/null
  local R=$SOURCE_ROOT
  git -C "$R" show-ref --verify --quiet "refs/heads/$branch" && die "branch already exists: $branch"
  # location precedence: --parent > $LITEPOWERS_WORKTREE_DIR > git config litepowers.worktreeDir (project) > .worktrees
  local psrc=arg
  if [ -z "$parent" ]; then
    local cfg; cfg=$(git -C "$R" config --get litepowers.worktreeDir 2>/dev/null || true)
    if [ -n "${LITEPOWERS_WORKTREE_DIR:-}" ]; then parent=$(to_native "$LITEPOWERS_WORKTREE_DIR"); psrc=env
    elif [ -n "$cfg" ]; then parent=$(to_native "$cfg"); psrc=project
    else parent=.worktrees; psrc=default; fi
    case $parent in /*|[A-Za-z]:*) ;; *) parent="$R/$parent";; esac
  else
    case $parent in /*) ;; *) parent="$PWD/$parent";; esac
  fi
  parent=${parent%/}; parent=${parent%/.}
  local target="$parent/$branch"
  [ -e "$target" ] && die "target exists: $target"
  # ignore: only when target is inside the repo
  case "$(canon "$parent")/" in "$(canon "$R")/"*)
    if ! git -C "$R" check-ignore -q --no-index -- "$target/.probe"; then
      local ex rel; ex=$(git -C "$R" rev-parse --path-format=absolute --git-path info/exclude)
      rel=$(canon "$parent"); rel=${rel#"$(canon "$R")"}; rel="${rel%/}/"
      mkdir -p -- "$(dirname -- "$ex")"; printf '%s\n' "$rel" >> "$ex"; out exclude_added "$rel"
      git -C "$R" check-ignore -q --no-index -- "$target/.probe" || die "target still not ignored: $target"
    fi;; esac
  if [ -z "$base" ]; then
    if [ "$fetch" = 1 ]; then
      if git -C "$R" fetch -q origin master 2>/dev/null; then base=origin/master
      elif git -C "$R" fetch -q origin main 2>/dev/null; then base=origin/main
      else die "fetch origin master/main failed in $R"; fi
    else
      for b in origin/master origin/main; do git -C "$R" rev-parse -q --verify "$b^{commit}" >/dev/null && { base=$b; break; }; done
      [ -n "$base" ] || die "no origin/master or origin/main"
    fi
  else
    [ "$fetch" = 1 ] && case $base in origin/*) git -C "$R" fetch -q origin "${base#origin/}" || die "fetch failed: $base";; esac
    git -C "$R" rev-parse -q --verify "$base^{commit}" >/dev/null || die "base not found: $base"
  fi
  mkdir -p -- "$parent"
  git -C "$R" worktree add -q -b "$branch" -- "$target" "$base" >&2 || die "git worktree add failed"
  out base "$base"; out parent_source "$psrc"
  verify_wt "$target" "$code"
}

is_registered() { # repo path -> 0 if path still listed as worktree
  local want; want=$(canon "$2")
  git -C "$1" worktree list --porcelain | while IFS= read -r l; do
    case $l in "worktree "*) [ "$(canon "${l#worktree }")" = "$want" ] && { echo y; break; };; esac
  done | grep -q y
}

# remove: exit 0 = fully removed; exit 3 = unregistered but files left (residue), non-fatal.
remove() {
  local wt=$1 code=$2 force=${3:-}
  verify_wt "$wt" "$code" >/dev/null
  local w; w=$(to_native "$wt")
  if [ "$force" != --force ] && [ -n "$(git -C "$w" status --porcelain)" ]; then die "worktree has uncommitted changes: $wt"; fi
  local admin=""; [ -f "$w/.git" ] && admin=$(sed -n 's/^gitdir: //p' "$w/.git")
  # single attempt, no retries
  git -C "$SOURCE_ROOT" worktree remove ${force:+--force} -- "$w" >&2 || true
  git -C "$SOURCE_ROOT" worktree prune >&2 || true
  if [ ! -e "$w" ]; then
    is_registered "$SOURCE_ROOT" "$w" && die "directory gone but still registered: $wt"
    out status removed; out worktree "$wt"; return 0
  fi
  # residue: make sure git metadata is gone (only the admin dir under <common>/worktrees/)
  if is_registered "$SOURCE_ROOT" "$w"; then
    [ -n "$admin" ] || die "remove failed and worktree still registered: $wt"
    case "$(canon "$admin")/" in "$(canon "$SOURCE_COMMON")/worktrees/"*) ;; *) die "unexpected admin dir: $admin";; esac
    rm -rf -- "$admin"; git -C "$SOURCE_ROOT" worktree prune >&2 || true
    is_registered "$SOURCE_ROOT" "$w" && die "remove failed and worktree still registered: $wt"
  fi
  local r=$w; [ "$IS_WIN" = 1 ] && r=$(cygpath -m -- "$w")
  out status removed_with_residue; out residue "$r"
  out note "leftover files not handled; close programs holding them and delete manually later"
  exit 3
}

cmd=${1:-}; shift || true
case $cmd in
  where) [ "$IS_WIN" = 1 ] && { SKILL_DIR=$(cygpath -m -- "$SKILL_DIR"); SCRIPT_DIR=$(cygpath -m -- "$SCRIPT_DIR"); }
         out skill_dir "$SKILL_DIR"; out script_sh "$SCRIPT_DIR/worktree.sh"; out script_ps1 "$SCRIPT_DIR/worktree.ps1";;
  locate) [ $# -eq 1 ] || die "usage: locate <code-path>"; locate "$1";;
  create) [ $# -ge 2 ] || die "usage: create <code-path> <branch> [--base ref] [--parent dir] [--no-fetch]"; create "$@";;
  verify) [ $# -eq 2 ] || die "usage: verify <worktree> <code-path>"; verify_wt "$1" "$2";;
  remove) [ $# -ge 2 ] || die "usage: remove <worktree> <code-path> [--force]"; remove "$@";;
  *) die "usage: worktree.sh {where|locate|create|verify|remove} ...";;
esac
