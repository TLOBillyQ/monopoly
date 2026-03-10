<#
.SYNOPSIS
    将项目文件部署到默认同步目录
.DESCRIPTION
    该脚本要求在 PowerShell 7 (pwsh) 环境执行。
    默认拷贝 Config/、src/ 目录以及 Data/UIManagerNodes.lua、Data/Prefab.lua 和 main.lua 到平台内置同步目录。
    为避免误发，脚本禁止部署到名称包含“发布”的目录。
.PARAMETER StartupProfile
    启动时注入的测试 profile 名（写入 main.lua 的 STARTUP_TEST_PROFILE）
.EXAMPLE
    pwsh -File .\scripts\deploy.ps1
.EXAMPLE
    pwsh -File .\scripts\deploy.ps1 -StartupProfile "items_move_control"
# macOS 默认同步目录:
#   /Users/billyq/Documents/eggy/LuaSource_大富翁-开发
#>

param(
    [string]$StartupProfile
)

function Exit-WithError {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
    exit 1
}

function Test-Pwsh7 {
    $edition = $PSVersionTable.PSEdition
    $major = $PSVersionTable.PSVersion.Major
    return ($edition -eq "Core" -and $major -ge 7)
}

function Get-DefaultSyncTargetPath {
    if ($IsWindows) {
        return "C:\Users\Lzx_8\Desktop\dev\LuaSource_大富翁-开发"
    }
    if ($IsMacOS) {
        return "/Users/billyq/Documents/eggy/LuaSource_大富翁-开发"
    }
    Exit-WithError "当前平台未配置默认同步目录，请先在 scripts/deploy.ps1 中补充默认路径。"
}

