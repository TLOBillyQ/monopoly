package.path = 'scripts/?.lua;scripts/?/?.lua;' .. package.path
local common = require('lib.common')

print('=== Testing path functions ===')
print('is_windows:', common.is_windows())

local test_dir = 'C:/Users/Lzx_8/Desktop/dev/LuaSource_大富翁-开发'
print('Test dir:', test_dir)

print('\n--- Testing _get_short_path_name ---')
local short_path = common._get_short_path_name(test_dir)
print('Short path:', short_path)

-- Debug: test the for command directly
print('\n--- Testing for command directly ---')
local win_path = test_dir:gsub("/", "\\")
local cmd = 'for %I in ("' .. win_path .. '") do @echo %~sI'
print('Command:', cmd)
local full_cmd = 'cmd /c chcp 65001 >nul 2>&1 & ' .. cmd
print('Full command:', full_cmd)
local process = io.popen(full_cmd, "r")
if process then
  local result = process:read("*l")
  process:close()
  print('Result:', result or "nil")
else
  print('Failed to run command')
end

print('\n--- Testing path_exists ---')
local exists = common.path_exists(test_dir)
print('path_exists:', exists)

print('\n--- Testing is_dir ---')
local isdir = common.is_dir(test_dir)
print('is_dir:', isdir)

print('\n--- Testing ensure_dir ---')
local ok, err = common.ensure_dir(test_dir)
print('ensure_dir result:', ok, err)

print('\n--- Test complete ---')
