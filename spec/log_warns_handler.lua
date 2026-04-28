--- Busted output handler: TAP format + behavior warn whitelist gate + slow case tracker.
---
--- Delegates display to busted.outputHandlers.TAP. Captures `print` output
--- per test, aggregates `[warn]` lines, tracks per-test wall-clock duration,
--- and emits a suite-end summary listing both warn aggregation and slow tests.
--- Non-whitelisted warns are surfaced as `# WARN ...` diagnostic lines so
--- TAP consumers still see them without breaking ok/not-ok grammar.
---
--- Slow threshold: env `MONO_TEST_SLOW_MS` (default 500). Tests exceeding the
--- threshold are flagged inline as `# SLOW <ms>ms <name>` and appear in the
--- suite-end `# slow summary:` block sorted by duration desc.
---
--- Whitelist source: docs/architecture/behavior_warns_data.lua

local log_capture_ok, log_capture = pcall(require, "spec.support.log_capture")
if not log_capture_ok then
  log_capture = { replay = function(_, _) end }
end
local warn_data = require("docs.architecture.behavior_warns_data")

local _DEFAULT_SLOW_MS = 500

local function _slow_threshold_ms()
  local raw = os.getenv("MONO_TEST_SLOW_MS")
  if raw == nil or raw == "" then
    return _DEFAULT_SLOW_MS
  end
  local n = tonumber(raw)
  if n == nil or n < 0 then
    return _DEFAULT_SLOW_MS
  end
  return n
end

local function _now_ms()
  return os.clock() * 1000.0
end

local function _element_name(element)
  if type(element) ~= "table" then
    return "<unknown>"
  end
  local name = element.name or element.descriptor or "<unnamed>"
  return tostring(name)
end

local function _whitelist_set()
  local out = {}
  for line, allowed in pairs((warn_data and warn_data.whitelist) or {}) do
    if allowed then
      out[line] = true
    end
  end
  return out
end

local function _is_whitelisted(line, whitelist)
  if whitelist[line] then
    return true
  end
  for prefix in pairs(whitelist) do
    if line:sub(1, #prefix) == prefix then
      return true
    end
  end
  return false
end

return function(options)
  local busted = require("busted")
  local handler = require("busted.outputHandlers.TAP")(options)

  local whitelist = _whitelist_set()
  local case_buffer = nil
  local original_print = nil
  local aggregated = {}
  local non_whitelisted_total = 0
  local slow_threshold = _slow_threshold_ms()
  local case_started_at = nil
  local current_case_name = nil
  local slow_cases = {}

  local function _start_capture()
    case_buffer = { lines = {} }
    original_print = _G.print
    _G.print = function(...)
      local parts = {}
      for index = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(index, ...))
      end
      case_buffer.lines[#case_buffer.lines + 1] = table.concat(parts, " ")
    end
  end

  local function _stop_capture()
    if original_print ~= nil then
      _G.print = original_print
      original_print = nil
    end
    local captured = case_buffer
    case_buffer = nil
    return captured or { lines = {} }
  end

  local function _process(captured)
    for _, line in ipairs(captured.lines) do
      if line:find("%[warn%]", 1, false) then
        aggregated[line] = (aggregated[line] or 0) + 1
        if not _is_whitelisted(line, whitelist) then
          non_whitelisted_total = non_whitelisted_total + 1
          io.write("# WARN " .. line .. "\n")
        end
      end
    end
    log_capture.replay(captured, function(line)
      if not line:find("%[warn%]", 1, false) then
        io.write("# " .. line .. "\n")
      end
    end)
  end

  busted.subscribe({ "test", "start" }, function(element)
    current_case_name = _element_name(element)
    case_started_at = _now_ms()
    _start_capture()
    return nil, true
  end)

  busted.subscribe({ "test", "end" }, function(element)
    local captured = _stop_capture()
    _process(captured)
    if case_started_at ~= nil then
      local elapsed = _now_ms() - case_started_at
      local name = _element_name(element) or current_case_name or "<unknown>"
      if elapsed >= slow_threshold then
        slow_cases[#slow_cases + 1] = { name = name, ms = elapsed }
        io.write(string.format("# SLOW %dms %s\n", math.floor(elapsed + 0.5), name))
      end
    end
    case_started_at = nil
    current_case_name = nil
    return nil, true
  end)

  busted.subscribe({ "suite", "end" }, function()
    if next(aggregated) ~= nil then
      io.write("# warn summary:\n")
      local rows = {}
      for line, count in pairs(aggregated) do
        rows[#rows + 1] = { line = line, count = count }
      end
      table.sort(rows, function(left, right)
        if left.count == right.count then
          return left.line < right.line
        end
        return left.count > right.count
      end)
      for _, row in ipairs(rows) do
        local tag = _is_whitelisted(row.line, whitelist) and "ok" or "non-whitelisted"
        io.write(string.format("#   [%s] x%d %s\n", tag, row.count, row.line))
      end
      if non_whitelisted_total > 0 then
        io.write(string.format("# total non-whitelisted warns: %d\n", non_whitelisted_total))
      end
    end
    if #slow_cases > 0 then
      io.write(string.format("# slow summary (threshold=%dms):\n", slow_threshold))
      table.sort(slow_cases, function(left, right)
        if left.ms == right.ms then
          return left.name < right.name
        end
        return left.ms > right.ms
      end)
      for _, row in ipairs(slow_cases) do
        io.write(string.format("#   [SLOW %dms] %s\n", math.floor(row.ms + 0.5), row.name))
      end
      io.write(string.format("# total slow tests: %d\n", #slow_cases))
    end
    io.flush()
    return nil, true
  end)

  return handler
end
