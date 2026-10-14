# packages/uml_quality/probe_config.ps1 -- uml-quality.json probe for #93.
# Validates the repository config with the adjacent uml-viewer's own reader and
# scope adapter (no local re-implementation), then prints the dispatch branch
# uml-command.ps1 would take. Read-only: no tool is started, nothing is written.
param([string]$Root, [string]$Scripts)
$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $Scripts 'uml-quality-config.ps1')
    . (Join-Path $Scripts 'uml-standard-quality.ps1')
    $config = Read-UmlQualityConfig $Root
    if ($null -eq $config) { throw "uml-quality.json is missing under $Root" }
    # Same precedence as uml-command.ps1: operations > standardTools > Clojure alias
    # (the alias route needs deps.edn and no standardTools).
    if ($config.ContainsKey('operations')) { throw 'operations is declared; the uml entry supports standardTools only.' }
    if (-not $config.ContainsKey('standardTools')) { throw 'standardTools is required.' }
    if (Test-Path -LiteralPath (Join-Path $Root 'deps.edn')) { Write-Output 'note=deps.edn present; standardTools still wins' }
    Write-Output 'dispatch=standardTools'
    foreach ($path in @(Get-UmlBusinessRoots $Root $config.standardTools)) { Write-Output "sourceRoot=$path" }
    $targets = @(Select-UmlMutationTargets $Root $config.standardTools @())
    Write-Output "mutateTargets=$($targets.Count)"
    exit 0
} catch { [Console]::Error.WriteLine("uml-quality.json: $_"); exit 1 }
