$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $root "bin"
$staging = Join-Path $root ".eggitor_export_tmp"
$zipPath = Join-Path $dist "eggitor_lua_export.zip"

$includeDirs = @(
  "src",
  "Data",
  "UIManager",
  "Utils"
)

$includeFiles = @(
  "main.lua",
  "DebugTools.lua",
  "eggitor_config.lua"
)

if (Test-Path $staging) {
  Remove-Item -Path $staging -Recurse -Force
}

New-Item -ItemType Directory -Path $staging -Force | Out-Null
New-Item -ItemType Directory -Path $dist -Force | Out-Null

foreach ($file in $includeFiles) {
  $src = Join-Path $root $file
  if (Test-Path $src) {
    $dest = Join-Path $staging $file
    $destDir = Split-Path -Parent $dest
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    Copy-Item -Path $src -Destination $dest -Force
  }
}

foreach ($dir in $includeDirs) {
  $path = Join-Path $root $dir
  if (-not (Test-Path $path)) {
    continue
  }
  Get-ChildItem -Path $path -Recurse -File -Filter *.lua | ForEach-Object {
    $rel = $_.FullName.Substring($root.Length + 1)
    $dest = Join-Path $staging $rel
    $destDir = Split-Path -Parent $dest
    if (-not (Test-Path $destDir)) {
      New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Copy-Item -Path $_.FullName -Destination $dest -Force
  }
}

if (Test-Path $zipPath) {
  Remove-Item -Path $zipPath -Force
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  Get-ChildItem -Path $staging -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($staging.Length + 1)
    $entry = $zip.CreateEntry($rel, [System.IO.Compression.CompressionLevel]::Optimal)
    $entryStream = $entry.Open()
    try {
      $fileStream = [System.IO.File]::Open($_.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
      try {
        $fileStream.CopyTo($entryStream)
      } finally {
        $fileStream.Dispose()
      }
    } finally {
      $entryStream.Dispose()
    }
  }
} finally {
  $zip.Dispose()
}

if (Test-Path $staging) {
  Remove-Item -Path $staging -Recurse -Force
}
