param(
    [string]$TargetPath,
    [string]$StartupProfile,
    [switch]$Help,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

$ErrorActionPreference = "Stop"

if ($IsWindows) {
    try {
        chcp 65001 | Out-Null
    } catch {
    }
    try {
        $utf8_no_bom = [System.Text.UTF8Encoding]::new($false)
        [Console]::InputEncoding = $utf8_no_bom
        [Console]::OutputEncoding = $utf8_no_bom
        $OutputEncoding = $utf8_no_bom
    } catch {
    }
}

function Get-Text {
    param(
        [string]$Zh,
        [string]$En
    )
    return "$Zh / $En"
}

function Write-Info {
    param([string]$Message)
    Write-Output ([string]$Message)
}

function Exit-WithError {
    param([string]$Message)
    [Console]::Error.WriteLine("✗ $Message")
    exit 1
}

function Normalize-PathText {
    param([string]$PathText)
    return ([string]$PathText).Replace("\", "/")
}

function Resolve-NormalizedPath {
    param([string]$PathText)

    $raw = [string]$PathText
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return ""
    }

    $absolute = $raw
    if (-not [System.IO.Path]::IsPathRooted($raw)) {
        $absolute = [System.IO.Path]::Combine((Get-Location).Path, $raw)
    }
    $full = [System.IO.Path]::GetFullPath($absolute)
    $normalized = Normalize-PathText $full
    return $normalized.TrimEnd("/")
}

function Resolve-HomeDir {
    if (-not [string]::IsNullOrWhiteSpace($env:HOME)) {
        return Normalize-PathText $env:HOME
    }
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        return Normalize-PathText $env:USERPROFILE
    }
    return ""
}

function Resolve-DefaultTargetPath {
    if (-not [string]::IsNullOrWhiteSpace($env:MONOPOLY_DEPLOY_TARGET)) {
        return [string]$env:MONOPOLY_DEPLOY_TARGET
    }

    $home_dir = (Resolve-HomeDir).TrimEnd("/")
    if ([string]::IsNullOrWhiteSpace($home_dir)) {
        Exit-WithError (Get-Text `
            "未配置部署目录，请设置 MONOPOLY_DEPLOY_TARGET、传入 --target-path，或在默认目录下创建 LuaSource_大富翁-发布。" `
            "Deploy target is not configured; set MONOPOLY_DEPLOY_TARGET, pass --target-path, or create the default LuaSource_大富翁-发布 directory.")
    }

    if ($IsWindows) {
        return "$home_dir/Desktop/dev/LuaSource_大富翁-发布"
    }
    if ($IsMacOS) {
        return "$home_dir/Documents/eggy/LuaSource_大富翁-发布"
    }

    Exit-WithError (Get-Text `
        "当前平台未配置默认部署目录，请设置 MONOPOLY_DEPLOY_TARGET 或传入 --target-path。" `
        "No default deploy target is configured for this platform; set MONOPOLY_DEPLOY_TARGET or pass --target-path.")
}

function Test-ProjectRoot {
    param([string]$PathText)
    return (Test-Path -LiteralPath (Join-Path $PathText "main.lua") -PathType Leaf) `
        -and (Test-Path -LiteralPath (Join-Path $PathText "src") -PathType Container) `
        -and (Test-Path -LiteralPath (Join-Path $PathText "tools") -PathType Container)
}

function Resolve-ProjectRoot {
    $candidates = @()
    $candidates += [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../.."))
    $candidates += (Get-Location).Path

    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-ProjectRoot $candidate)) {
            return (Resolve-NormalizedPath $candidate)
        }
    }

    return (Resolve-NormalizedPath $candidates[0])
}

function Escape-LuaDoubleQuotedString {
    param([string]$Text)
    $value = [string]$Text
    $value = $value.Replace("\", "\\")
    $value = $value.Replace('"', '\"')
    return $value
}

function Copy-DirectoryTree {
    param(
        [string]$SourceDir,
        [string]$TargetDir
    )

    if (Test-Path -LiteralPath $TargetDir -PathType Container) {
        Remove-Item -LiteralPath $TargetDir -Recurse -Force
    }
    [System.IO.Directory]::CreateDirectory($TargetDir) | Out-Null
    $entries = Get-ChildItem -LiteralPath $SourceDir -Force
    foreach ($entry in $entries) {
        $destination = Join-Path $TargetDir $entry.Name
        Copy-Item -LiteralPath $entry.FullName -Destination $destination -Force -Recurse
    }
}

function Write-MainLua {
    param(
        [string]$SourcePath,
        [string]$TargetPath,
        [string]$StartupProfileValue
    )

    $target_parent = Split-Path -Parent $TargetPath
    if (-not [string]::IsNullOrWhiteSpace($target_parent)) {
        [System.IO.Directory]::CreateDirectory($target_parent) | Out-Null
    }

    $source_text = Get-Content -LiteralPath $SourcePath -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($StartupProfileValue)) {
        Set-Content -LiteralPath $TargetPath -Encoding UTF8 -NoNewline -Value $source_text
        return
    }

    $escaped = Escape-LuaDoubleQuotedString $StartupProfileValue
    $prefix = "STARTUP_TEST_PROFILE = ""$escaped""`n"
    Set-Content -LiteralPath $TargetPath -Encoding UTF8 -NoNewline -Value ($prefix + $source_text)
}

