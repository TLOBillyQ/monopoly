# Resolve exactly the same scoped files as the upstream dispatcher.
param([string]$Root, [string]$Scripts, [string]$ArgsFile, [string]$OutFile)
$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $Scripts 'uml-quality-config.ps1')
    . (Join-Path $Scripts 'uml-standard-quality.ps1')
    $config = Read-UmlQualityConfig $Root
    if ($null -eq $config -or -not $config.ContainsKey('standardTools') -or $config.ContainsKey('operations')) {
        throw 'Independent mutation verification requires standardTools.'
    }
    $forward = @(Get-Content -LiteralPath $ArgsFile -Raw | ConvertFrom-Json)
    $resolved = @(Select-UmlMutationTargets $Root $config.standardTools $forward)
    # Selection puts all options (and their values) before the normalized files.
    $takesValue = @('--coverage-command','--test-command','--busted-task','--timeout-factor','--mutation-warning','--max-workers','--lines')
    $targets = @()
    for ($i = 0; $i -lt $resolved.Count; $i++) {
        if ($resolved[$i].StartsWith('-')) {
            if ($resolved[$i] -in $takesValue) { $i++ }
        } else { $targets += $resolved[$i] }
    }
    if ($targets.Count -eq 0) { throw 'No mutation targets selected.' }
    ConvertTo-Json -InputObject @($targets) -Compress | Set-Content -LiteralPath $OutFile -Encoding utf8
} catch { [Console]::Error.WriteLine("mutation target selection: $_"); exit 1 }
