-- 环境探测与临时空间分配:当前平台、当前目录、临时目录落点。
--
-- 与 path.lua 划清界限——那边是纯路径演算,这边要读环境变量、起子进程、建目录。
-- 与 proc.lua 划清界限——那边是"跑一条命令拿结果",这边只是"问环境是什么样"。
--
-- 工具链只跑在 macOS 与 WSL Ubuntu 上(工单 #127 / #129;#127 平台约束)。注意别把「工具链跑在哪个
-- OS」与「部署目标是哪个 OS」搞混:Eggy 宿主仍在 Windows 端,那条路径活在
-- tools/packages/ops/deploy.lua 里,与本文件无关。
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
  local process = io.popen("uname")
  if process == nil then
    return false
  end
  local content = process:read("*l") or ""
  process:close()
  return path_lib.normalize_path(content) == "Darwin"
end

function env.current_dir()
  local process = io.popen("pwd")
  if process == nil then
    return "."
  end
  local path = process:read("*l") or "."
  process:close()
  return path_lib.normalize_path(path)
end

function env.system_tmp_dir()
  local value = os.getenv("TMPDIR")
  if value == nil or value == "" then
    value = "/tmp"
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
  if env.is_macos() then
    return shell_lib.build_command({ "open", normalized })
  end
  return shell_lib.build_command({ "xdg-open", normalized })
end

return env
