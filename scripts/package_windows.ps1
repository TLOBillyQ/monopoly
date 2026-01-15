$ErrorActionPreference = "Stop"



# Define paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = (Resolve-Path "$ScriptDir\..").Path
$BinWindowsDir = Join-Path $ProjectRoot "bin\windows"
$TempZipFile = Join-Path $ProjectRoot "game_temp.zip"
$LoveFile = Join-Path $BinWindowsDir "SuperGame.love"
$GameExe = Join-Path $BinWindowsDir "Game.exe"

Write-Host "Starting packaging process..."

# 1. Zip src/ directory, assets/ directory and main.lua
Write-Host "1. Creating zip package from src/, assets/ and main.lua..."
$SourceItems = @(
    (Join-Path $ProjectRoot "src"),
    (Join-Path $ProjectRoot "assets"),
    (Join-Path $ProjectRoot "main.lua")
)

if (Test-Path $TempZipFile) {
    Remove-Item $TempZipFile -Force
}

Compress-Archive -Path $SourceItems -DestinationPath $TempZipFile -Force

# 2. Move zip to bin/windows/SuperGame.love
Write-Host "2. Moving zip to $LoveFile..."
if (Test-Path $LoveFile) {
    Remove-Item $LoveFile -Force
}
Move-Item -Path $TempZipFile -Destination $LoveFile -Force

# 3. Execute cmd command to create Game.exe
Write-Host "3. Creating Game.exe..."
if (-not (Test-Path "$BinWindowsDir\love.exe")) {
    Write-Error "love.exe not found in $BinWindowsDir"
    exit 1
}

# Change directory to bin/windows to execute the copy command simply
Push-Location $BinWindowsDir
try {
    # Using cmd /c to execute the binary concatenation
    cmd /c "copy /b love.exe+SuperGame.love Game.exe"
}
finally {
    Pop-Location
}

if (-not (Test-Path $GameExe)) {
    Write-Error "Failed to create Game.exe"
    exit 1
}

# 4. Cleanup intermediate files
Write-Host "4. Cleaning up intermediate files in bin/windows..."
if (Test-Path $LoveFile) {
    Remove-Item $LoveFile -Force
}

Write-Host "Packaging successful! Output: $GameExe"

