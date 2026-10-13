# litepowers git-worktrees helper (Windows PowerShell 5.1 / pwsh 7). UTF-8 with BOM for PS 5.1.
# Usage:
#   worktree.ps1 where             (print own skill/script paths)
#   worktree.ps1 locate <code-path>
#   worktree.ps1 create <code-path> <branch> [-Base <ref>] [-Parent <dir>] [-NoFetch]
#   worktree.ps1 verify <worktree> <code-path>
#   worktree.ps1 remove <worktree> <code-path> [-Force]
# Output: key=value lines on stdout; "error=<msg>" on stderr, exit 1.
param(
  [Parameter(Position=0)][string]$Cmd,
  [Parameter(Position=1)][string]$A1,
  [Parameter(Position=2)][string]$A2,
  [string]$Base, [string]$Parent, [switch]$NoFetch, [switch]$Force
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8; $OutputEncoding = $utf8
# Self-locate (no hard-coded paths): works via symlink/junction/copy.
$ScriptDir = $PSScriptRoot
$SkillDir = Split-Path -Parent $ScriptDir
$IsWin = ($env:OS -eq 'Windows_NT')

function Die([string]$m) { [Console]::Error.WriteLine("error=$m"); exit 1 }
function Out([string]$k, [string]$v) { [Console]::Out.WriteLine("$k=$v") }
# PS 5.1 quirk: with ErrorActionPreference=Stop, native stderr becomes a terminating
# NativeCommandError even when redirected; relax it locally around git calls.
function G { # run git, return trimmed stdout or $null on failure
  $ErrorActionPreference = 'Continue'
  $o = & git @args 2>$null
  if ($LASTEXITCODE -ne 0) { return $null }
  if ($null -eq $o) { return '' }
  return (@($o) -join "`n").Trim()
}
function GOk { $ErrorActionPreference = 'Continue'; & git @args *> $null; return ($LASTEXITCODE -eq 0) }
function Canon([string]$p) {
  $full = [IO.Path]::GetFullPath(($p -replace '/', [IO.Path]::DirectorySeparatorChar))
  $full = $full.TrimEnd('\','/')
  if ($IsWin) { $full = $full.Replace('\','/').ToLowerInvariant() }
  return $full
}
function ExistingDir([string]$p) {
  $s = [IO.Path]::GetFullPath($p)
  while (-not (Test-Path -LiteralPath $s -PathType Container)) {
    $n = [IO.Path]::GetDirectoryName($s)
    if ([string]::IsNullOrEmpty($n) -or $n -eq $s) { Die "no existing ancestor for: $p" }
    $s = $n
  }
  return $s
}
function CommonDir([string]$d) { G -C $d rev-parse --path-format=absolute --git-common-dir }
function MainRoot([string]$d) {
  $c = CommonDir $d; if ($null -eq $c) { return $null }
  $r = G -C (Join-Path $c '..') rev-parse --show-toplevel
  if ($r) { return $r }
  return [IO.Path]::GetDirectoryName($c.TrimEnd('/','\'))
}

$script:SourceRoot = $null; $script:SourceCommon = $null
function Locate([string]$p, [bool]$print = $true) {
  $start = ExistingDir $p
  $top = G -C $start rev-parse --show-toplevel
  if (-not $top) { Die "not inside a git repo: $p" }
  $script:SourceCommon = CommonDir $start
  $script:SourceRoot = MainRoot $start
  if (-not $print) { return }
  $outer = G -C ([IO.Path]::GetDirectoryName(([IO.Path]::GetFullPath($script:SourceRoot)).TrimEnd('\','/'))) rev-parse --show-toplevel
  Out source_root $script:SourceRoot; Out code_toplevel $top; Out common_dir $script:SourceCommon
  if ((Canon $top) -eq (Canon $script:SourceRoot)) { Out in_worktree no } else { Out in_worktree yes }
  Out outer_repo "$outer"
  $sess = MainRoot (Get-Location).ProviderPath
  Out session_root "$sess"
  if ($sess -and (Canon $sess) -eq (Canon $script:SourceRoot)) { Out session_matches yes } else { Out session_matches no }
}

function VerifyWt([string]$wt, [string]$code, [bool]$print = $true) {
  if (-not (Test-Path -LiteralPath $wt -PathType Container)) { Die "worktree path missing: $wt" }
  Locate $code $false
  $a = CommonDir $wt; if (-not $a) { Die "not a git dir: $wt" }
  $wtop = G -C $wt rev-parse --show-toplevel
  if ((Canon $a) -ne (Canon $script:SourceCommon)) { Die "worktree belongs to wrong repo: worktree=$wtop common=$a expected=$($script:SourceCommon)" }
  if ((Canon $wtop) -eq (Canon $script:SourceRoot)) { Die "path is the main checkout, not a worktree: $wtop" }
  if ($print) {
    Out status ok; Out worktree $wtop; Out source_root $script:SourceRoot
    Out branch (G -C $wt branch --show-current); Out head (G -C $wt rev-parse HEAD)
  }
}

function Create([string]$code, [string]$branch) {
  if (-not (GOk check-ref-format --branch $branch)) { Die "invalid branch name: $branch" }
  Locate $code $false
  $R = $script:SourceRoot
  if (GOk -C $R show-ref --verify --quiet "refs/heads/$branch") { Die "branch already exists: $branch" }
  if ($Parent) { $par = [IO.Path]::GetFullPath($Parent) } else { $par = Join-Path $R '.claude/worktrees' }
  $target = [IO.Path]::GetFullPath((Join-Path $par $branch))
  if (Test-Path -LiteralPath $target) { Die "target exists: $target" }
  $cr = Canon $R; $cp = Canon $par
  if ($cp.StartsWith($cr + '/') -or $cp.StartsWith($cr + '\')) {
    $probe = (Join-Path $target '.probe')
    if (-not (GOk -C $R check-ignore -q --no-index -- $probe)) {
      $ex = G -C $R rev-parse --path-format=absolute --git-path info/exclude
      $rel = '/' + ($cp.Substring($cr.Length).Trim('/','\') -replace '\\','/') + '/'
      $exDir = [IO.Path]::GetDirectoryName($ex); if (-not (Test-Path -LiteralPath $exDir)) { New-Item -ItemType Directory -Path $exDir | Out-Null }
      [IO.File]::AppendAllText($ex, "$rel`n", $utf8)
      Out exclude_added $rel
      if (-not (GOk -C $R check-ignore -q --no-index -- $probe)) { Die "target still not ignored: $target" }
    }
  }
  $b = $Base
  if (-not $b) {
    if (-not $NoFetch) {
      if (GOk -C $R fetch -q origin master) { $b = 'origin/master' }
      elseif (GOk -C $R fetch -q origin main) { $b = 'origin/main' }
      else { Die "fetch origin master/main failed in $R" }
    } else {
      foreach ($c in 'origin/master','origin/main') { if (GOk -C $R rev-parse -q --verify "$c^{commit}") { $b = $c; break } }
      if (-not $b) { Die 'no origin/master or origin/main' }
    }
  } else {
    if (-not $NoFetch -and $b.StartsWith('origin/')) { if (-not (GOk -C $R fetch -q origin $b.Substring(7))) { Die "fetch failed: $b" } }
    if (-not (GOk -C $R rev-parse -q --verify "$b^{commit}")) { Die "base not found: $b" }
  }
  New-Item -ItemType Directory -Force -Path $par | Out-Null
  $ErrorActionPreference = 'Continue'
  & git -C $R worktree add -q -b $branch -- $target $b 2>&1 | ForEach-Object { [Console]::Error.WriteLine("$_") }
  if ($LASTEXITCODE -ne 0) { Die 'git worktree add failed' }
  Out base $b
  VerifyWt $target $code
}

function FindRecycler {
  if ($env:LITEPOWERS_RECYCLE -and (Test-Path -LiteralPath $env:LITEPOWERS_RECYCLE)) { return $env:LITEPOWERS_RECYCLE }
  $c = Get-Command rm_win.exe, rm_win -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($c) { return $c.Source }
  return $null
}

function Remove([string]$wt, [string]$code) {
  VerifyWt $wt $code $false
  $dirty = G -C $wt status --porcelain
  if ($dirty -and -not $Force) { Die "worktree has uncommitted changes: $wt" }
  $ErrorActionPreference = 'Continue'
  $rec = FindRecycler
  if ($rec) {
    # reversible: move directory to Recycle Bin, then let git drop the stale registration
    & $rec $wt
    if ($LASTEXITCODE -ne 0 -or (Test-Path -LiteralPath $wt)) { Die "recycle failed: $wt" }
    if (-not (GOk -C $script:SourceRoot worktree prune)) { Die 'worktree prune failed' }
    Out method recycle
  } else {
    if ($Force) { & git -C $script:SourceRoot worktree remove --force -- $wt } else { & git -C $script:SourceRoot worktree remove -- $wt }
    if ($LASTEXITCODE -ne 0) { Die 'worktree remove failed' }
    Out method git
  }
  Out status removed; Out worktree $wt
}

switch ($Cmd) {
  'where'  { Out skill_dir $SkillDir; Out script_sh (Join-Path $ScriptDir 'worktree.sh'); Out script_ps1 (Join-Path $ScriptDir 'worktree.ps1') }
  'locate' { if (-not $A1) { Die 'usage: locate <code-path>' }; Locate $A1 }
  'create' { if (-not $A2) { Die 'usage: create <code-path> <branch> [-Base ref] [-Parent dir] [-NoFetch]' }; Create $A1 $A2 }
  'verify' { if (-not $A2) { Die 'usage: verify <worktree> <code-path>' }; VerifyWt $A1 $A2 }
  'remove' { if (-not $A2) { Die 'usage: remove <worktree> <code-path> [-Force]' }; Remove $A1 $A2 }
  default  { Die 'usage: worktree.ps1 {where|locate|create|verify|remove} ...' }
}
exit 0
