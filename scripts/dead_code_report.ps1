param(
  [string]$Root = (Get-Location).Path,
  [string]$Entry = "main.lua"
)

Set-StrictMode -Version Latest

function NormPath([string]$p) {
  if (-not $p) { return $p }
  try {
    return ([System.IO.Path]::GetFullPath($p)).ToLowerInvariant()
  } catch {
    return $p.ToLowerInvariant()
  }
}

function Resolve-ModToPaths([string]$mod, [string]$root) {
  # Lua module name to workspace-relative file paths.
  $rel = ($mod -replace '\.','\\')
  return @(
    (Join-Path $root ($rel + '.lua')),
    (Join-Path $root ($rel + '\\init.lua'))
  )
}

$rootFull = [System.IO.Path]::GetFullPath($Root)
$entryFull = Join-Path $rootFull $Entry
if (-not (Test-Path $entryFull)) {
  throw "Entry file not found: $entryFull"
}

# Collect all .lua user files.
$allLua = Get-ChildItem -Recurse -Path $rootFull -Filter *.lua -File | ForEach-Object { $_.FullName }

# Build requires map.
$requiresByFile = @{}
$requirePattern = 'require\s*\(\s*(["\''])([^"\'']+)\1\s*\)'
foreach ($f in $allLua) {
  $mods = New-Object System.Collections.Generic.List[string]
  $matches = Select-String -Path $f -Pattern $requirePattern -AllMatches -ErrorAction SilentlyContinue
  foreach ($m in $matches) {
    foreach ($mm in $m.Matches) {
      $mods.Add($mm.Groups[2].Value)
    }
  }
  $requiresByFile[(NormPath $f)] = $mods
}

# BFS from entry.
$queue = New-Object System.Collections.Generic.Queue[string]
$reachable = New-Object System.Collections.Generic.HashSet[string]
$queue.Enqueue((NormPath $entryFull)) | Out-Null

while ($queue.Count -gt 0) {
  $cur = $queue.Dequeue()
  if (-not $reachable.Add($cur)) { continue }

  $mods = $requiresByFile[$cur]
  if (-not $mods) { continue }

  foreach ($mod in $mods) {
    foreach ($p in (Resolve-ModToPaths $mod $rootFull)) {
      if (Test-Path $p) {
        $queue.Enqueue((NormPath $p)) | Out-Null
      }
    }
  }
}

# Report unreachable under src/
$srcRoot = Join-Path $rootFull 'src'
$srcLua = Get-ChildItem -Recurse -Path $srcRoot -Filter *.lua -File | ForEach-Object { NormPath $_.FullName }
$unreach = @($srcLua | Where-Object { -not $reachable.Contains($_) } | Sort-Object)

Write-Host "Reachable files: $($reachable.Count)"
Write-Host "Unreachable under src/: $($unreach.Count)"
$unreach | ForEach-Object {
  $p = $_
  if ($p.StartsWith((NormPath $rootFull) + "\\")) {
    $p = $p.Substring((NormPath $rootFull).Length + 1)
  }
  Write-Output $p
}
