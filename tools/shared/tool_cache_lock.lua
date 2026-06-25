local common = require("shared.lib.common")

local tool_cache_lock = {}

local function _execute_success(ok, _, code)
  if type(ok) == "number" then
    return ok == 0
  end
  return ok == true and (code == nil or code == 0)
end

local function _powershell_literal(value)
  return "'" .. tostring(value or ""):gsub("'", "''") .. "'"
end

local function _mkdir_once(path)
  local command
  if common.is_windows() then
    command = table.concat({
      "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command ",
      [["try { New-Item -ItemType Directory -Path ]],
      _powershell_literal(path),
      [[ -ErrorAction Stop | Out-Null; exit 0 } catch { exit 1 }" > nul 2> nul]],
    })
  else
    command = "mkdir " .. common.shell_quote(path) .. " >/dev/null 2>&1"
  end
  return _execute_success(os.execute(command))
end

local function _sleep_briefly()
  if common.is_windows() then
    os.execute([[powershell -NoProfile -NonInteractive -Command "Start-Sleep -Milliseconds 100" > nul 2> nul]])
  else
    os.execute("sleep 0.1 >/dev/null 2>&1")
  end
end

local function _acquire(path)
  local started = os.time()
  while true do
    if _mkdir_once(path) then
      return function()
        common.remove_path(path)
      end
    end
    if os.time() - started > 300 then
      return nil, "timed out waiting for tool cache lock: " .. tostring(path)
    end
    _sleep_briefly()
  end
end

function tool_cache_lock.with_lock(path, fn)
  local release_lock, lock_err = _acquire(path)
  if release_lock == nil then
    return nil, lock_err
  end
  local ok, value, err = xpcall(fn, debug.traceback)
  release_lock()
  if not ok then
    return nil, value
  end
  return value, err
end

return tool_cache_lock
