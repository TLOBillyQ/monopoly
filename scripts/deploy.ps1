
<#
.SYNOPSIS
    将项目文件以软链方式部署到目标目录
.DESCRIPTION
    维护固定受控路径的链接关系：
    Config/、src/、vendor/、main.lua、Data/UIManagerNodes.lua、Data/Prefab.lua。
    当目标已有冲突文件/目录时，先自动备份到 .deploy_backup/<时间戳>/ 再替换为链接。
    Windows 下目录和文件均仅使用 SymbolicLink。
.PARAMETER TargetPath
    目标目录的绝对路径。Windows 未传入时默认同时部署到 LuaSource_monopoly 与 LuaSource_monopoly_1。
.PARAMETER DryRun
    只预览动作，不落盘修改
.EXAMPLE
    .\deploy.ps1 -TargetPath "C:\Target\Project"
.EXAMPLE
    .\deploy.ps1 -TargetPath "C:\Target\Project" -DryRun
#>

param(
    [Parameter(Mandatory=$false, HelpMessage="请输入目标目录的路径")]
    [string]$TargetPath,
    [switch]$DryRun
)

# 未传入时按平台选择默认路径
$TargetPaths = @()
if (-not $TargetPath) {
    if ($IsWindows) {
        $TargetPaths = @(
            "C:\\Users\\Lzx_8\\Desktop\\dev\\LuaSource_monopoly",
            "C:\\Users\\Lzx_8\\Desktop\\dev\\LuaSource_monopoly_1"
        )
    } elseif ($IsMacOS) {
        $TargetPaths = @("/Users/billyq/Documents/eggy/LuaSource_monopoly")
    } else {
        Write-Host "✗ 不支持的系统平台，请显式传入 -TargetPath" -ForegroundColor Red
        exit 1
    }
} else {
    $TargetPaths = @($TargetPath)
}

# 规范化目标路径（移除末尾斜杠，尽量解析完整路径；并去重）
$normalizedTargets = @()
foreach ($path in $TargetPaths) {
    $normalized = $path.TrimEnd("/").TrimEnd("\")
    if (Test-Path -LiteralPath $normalized) {
        $normalized = (Resolve-Path -LiteralPath $normalized).Path
    } else {
        $normalized = [System.IO.Path]::GetFullPath($normalized)
    }
    if (-not ($normalizedTargets -contains $normalized)) {
        $normalizedTargets += $normalized
    }
}
$TargetPaths = $normalizedTargets

# 获取脚本所在目录的上一级目录（项目根目录）
$ProjectRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))

function Get-NormalizedPath {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (Test-Path -LiteralPath $Path) {
        return (Resolve-Path -LiteralPath $Path).Path
    }
    return [System.IO.Path]::GetFullPath($Path)
}

function Paths-Equal {
    param(
        [Parameter(Mandatory=$true)][string]$Left,
        [Parameter(Mandatory=$true)][string]$Right
    )
    $a = [System.IO.Path]::GetFullPath($Left).TrimEnd('\', '/')
    $b = [System.IO.Path]::GetFullPath($Right).TrimEnd('\', '/')
    if ($IsWindows) {
        return [string]::Equals($a, $b, [System.StringComparison]::OrdinalIgnoreCase)
    }
    return [string]::Equals($a, $b, [System.StringComparison]::Ordinal)
}

function Ensure-Directory {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (Test-Path -LiteralPath $Path) {
        return
    }
    if ($DryRun) {
        Write-Host "[DryRun] 将创建目录: $Path" -ForegroundColor DarkYellow
        return
    }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Get-LinkTargetPath {
    param([Parameter(Mandatory=$true)]$Item)

    $target = $Item.Target
    if ($null -eq $target) {
        return $null
    }
    if ($target -is [array]) {
        if ($target.Count -eq 0) {
            return $null
        }
        $target = $target[0]
    }
    if ([string]::IsNullOrWhiteSpace($target)) {
        return $null
    }
    if (-not [System.IO.Path]::IsPathRooted($target)) {
        $target = Join-Path $Item.DirectoryName $target
    }
    return Get-NormalizedPath $target
}

function Is-SameLinkTarget {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$ExpectedTarget
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $item = Get-Item -LiteralPath $Path -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
        return $false
    }

    $actualTarget = Get-LinkTargetPath $item
    if (-not $actualTarget) {
        return $false
    }

    return (Paths-Equal -Left $actualTarget -Right $ExpectedTarget)
}

function New-ManagedLink {
    param(
        [Parameter(Mandatory=$true)][string]$SourcePath,
        [Parameter(Mandatory=$true)][string]$DestinationPath,
        [Parameter(Mandatory=$true)][bool]$IsDirectory
    )

    $parent = Split-Path -Parent $DestinationPath
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        Ensure-Directory $parent
    }

    if ($DryRun) {
        Write-Host "[DryRun] 将创建链接: $DestinationPath -> $SourcePath" -ForegroundColor DarkYellow
        return
    }

    try {
        New-Item -ItemType SymbolicLink -Path $DestinationPath -Target $SourcePath -ErrorAction Stop | Out-Null
    } catch {
        if ($IsWindows) {
            throw "创建软链失败: $DestinationPath -> $SourcePath。请确认已启用开发者模式或具备创建符号链接权限。原始错误: $($_.Exception.Message)"
        }
        throw
    }
}

function Move-ToBackup {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$RelativePath,
        [Parameter(Mandatory=$true)][string]$TargetRoot,
        [ref]$BackupRootRef
    )

    if (-not $BackupRootRef.Value) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $BackupRootRef.Value = Join-Path $TargetRoot ".deploy_backup\$timestamp"
        Ensure-Directory $BackupRootRef.Value
    }

    $backupPath = Join-Path $BackupRootRef.Value $RelativePath
    $backupDir = Split-Path -Parent $backupPath
    if (-not [string]::IsNullOrWhiteSpace($backupDir)) {
        Ensure-Directory $backupDir
    }

    if ($DryRun) {
        Write-Host "[DryRun] 将备份冲突项: $Path -> $backupPath" -ForegroundColor DarkYellow
        return
    }

    Move-Item -LiteralPath $Path -Destination $backupPath -Force
    Write-Host "  已备份: $Path -> $backupPath" -ForegroundColor Yellow
}

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "开始软链部署项目文件" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "项目根目录: $ProjectRoot" -ForegroundColor Yellow
Write-Host "目标目录数量: $($TargetPaths.Count)" -ForegroundColor Yellow
foreach ($target in $TargetPaths) {
    Write-Host "  - $target" -ForegroundColor Yellow
}
if ($DryRun) {
    Write-Host "模式: DryRun（只预览，不修改）" -ForegroundColor Yellow
}
Write-Host ""

