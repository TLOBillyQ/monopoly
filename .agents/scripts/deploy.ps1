
<#
.SYNOPSIS
    将项目文件部署到目标目录
.DESCRIPTION
    拷贝 Config/, src/, vendor/ 目录以及 Data/UIManagerNodes.lua 和 main.lua 到指定的目标目录
.PARAMETER TargetPath
    目标目录的绝对路径
.EXAMPLE
    .\deploy.ps1 -TargetPath "C:\Target\Project"
#>

param(
    [Parameter(Mandatory=$false, HelpMessage="请输入目标目录的路径")]
    [string]$TargetPath
)

# 未传入时按平台选择默认路径
if (-not $TargetPath) {
    if ($IsWindows) {
        $TargetPath = "C:\\Users\\Lzx_8\\Desktop\\dev\\LuaSource_monopoly"
    } elseif ($IsMacOS) {
        $TargetPath = "/Users/billyq/Documents/eggy/LuaSource_monopoly"
    } else {
        Write-Host "✗ 不支持的系统平台，请显式传入 -TargetPath" -ForegroundColor Red
        exit 1
    }
}

# 规范化目标路径（移除末尾斜杠，解析完整路径）
$TargetPath = $TargetPath.TrimEnd("/").TrimEnd("\")
if (Test-Path $TargetPath) {
    $TargetPath = (Resolve-Path $TargetPath).Path
}

# 获取脚本所在目录的上两级目录（项目根目录）
$ScriptRoot = Split-Path -Parent $PSScriptRoot
$ProjectRoot = Split-Path -Parent $ScriptRoot

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "开始部署项目文件" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "项目根目录: $ProjectRoot" -ForegroundColor Yellow
Write-Host "目标目录: $TargetPath" -ForegroundColor Yellow
Write-Host ""

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

# 定义要拷贝的目录列表
$Directories = @("Config", "src", "vendor")

# 定义要拷贝的单个文件列表
$Files = @(
    @{Source = "main.lua"; Target = "main.lua"},
    @{Source = "Data/UIManagerNodes.lua"; Target = "Data/UIManagerNodes.lua"}
)

# 拷贝目录
foreach ($dir in $Directories) {
    $sourcePath = Join-Path $ProjectRoot $dir
    # 确保目标路径不会嵌套
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
            # 使用 LiteralPath 避免路径解析问题
            Copy-Item -LiteralPath $sourcePath -Destination $fileDestPath -Force
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
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "部署完成！" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
