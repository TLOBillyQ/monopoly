
<#
.SYNOPSIS
    将项目文件部署到目标目录
.DESCRIPTION
    该脚本要求在 PowerShell 7 (pwsh) 环境执行。
    默认拷贝 Config/、src/ 目录以及 Data/UIManagerNodes.lua、Data/Prefab.lua 和 main.lua 到目标目录。
    Windows 与 macOS 在未传 -TargetPath 时都会默认部署到单个同步目标目录。
    如需额外拷贝 vendor/，请传入 -IncludeVendor 参数。
.PARAMETER TargetPath
    目标目录的绝对路径。支持传入多个；未传时使用平台默认同步目录。
.PARAMETER IncludeVendor
    是否额外拷贝 vendor/ 目录（默认不拷贝）
.PARAMETER StartupProfile
    启动时注入的测试 profile 名（写入 main.lua 的 STARTUP_TEST_PROFILE）
.PARAMETER StartupAiMode
    启动时注入的 AI 模式（写入 main.lua 的 STARTUP_AI_MODE）
.PARAMETER StartupLocalHumanRoleId
    启动时注入的本机人类 role_id（写入 main.lua 的 STARTUP_LOCAL_HUMAN_ROLE_ID）
.EXAMPLE
    pwsh -File .\deploy.ps1 -TargetPath "C:\Target\Project"
.EXAMPLE
    pwsh -File .\deploy.ps1 -TargetPath "C:\Target\Project" -IncludeVendor
.EXAMPLE
    pwsh -File .\deploy.ps1 -TargetPath "C:\Users\Lzx_8\Desktop\dev\LuaSource_大富翁-开发"
.EXAMPLE
    pwsh -File .\deploy.ps1 -TargetPath "C:\Users\Lzx_8\Desktop\dev\LuaSource_大富翁-发布"
.EXAMPLE
    pwsh -File .\deploy.ps1 -StartupProfile "items_move_control"
.EXAMPLE
    pwsh -File .\deploy.ps1 -StartupProfile "market" -StartupAiMode "all_except_local_human" -StartupLocalHumanRoleId 123
# macOS 默认同步目录:
#   /Users/billyq/Documents/eggy/LuaSource_大富翁-开发
#>

param(
    [Parameter(Mandatory=$false, HelpMessage="请输入目标目录的路径")]
    [string[]]$TargetPath,
    [switch]$IncludeVendor,
    [string]$StartupProfile,
    [ValidateSet("default", "all_except_local_human")]
    [string]$StartupAiMode = "default",
    [string]$StartupLocalHumanRoleId
)

function Test-Pwsh7 {
    $edition = $PSVersionTable.PSEdition
    $major = $PSVersionTable.PSVersion.Major
    return ($edition -eq "Core" -and $major -ge 7)
}

function Get-DefaultSyncTargetPaths {
    if ($IsWindows) {
        return @(
            "C:\\Users\\Lzx_8\\Desktop\\dev\\LuaSource_大富翁-开发"
        )
    }
    if ($IsMacOS) {
        return @(
            "/Users/billyq/Documents/eggy/LuaSource_大富翁-开发"
        )
    }
    return $null
}

function Normalize-TargetPath {
    param([string]$Path)
    $normalized = $Path.TrimEnd("/").TrimEnd("\")
    if (Test-Path $normalized) {
        return (Resolve-Path $normalized).Path
    }
    return [System.IO.Path]::GetFullPath($normalized)
}

function Resolve-SyncTargetPaths {
    param([string[]]$RequestedPaths)

    $defaultSyncTargets = Get-DefaultSyncTargetPaths
    if (-not $RequestedPaths -or $RequestedPaths.Count -eq 0) {
        if ($defaultSyncTargets) {
            return $defaultSyncTargets
        }
        Write-Host "✗ 不支持的系统平台，请显式传入 -TargetPath" -ForegroundColor Red
        exit 1
    }

    return @($RequestedPaths)
}

if (-not (Test-Pwsh7)) {
    $edition = $PSVersionTable.PSEdition
    $version = $PSVersionTable.PSVersion.ToString()
    Write-Host "✗ 部署脚本要求在 PowerShell 7+ (pwsh) 环境运行。" -ForegroundColor Red
    Write-Host "  当前环境: PSEdition=$edition Version=$version" -ForegroundColor Yellow
    Write-Host "  请使用: pwsh -File .\scripts\deploy.ps1 [-TargetPath PATH] [-IncludeVendor] [-StartupProfile NAME] [-StartupAiMode MODE] [-StartupLocalHumanRoleId ID]" -ForegroundColor Yellow
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
        [string]$AiMode,
        [string]$LocalHumanRoleId
    )
    $sourceText = Get-Content -Path $SourceMainLua -Raw
    $prefixes = @()
    if ([string]::IsNullOrWhiteSpace($ProfileName) -eq $false) {
        $escaped = Escape-LuaStringDoubleQuoted -Text $ProfileName
        $prefixes += "STARTUP_TEST_PROFILE = `"$escaped`""
    }
    if ([string]::IsNullOrWhiteSpace($AiMode) -eq $false -and $AiMode -ne "default") {
        $escapedAiMode = Escape-LuaStringDoubleQuoted -Text $AiMode
        $prefixes += "STARTUP_AI_MODE = `"$escapedAiMode`""
    }
    if ([string]::IsNullOrWhiteSpace($LocalHumanRoleId) -eq $false) {
        $prefixes += "STARTUP_LOCAL_HUMAN_ROLE_ID = $LocalHumanRoleId"
    }
    if ($prefixes.Count -eq 0) {
      Set-Content -Path $DestMainLua -Value $sourceText -NoNewline
      return
    }
    $prefix = ($prefixes -join [Environment]::NewLine) + [Environment]::NewLine
    Set-Content -Path $DestMainLua -Value ($prefix + $sourceText) -NoNewline
}

