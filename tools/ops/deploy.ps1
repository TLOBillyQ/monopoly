param(
    [string]$TargetPath,
    [string]$StartupProfile,
    [switch]$Help,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

function Exit-WithError {
    param([string]$Message)
    Write-Error $Message
    exit 1
}

if ($RemainingArgs.Count -gt 0) {
    $unknownArgs = @()
    foreach ($arg in $RemainingArgs) {
        if ($arg -in @("--help", "-h")) {
            $Help = $true
        } else {
            $unknownArgs += $arg
        }
    }

    if ($unknownArgs.Count -gt 0) {
        Exit-WithError ("未知参数 / Unknown flag: {0}" -f ($unknownArgs -join " "))
    }
}

$lua = Get-Command "lua" -ErrorAction SilentlyContinue
if ($null -eq $lua) {
    Exit-WithError "未找到 lua 命令，请先安装 Lua 并确保其在 PATH 中。 / Lua command not found; install Lua and ensure it is available on PATH."
}

$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$deploy_lua = Join-Path $script_dir "deploy.lua"

$arguments = @($deploy_lua)
if ($Help) {
    $arguments += "--help"
}
if (-not [string]::IsNullOrWhiteSpace($TargetPath)) {
    $arguments += "--target-path"
    $arguments += $TargetPath
}
if (-not [string]::IsNullOrWhiteSpace($StartupProfile)) {
    $arguments += "--startup-profile"
    $arguments += $StartupProfile
}

& $lua.Source @arguments
exit $LASTEXITCODE
