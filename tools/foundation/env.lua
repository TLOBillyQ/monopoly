-- 环境探测与临时空间分配:当前平台、当前目录、临时目录落点。
--
-- 与 path.lua 划清界限——那边是纯路径演算,这边要读环境变量、起子进程、建目录。
-- 与 proc.lua 划清界限——那边是"跑一条命令拿结果",这边只是"问环境是什么样"。
--
-- 原生 Windows 单平台(ADR 0066):忽略 MSYS PWD，临时目录取 TEMP/TMP。
local path_lib = require("foundation.path")
local shell_lib = require("foundation.shell")
local fs_lib = require("foundation.fs")

local env = {}

local _temp_counter = 0

local function _entropy_token()
  local pointer = tostring({}):gsub("[^%w]+", "")
  if pointer == "" then
    pointer = "ptr"
  end
  _temp_counter = _temp_counter + 1
  return table.concat({
    tostring(os.time()),
    tostring(_temp_counter),
    pointer,
  }, "_")
end

function env.is_macos()
  return false
end

function env.current_dir()
  local process = io.popen("cmd.exe /d /v:off /c cd")
  if process == nil then
    return "."
  end
  local path = process:read("*l") or "."
  process:close()
  return path_lib.normalize_path(path)
end

function env.system_tmp_dir()
  local value = os.getenv("TEMP") or os.getenv("TMP")
  if value == nil or value == "" then
    value = env.current_dir()
  end
  return path_lib.normalize_path(value)
end

function env.make_temp_path(prefix, suffix)
  local base_dir = path_lib.join_path(env.system_tmp_dir(), "eggy_script_tools")
  fs_lib.ensure_dir(base_dir)
  local name = table.concat({
    tostring(prefix or "tmp"),
    _entropy_token(),
  }, "_")
  return path_lib.join_path(base_dir, name .. tostring(suffix or ""))
end

function env.build_open_command(path)
  local normalized = path_lib.normalize_path(path)
  return 'start "" ' .. shell_lib.shell_quote(normalized:gsub("/", "\\"))
end

return env
