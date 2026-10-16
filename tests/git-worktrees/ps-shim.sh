#!/usr/bin/env bash
# Test harness only: the bash runner needs one PowerShell host per call. Inside that host
# the script is invoked the same way agents must invoke it: `& <worktree.ps1> <args>`.
S=${PS1_SCRIPT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../skills/git-worktrees/scripts" && pwd)/worktree.ps1}
PS_HOST=${WT_POWERSHELL:-pwsh}
case "$(uname -s)" in MSYS*|MINGW*|CYGWIN*) S=$(cygpath -m "$S");; esac
a=(); for x in "$@"; do case $x in --base) a+=(-Base);; --parent) a+=(-Parent);; --no-fetch) a+=(-NoFetch);; --force) a+=(-Force);; *) a+=("$x");; esac; done
WT_ARGS=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' "${a[@]}") WT_S="$S" \
exec "$PS_HOST" -NoProfile -NonInteractive -Command '$pos = @(); $named = @{}; $a = @(ConvertFrom-Json $env:WT_ARGS)
for ($i = 0; $i -lt $a.Count; $i++) {
  if ($a[$i] -in "-Force","-NoFetch") { $named[$a[$i].Substring(1)] = $true }
  elseif ($a[$i] -in "-Base","-Parent") { $k = $a[$i].Substring(1); $i++; $named[$k] = $a[$i] }
  else { $pos += $a[$i] } }
$global:LASTEXITCODE = 0
switch ($pos.Count) { 1 { & $env:WT_S $pos[0] @named } 2 { & $env:WT_S $pos[0] $pos[1] @named } default { & $env:WT_S $pos[0] $pos[1] $pos[2] @named } }
$ok = $?
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; if (-not $ok) { exit 1 }; exit 0'
