#Requires -Version 5.1
# litepowers git-worktrees helper (Windows PowerShell 5.1 / PowerShell 7+). Call directly with the call operator:
#   & "$SKILL_DIR/scripts/worktree.ps1" where
# Do not nest it in another pwsh/powershell process.
# Usage:
#   worktree.ps1 where             (print own skill/script paths)
#   worktree.ps1 locate <code-path>
#   worktree.ps1 create <code-path> <branch> [-Base <ref>] [-Parent <dir>] [-NoFetch]
#   worktree.ps1 verify <worktree> <code-path>
#   worktree.ps1 remove <worktree> <code-path> [-Force]
# Output: key=value lines on stdout; "error=<msg>" on stderr, exit 1.
# Exit codes: 0 ok; 1 error; 3 remove: unregistered but leftover files (status=removed_with_residue).
param(
  [Parameter(Position=0)][string]$Cmd,
  [Parameter(Position=1)][string]$A1,
  [Parameter(Position=2)][string]$A2,
  [string]$Base, [string]$Parent, [switch]$NoFetch, [switch]$Force
)
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
# Runs inside the caller's session: save and restore anything global we touch.
$script:SavedConsoleEnc = [Console]::OutputEncoding
$script:SavedPrompt = $env:GIT_TERMINAL_PROMPT; $script:SavedGcm = $env:GCM_INTERACTIVE
[Console]::OutputEncoding = $utf8; $OutputEncoding = $utf8
$env:GIT_TERMINAL_PROMPT = '0'; $env:GCM_INTERACTIVE = 'never'   # never let git prompt
# Self-locate (no hard-coded paths): works via symlink/junction/copy.
$ScriptDir = $PSScriptRoot
$SkillDir = Split-Path -Parent $ScriptDir
$IsWin = ($env:OS -eq 'Windows_NT')

function Die([string]$m) { [Console]::Error.WriteLine("error=$m"); exit 1 }
function Out([string]$k, [string]$v) { Write-Output "$k=$v" }
# Keep git failures non-terminating; callers check $LASTEXITCODE.
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
  # location precedence: -Parent > $env:LITEPOWERS_WORKTREE_DIR > git config litepowers.worktreeDir (project) > .worktrees
  if ($Parent) { $par = $Parent; if (-not [IO.Path]::IsPathRooted($par)) { $par = Join-Path (Get-Location).ProviderPath $par }; $par = [IO.Path]::GetFullPath($par); $psrc = 'arg' }
  else {
    $cfg = G -C $R config --get litepowers.worktreeDir
    if ($env:LITEPOWERS_WORKTREE_DIR) { $par = $env:LITEPOWERS_WORKTREE_DIR; $psrc = 'env' }
    elseif ($cfg) { $par = $cfg; $psrc = 'project' }
    else { $par = '.worktrees'; $psrc = 'default' }
    if (-not [IO.Path]::IsPathRooted($par)) { $par = Join-Path $R $par }
    $par = [IO.Path]::GetFullPath($par)
  }
  $par = $par.TrimEnd('\','/')
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
  Out base $b; Out parent_source $psrc
  VerifyWt $target $code
}

function IsRegistered([string]$repo, [string]$path) {
  $want = Canon $path
  foreach ($l in @((G -C $repo worktree list --porcelain) -split "`n")) {
    if ($l.StartsWith('worktree ') -and (Canon $l.Substring(9)) -eq $want) { return $true }
  }
  return $false
}

# remove: exit 0 = fully removed; exit 3 = unregistered but files left (residue), non-fatal.
function Remove([string]$wt, [string]$code) {
  VerifyWt $wt $code $false
  $dirty = G -C $wt status --porcelain
  if ($dirty -and -not $Force) { Die "worktree has uncommitted changes: $wt" }
  $ErrorActionPreference = 'Continue'
  $full = [IO.Path]::GetFullPath($wt)
  $admin = $null; $gf = Join-Path $full '.git'
  if (Test-Path -LiteralPath $gf -PathType Leaf) { $m = [regex]::Match([IO.File]::ReadAllText($gf), '^gitdir:\s*(.+?)\s*$', 'Multiline'); if ($m.Success) { $admin = $m.Groups[1].Value } }
  # single attempt, no retries
  if ($Force) { & git -C $script:SourceRoot worktree remove --force -- $full 2>&1 | ForEach-Object { [Console]::Error.WriteLine("$_") } }
  else { & git -C $script:SourceRoot worktree remove -- $full 2>&1 | ForEach-Object { [Console]::Error.WriteLine("$_") } }
  $null = GOk -C $script:SourceRoot worktree prune
  if (-not (Test-Path -LiteralPath $full)) {
    if (IsRegistered $script:SourceRoot $full) { Die "directory gone but still registered: $wt" }
    Out status removed; Out worktree $wt; exit 0
  }
  if (IsRegistered $script:SourceRoot $full) {
    if (-not $admin) { Die "remove failed and worktree still registered: $wt" }
    if (-not (Canon $admin).StartsWith((Canon $script:SourceCommon) + '/worktrees/') -and -not (Canon $admin).StartsWith((Canon $script:SourceCommon) + '\worktrees\')) { Die "unexpected admin dir: $admin" }
    Remove-Item -LiteralPath $admin -Recurse -Force -ErrorAction SilentlyContinue
    $null = GOk -C $script:SourceRoot worktree prune
    if (IsRegistered $script:SourceRoot $full) { Die "remove failed and worktree still registered: $wt" }
  }
  $r = $full; if ($IsWin) { $r = $r.Replace('\','/') }
  Out status removed_with_residue; Out residue $r
  Out note 'leftover files not handled; close programs holding them and delete manually later'
  exit 3
}

try {
switch ($Cmd) {
  'where'  { Out skill_dir $SkillDir; Out script_sh (Join-Path $ScriptDir 'worktree.sh'); Out script_ps1 (Join-Path $ScriptDir 'worktree.ps1') }
  'locate' { if (-not $A1) { Die 'usage: locate <code-path>' }; Locate $A1 }
  'create' { if (-not $A2) { Die 'usage: create <code-path> <branch> [-Base ref] [-Parent dir] [-NoFetch]' }; Create $A1 $A2 }
  'verify' { if (-not $A2) { Die 'usage: verify <worktree> <code-path>' }; VerifyWt $A1 $A2 }
  'remove' { if (-not $A2) { Die 'usage: remove <worktree> <code-path> [-Force]' }; Remove $A1 $A2 }
  default  { Die 'usage: worktree.ps1 {where|locate|create|verify|remove} ...' }
}
} finally {
  [Console]::OutputEncoding = $script:SavedConsoleEnc
  $env:GIT_TERMINAL_PROMPT = $script:SavedPrompt; $env:GCM_INTERACTIVE = $script:SavedGcm
}
exit 0
