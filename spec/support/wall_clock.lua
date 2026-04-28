local bootstrap = require("spec.bootstrap")
bootstrap.install_package_paths()
local common = require("shared.lib.common")

local M = {}

local function _trim(text)
  return tostring(text or ""):match("^%s*(.-)%s*$")
end

local function _parse_ms(output)
  local value = common.to_integer(_trim(output))
  if value == nil then
    return nil
  end
  return value
end

local function _traceback(err)
  if type(traceback) == "function" then
    return traceback(err)
  end
  return tostring(err)
end

local function _run_now_command(command, source)
  local result = common.run_command(command)
  if not result.ok then
    return nil
  end
  local value = _parse_ms(result.output)
  if value == nil then
    return nil
  end
  return value, source
end

local function _now_ms()
  if common.is_windows() then
    return _run_now_command({
      "powershell",
      "-NoProfile",
      "-NonInteractive",
      "-Command",
      "[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()",
    }, "powershell")
  end

  if common.command_exists("python3") then
    local value, source = _run_now_command({
      "python3",
      "-c",
      "import time; print(time.time_ns() // 1000000)",
    }, "python3")
    if value ~= nil then
      return value, source
    end
  end

  if common.command_exists("python") then
    local value, source = _run_now_command({
      "python",
      "-c",
      "import time; print(time.time_ns() // 1000000)",
    }, "python")
    if value ~= nil then
      return value, source
    end
  end

  if common.command_exists("perl") then
    local value, source = _run_now_command({
      "perl",
      "-MTime::HiRes=time",
      "-e",
      "print int(time()*1000)",
    }, "perl")
    if value ~= nil then
      return value, source
    end
  end

  return os.time() * 1000, "os.time"
end

function M.start()
  local started_ms, source = _now_ms()
  return {
    started_ms = started_ms,
    source = source,
  }
end

function M.finish(timer)
  local ended_ms, end_source = _now_ms()
  local started_ms = timer and timer.started_ms or 0
  local elapsed_ms = ended_ms - started_ms
  if elapsed_ms < 0 then
    elapsed_ms = 0
  end
  return {
    elapsed_ms = elapsed_ms,
    source = timer and timer.source or end_source,
  }
end

function M.measure(fn)
  local timer = M.start()
  local ok, result = xpcall(fn, _traceback)
  local timing = M.finish(timer)
  if not ok then
    error(result)
  end
  return result, timing
end

return M
