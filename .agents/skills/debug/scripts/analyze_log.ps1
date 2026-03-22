param(
    [string]$Platform = "auto",
    [string]$TargetPath,
    [string]$LogPath,
    [int]$TailLines = 120,
    [int]$ContextLines = 4,
    [int]$MaxMatches = 8
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Resolve-HomeDir {
    if (-not [string]::IsNullOrWhiteSpace($env:HOME)) {
        return $env:HOME
    }
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        return $env:USERPROFILE
    }
    throw "HOME and USERPROFILE are both empty."
}

function Resolve-AbsolutePath {
    param([string]$PathText)

    if ([string]::IsNullOrWhiteSpace($PathText)) {
        return ""
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($PathText)
    if ($expanded.StartsWith("~/") -or $expanded.StartsWith("~\")) {
        $expanded = Join-Path (Resolve-HomeDir) $expanded.Substring(2)
    }

    if (-not [System.IO.Path]::IsPathRooted($expanded)) {
        $expanded = Join-Path (Get-Location).Path $expanded
    }

    return [System.IO.Path]::GetFullPath($expanded)
}

function Resolve-PlatformName {
    param([string]$RawPlatform)

    $value = ([string]$RawPlatform).Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($value) -or $value -eq "auto") {
        if ($IsWindows) {
            return "win"
        }
        if ($IsMacOS) {
            return "mac"
        }
        throw "Platform is not supported. Pass -Platform win or -Platform mac."
    }

    switch ($value) {
        "win" { return "win" }
        "windows" { return "win" }
        "mac" { return "mac" }
        "macos" { return "mac" }
        default { throw "Unsupported platform '$RawPlatform'. Use win or mac." }
    }
}

function Resolve-DefaultTargetPath {
    param([string]$ResolvedPlatform)

    if (-not [string]::IsNullOrWhiteSpace($env:MONOPOLY_DEPLOY_TARGET)) {
        return Resolve-AbsolutePath $env:MONOPOLY_DEPLOY_TARGET
    }

    $home_dir = Resolve-HomeDir
    switch ($ResolvedPlatform) {
        "win" { return (Join-Path (Join-Path (Join-Path $home_dir "Desktop") "dev") "LuaSource_大富翁-发布") }
        "mac" { return (Join-Path (Join-Path (Join-Path $home_dir "Documents") "eggy") "LuaSource_大富翁-发布") }
        default { throw "Unsupported platform '$ResolvedPlatform'." }
    }
}

function Resolve-LogFilePath {
    param(
        [string]$ResolvedPlatform,
        [string]$RawTargetPath,
        [string]$RawLogPath
    )

    if (-not [string]::IsNullOrWhiteSpace($RawLogPath)) {
        return Resolve-AbsolutePath $RawLogPath
    }

    if (-not [string]::IsNullOrWhiteSpace($RawTargetPath)) {
        return Join-Path (Resolve-AbsolutePath $RawTargetPath) "log.txt"
    }

    return Join-Path (Resolve-DefaultTargetPath $ResolvedPlatform) "log.txt"
}

function Get-MatchRule {
    param([string]$LineText)

    $rules = @(
        @{ name = "stack_traceback"; pattern = "stack traceback|traceback"; rank = 100 },
        @{ name = "error"; pattern = "\[error\]|\berror\b"; rank = 90 },
        @{ name = "attempt"; pattern = "attempt to"; rank = 85 },
        @{ name = "nil_value"; pattern = "nil value"; rank = 80 },
        @{ name = "exception"; pattern = "exception"; rank = 75 },
        @{ name = "failed"; pattern = "\bfailed\b|\bfailure\b"; rank = 70 },
        @{ name = "panic"; pattern = "\bpanic\b"; rank = 65 },
        @{ name = "warn"; pattern = "\[warn\]|\bwarning\b|\bwarn\b"; rank = 40 }
    )

    foreach ($rule in $rules) {
        if ($LineText -match $rule.pattern) {
            return $rule
        }
    }

    return $null
}

function Get-UniqueMatchKey {
    param([string]$LineText)

    $normalized = $LineText
    $normalized = $normalized -replace '^\[[^\]]+\]\s+\[[^\]]+\]\s*', ''
    $normalized = $normalized -replace '"', ''
    $normalized = $normalized -replace '\d{2}:\d{2}:\d{2}', '<time>'
    return $normalized.Trim()
}

function Write-ContextBlock {
    param(
        [string[]]$Lines,
        [int]$CenterLineNumber,
        [int]$Radius
    )

    $start = [Math]::Max(1, $CenterLineNumber - $Radius)
    $end = [Math]::Min($Lines.Count, $CenterLineNumber + $Radius)
    for ($line_number = $start; $line_number -le $end; $line_number += 1) {
        $prefix = " "
        if ($line_number -eq $CenterLineNumber) {
            $prefix = ">"
        }
        Write-Output ("{0} {1,5} | {2}" -f $prefix, $line_number, $Lines[$line_number - 1])
    }
}

$resolved_platform = Resolve-PlatformName $Platform
$log_file_path = Resolve-LogFilePath -ResolvedPlatform $resolved_platform -RawTargetPath $TargetPath -RawLogPath $LogPath

if (-not (Test-Path -LiteralPath $log_file_path -PathType Leaf)) {
    throw "log.txt not found: $log_file_path"
}

$log_item = Get-Item -LiteralPath $log_file_path
$lines = Get-Content -LiteralPath $log_file_path -Encoding UTF8
$total_lines = $lines.Count
$tail_start = [Math]::Max(1, $total_lines - $TailLines + 1)

$matches = New-Object System.Collections.Generic.List[object]
$seen_keys = New-Object System.Collections.Generic.HashSet[string]

for ($index = 0; $index -lt $lines.Count; $index += 1) {
    $line_text = [string]$lines[$index]
    $rule = Get-MatchRule $line_text
    if ($null -eq $rule) {
        continue
    }

    $unique_key = Get-UniqueMatchKey $line_text
    if ($seen_keys.Contains($unique_key)) {
        continue
    }

    [void]$seen_keys.Add($unique_key)
    $matches.Add([pscustomobject]@{
        line_number = $index + 1
        kind = $rule.name
        rank = $rule.rank
        text = $line_text
    })
}

$top_matches = $matches |
    Sort-Object @{ Expression = "rank"; Descending = $true }, @{ Expression = "line_number"; Descending = $true } |
    Select-Object -First $MaxMatches

Write-Output ("LOG_PATH: {0}" -f $log_item.FullName)
Write-Output ("PLATFORM: {0}" -f $resolved_platform)
Write-Output ("LAST_WRITE_TIME: {0:yyyy-MM-dd HH:mm:ss}" -f $log_item.LastWriteTime)
Write-Output ("SIZE_BYTES: {0}" -f $log_item.Length)
Write-Output ("TOTAL_LINES: {0}" -f $total_lines)
Write-Output ("MATCH_COUNT: {0}" -f $top_matches.Count)
Write-Output ""

if ($top_matches.Count -gt 0) {
    Write-Output "TOP_MATCHES:"
    foreach ($match in $top_matches) {
        Write-Output ("- line={0} kind={1} text={2}" -f $match.line_number, $match.kind, $match.text)
    }
    Write-Output ""

    $context_index = 1
    foreach ($match in $top_matches) {
        Write-Output ("CONTEXT {0}: line={1} kind={2}" -f $context_index, $match.line_number, $match.kind)
        Write-ContextBlock -Lines $lines -CenterLineNumber $match.line_number -Radius $ContextLines
        Write-Output ""
        $context_index += 1
    }
} else {
    Write-Output "TOP_MATCHES:"
    Write-Output "- none"
    Write-Output ""
}

Write-Output ("TAIL: start_line={0}" -f $tail_start)
for ($line_number = $tail_start; $line_number -le $total_lines; $line_number += 1) {
    Write-Output ("  {0,5} | {1}" -f $line_number, $lines[$line_number - 1])
}
