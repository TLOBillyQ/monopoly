
<#
.SYNOPSIS
    将项目文件部署到目标目录
.DESCRIPTION
    该脚本要求在 PowerShell 7 (pwsh) 环境执行。
    默认拷贝 Config/、src/ 目录以及 Data/UIManagerNodes.lua、Data/Prefab.lua 和 main.lua 到目标目录。
    如需额外拷贝 vendor/，请传入 -IncludeVendor 参数。
.PARAMETER TargetPath
    目标目录的绝对路径
.PARAMETER IncludeVendor
    是否额外拷贝 vendor/ 目录（默认不拷贝）
.PARAMETER StartupProfile
    启动时注入的测试 profile 名（写入 main.lua 的 STARTUP_TEST_PROFILE）
.PARAMETER AllowReleaseTestProfile
    release 模式下允许注入 STARTUP_TEST_PROFILE（会额外写入 RELEASE_ALLOW_TEST_PROFILE=true）
.PARAMETER Mode
    部署模式：dev 或 release（默认 dev）。release 模式会注入 RELEASE_BUILD=true。
.PARAMETER MuteLuaTips
    注入 EGGY_MUTE_LUA_TIPS=true，静音 Lua 侧 show_tips（用于二分定位引擎侧气泡）。
.EXAMPLE
    pwsh -File .\deploy.ps1 -TargetPath "C:\Target\Project"
.EXAMPLE
    pwsh -File .\deploy.ps1 -TargetPath "C:\Target\Project" -IncludeVendor
.EXAMPLE
    pwsh -File .\deploy.ps1 -StartupProfile "items_move_control"
.EXAMPLE
    pwsh -File .\deploy.ps1 -Mode release
.EXAMPLE
    pwsh -File .\deploy.ps1 -Mode release -AllowReleaseTestProfile -StartupProfile "items_target_disrupt"
.EXAMPLE
    pwsh -File .\deploy.ps1 -Mode release -AllowReleaseTestProfile -StartupProfile "items_move_control" -MuteLuaTips
#>

param(
    [Parameter(Mandatory=$false, HelpMessage="请输入目标目录的路径")]
    [string]$TargetPath,
    [switch]$IncludeVendor,
    [string]$StartupProfile,
    [switch]$AllowReleaseTestProfile,
    [switch]$MuteLuaTips,
    [ValidateSet("dev", "release")]
    [string]$Mode = "dev"
)

function Test-Pwsh7 {
    $edition = $PSVersionTable.PSEdition
    $major = $PSVersionTable.PSVersion.Major
    return ($edition -eq "Core" -and $major -ge 7)
}

if (-not (Test-Pwsh7)) {
    $edition = $PSVersionTable.PSEdition
    $version = $PSVersionTable.PSVersion.ToString()
    Write-Host "✗ 部署脚本要求在 PowerShell 7+ (pwsh) 环境运行。" -ForegroundColor Red
    Write-Host "  当前环境: PSEdition=$edition Version=$version" -ForegroundColor Yellow
    Write-Host "  请使用: pwsh -File .\scripts\deploy.ps1 [-TargetPath PATH] [-IncludeVendor] [-StartupProfile NAME] [-AllowReleaseTestProfile] [-MuteLuaTips] [-Mode dev|release]" -ForegroundColor Yellow
    exit 1
}

# 获取脚本所在目录的上一级目录（项目根目录）
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$SourceMainLuaPath = Join-Path $ProjectRoot "main.lua"