function Get-LuaEffectiveLineCount {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        return 0
    }

    $lines = Get-Content -Path $FilePath
    $effectiveLineCount = 0
    $inBlockComment = $false

    foreach ($line in $lines) {
        $currentLine = $line

        while ($true) {
            if ($inBlockComment) {
                $blockCommentEnd = $currentLine.IndexOf("]]")
                if ($blockCommentEnd -lt 0) {
                    $currentLine = ""
                    break
                }

                $currentLine = $currentLine.Substring($blockCommentEnd + 2)
                $inBlockComment = $false
                continue
            }

            $blockCommentStart = $currentLine.IndexOf("--[[")
            $lineCommentStart = $currentLine.IndexOf("--")

            if ($lineCommentStart -lt 0) {
                break
            }

            if ($blockCommentStart -ge 0 -and $blockCommentStart -eq $lineCommentStart) {
                $beforeComment = $currentLine.Substring(0, $blockCommentStart)
                $blockCommentEnd = $currentLine.IndexOf("]]", $blockCommentStart + 4)

                if ($blockCommentEnd -ge 0) {
                    $currentLine = $beforeComment + $currentLine.Substring($blockCommentEnd + 2)
                    continue
                }

                $currentLine = $beforeComment
                $inBlockComment = $true
                break
            }

            $currentLine = $currentLine.Substring(0, $lineCommentStart)
            break
        }

        if (-not [string]::IsNullOrWhiteSpace($currentLine)) {
            $effectiveLineCount += 1
        }
    }

    return $effectiveLineCount
}

function Get-DeploymentEffectiveLuaLineCount {
    param(
        [string]$DeployTargetPath,
        [string[]]$DeployedDirectories,
        [object[]]$DeployedFiles
    )

    $allLuaFiles = @()

    foreach ($dir in $DeployedDirectories) {
        $deployedDirPath = Join-Path $DeployTargetPath $dir
        if (Test-Path $deployedDirPath) {
            $allLuaFiles += @(Get-ChildItem -Path $deployedDirPath -Recurse -File -Filter "*.lua" | Select-Object -ExpandProperty FullName)
        }
    }

    foreach ($file in $DeployedFiles) {
        $deployedFilePath = Join-Path $DeployTargetPath $file.Target
        if ((Test-Path $deployedFilePath) -and $deployedFilePath.EndsWith(".lua")) {
            $allLuaFiles += $deployedFilePath
        }
    }

    $totalEffectiveLineCount = 0
    foreach ($luaFile in ($allLuaFiles | Sort-Object -Unique)) {
        $totalEffectiveLineCount += Get-LuaEffectiveLineCount -FilePath $luaFile
    }

    return $totalEffectiveLineCount
}

