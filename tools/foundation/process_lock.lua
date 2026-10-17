-- 跨进程目录锁:原生 Windows 的 mkdir 对同一路径只有一个进程能成功。
-- 用于工具自举等 package.path 已装好的运行期路径;等待与释放均不依赖 LuaRocks。
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")
local shell_lib = require("foundation.shell")

local process_lock = {}

local _POWERSHELL = (os.getenv("SystemRoot") or "C:/Windows")
  .. "/System32/WindowsPowerShell/v1.0/powershell.exe"
local _TIMEOUT_SECONDS = 600

local function _try_create(lock_path)
  local native = path_lib.normalize_path(lock_path):gsub("/", "\\")
  local result = proc_lib.run_command("mkdir " .. shell_lib.shell_quote(native) .. " 2>nul")
  return result.ok == true
end

local function _wait()
  local result = proc_lib.run_command({
    _POWERSHELL,
    "-NoProfile",
    "-NonInteractive",
    "-Command",
    "[System.Threading.Thread]::Sleep(100)",
  })
  return result.ok == true, result.output
end

-- fn 的多个返回值(包括 nil, err, unavailable)原样透传;异常也先放锁再抛出。
function process_lock.with_lock(lock_path, fn)
  assert(type(fn) == "function", "process lock callback required")
  local deadline = os.time() + _TIMEOUT_SECONDS
  while not _try_create(lock_path) do
    if os.time() >= deadline then
      return nil, "timed out waiting for process lock: " .. tostring(lock_path)
    end
    local waited, wait_err = _wait()
    if not waited then
      return nil, "failed while waiting for process lock: " .. tostring(wait_err)
    end
  end

  local results = table.pack(pcall(fn))
  local released, release_err = fs_lib.remove_path(lock_path)
  if not results[1] then
    error(results[2], 0)
  end
  if not released then
    return nil, release_err
  end
  return table.unpack(results, 2, results.n)
end

return process_lock