function Normalize-TargetPath {
    param([string]$Path)
    $normalized = $Path.TrimEnd("/").TrimEnd("\")
    if (Test-Path $normalized) {
        return (Resolve-Path $normalized).Path
    }
    return [System.IO.Path]::GetFullPath($normalized)
}

function Test-ForbiddenDeployTargetPath {
    param([string]$Path)

    foreach ($segment in ($Path -split '[\\/]')) {
        if ([string]::IsNullOrWhiteSpace($segment)) {
            continue
        }
        if ($segment.Contains("发布")) {
            return $true
        }
    }

    return $false
}

if (-not (Test-Pwsh7)) {
    $edition = $PSVersionTable.PSEdition
    $version = $PSVersionTable.PSVersion.ToString()
    Write-Host "✗ 部署脚本要求在 PowerShell 7+ (pwsh) 环境运行。" -ForegroundColor Red
    Write-Host "  当前环境: PSEdition=$edition Version=$version" -ForegroundColor Yellow
    Write-Host "  请使用: pwsh -File .\scripts\deploy.ps1 [-StartupProfile NAME]" -ForegroundColor Yellow
    exit 1
}

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$TargetPath = Normalize-TargetPath -Path (Get-DefaultSyncTargetPath)

if (Test-ForbiddenDeployTargetPath -Path $TargetPath) {
    Exit-WithError "禁止部署到名称包含“发布”的目录: $TargetPath"
}

function Escape-LuaStringDoubleQuoted {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    return $Text.Replace('\', '\\').Replace('"', '\"')
}

function Write-MainLuaForStartupPolicy {
    param(
        [string]$SourceMainLua,
        [string]$DestMainLua,
        [string]$ProfileName
    )

    $sourceText = Get-Content -Path $SourceMainLua -Raw
    if ([string]::IsNullOrWhiteSpace($ProfileName)) {
        Set-Content -Path $DestMainLua -Value $sourceText -NoNewline
        return
    }

    $escapedProfileName = Escape-LuaStringDoubleQuoted -Text $ProfileName
    $prefix = "STARTUP_TEST_PROFILE = `"$escapedProfileName`"" + [Environment]::NewLine
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

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "开始部署项目文件" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "项目根目录: $ProjectRoot" -ForegroundColor Yellow
Write-Host "目标目录: $TargetPath" -ForegroundColor Yellow
Write-Host "部署模式: 默认同步目录" -ForegroundColor Yellow
if ([string]::IsNullOrWhiteSpace($StartupProfile)) {
    Write-Host "启动 Profile: default (未注入 STARTUP_TEST_PROFILE)" -ForegroundColor Yellow
} else {
    Write-Host "启动 Profile: $StartupProfile" -ForegroundColor Yellow
}
Write-Host ""

$Directories = @("Config", "src")
$Files = @(
    @{Source = "main.lua"; Target = "main.lua"},
    @{Source = "Data/UIManagerNodes.lua"; Target = "Data/UIManagerNodes.lua"},
    @{Source = "Data/Prefab.lua"; Target = "Data/Prefab.lua"}
)

Write-Host "--------------------------------------" -ForegroundColor Cyan
Write-Host "部署目标: $TargetPath" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor Cyan

if (-not (Test-Path $TargetPath)) {
    Write-Host "目标目录不存在，正在创建..." -ForegroundColor Yellow
    try {
        New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
        Write-Host "✓ 目标目录创建成功" -ForegroundColor Green
    } catch {
        Exit-WithError "创建目标目录失败: $_"
    }
}

foreach ($dir in $Directories) {
    $sourcePath = Join-Path $ProjectRoot $dir
    $destPath = Join-Path $TargetPath $dir

    if (Test-Path $sourcePath) {
        Write-Host "正在拷贝目录: $dir ..." -ForegroundColor Cyan
        Write-Host "  源: $sourcePath" -ForegroundColor Gray
        Write-Host "  目: $destPath" -ForegroundColor Gray
        try {
            if (Test-Path $destPath) {
                Remove-Item -Path $destPath -Recurse -Force
            }
            Copy-Item -LiteralPath $sourcePath -Destination $destPath -Recurse -Force
            Write-Host "✓ $dir 拷贝成功" -ForegroundColor Green
        } catch {
            Exit-WithError "$dir 拷贝失败: $_"
        }
    } else {
        Write-Host "⚠ 源目录不存在: $sourcePath" -ForegroundColor Yellow
    }
}

foreach ($file in $Files) {
    $sourcePath = Join-Path $ProjectRoot $file.Source
    $fileDestPath = Join-Path $TargetPath $file.Target
    $fileDestDir = Split-Path -Parent $fileDestPath

    if (Test-Path $sourcePath) {
        Write-Host "正在拷贝文件: $($file.Source) ..." -ForegroundColor Cyan
        Write-Host "  源: $sourcePath" -ForegroundColor Gray
        Write-Host "  目: $fileDestPath" -ForegroundColor Gray
        try {
            if (-not (Test-Path $fileDestDir)) {
                New-Item -ItemType Directory -Path $fileDestDir -Force | Out-Null
            }
            if ($file.Source -eq "main.lua") {
                Write-MainLuaForStartupPolicy -SourceMainLua $sourcePath -DestMainLua $fileDestPath -ProfileName $StartupProfile
            } else {
                Copy-Item -LiteralPath $sourcePath -Destination $fileDestPath -Force
            }
            Write-Host "✓ $($file.Source) 拷贝成功" -ForegroundColor Green
        } catch {
            Exit-WithError "$($file.Source) 拷贝失败: $_"
        }
    } else {
        Write-Host "⚠ 源文件不存在: $sourcePath" -ForegroundColor Yellow
    }
}

Write-Host ""

$effectiveLuaLineCount = Get-DeploymentEffectiveLuaLineCount -DeployTargetPath $TargetPath -DeployedDirectories $Directories -DeployedFiles $Files
$effectiveLuaLineBreakdown = Get-DeploymentEffectiveLuaLineBreakdown -DeployTargetPath $TargetPath -DeployedDirectories $Directories -DeployedFiles $Files
$DeployLineCountSummary = @(
    [PSCustomObject]@{
        TargetPath = $TargetPath
        EffectiveLuaLineCount = $effectiveLuaLineCount
        EffectiveLuaLineBreakdown = $effectiveLuaLineBreakdown
    }
)
Write-Host ("有效代码行数: {0}" -f $effectiveLuaLineCount) -ForegroundColor Magenta
foreach ($entry in $effectiveLuaLineBreakdown) {
    Write-Host ("  - {0}: {1}" -f $entry.Name, $entry.EffectiveLuaLineCount) -ForegroundColor DarkMagenta
}
Write-Host ""

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "部署完成！" -ForegroundColor Green
foreach ($summary in $DeployLineCountSummary) {
    Write-Host ("  {0} -> 有效代码行数 {1}" -f $summary.TargetPath, $summary.EffectiveLuaLineCount) -ForegroundColor Magenta
    foreach ($entry in $summary.EffectiveLuaLineBreakdown) {
        Write-Host ("    - {0}: {1}" -f $entry.Name, $entry.EffectiveLuaLineCount) -ForegroundColor DarkMagenta
    }
}
Write-Host "======================================" -ForegroundColor Cyan