function Get-DeploymentEffectiveLuaLineBreakdown {
    param(
        [string]$DeployTargetPath,
        [string[]]$DeployedDirectories,
        [object[]]$DeployedFiles
    )

    $lineBreakdown = @()

    foreach ($dir in $DeployedDirectories) {
        $deployedDirPath = Join-Path $DeployTargetPath $dir
        $effectiveLineCount = 0

        if (Test-Path $deployedDirPath) {
            $luaFiles = @(Get-ChildItem -Path $deployedDirPath -Recurse -File -Filter "*.lua" | Select-Object -ExpandProperty FullName)
            foreach ($luaFile in $luaFiles) {
                $effectiveLineCount += Get-LuaEffectiveLineCount -FilePath $luaFile
            }
        }

        $lineBreakdown += @{
            Name = $dir
            Type = "Directory"
            EffectiveLuaLineCount = $effectiveLineCount
        }
    }

    foreach ($file in $DeployedFiles) {
        $deployedFilePath = Join-Path $DeployTargetPath $file.Target
        $effectiveLineCount = 0

        if ((Test-Path $deployedFilePath) -and $deployedFilePath.EndsWith(".lua")) {
            $effectiveLineCount = Get-LuaEffectiveLineCount -FilePath $deployedFilePath
        }

        $lineBreakdown += @{
            Name = $file.Target
            Type = "File"
            EffectiveLuaLineCount = $effectiveLineCount
        }
    }

    return $lineBreakdown
}

# 未传入时按平台选择默认单目标。
$TargetPaths = Resolve-SyncTargetPaths -RequestedPaths $TargetPath

# 规范化目标路径（移除末尾斜杠，解析完整路径，并去重）
$normalizedTargets = @()
foreach ($path in $TargetPaths) {
    $normalized = Normalize-TargetPath -Path $path
    if (-not ($normalizedTargets -contains $normalized)) {
        $normalizedTargets += $normalized
    }
}
$TargetPaths = $normalizedTargets

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "开始部署项目文件" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "项目根目录: $ProjectRoot" -ForegroundColor Yellow
Write-Host "目标目录数量: $($TargetPaths.Count)" -ForegroundColor Yellow
Write-Host "部署模式: 按目标列表同步" -ForegroundColor Yellow
if ([string]::IsNullOrWhiteSpace($StartupProfile)) {
    Write-Host "启动 Profile: default (未注入 STARTUP_TEST_PROFILE)" -ForegroundColor Yellow
} else {
    Write-Host "启动 Profile: $StartupProfile" -ForegroundColor Yellow
}
if ([string]::IsNullOrWhiteSpace($StartupAiMode) -or $StartupAiMode -eq "default") {
    Write-Host "启动 AI 模式: default" -ForegroundColor Yellow
} elseif ([string]::IsNullOrWhiteSpace($StartupLocalHumanRoleId)) {
    Write-Host "启动 AI 模式: $StartupAiMode (未传 StartupLocalHumanRoleId，运行时将回退到 1 号位人类)" -ForegroundColor Yellow
} else {
    Write-Host "启动 AI 模式: $StartupAiMode (local_human_role_id=$StartupLocalHumanRoleId)" -ForegroundColor Yellow
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

$DeployLineCountSummary = @()

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
                    Write-MainLuaForStartupPolicy -SourceMainLua $sourcePath -DestMainLua $fileDestPath -ProfileName $StartupProfile -AiMode $StartupAiMode -LocalHumanRoleId $StartupLocalHumanRoleId
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

    Write-Host "" 

    $effectiveLuaLineCount = Get-DeploymentEffectiveLuaLineCount -DeployTargetPath $TargetPath -DeployedDirectories $Directories -DeployedFiles $Files
    $effectiveLuaLineBreakdown = Get-DeploymentEffectiveLuaLineBreakdown -DeployTargetPath $TargetPath -DeployedDirectories $Directories -DeployedFiles $Files
    $DeployLineCountSummary += @{
        TargetPath = $TargetPath
        EffectiveLuaLineCount = $effectiveLuaLineCount
        EffectiveLuaLineBreakdown = $effectiveLuaLineBreakdown
    }
    Write-Host ("有效代码行数: {0}" -f $effectiveLuaLineCount) -ForegroundColor Magenta
    foreach ($entry in $effectiveLuaLineBreakdown) {
        Write-Host ("  - {0}: {1}" -f $entry.Name, $entry.EffectiveLuaLineCount) -ForegroundColor DarkMagenta
    }
    Write-Host ""
}

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "部署完成！" -ForegroundColor Green
foreach ($summary in $DeployLineCountSummary) {
    Write-Host ("  {0} -> 有效代码行数 {1}" -f $summary.TargetPath, $summary.EffectiveLuaLineCount) -ForegroundColor Magenta
    foreach ($entry in $summary.EffectiveLuaLineBreakdown) {
        Write-Host ("    - {0}: {1}" -f $entry.Name, $entry.EffectiveLuaLineCount) -ForegroundColor DarkMagenta
    }
}
Write-Host "======================================" -ForegroundColor Cyan
