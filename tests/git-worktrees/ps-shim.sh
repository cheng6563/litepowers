#!/usr/bin/env bash
# translate bash-style flags to PS params, then run pwsh/powershell
PS=${PS:-pwsh}; S=${PS1_SCRIPT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../skills/git-worktrees/scripts" && pwd)/worktree.ps1}
a=(); for x in "$@"; do case $x in --base) a+=(-Base);; --parent) a+=(-Parent);; --no-fetch) a+=(-NoFetch);; --force) a+=(-Force);; *) a+=("$x");; esac; done
exec "$PS" -NoProfile -ExecutionPolicy Bypass -File "$S" "${a[@]}"
