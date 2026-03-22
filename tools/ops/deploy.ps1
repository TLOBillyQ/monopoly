param(
    [string]$TargetPath,
    [string]$StartupProfile,
    [string]$BuildMode = "release",
    [string]$VehicleRuntime = "none",
    [switch]$KeepTestStartup,
    [switch]$Bak,
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
    param([string]$Suffix = "发布")

    if (-not [string]::IsNullOrWhiteSpace($env:MONOPOLY_DEPLOY_TARGET)) {
        return [string]$env:MONOPOLY_DEPLOY_TARGET
    }

    $home_dir = (Resolve-HomeDir).TrimEnd("/")
    if ([string]::IsNullOrWhiteSpace($home_dir)) {
        Exit-WithError (Get-Text `
            "未配置部署目录，请设置 MONOPOLY_DEPLOY_TARGET、传入 --target-path，或在默认目录下创建 LuaSource_大富翁-$Suffix。" `
            "Deploy target is not configured; set MONOPOLY_DEPLOY_TARGET, pass --target-path, or create the default LuaSource_大富翁-$Suffix directory.")
    }

    if ($IsWindows) {
        if ($Suffix -eq "发布") {
            return "$home_dir/Desktop/dev/LuaSource_大富翁-发布"
        }
        return "$home_dir/Desktop/dev/LuaSource_大富翁-$Suffix"
    }
    if ($IsMacOS) {
        if ($Suffix -eq "发布") {
            return "$home_dir/Documents/eggy/LuaSource_大富翁-发布"
        }
        return "$home_dir/Documents/eggy/LuaSource_大富翁-$Suffix"
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
        [string]$TargetDir,
        [string[]]$Exclude = @()
    )

    if (Test-Path -LiteralPath $TargetDir -PathType Container) {
        Remove-Item -LiteralPath $TargetDir -Recurse -Force
    }
    [System.IO.Directory]::CreateDirectory($TargetDir) | Out-Null
    $entries = Get-ChildItem -LiteralPath $SourceDir -Force | Where-Object { $Exclude -notcontains $_.Name }
    foreach ($entry in $entries) {
        $destination = Join-Path $TargetDir $entry.Name
        Copy-Item -LiteralPath $entry.FullName -Destination $destination -Force -Recurse
    }
}

function Write-MainLua {
    param(
        [string]$SourcePath,
        [string]$TargetPath,
        [string]$StartupProfileValue,
        [string]$BuildMode,
        [string]$StartupProfileSource,
        [string]$StartupProfileModule,
        [string]$VehicleRuntimeMode,
        [string]$VehicleRuntimeModule
    )

    $target_parent = Split-Path -Parent $TargetPath
    if (-not [string]::IsNullOrWhiteSpace($target_parent)) {
        [System.IO.Directory]::CreateDirectory($target_parent) | Out-Null
    }

    $source_text = Get-Content -LiteralPath $SourcePath -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($BuildMode) `
        -and [string]::IsNullOrWhiteSpace($StartupProfileValue) `
        -and [string]::IsNullOrWhiteSpace($StartupProfileModule) `
        -and [string]::IsNullOrWhiteSpace($VehicleRuntimeMode) `
        -and [string]::IsNullOrWhiteSpace($VehicleRuntimeModule)) {
        Set-Content -LiteralPath $TargetPath -Encoding UTF8 -NoNewline -Value $source_text
        return
    }

    $prefix_lines = @()
    if (-not [string]::IsNullOrWhiteSpace($BuildMode)) {
        $escaped_build_mode = Escape-LuaDoubleQuotedString $BuildMode
        $prefix_lines += "MONOPOLY_BUILD_MODE = ""$escaped_build_mode"""
    }
    if (-not [string]::IsNullOrWhiteSpace($StartupProfileValue)) {
        $escaped = Escape-LuaDoubleQuotedString $StartupProfileValue
        $prefix_lines += "STARTUP_TEST_PROFILE = ""$escaped"""
    }
    if (-not [string]::IsNullOrWhiteSpace($StartupProfileSource)) {
        $escaped_source = Escape-LuaDoubleQuotedString $StartupProfileSource
        $prefix_lines += "STARTUP_PROFILE_SOURCE = ""$escaped_source"""
    }
    if (-not [string]::IsNullOrWhiteSpace($StartupProfileModule)) {
        $escaped_module = Escape-LuaDoubleQuotedString $StartupProfileModule
        $prefix_lines += "STARTUP_PROFILE_MODULE = ""$escaped_module"""
    }
    if (-not [string]::IsNullOrWhiteSpace($VehicleRuntimeMode)) {
        $escaped_vehicle_mode = Escape-LuaDoubleQuotedString $VehicleRuntimeMode
        $prefix_lines += "VEHICLE_RUNTIME_MODE = ""$escaped_vehicle_mode"""
    }
    if (-not [string]::IsNullOrWhiteSpace($VehicleRuntimeModule)) {
        $escaped_vehicle_module = Escape-LuaDoubleQuotedString $VehicleRuntimeModule
        $prefix_lines += "VEHICLE_RUNTIME_MODULE = ""$escaped_vehicle_module"""
    }
    $prefix = ($prefix_lines -join "`n") + "`n"
    Set-Content -LiteralPath $TargetPath -Encoding UTF8 -NoNewline -Value ($prefix + $source_text)
}

function Remove-NestedPaths {
    param(
        [string]$RootDir,
        [string[]]$RelativePaths = @()
    )

    foreach ($relative_path in $RelativePaths) {
        if ([string]::IsNullOrWhiteSpace($relative_path)) {
            continue
        }
        $target = Join-Path $RootDir $relative_path
        if (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Recurse -Force
        }
    }
}

function Invoke-GenerateStartupProfile {
    param(
        [string]$ProjectRoot,
        [string]$ProfileName,
        [string]$OutputPath
    )

    if ([string]::IsNullOrWhiteSpace($ProfileName) -or $ProfileName -eq "default") {
        return $false
    }

    $generator = Join-Path $ProjectRoot "tools/ops/generate_startup_profile.lua"
    if (-not (Test-Path -LiteralPath $generator -PathType Leaf)) {
        Exit-WithError (Get-Text "缺少启动档生成脚本" "Missing startup profile generator script")
    }

    $output_parent = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($output_parent)) {
        [System.IO.Directory]::CreateDirectory($output_parent) | Out-Null
    }

    & lua $generator $ProfileName $OutputPath
    if ($LASTEXITCODE -ne 0) {
        Exit-WithError (Get-Text "生成启动档模块失败" "Failed to generate startup profile module")
    }
    return $true
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
    param(
        [string]$PathText,
        [string[]]$Exclude = @()
    )

    if (-not (Test-Path -LiteralPath $PathText -PathType Container)) {
        return 0
    }

    $total = 0
    $files = Get-ChildItem -LiteralPath $PathText -Recurse -File -Filter "*.lua" -Force | Where-Object {
        $relPath = $_.FullName.Substring($PathText.Length).TrimStart('\', '/')
        $shouldExclude = $false
        foreach ($ex in $Exclude) {
            if ($relPath -eq $ex -or $relPath.StartsWith($ex + "\") -or $relPath.StartsWith($ex + "/")) {
                $shouldExclude = $true
                break
            }
        }
        -not $shouldExclude
    }
    foreach ($file in $files) {
        $total += Get-EffectiveLuaLineCountForFile $file.FullName
    }
    return $total
}

function Get-LuaFileCount {
    param(
        [string]$PathText,
        [string[]]$Exclude = @()
    )

    if (-not (Test-Path -LiteralPath $PathText)) {
        return 0
    }

    if (Test-Path -LiteralPath $PathText -PathType Leaf) {
        return 1
    }

    $files = Get-ChildItem -LiteralPath $PathText -Recurse -File -Filter "*.lua" -Force | Where-Object {
        $relPath = $_.FullName.Substring($PathText.Length).TrimStart('\', '/')
        $shouldExclude = $false
        foreach ($ex in $Exclude) {
            if ($relPath -eq $ex -or $relPath.StartsWith($ex + "\") -or $relPath.StartsWith($ex + "/")) {
                $shouldExclude = $true
                break
            }
        }
        -not $shouldExclude
    }
    return $files.Count
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
            "^(--build-mode|-BuildMode)$" {
                if (($index + 1) -ge $RemainingArgs.Count) {
                    Exit-WithError (Get-Text "参数缺少取值: $token" "Missing value for flag: $token")
                }
                $script:BuildMode = [string]$RemainingArgs[$index + 1]
                $index += 2
                continue
            }
            "^(--keep-test-startup|-KeepTestStartup)$" {
                $script:KeepTestStartup = $true
                $index += 1
                continue
            }
            "^(--vehicle-runtime|-VehicleRuntime)$" {
                if (($index + 1) -ge $RemainingArgs.Count) {
                    Exit-WithError (Get-Text "参数缺少取值: $token" "Missing value for flag: $token")
                }
                $script:VehicleRuntime = [string]$RemainingArgs[$index + 1]
                $index += 2
                continue
            }
            "^(--bak|-Bak)$" {
                $script:Bak = $true
                $index += 1
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
        "用法: pwsh -File tools/ops/deploy.ps1 [--target-path PATH|-TargetPath PATH] [--build-mode release|debug|-BuildMode release|debug] [--startup-profile NAME|-StartupProfile NAME] [--vehicle-runtime none|legacy|-VehicleRuntime none|legacy] [--keep-test-startup|-KeepTestStartup] [--bak|-Bak]" `
        "Usage: pwsh -File tools/ops/deploy.ps1 [--target-path PATH|-TargetPath PATH] [--build-mode release|debug|-BuildMode release|debug] [--startup-profile NAME|-StartupProfile NAME] [--vehicle-runtime none|legacy|-VehicleRuntime none|legacy] [--keep-test-startup|-KeepTestStartup] [--bak|-Bak]")
    exit 0
}

try {
    $project_root = Resolve-ProjectRoot
    $suffix = if ($Bak) { "备份" } else { "发布" }
    $target_source = if (-not [string]::IsNullOrWhiteSpace($TargetPath)) { $TargetPath } else { Resolve-DefaultTargetPath -Suffix $suffix }
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
    Write-Info ((Get-Text "构建模式: " "Build mode: ") + $BuildMode)
    Write-Info ((Get-Text "载具运行时: " "Vehicle runtime: ") + $VehicleRuntime)
    Write-Info ""
    Write-Info "--------------------------------------"
    Write-Info ((Get-Text "部署目标: " "Deploy target: ") + $target_path)
    Write-Info "--------------------------------------"

    if ($BuildMode -ne "release" -and $BuildMode -ne "debug") {
        Exit-WithError (Get-Text "构建模式仅支持 release 或 debug" "Build mode must be release or debug")
    }
    $third_party_exclude = @("Behavior", "NavMesh", "Bincore.lua")
    $strip_test_startup = -not $KeepTestStartup
    if ($BuildMode -eq "release") {
        $strip_test_startup = $true
        if (-not [string]::IsNullOrWhiteSpace($StartupProfile)) {
            Exit-WithError (Get-Text "release 模式不允许注入 startup profile" "startup profile injection is not allowed in release mode")
        }
        if ($VehicleRuntime -ne "none") {
            Exit-WithError (Get-Text "release 模式不允许启用 legacy 载具运行时" "legacy vehicle runtime is not allowed in release mode")
        }
    }
    if ($VehicleRuntime -ne "none" -and $VehicleRuntime -ne "legacy") {
        Exit-WithError (Get-Text "载具运行时参数仅支持 none 或 legacy" "Vehicle runtime must be none or legacy")
    }
    $generated_profile_module = $null
    $generated_profile_rel_path = "Data/StartupProfileGenerated.lua"
    $src_nested_exclude = @("config/testing", "app/bootstrap/testing")
    $release_bridge_files = @(
        "app/bootstrap/startup_profile_source.lua",
        "app/bootstrap/startup_bootstrap.lua"
    )
    $vehicle_legacy_files = @("host/eggy/vehicle_runtime_legacy.lua")

    foreach ($dir_name in $directories) {
        $source_path = Join-Path $project_root $dir_name
        $target_dir_path = Join-Path $target_path $dir_name
        if (Test-Path -LiteralPath $source_path -PathType Container) {
            Write-Info ((Get-Text "正在拷贝目录: " "Copying directory: ") + "$dir_name ...")
            Write-Info ("  " + (Get-Text "源" "Source") + ": " + (Normalize-PathText $source_path))
            Write-Info ("  " + (Get-Text "目" "Target") + ": " + (Normalize-PathText $target_dir_path))
            if ($dir_name -eq "vendor/third_party") {
                Copy-DirectoryTree -SourceDir $source_path -TargetDir $target_dir_path -Exclude $third_party_exclude
            } else {
                Copy-DirectoryTree -SourceDir $source_path -TargetDir $target_dir_path
                if ($dir_name -eq "src" -and $strip_test_startup) {
                    Remove-NestedPaths -RootDir $target_dir_path -RelativePaths $src_nested_exclude
                }
                if ($dir_name -eq "src" -and $BuildMode -eq "release") {
                    Remove-NestedPaths -RootDir $target_dir_path -RelativePaths $release_bridge_files
                }
                if ($dir_name -eq "src" -and $VehicleRuntime -eq "none") {
                    Remove-NestedPaths -RootDir $target_dir_path -RelativePaths $vehicle_legacy_files
                }
            }
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
                if ([string]::IsNullOrWhiteSpace($generated_profile_module) -and `
                    (Invoke-GenerateStartupProfile -ProjectRoot $project_root -ProfileName $StartupProfile `
                      -OutputPath (Join-Path $target_path $generated_profile_rel_path))) {
                    $generated_profile_module = "Data.StartupProfileGenerated"
                }
                $startup_profile_source = if ([string]::IsNullOrWhiteSpace($generated_profile_module)) { $null } else { "generated" }
                $vehicle_runtime_module = if ($VehicleRuntime -eq "legacy") { "src.host.eggy.vehicle_runtime_legacy" } else { $null }
                Write-MainLua -SourcePath $source_path -TargetPath $target_file_path `
                  -BuildMode $BuildMode `
                  -StartupProfileValue $StartupProfile `
                  -StartupProfileSource $startup_profile_source `
                  -StartupProfileModule $generated_profile_module `
                  -VehicleRuntimeMode $VehicleRuntime `
                  -VehicleRuntimeModule $vehicle_runtime_module
            } else {
                Copy-FileWithParentDir -SourcePath $source_path -TargetPath $target_file_path
            }
            Write-Info ("✓ " + (Get-Text "$source_rel 拷贝成功" "$source_rel copied successfully"))
        } else {
            Write-Info ((Get-Text "⚠ 源文件不存在: " "⚠ Source file does not exist: ") + (Normalize-PathText $source_path))
        }
    }

    $third_party_exclude = @("Behavior", "NavMesh", "Bincore.lua")

    $breakdown = @()
    $breakdown += @{
        name = "src"
        files = (Get-LuaFileCount (Join-Path $target_path "src"))
        count = (Get-EffectiveLuaLineCountForDir (Join-Path $target_path "src"))
    }
    $breakdown += @{
        name = "vendor/third_party"
        files = (Get-LuaFileCount (Join-Path $target_path "vendor/third_party"))
        count = (Get-EffectiveLuaLineCountForDir (Join-Path $target_path "vendor/third_party"))
    }

    $breakdown += @{ name = "main.lua"; files = 1; count = (Get-EffectiveLuaLineCountForFile (Join-Path $target_path "main.lua")) }
    $breakdown += @{
        name = "Data/UIManagerNodes.lua"
        files = 1
        count = (Get-EffectiveLuaLineCountForFile (Join-Path $target_path "Data/UIManagerNodes.lua"))
    }
    $breakdown += @{
        name = "Data/Prefab.lua"
        files = 1
        count = (Get-EffectiveLuaLineCountForFile (Join-Path $target_path "Data/Prefab.lua"))
    }

    $total_files = 0
    $total_effective_line_count = 0
    foreach ($row in $breakdown) {
        $total_files += [int]$row.files
        $total_effective_line_count += [int]$row.count
    }

    Write-Info ""
    Write-Info ("Lua文件: " + $total_files + " / Lua Files: " + $total_files)
    Write-Info ("有效代码行数: " + $total_effective_line_count + " / Effective LOC: " + $total_effective_line_count)
    foreach ($row in $breakdown) {
        Write-Info ("  - " + $row.name + ": " + $row.files + " files, " + [string]$row.count + " LOC")
    }
    Write-Info ""
    Write-Info "======================================"
    Write-Info (Get-Text "部署完成！" "Deployment completed!")
    Write-Info ("  " + $target_path)
    Write-Info ("  Lua文件 / Lua Files: " + $total_files + ", 有效代码行数 / Effective LOC: " + $total_effective_line_count)
    foreach ($row in $breakdown) {
        Write-Info ("    - " + $row.name + ": " + $row.files + " files, " + [string]$row.count + " LOC")
    }
    Write-Info "======================================"
    exit 0
} catch {
    Exit-WithError $_.Exception.Message
}
