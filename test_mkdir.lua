package.path = 'scripts/?.lua;scripts/?/?.lua;' .. package.path
local common = require('lib.common')

local test_dir = 'C:/Users/Lzx_8/Desktop/dev/LuaSource_大富翁-开发'
local win_path = test_dir:gsub("/", "\\")

print('Testing mkdir commands:')
print('Target:', win_path)

-- Test 1: Direct mkdir with UTF-8 code page
print('\n1. Testing direct mkdir with chcp 65001:')
local cmd1 = 'cmd /c chcp 65001 >nul 2>&1 & mkdir "' .. win_path .. '" 2>nul'
print('Command:', cmd1)
local ok1, kind1, code1 = os.execute(cmd1)
print('Result:', ok1, kind1, code1)

-- Check if it was created
print('\n2. Checking if directory was created:')
local check_cmd = 'cmd /c chcp 65001 >nul 2>&1 & if exist "' .. win_path .. '\\" (echo YES) else (echo NO)'
local process = io.popen(check_cmd, "r")
if process then
  local result = process:read("*l")
  process:close()
  print('Exists:', result or "nil")
end

-- Test 3: Try using PowerShell
print('\n3. Testing PowerShell mkdir:')
local ps_cmd = 'powershell -NoProfile -Command "New-Item -ItemType Directory -Path \'' .. win_path .. '\' -Force" 2>nul'
print('Command:', ps_cmd)
local ok3 = os.execute(ps_cmd)
print('Result:', ok3)

print('\nDone.')
