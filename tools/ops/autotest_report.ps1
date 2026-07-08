[CmdletBinding()]
param(
    [string]$LogPath,
    [string]$TargetPath,
    [switch]$Wait,
    [int]$TimeoutSeconds = 1800,
    [int]$PollSeconds = 2
)

# 解析 autotest 部署包运行后 log.txt 里的 [autotest] 结果行，输出汇总并以
# 退出码表达结果（0=全部通过 1=有失败/错误 2=未找到 autotest 输出）。
# 行格式契约由 src/app/testing/autotest_results.lua 定义、
# spec/behavior/app/autotest_results_spec.lua 钉住。

$ErrorActionPreference = "Stop"

function Test-IsWindowsHost {
    if ($env:OS -eq "Windows_NT") {
        return $true
    }
    return [System.IO.Path]::DirectorySeparatorChar -eq '\'
}

function Resolve-HomeDir {
    if (-not [string]::IsNullOrWhiteSpace($env:HOME)) {
        return $env:HOME
    }
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        return $env:USERPROFILE
    }
    return ""
}

function Join-LuaSourceDirName {
    return ("LuaSource_" + [string][char]0x5927 + [string][char]0x5BCC + [string][char]0x7FC1)
}

function Resolve-DefaultLogPath {
    $home_dir = Resolve-HomeDir
    if ([string]::IsNullOrWhiteSpace($home_dir)) {
        return ""
    }
    if (Test-IsWindowsHost) {
        return Join-Path (Join-Path (Join-Path (Join-Path $home_dir "Desktop") "dev") (Join-LuaSourceDirName)) "log.txt"
    }
    return Join-Path (Join-Path (Join-Path (Join-Path $home_dir "Documents") "eggy") (Join-LuaSourceDirName)) "log.txt"
}

function Resolve-LogPath {
    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
        return $LogPath
    }
    if (-not [string]::IsNullOrWhiteSpace($TargetPath)) {
        return Join-Path $TargetPath "log.txt"
    }
    return Resolve-DefaultLogPath
}

function Read-AutotestBlock {
    param([string]$PathText)

    if (-not (Test-Path -LiteralPath $PathText -PathType Leaf)) {
        return $null
    }
    $lines = Get-Content -LiteralPath $PathText -Encoding UTF8 |
        Where-Object { $_ -match "\[autotest\]" }
    if ($lines.Count -eq 0) {
        return $null
    }

    # 只取最后一个 begin 块，避免同一 log 里的历史批次干扰。
    $begin_index = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "\[autotest\] begin ") {
            $begin_index = $i
        }
    }
    if ($begin_index -ge 0) {
        return $lines[$begin_index..($lines.Count - 1)]
    }
    return $lines
}

function Get-SummaryLine {
    param([string[]]$BlockLines)
    foreach ($line in $BlockLines) {
        if ($line -match "\[autotest\] summary ") {
            return $line
        }
    }
    return $null
}

function Get-ErrorLine {
    param([string[]]$BlockLines)
    foreach ($line in $BlockLines) {
        if ($line -match "\[autotest\] error ") {
            return $line
        }
    }
    return $null
}

$resolved_log_path = Resolve-LogPath
if ([string]::IsNullOrWhiteSpace($resolved_log_path)) {
    [Console]::Error.WriteLine("ERROR: cannot resolve log path / 无法解析日志路径")
    exit 2
}

Write-Output ("Log: " + $resolved_log_path)

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$block = $null
while ($true) {
    $block = Read-AutotestBlock $resolved_log_path
    $finished = $false
    if ($block -ne $null) {
        if ((Get-SummaryLine $block) -ne $null -or (Get-ErrorLine $block) -ne $null) {
            $finished = $true
        }
    }
    if ($finished -or (-not $Wait)) {
        break
    }
    if ((Get-Date) -gt $deadline) {
        break
    }
    Start-Sleep -Seconds $PollSeconds
}

if ($block -eq $null) {
    [Console]::Error.WriteLine("ERROR: no [autotest] output found in log / 日志中没有 [autotest] 输出")
    exit 2
}

$error_line = Get-ErrorLine $block
if ($error_line -ne $null) {
    Write-Output $error_line
    [Console]::Error.WriteLine("ERROR: autotest reported a startup error / autotest 启动报错")
    exit 1
}

$fail_lines = @()
foreach ($line in $block) {
    if ($line -match "\[autotest\] (begin|profile|summary) ") {
        Write-Output ($line -replace "^.*\[autotest\]", "[autotest]")
        if ($line -match "\[autotest\] profile=.* result=fail ") {
            $fail_lines += $line
        }
    }
}

$summary_line = Get-SummaryLine $block
if ($summary_line -eq $null) {
    [Console]::Error.WriteLine("ERROR: autotest run has not finished (no summary) / autotest 尚未跑完（缺 summary 行）")
    exit 2
}

if ($summary_line -match " fail=(\d+)") {
    $fail_count = [int]$Matches[1]
    if ($fail_count -gt 0) {
        [Console]::Error.WriteLine("ERROR: " + $fail_count + " profile(s) failed / " + $fail_count + " 个 profile 失败")
        exit 1
    }
}

Write-Output "All profiles passed / 全部 profile 通过"
exit 0
