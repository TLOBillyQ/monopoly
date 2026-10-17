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

local function _mkdir(lock_path)
  local native = path_lib.normalize_path(lock_path):gsub("/", "\\")
  return proc_lib.run_command("mkdir " .. shell_lib.shell_quote(native))
end

-- mkdir 失败后锁目录存在才是竞争。若目录不存在,立即再试一次:持有者可能
-- 恰好在 mkdir 与存在性检查之间放锁;第二次仍不存在则保留真实 code/output 快速失败。
local function _acquire(lock_path)
  for attempt = 1, 2 do
    local result = _mkdir(lock_path)
    if result.ok == true then
      return "acquired", result
    end
    if fs_lib.path_exists(lock_path) then
      return "busy", result
    end
    if attempt == 2 then
      return "error", result
    end
  end
end

local function _mkdir_error(lock_path, result)
  return "failed to create process lock " .. tostring(lock_path)
    .. " (exit code " .. tostring(result.code or 1) .. "): " .. tostring(result.output or "")
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
  -- 先建 parent,保证最后的 mkdir 只需要原子争抢锁目录本身。并发建 parent 时,
  -- 一方可能因另一方抢先建成而报错;parent 已存在说明该竞态已安全收敛。
  local parent_ok, parent_err = fs_lib.ensure_parent_dir(lock_path)
  if not parent_ok and not fs_lib.path_exists(path_lib.parent_dir(lock_path)) then
    return nil, parent_err
  end

  local deadline = os.time() + _TIMEOUT_SECONDS
  while true do
    local status, result = _acquire(lock_path)
    if status == "acquired" then
      break
    end
    if status == "error" then
      return nil, _mkdir_error(lock_path, result)
    end
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
