# Issues — config-data-upgrade

## [2026-03-26] CRITICAL: xlsx_reader broken on Windows

- **File**: `tools/shared/lib/xlsx_reader.lua`
- **Error**: `Failed to read zip entry: xl/workbook.xml`
- **Symptom**: Export tool hangs/times out when run
- **Likely cause**: zip decompression tool incompatibility with Chinese-character paths on Windows
- **Status**: BLOCKING Task 1-10, F1-F3 — Task 0 must fix this first

## [2026-03-26] Windows diff incompatibility

- `diff` command on Windows = PowerShell Compare-Object (path objects, not content)
- Workaround: use Lua-based file comparison in QA scenarios
