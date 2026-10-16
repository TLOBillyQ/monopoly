-- 子进程:跑一条命令并拿回 (ok, code, output)。
--
-- run_command 把 stdout/stderr 重定向到临时文件再读回来,所以本模块依赖 env(临时落点)
-- 与 fs(读回与清理)。反向不成立:fs 不认识子进程,这条单向依赖是分层的关键。
--
-- 原生 Windows 单平台(ADR 0066)。字符串是 cmd 语法，数组是字面参数；
-- 临时 CRLF/UTF-8 cmd 脚本以关闭延迟展开存参数，再延迟展开启动真实程序。
-- 不对输出换行或字节编码做隐式转换，非零退出码原样返回。
local text_lib = require("foundation.text")
local path_lib = require("foundation.path")
local shell_lib = require("foundation.shell")
local fs_lib = require("foundation.fs")
local env_lib = require("foundation.env")

local proc = {}

function proc.command_exists(name)
  local command_name = tostring(name or "")
  if command_name == "" then
    return false
  end

  local command = "where.exe " .. shell_lib.shell_quote(command_name) .. " >nul 2>&1"
  local ok, kind, code = os.execute(command)
  local success = shell_lib.exit_status(ok, kind, code)
  return success
end

function proc.run_command(command, options)
  local args = command
  if type(command) ~= "string" and (type(args) ~= "table" or #args == 0) then
    return {
      ok = false,
      code = 1,
      output = text_lib.bilingual("命令参数无效", "Invalid command arguments"),
    }
  end

  local output_path = env_lib.make_temp_path("command_output", ".log")
  local cwd_path = options and options.cwd and path_lib.normalize_path(options.cwd) or nil
  local stdin_path = options and options.stdin_path and path_lib.normalize_path(options.stdin_path) or nil

  local setup = ""
  local command_text = command
  if type(command) == "table" then
    local variables = {}
    for index, value in ipairs(args) do
      local quoted = shell_lib.shell_quote(value):gsub("%%", "%%%%"):gsub('([&|<>%^()" ])', '^%1')
      setup = setup .. "set eggy_arg_" .. index .. "=" .. quoted .. "\r\n"
      variables[#variables + 1] = index == 1 and shell_lib.shell_quote(value) or ("!eggy_arg_" .. index .. "!")
    end
    setup = setup .. "setlocal enabledelayedexpansion\r\n"
    command_text = table.concat(variables, " ")
  end
  if cwd_path then
    setup = "cd /d " .. shell_lib.shell_quote(cwd_path:gsub("/", "\\")) .. "\r\nif errorlevel 1 exit /b 1\r\n" .. setup
  end
  local wrapped = command_text
  local redirected = wrapped
  if stdin_path ~= nil and stdin_path ~= "" then
    redirected = redirected .. " < " .. shell_lib.shell_quote(stdin_path)
  end
  redirected = redirected .. " > " .. shell_lib.shell_quote(output_path) .. " 2>&1"
  local batch_path = env_lib.make_temp_path("command", ".cmd")
  -- chcp.com 会读取继承来的 stdin;worker 的 JSONL job 输入必须留给父进程。
  fs_lib.write_file(batch_path, "@echo off\r\nchcp 65001 <nul >nul\r\n" .. setup .. redirected .. "\r\nexit /b %errorlevel%\r\n")
  local ok, kind, code = os.execute('cmd.exe /d /v:off /c ""' .. batch_path:gsub("/", "\\") .. '""')
  fs_lib.remove_path(batch_path)
  local success, exit_code = shell_lib.exit_status(ok, kind, code)
  local output = fs_lib.read_raw(output_path) or ""
  fs_lib.remove_path(output_path)
  return {
    ok = success,
    code = exit_code,
    output = output,
  }
end

function proc.collect_files(root, extension)
  local normalized_root = path_lib.normalize_path(root)
  local normalized_extension = tostring(extension or "")
  if normalized_extension ~= "" and normalized_extension:sub(1, 1) ~= "." then
    normalized_extension = "." .. normalized_extension
  end

  if not fs_lib.path_exists(normalized_root) then
    return nil, text_lib.bilingual_with_suffix("目录不存在: ", "Directory does not exist: ", root)
  end

  local command = "(dir /b /s /a-d " .. shell_lib.shell_quote(normalized_root:gsub("/", "\\") .. "\\*") .. " 2>nul & ver >nul)"
  local result = proc.run_command(command)
  if not result.ok then
    return nil, text_lib.bilingual_with_suffix("收集文件失败: ", "Failed to collect files: ", root)
  end

  local files = {}
  for line in (result.output .. "\n"):gmatch("(.-)\n") do
    line = line:gsub("\r$", "")
    if line ~= "" and (normalized_extension == "" or line:sub(-#normalized_extension) == normalized_extension) then
      files[#files + 1] = path_lib.normalize_path(line)
    end
  end
  table.sort(files)
  return files
end

function proc.collect_lua_files(root)
  return proc.collect_files(root, ".lua")
end

function proc.open_path(path)
  local normalized = path_lib.normalize_path(path)
  local result = proc.run_command(env_lib.build_open_command(normalized))
  if not result.ok then
    return nil, text_lib.bilingual_with_suffix("打开路径失败: ", "Failed to open path: ", path)
  end
  return true
end

return proc