function Copy-FileWithParentDir {
    param(
        [string]$SourcePath,
        [string]$TargetPath
    )

    $target_parent = Split-Path -Parent $TargetPath
    if (-not [string]::IsNullOrWhiteSpace($target_parent)) {
        [System.IO.Directory]::CreateDirectory($target_parent) | Out-Null
    }
    Copy-Item -LiteralPath $SourcePath -Destination $TargetPath -Force
}

function Get-EffectiveLuaLineCountForFile {
    param([string]$PathText)

    if (-not (Test-Path -LiteralPath $PathText -PathType Leaf)) {
        return 0
    }

    $count = 0
    $lines = Get-Content -LiteralPath $PathText -Encoding UTF8
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -ne "" -and -not $trimmed.StartsWith("--")) {
            $count += 1
        }
    }
    return $count
}

function Get-EffectiveLuaLineCountForDir {
    param([string]$PathText)

    if (-not (Test-Path -LiteralPath $PathText -PathType Container)) {
        return 0
    }

    $total = 0
    $files = Get-ChildItem -LiteralPath $PathText -Recurse -File -Filter "*.lua" -Force
    foreach ($file in $files) {
        $total += Get-EffectiveLuaLineCountForFile $file.FullName
    }
    return $total
}

function Parse-RemainingArgs {
    if ($null -eq $RemainingArgs -or $RemainingArgs.Count -eq 0) {
        return
    }

    $unknown_args = @()
    $index = 0
    while ($index -lt $RemainingArgs.Count) {
        $token = [string]$RemainingArgs[$index]
        switch -Regex ($token) {
            "^(--help|-h)$" {
                $script:Help = $true
                $index += 1
                continue
            }
            "^(--target-path|-TargetPath)$" {
                if (($index + 1) -ge $RemainingArgs.Count) {
                    Exit-WithError (Get-Text "参数缺少取值: $token" "Missing value for flag: $token")
                }
                $script:TargetPath = [string]$RemainingArgs[$index + 1]
                $index += 2
                continue
            }
            "^(--startup-profile|-StartupProfile)$" {
                if (($index + 1) -ge $RemainingArgs.Count) {
                    Exit-WithError (Get-Text "参数缺少取值: $token" "Missing value for flag: $token")
                }
                $script:StartupProfile = [string]$RemainingArgs[$index + 1]
                $index += 2
                continue
            }
            default {
                $unknown_args += $token
                $index += 1
                continue
            }
        }
    }

    if ($unknown_args.Count -gt 0) {
        Exit-WithError ("未知参数 / Unknown flag: {0}" -f ($unknown_args -join " "))
    }
}

Parse-RemainingArgs

if ($Help) {
    Write-Info (Get-Text `
        "用法: pwsh -File tools/ops/deploy.ps1 [--target-path PATH|-TargetPath PATH] [--startup-profile NAME|-StartupProfile NAME]" `
        "Usage: pwsh -File tools/ops/deploy.ps1 [--target-path PATH|-TargetPath PATH] [--startup-profile NAME|-StartupProfile NAME]")
    exit 0
}