function Escape-LuaStringDoubleQuoted {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    return $Text.Replace('\', '\\').Replace('"', '\"')
}

function Write-MainLuaForStartupPolicy {
    param(
        [string]$SourceMainLua,
        [string]$DestMainLua,
        [string]$ProfileName,
        [string]$DeployMode,
        [bool]$AllowReleaseProfileOverride,
        [bool]$MuteTips
    )
    $sourceText = Get-Content -Path $SourceMainLua -Raw
    $prefixes = @()
    if ($DeployMode -eq "release") {
        $prefixes += "RELEASE_BUILD = true"
        if ($AllowReleaseProfileOverride) {
            $prefixes += "RELEASE_ALLOW_TEST_PROFILE = true"
        }
    }
    if ([string]::IsNullOrWhiteSpace($ProfileName) -eq $false) {
        $escaped = Escape-LuaStringDoubleQuoted -Text $ProfileName
        $prefixes += "STARTUP_TEST_PROFILE = `"$escaped`""
    }
    if ($MuteTips) {
        $prefixes += "EGGY_MUTE_LUA_TIPS = true"
    }
    if ($prefixes.Count -eq 0) {
      Set-Content -Path $DestMainLua -Value $sourceText -NoNewline
      return
    }
    $prefix = ($prefixes -join [Environment]::NewLine) + [Environment]::NewLine
    Set-Content -Path $DestMainLua -Value ($prefix + $sourceText) -NoNewline
}

if ($Mode -eq "release" -and [string]::IsNullOrWhiteSpace($StartupProfile) -eq $false -and -not $AllowReleaseTestProfile) {
    Write-Host "✗ release 模式如需 -StartupProfile，必须同时传入 -AllowReleaseTestProfile。" -ForegroundColor Red
    exit 1
}

if ($Mode -eq "dev" -and $AllowReleaseTestProfile) {
    Write-Host "✗ -AllowReleaseTestProfile 仅支持与 -Mode release 搭配使用。" -ForegroundColor Red
    exit 1
}

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

# 规范化目标路径（移除末尾斜杠，解析完整路径，并去重）
$normalizedTargets = @()
foreach ($path in $TargetPaths) {
    $normalized = $path.TrimEnd("/").TrimEnd("\")
    if (Test-Path $normalized) {
        $normalized = (Resolve-Path $normalized).Path
    } else {
        $normalized = [System.IO.Path]::GetFullPath($normalized)
    }
    if (-not ($normalizedTargets -contains $normalized)) {
        $normalizedTargets += $normalized
    }
}
$TargetPaths = $normalizedTargets

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "开始部署项目文件" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "项目根目录: $ProjectRoot" -ForegroundColor Yellow
Write-Host "部署模式: $Mode" -ForegroundColor Yellow
Write-Host "目标目录数量: $($TargetPaths.Count)" -ForegroundColor Yellow
if ($Mode -eq "release" -and -not $AllowReleaseTestProfile) {
    Write-Host "启动 Profile: default (release-prod 固定，不注入 STARTUP_TEST_PROFILE)" -ForegroundColor Yellow
} elseif ($Mode -eq "release" -and $AllowReleaseTestProfile -and [string]::IsNullOrWhiteSpace($StartupProfile)) {
    Write-Host "启动 Profile: default (release-qa 已启用覆盖，但未传 StartupProfile)" -ForegroundColor Yellow
} elseif ($Mode -eq "release" -and $AllowReleaseTestProfile) {
    Write-Host "启动 Profile: $StartupProfile (release-qa 覆盖已启用)" -ForegroundColor Yellow
} elseif ([string]::IsNullOrWhiteSpace($StartupProfile)) {
    Write-Host "启动 Profile: default (未注入 STARTUP_TEST_PROFILE)" -ForegroundColor Yellow
} else {
    Write-Host "启动 Profile: $StartupProfile" -ForegroundColor Yellow
}
if ($MuteLuaTips) {
    Write-Host "Lua Tips: muted (EGGY_MUTE_LUA_TIPS=true)" -ForegroundColor Yellow
}
foreach ($target in $TargetPaths) {
    Write-Host "  - $target" -ForegroundColor Yellow
}
Write-Host ""

# 定义要拷贝的目录列表（vendor 默认不拷贝）
$Directories = @("Config", "src")
if ($IncludeVendor) {
    $Directories += "vendor"
}

# 定义要拷贝的单个文件列表
$Files = @(
    @{Source = "main.lua"; Target = "main.lua"},
    @{Source = "Data/UIManagerNodes.lua"; Target = "Data/UIManagerNodes.lua"},
    @{Source = "Data/Prefab.lua"; Target = "Data/Prefab.lua"}
)

foreach ($TargetPath in $TargetPaths) {
    Write-Host "--------------------------------------" -ForegroundColor Cyan
    Write-Host "部署目标: $TargetPath" -ForegroundColor Cyan
    Write-Host "--------------------------------------" -ForegroundColor Cyan

    # 检查目标目录是否存在，不存在则创建
    if (-not (Test-Path $TargetPath)) {
        Write-Host "目标目录不存在，正在创建..." -ForegroundColor Yellow
        try {
            New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
            Write-Host "✓ 目标目录创建成功" -ForegroundColor Green
        } catch {
            Write-Host "✗ 创建目标目录失败: $_" -ForegroundColor Red
            exit 1
        }
    }

    # 拷贝目录
    foreach ($dir in $Directories) {
        $sourcePath = Join-Path $ProjectRoot $dir
        $destPath = Join-Path $TargetPath $dir

        if (Test-Path $sourcePath) {
            Write-Host "正在拷贝目录: $dir ..." -ForegroundColor Cyan
            Write-Host "  源: $sourcePath" -ForegroundColor Gray
            Write-Host "  目: $destPath" -ForegroundColor Gray
            try {
                # 如果目标已存在，先删除以避免嵌套问题
                if (Test-Path $destPath) {
                    Remove-Item -Path $destPath -Recurse -Force
                }
                # 复制目录（-Recurse 递归拷贝子目录）
                Copy-Item -LiteralPath $sourcePath -Destination $destPath -Recurse -Force
                Write-Host "✓ $dir 拷贝成功" -ForegroundColor Green
            } catch {
                Write-Host "✗ $dir 拷贝失败: $_" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "⚠ 源目录不存在: $sourcePath" -ForegroundColor Yellow
        }
    }

    # 拷贝文件
    foreach ($file in $Files) {
        $sourcePath = Join-Path $ProjectRoot $file.Source
        $fileDestPath = Join-Path $TargetPath $file.Target
        $fileDestDir = Split-Path -Parent $fileDestPath

        if (Test-Path $sourcePath) {
            Write-Host "正在拷贝文件: $($file.Source) ..." -ForegroundColor Cyan
            Write-Host "  源: $sourcePath" -ForegroundColor Gray
            Write-Host "  目: $fileDestPath" -ForegroundColor Gray
            try {
                # 确保目标目录存在
                if (-not (Test-Path $fileDestDir)) {
                    New-Item -ItemType Directory -Path $fileDestDir -Force | Out-Null
                }
                if ($file.Source -eq "main.lua") {
                    Write-MainLuaForStartupPolicy -SourceMainLua $sourcePath -DestMainLua $fileDestPath -ProfileName $StartupProfile -DeployMode $Mode -AllowReleaseProfileOverride $AllowReleaseTestProfile -MuteTips $MuteLuaTips
                } else {
                    Copy-Item -LiteralPath $sourcePath -Destination $fileDestPath -Force
                }
                Write-Host "✓ $($file.Source) 拷贝成功" -ForegroundColor Green
            } catch {
                Write-Host "✗ $($file.Source) 拷贝失败: $_" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "⚠ 源文件不存在: $sourcePath" -ForegroundColor Yellow
        }
    }

    if ($Mode -eq "release") {
        $targetGeneratedDir = Join-Path $TargetPath "Config/Generated"
        Write-Host "正在导出 release 配置到目标目录..." -ForegroundColor Cyan
        Write-Host "  目: $targetGeneratedDir" -ForegroundColor Gray
        try {
            python (Join-Path $ProjectRoot "scripts/export_xlsx.py") --mode release --output-dir $targetGeneratedDir
            if ($LASTEXITCODE -ne 0) {
                throw "export_xlsx.py failed with exit code $LASTEXITCODE"
            }
            Write-Host "✓ release 配置导出成功" -ForegroundColor Green
        } catch {
            Write-Host "✗ release 配置导出失败: $_" -ForegroundColor Red
            exit 1
        }
    }

    Write-Host ""
}

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "部署完成！" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan

