[CmdletBinding()]
param(
    [string]$TargetPath,
    [string]$StartupProfile,
    [ValidateSet("auto", "win", "windows", "mac", "macos")]
    [string]$Platform = "auto",
    [ValidateSet("release", "debug")]
    [string]$BuildMode = "release",
    [switch]$KeepTestStartup,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function Test-IsWindowsHost {
    if ($env:OS -eq "Windows_NT") {
        return $true
    }
    return [System.IO.Path]::DirectorySeparatorChar -eq '\'
}

function Test-IsMacOSHost {
    if (Test-IsWindowsHost) {
        return $false
    }

    $runtime_info_type = [System.Type]::GetType("System.Runtime.InteropServices.RuntimeInformation")
    $os_platform_type = [System.Type]::GetType("System.Runtime.InteropServices.OSPlatform")
    if ($runtime_info_type -ne $null -and $os_platform_type -ne $null) {
        $osx_field = $os_platform_type.GetField("OSX")
        $is_os_platform = $runtime_info_type.GetMethod("IsOSPlatform")
        if ($osx_field -ne $null -and $is_os_platform -ne $null) {
            return $is_os_platform.Invoke($null, @($osx_field.GetValue($null))) -eq $true
        }
    }

    try {
        $uname = & uname 2>$null
        return ([string]$uname).Trim() -eq "Darwin"
    } catch {
        return $false
    }
}

if (Test-IsWindowsHost) {
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
    [Console]::Error.WriteLine("ERROR: $Message")
    exit 1
}

function Normalize-PathText {
    param([string]$PathText)
    return ([string]$PathText).Replace("\", "/")
}

function Resolve-NormalizedPath {
    param([string]$PathText)

    if ([string]::IsNullOrWhiteSpace($PathText)) {
        return ""
    }

    $candidate = [Environment]::ExpandEnvironmentVariables([string]$PathText)
    if ($candidate.StartsWith("~/") -or $candidate.StartsWith("~\")) {
        $candidate = Join-Path (Resolve-HomeDir) $candidate.Substring(2)
    }
    if (-not [System.IO.Path]::IsPathRooted($candidate)) {
        $candidate = [System.IO.Path]::Combine((Get-Location).Path, $candidate)
    }
    return (Normalize-PathText ([System.IO.Path]::GetFullPath($candidate))).TrimEnd("/")
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

function Resolve-PlatformName {
    param([string]$RawPlatform)

    $value = ([string]$RawPlatform).Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($value) -or $value -eq "auto") {
        if (Test-IsWindowsHost) {
            return "win"
        }
        if (Test-IsMacOSHost) {
            return "mac"
        }
        Exit-WithError "Platform is not supported. Pass -Platform win or -Platform mac."
    }

    switch ($value) {
        "win" { return "win" }
        "windows" { return "win" }
        "mac" { return "mac" }
        "macos" { return "mac" }
        default { Exit-WithError ("Unsupported platform '{0}'. Use win or mac." -f $RawPlatform) }
    }
}

function Resolve-DefaultTargetPath {
    param([string]$ResolvedPlatform)

    if (-not [string]::IsNullOrWhiteSpace($env:MONOPOLY_DEPLOY_TARGET)) {
        return Resolve-NormalizedPath $env:MONOPOLY_DEPLOY_TARGET
    }

    $home_dir = Resolve-HomeDir
    if ([string]::IsNullOrWhiteSpace($home_dir)) {
        Exit-WithError "Deploy target is not configured; set MONOPOLY_DEPLOY_TARGET or pass -TargetPath."
    }

    switch ($ResolvedPlatform) {
        "win" {
            return Resolve-NormalizedPath (Join-Path (Join-Path (Join-Path $home_dir "Desktop") "dev") (Join-LuaSourceDirName))
        }
        "mac" {
            return Resolve-NormalizedPath (Join-Path (Join-Path (Join-Path $home_dir "Documents") "eggy") (Join-LuaSourceDirName))
        }
        default {
            Exit-WithError "No default deploy target is configured for this platform; set MONOPOLY_DEPLOY_TARGET or pass -TargetPath."
        }
    }
}

function Join-LuaSourceDirName {
    return ("LuaSource_" + [string][char]0x5927 + [string][char]0x5BCC + [string][char]0x7FC1)
}

function Resolve-EffectiveBuildMode {
    param(
        [string]$RequestedBuildMode,
        [string]$StartupProfileValue
    )

    if ([string]::IsNullOrWhiteSpace($StartupProfileValue)) {
        if ($RequestedBuildMode -ne "release") {
            return [pscustomobject]@{
                mode = "release"
                note = "No startup profile was specified; forcing release build mode."
            }
        }
        return [pscustomobject]@{
            mode = "release"
            note = $null
        }
    }

    if ($RequestedBuildMode -ne "debug") {
        return [pscustomobject]@{
            mode = "debug"
            note = "Startup profile detected; forcing debug build mode."
        }
    }

    return [pscustomobject]@{
        mode = "debug"
        note = $null
    }
}

function Test-ProjectRoot {
    param([string]$PathText)

    return (Test-Path -LiteralPath (Join-Path $PathText "main.lua") -PathType Leaf) `
        -and (Test-Path -LiteralPath (Join-Path $PathText "src") -PathType Container) `
        -and (Test-Path -LiteralPath (Join-Path $PathText "tools") -PathType Container)
}

function Resolve-ProjectRoot {
    $candidates = @(
        [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../..")),
        (Get-Location).Path
    )

    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-ProjectRoot $candidate)) {
            return Resolve-NormalizedPath $candidate
        }
    }

    return Resolve-NormalizedPath $candidates[0]
}

function Escape-LuaDoubleQuotedString {
    param([string]$Text)

    $value = [string]$Text
    $value = $value.Replace("\", "\\")
    $value = $value.Replace('"', '\"')
    return $value
}

function Reset-Directory {
    param([string]$PathText)

    if (Test-Path -LiteralPath $PathText) {
        Remove-Item -LiteralPath $PathText -Recurse -Force
    }
    [System.IO.Directory]::CreateDirectory($PathText) | Out-Null
}

function Copy-DirectoryTree {
    param(
        [string]$SourceDir,
        [string]$TargetDir,
        [string[]]$ExcludeNames = @()
    )

    Reset-Directory $TargetDir
    $entries = Get-ChildItem -LiteralPath $SourceDir -Force | Where-Object {
        $ExcludeNames -notcontains $_.Name
    }
    foreach ($entry in $entries) {
        Copy-Item -LiteralPath $entry.FullName -Destination (Join-Path $TargetDir $entry.Name) -Force -Recurse
    }
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

function Remove-NestedPaths {
    param(
        [string]$RootDir,
        [string[]]$RelativePaths
    )

    foreach ($relative_path in $RelativePaths) {
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
        Exit-WithError "Missing startup profile generator script"
    }

    $output_parent = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($output_parent)) {
        [System.IO.Directory]::CreateDirectory($output_parent) | Out-Null
    }

    & lua $generator $ProfileName $OutputPath
    if ($LASTEXITCODE -ne 0) {
        Exit-WithError "Failed to generate startup profile module"
    }
    return $true
}

function Write-MainLua {
    param(
        [string]$SourcePath,
        [string]$TargetPath,
        [string]$BuildModeValue,
        [string]$StartupProfileValue,
        [string]$StartupProfileSource,
        [string]$StartupProfileModule
    )

    $prefix_lines = @()
    if (-not [string]::IsNullOrWhiteSpace($BuildModeValue)) {
        $prefix_lines += "MONOPOLY_BUILD_MODE = ""$(Escape-LuaDoubleQuotedString $BuildModeValue)"""
    }
    if (-not [string]::IsNullOrWhiteSpace($StartupProfileValue)) {
        $prefix_lines += "STARTUP_TEST_PROFILE = ""$(Escape-LuaDoubleQuotedString $StartupProfileValue)"""
    }
    if (-not [string]::IsNullOrWhiteSpace($StartupProfileSource)) {
        $prefix_lines += "STARTUP_PROFILE_SOURCE = ""$(Escape-LuaDoubleQuotedString $StartupProfileSource)"""
    }
    if (-not [string]::IsNullOrWhiteSpace($StartupProfileModule)) {
        $prefix_lines += "STARTUP_PROFILE_MODULE = ""$(Escape-LuaDoubleQuotedString $StartupProfileModule)"""
    }

    $target_parent = Split-Path -Parent $TargetPath
    if (-not [string]::IsNullOrWhiteSpace($target_parent)) {
        [System.IO.Directory]::CreateDirectory($target_parent) | Out-Null
    }

    $source_text = Get-Content -LiteralPath $SourcePath -Raw -Encoding UTF8
    $prefix = ""
    if ($prefix_lines.Count -gt 0) {
        $prefix = ($prefix_lines -join "`n") + "`n"
    }
    Set-Content -LiteralPath $TargetPath -Encoding UTF8 -NoNewline -Value ($prefix + $source_text)
}

function Get-EffectiveLuaLineCountForFile {
    param([string]$PathText)

    if (-not (Test-Path -LiteralPath $PathText -PathType Leaf)) {
        return 0
    }

    $count = 0
    foreach ($line in (Get-Content -LiteralPath $PathText -Encoding UTF8)) {
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
    foreach ($file in (Get-ChildItem -LiteralPath $PathText -Recurse -File -Filter "*.lua" -Force)) {
        $total += Get-EffectiveLuaLineCountForFile $file.FullName
    }
    return $total
}

function Get-LuaFileCount {
    param([string]$PathText)

    if (-not (Test-Path -LiteralPath $PathText)) {
        return 0
    }
    if (Test-Path -LiteralPath $PathText -PathType Leaf) {
        return 1
    }
    return (Get-ChildItem -LiteralPath $PathText -Recurse -File -Filter "*.lua" -Force).Count
}

if ($Help) {
    Write-Info "Usage: .\\tools\\ops\\deploy.ps1 [-TargetPath PATH] [-Platform auto|win|mac] [-BuildMode release|debug] [-StartupProfile NAME] [-KeepTestStartup]"
    exit 0
}

try {
    $project_root = Resolve-ProjectRoot
    $resolved_platform = Resolve-PlatformName $Platform
    $build_mode_resolution = Resolve-EffectiveBuildMode -RequestedBuildMode $BuildMode -StartupProfileValue $StartupProfile
    $effective_build_mode = [string]$build_mode_resolution.mode
    $target_source = if (-not [string]::IsNullOrWhiteSpace($TargetPath)) { $TargetPath } else { Resolve-DefaultTargetPath $resolved_platform }
    $target_path = Resolve-NormalizedPath $target_source

    [System.IO.Directory]::CreateDirectory($target_path) | Out-Null

    Write-Info "======================================"
    Write-Info "Starting project deployment"
    Write-Info "======================================"
    Write-Info ("Project root: " + $project_root)
    Write-Info ("Target path: " + $target_path)
    Write-Info ("Platform: " + $resolved_platform)
    if ([string]::IsNullOrWhiteSpace($StartupProfile)) {
        Write-Info "Startup profile: default (STARTUP_TEST_PROFILE not injected)"
    } else {
        Write-Info ("Startup profile: " + $StartupProfile)
    }
    if (-not [string]::IsNullOrWhiteSpace($build_mode_resolution.note)) {
        Write-Info $build_mode_resolution.note
    }
    Write-Info ("Build mode: " + $effective_build_mode)
    Write-Info ""
    Write-Info "--------------------------------------"
    Write-Info ("Deploy target: " + $target_path)
    Write-Info "--------------------------------------"

    Copy-DirectoryTree -SourceDir (Join-Path $project_root "src") -TargetDir (Join-Path $target_path "src")
    Copy-DirectoryTree `
        -SourceDir (Join-Path $project_root "vendor/third_party") `
        -TargetDir (Join-Path $target_path "vendor/third_party") `
        -ExcludeNames @("Behavior", "NavMesh", "Bincore.lua")

    $strip_test_startup = -not $KeepTestStartup
    if ($effective_build_mode -eq "release") {
        $strip_test_startup = $true
    }
    if ($strip_test_startup) {
        Remove-NestedPaths -RootDir (Join-Path $target_path "src") -RelativePaths @(
            "config/testing",
            "app/testing"
        )
    }
    if ($effective_build_mode -eq "release") {
        Remove-NestedPaths -RootDir (Join-Path $target_path "src") -RelativePaths @(
            "app/profile_source.lua",
            "app/profile_bootstrap.lua"
        )
    }

    $generated_profile_module = $null
    if (Invoke-GenerateStartupProfile `
        -ProjectRoot $project_root `
        -ProfileName $StartupProfile `
        -OutputPath (Join-Path $target_path "Data/StartupProfileGenerated.lua")) {
        $generated_profile_module = "Data.StartupProfileGenerated"
    }
    $startup_profile_source = if ($generated_profile_module) { "generated" } else { $null }

    Write-MainLua `
        -SourcePath (Join-Path $project_root "main.lua") `
        -TargetPath (Join-Path $target_path "main.lua") `
        -BuildModeValue $effective_build_mode `
        -StartupProfileValue $StartupProfile `
        -StartupProfileSource $startup_profile_source `
        -StartupProfileModule $generated_profile_module
    Copy-FileWithParentDir `
        -SourcePath (Join-Path $project_root "Data/UIManagerNodes.lua") `
        -TargetPath (Join-Path $target_path "Data/UIManagerNodes.lua")
    Copy-FileWithParentDir `
        -SourcePath (Join-Path $project_root "Data/Prefab.lua") `
        -TargetPath (Join-Path $target_path "Data/Prefab.lua")

    $total_files = `
        (Get-LuaFileCount (Join-Path $target_path "src")) + `
        (Get-LuaFileCount (Join-Path $target_path "vendor/third_party")) + `
        (Get-LuaFileCount (Join-Path $target_path "main.lua")) + `
        (Get-LuaFileCount (Join-Path $target_path "Data/UIManagerNodes.lua")) + `
        (Get-LuaFileCount (Join-Path $target_path "Data/Prefab.lua"))
    $total_effective_line_count = `
        (Get-EffectiveLuaLineCountForDir (Join-Path $target_path "src")) + `
        (Get-EffectiveLuaLineCountForDir (Join-Path $target_path "vendor/third_party")) + `
        (Get-EffectiveLuaLineCountForFile (Join-Path $target_path "main.lua")) + `
        (Get-EffectiveLuaLineCountForFile (Join-Path $target_path "Data/UIManagerNodes.lua")) + `
        (Get-EffectiveLuaLineCountForFile (Join-Path $target_path "Data/Prefab.lua"))

    Write-Info ""
    Write-Info ("Lua Files: " + $total_files)
    Write-Info ("Effective LOC: " + $total_effective_line_count)
    Write-Info ""
    Write-Info "======================================"
    Write-Info "Deployment completed!"
    Write-Info ("  " + $target_path)
    Write-Info ("  Lua Files: " + $total_files + ", Effective LOC: " + $total_effective_line_count)
    Write-Info "======================================"
    exit 0
} catch {
    Exit-WithError $_.Exception.Message
}
