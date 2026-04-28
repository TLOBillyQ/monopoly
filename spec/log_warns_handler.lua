--- Busted output handler: TAP format + behavior warn whitelist gate.
---
--- Delegates display to busted.outputHandlers.TAP. Captures `print` output
--- per test, aggregates `[warn]` lines, and emits a suite-end summary.
--- Non-whitelisted warns are surfaced as `# WARN ...` diagnostic lines so
--- TAP consumers still see them without breaking ok/not-ok grammar.
---
--- Whitelist source: docs/architecture/behavior_warns_data.lua

local log_capture = require("tests.support.log_capture")
local warn_data = require("docs.architecture.behavior_warns_data")

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

  busted.subscribe({ "test", "start" }, function()
    _start_capture()
    return nil, true
  end)

  busted.subscribe({ "test", "end" }, function()
    local captured = _stop_capture()
    _process(captured)
    return nil, true
  end)

  busted.subscribe({ "suite", "end" }, function()
    if next(aggregated) == nil then
      return nil, true
    end
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
    io.flush()
    return nil, true
  end)

  return handler
end