# 固定受控映射（不可配置）
$Mappings = @(
    @{ Relative = "Config"; IsDirectory = $true },
    @{ Relative = "src"; IsDirectory = $true },
    @{ Relative = "vendor"; IsDirectory = $true },
    @{ Relative = "main.lua"; IsDirectory = $false },
    @{ Relative = "Data/UIManagerNodes.lua"; IsDirectory = $false },
    @{ Relative = "Data/Prefab.lua"; IsDirectory = $false }
)

# 预先检查源路径
foreach ($mapping in $Mappings) {
    $sourcePath = Get-NormalizedPath (Join-Path $ProjectRoot $mapping.Relative)
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        Write-Host "✗ 软链部署失败: 源路径不存在: $sourcePath" -ForegroundColor Red
        exit 1
    }
}

$totalCreated = 0
$totalReplaced = 0
$totalUnchanged = 0

foreach ($TargetPath in $TargetPaths) {
    Write-Host "--------------------------------------" -ForegroundColor Cyan
    Write-Host "部署目标: $TargetPath" -ForegroundColor Cyan
    Write-Host "--------------------------------------" -ForegroundColor Cyan

    # 检查目标目录是否存在，不存在则创建（DryRun 仅提示）
    if (-not (Test-Path -LiteralPath $TargetPath)) {
        if ($DryRun) {
            Write-Host "[DryRun] 目标目录不存在，将创建: $TargetPath" -ForegroundColor DarkYellow
        } else {
            Write-Host "目标目录不存在，正在创建..." -ForegroundColor Yellow
            New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
            Write-Host "✓ 目标目录创建成功" -ForegroundColor Green
        }
    }

    $createdCount = 0
    $replacedCount = 0
    $unchangedCount = 0
    $backupRoot = $null
    $backupRootRef = [ref]$backupRoot

    try {
        foreach ($mapping in $Mappings) {
            $relative = $mapping.Relative
            $isDirectory = [bool]$mapping.IsDirectory
            $sourcePath = Get-NormalizedPath (Join-Path $ProjectRoot $relative)
            $destPath = Get-NormalizedPath (Join-Path $TargetPath $relative)

            Write-Host "处理: $relative" -ForegroundColor Cyan
            Write-Host "  源: $sourcePath" -ForegroundColor Gray
            Write-Host "  目: $destPath" -ForegroundColor Gray

            if (-not (Test-Path -LiteralPath $destPath)) {
                New-ManagedLink -SourcePath $sourcePath -DestinationPath $destPath -IsDirectory $isDirectory
                $createdCount++
                if ($DryRun) {
                    Write-Host "✓ 预览：将创建链接" -ForegroundColor Green
                } else {
                    Write-Host "✓ 已创建链接" -ForegroundColor Green
                }
                continue
            }

            if (Is-SameLinkTarget -Path $destPath -ExpectedTarget $sourcePath) {
                $unchangedCount++
                Write-Host "✓ 已是目标链接，跳过" -ForegroundColor Green
                continue
            }

            Move-ToBackup -Path $destPath -RelativePath $relative -TargetRoot $TargetPath -BackupRootRef $backupRootRef
            New-ManagedLink -SourcePath $sourcePath -DestinationPath $destPath -IsDirectory $isDirectory
            $replacedCount++
            if ($DryRun) {
                Write-Host "✓ 预览：将替换为链接" -ForegroundColor Green
            } else {
                Write-Host "✓ 已替换为链接" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "✗ 软链部署失败（目标: $TargetPath）: $_" -ForegroundColor Red
        exit 1
    }

    $backupSummary = if ($backupRootRef.Value) { $backupRootRef.Value } else { "none" }
    $totalCreated += $createdCount
    $totalReplaced += $replacedCount
    $totalUnchanged += $unchangedCount

    Write-Host ""
    Write-Host "目标汇总: $TargetPath" -ForegroundColor Yellow
    Write-Host "created: $createdCount" -ForegroundColor Yellow
    Write-Host "replaced_with_backup: $replacedCount" -ForegroundColor Yellow
    Write-Host "unchanged: $unchangedCount" -ForegroundColor Yellow
    Write-Host "backup_root: $backupSummary" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "软链部署完成" -ForegroundColor Green
Write-Host "目标数: $($TargetPaths.Count)" -ForegroundColor Yellow
Write-Host "created(total): $totalCreated" -ForegroundColor Yellow
Write-Host "replaced_with_backup(total): $totalReplaced" -ForegroundColor Yellow
Write-Host "unchanged(total): $totalUnchanged" -ForegroundColor Yellow
Write-Host "======================================" -ForegroundColor Cyan
exit 0
