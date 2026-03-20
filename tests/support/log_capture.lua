local M = {}

local _DEFAULT_SUMMARY_LEVELS = {
  warn = true,
}

local function _traceback(err)
  if type(traceback) == "function" then
    return traceback(err)
  end
  return err
end

local function _stringify(...)
  local parts = {}
  for index = 1, select("#", ...) do
    parts[#parts + 1] = tostring(select(index, ...))
  end
  return table.concat(parts, " ")
end

function M.capture(fn, opts)
  opts = opts or {}
  if opts.enabled == false then
    local ok, result = xpcall(fn, _traceback)
    return ok, result, { lines = {} }
  end

  local captured = { lines = {} }
  local original_print = print
  _G.print = function(...)
    captured.lines[#captured.lines + 1] = _stringify(...)
  end

  local ok, result = xpcall(fn, _traceback)
  _G.print = original_print
  return ok, result, captured
end

function M.replay(captured, writer)
  local emit = writer or print
  for _, line in ipairs((captured and captured.lines) or {}) do
    emit(line)
  end
end

function M.collect_summary(summary, captured)
  summary = summary or {}
  for _, line in ipairs((captured and captured.lines) or {}) do
    if line:find("%[warn%]", 1, false) or line:find("%[info%]", 1, false) or line:find("%[event%]", 1, false) then
      summary[line] = (summary[line] or 0) + 1
    end
  end
  return summary
end

local function _line_level(line)
  if type(line) ~= "string" then
    return nil
  end
  if line:find("%[warn%]", 1, false) then
    return "warn"
  end
  if line:find("%[info%]", 1, false) then
    return "info"
  end
  if line:find("%[event%]", 1, false) then
    return "event"
  end
  return nil
end

function M.summary_lines(summary, opts)
  opts = opts or {}
  local levels = opts.levels or _DEFAULT_SUMMARY_LEVELS
  local lines = {}
  for text, count in pairs(summary or {}) do
    local level = _line_level(text)
    if count > 1 and level ~= nil and levels[level] == true then
      lines[#lines + 1] = {
        text = text,
        count = count,
      }
    end
  end
  table.sort(lines, function(left, right)
    if left.count == right.count then
      return left.text < right.text
    end
    return left.count > right.count
  end)
  return lines
end

return M
