#!/usr/bin/env pwsh
# 运行全AI模式
# 用法 Windows: pwsh scripts/run_all_ai.ps1 或 .\scripts\run_all_ai.ps1
# 用法 macOS/Linux: pwsh scripts/run_all_ai.ps1 或 ./scripts/run_all_ai.ps1

$env:ALL_AI = "1"
Write-Host "启动全AI模式（无UI）..."
lua main.lua
