local M = {}

local function _copy_sorted(entries)
  local copy = {}
  for _, entry in ipairs(entries or {}) do
    copy[#copy + 1] = entry
  end
  table.sort(copy, function(left, right)
    return (left.elapsed_ms or 0) > (right.elapsed_ms or 0)
  end)
  return copy
end

local function _has_nonzero(entries)
  for _, entry in ipairs(entries or {}) do
    if (entry.elapsed_ms or 0) > 0 then
      return true
    end
  end
  return false
end

function M.print_lane_summary(lane_name, result, opts)
  local timing_data = result and result.timing_data
  if type(timing_data) ~= "table" then
    return
  end

  local top_n = (opts and opts.top_n) or 5
  local suite_times = _copy_sorted(timing_data.suite_times)
  local case_times = _copy_sorted(timing_data.case_times)
  local total_elapsed_ms = timing_data.total_elapsed_ms or 0
  local timer_source = timing_data.timer_source or "unknown"

  print("")
  print(string.format("[%s] timing total=%dms source=%s", tostring(lane_name), total_elapsed_ms, tostring(timer_source)))

  if _has_nonzero(suite_times) then
    print(string.format("[%s] top suites:", tostring(lane_name)))
    for index = 1, math.min(top_n, #suite_times) do
      local entry = suite_times[index]
      print(string.format("  %6dms  %s (%d cases)", entry.elapsed_ms or 0, tostring(entry.name), entry.case_count or 0))
    end
  end

  if _has_nonzero(case_times) then
    print(string.format("[%s] top cases:", tostring(lane_name)))
    for index = 1, math.min(top_n, #case_times) do
      local entry = case_times[index]
      print(string.format("  %6dms  %s", entry.elapsed_ms or 0, tostring(entry.name)))
    end
  end
end

return M