try {
    $project_root = Resolve-ProjectRoot
    $target_source = if (-not [string]::IsNullOrWhiteSpace($TargetPath)) { $TargetPath } else { Resolve-DefaultTargetPath }
    $target_path = Resolve-NormalizedPath $target_source

    [System.IO.Directory]::CreateDirectory($target_path) | Out-Null

    $directories = @("src", "vendor/third_party")
    $files = @(
        @{ source = "main.lua"; target = "main.lua" },
        @{ source = "Data/UIManagerNodes.lua"; target = "Data/UIManagerNodes.lua" },
        @{ source = "Data/Prefab.lua"; target = "Data/Prefab.lua" }
    )

    Write-Info "======================================"
    Write-Info (Get-Text "开始部署项目文件" "Starting project deployment")
    Write-Info "======================================"
    Write-Info ((Get-Text "项目根目录: " "Project root: ") + $project_root)
    Write-Info ((Get-Text "目标目录: " "Target path: ") + $target_path)
    if ([string]::IsNullOrWhiteSpace($StartupProfile)) {
        Write-Info (Get-Text `
            "启动 Profile: default（未注入 STARTUP_TEST_PROFILE）" `
            "Startup profile: default (STARTUP_TEST_PROFILE not injected)")
    } else {
        Write-Info ((Get-Text "启动 Profile: " "Startup profile: ") + $StartupProfile)
    }
    Write-Info ""
    Write-Info "--------------------------------------"
    Write-Info ((Get-Text "部署目标: " "Deploy target: ") + $target_path)
    Write-Info "--------------------------------------"

    foreach ($dir_name in $directories) {
        $source_path = Join-Path $project_root $dir_name
        $target_dir_path = Join-Path $target_path $dir_name
        if (Test-Path -LiteralPath $source_path -PathType Container) {
            Write-Info ((Get-Text "正在拷贝目录: " "Copying directory: ") + "$dir_name ...")
            Write-Info ("  " + (Get-Text "源" "Source") + ": " + (Normalize-PathText $source_path))
            Write-Info ("  " + (Get-Text "目" "Target") + ": " + (Normalize-PathText $target_dir_path))
            Copy-DirectoryTree -SourceDir $source_path -TargetDir $target_dir_path
            Write-Info ("✓ " + (Get-Text "$dir_name 拷贝成功" "$dir_name copied successfully"))
        } else {
            Write-Info ((Get-Text "⚠ 源目录不存在: " "⚠ Source directory does not exist: ") + (Normalize-PathText $source_path))
        }
    }

    foreach ($entry in $files) {
        $source_rel = [string]$entry.source
        $target_rel = [string]$entry.target
        $source_path = Join-Path $project_root $source_rel
        $target_file_path = Join-Path $target_path $target_rel
        if (Test-Path -LiteralPath $source_path -PathType Leaf) {
            Write-Info ((Get-Text "正在拷贝文件: " "Copying file: ") + "$source_rel ...")
            Write-Info ("  " + (Get-Text "源" "Source") + ": " + (Normalize-PathText $source_path))
            Write-Info ("  " + (Get-Text "目" "Target") + ": " + (Normalize-PathText $target_file_path))
            if ($source_rel -eq "main.lua") {
                Write-MainLua -SourcePath $source_path -TargetPath $target_file_path -StartupProfileValue $StartupProfile
            } else {
                Copy-FileWithParentDir -SourcePath $source_path -TargetPath $target_file_path
            }
            Write-Info ("✓ " + (Get-Text "$source_rel 拷贝成功" "$source_rel copied successfully"))
        } else {
            Write-Info ((Get-Text "⚠ 源文件不存在: " "⚠ Source file does not exist: ") + (Normalize-PathText $source_path))
        }
    }

    $breakdown = @()
    $breakdown += @{ name = "src"; count = (Get-EffectiveLuaLineCountForDir (Join-Path $project_root "src")) }
    $breakdown += @{ name = "vendor/third_party"; count = (Get-EffectiveLuaLineCountForDir (Join-Path $project_root "vendor/third_party")) }

    $main_count = Get-EffectiveLuaLineCountForFile (Join-Path $project_root "main.lua")
    if ((Test-Path -LiteralPath (Join-Path $project_root "main.lua") -PathType Leaf) -and -not [string]::IsNullOrWhiteSpace($StartupProfile)) {
        $main_count += 1
    }
    $breakdown += @{ name = "main.lua"; count = $main_count }
    $breakdown += @{ name = "Data/UIManagerNodes.lua"; count = (Get-EffectiveLuaLineCountForFile (Join-Path $project_root "Data/UIManagerNodes.lua")) }
    $breakdown += @{ name = "Data/Prefab.lua"; count = (Get-EffectiveLuaLineCountForFile (Join-Path $project_root "Data/Prefab.lua")) }

    $total_effective_line_count = 0
    foreach ($row in $breakdown) {
        $total_effective_line_count += [int]$row.count
    }

    Write-Info ""
    Write-Info ((Get-Text "有效代码行数: " "Effective LOC: ") + $total_effective_line_count)
    foreach ($row in $breakdown) {
        Write-Info ("  - " + $row.name + ": " + [string]$row.count)
    }
    Write-Info ""
    Write-Info "======================================"
    Write-Info (Get-Text "部署完成！" "Deployment completed!")
    Write-Info ("  " + $target_path + " -> " + (Get-Text "有效代码行数 " "effective LOC ") + $total_effective_line_count)
    foreach ($row in $breakdown) {
        Write-Info ("    - " + $row.name + ": " + [string]$row.count)
    }
    Write-Info "======================================"
    exit 0
} catch {
    Exit-WithError $_.Exception.Message
}
