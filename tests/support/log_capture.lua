local M = {}

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

function M.summary_lines(summary)
  local lines = {}
  for text, count in pairs(summary or {}) do
    if count > 1 then
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
