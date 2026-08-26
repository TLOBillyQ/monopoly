-- 子进程:跑一条命令并拿回 (ok, code, output)。
--
-- run_command 把 stdout/stderr 重定向到临时文件再读回来,所以本模块依赖 env(临时落点)
-- 与 fs(读回与清理)。反向不成立:fs 不认识子进程,这条单向依赖是分层的关键。
--
-- 工具链只跑在 macOS 与 WSL Ubuntu 上(工单 #127 / #129;#127 平台约束),所以只有 POSIX 一条路径。
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

  local command = "command -v " .. shell_lib.shell_quote(command_name) .. " >/dev/null 2>&1"
  local ok, kind, code = os.execute(command)
  return shell_lib.exit_status(ok, kind, code)
end

function proc.run_command(command, options)
  local args = command
  if type(command) == "string" then
    args = { "sh", "-lc", tostring(command) }
  end

  if type(args) ~= "table" or #args == 0 then
    return {
      ok = false,
      code = 1,
      output = text_lib.bilingual("命令参数无效", "Invalid command arguments"),
    }
  end

  local output_path = env_lib.make_temp_path("command_output", ".log")
  local cwd_path = options and options.cwd and path_lib.normalize_path(options.cwd) or nil
  local stdin_path = options and options.stdin_path and path_lib.normalize_path(options.stdin_path) or nil

  local command_text = shell_lib.build_command(args)
  local wrapped = shell_lib.wrap_command_with_cwd(command_text, cwd_path)
  local redirected = wrapped
  if stdin_path ~= nil and stdin_path ~= "" then
    redirected = redirected .. " < " .. shell_lib.shell_quote(stdin_path)
  end
  redirected = redirected .. " > " .. shell_lib.shell_quote(output_path) .. " 2>&1"
  local ok, kind, code = os.execute(redirected)
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

  local command = {
    "find",
    normalized_root,
    "-type",
    "f",
  }
  if normalized_extension ~= "" then
    command[#command + 1] = "-name"
    command[#command + 1] = "*" .. normalized_extension
  end
  local result = proc.run_command(command)
  if not result.ok then
    return nil, text_lib.bilingual_with_suffix("收集文件失败: ", "Failed to collect files: ", root)
  end

  local files = {}
  for line in (result.output .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then
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
