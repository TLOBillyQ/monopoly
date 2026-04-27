local catalog = require("tests.catalog")
local log_capture = require("tests.support.log_capture")
local timing_summary = require("tests.support.timing_summary")

local M = {}
local _timing_enabled = os.getenv("MONO_TEST_TIMING") == "1"
local wall_clock = _timing_enabled and require("tests.support.wall_clock") or nil

local function _sum_elapsed(script_times)
  local total = 0
  for _, entry in ipairs(script_times) do
    total = total + entry.elapsed_ms
  end
  return total
end

local function _print_timing_report(script_times)
  table.sort(script_times, function(left, right)
    return (left.elapsed_ms or 0) > (right.elapsed_ms or 0)
  end)
  timing_summary.print_script_summary("guard", _sum_elapsed(script_times), script_times)
end

local function _run_script(script, summary)
  local guard_module = require(script.module_name)
  local timer = _timing_enabled and wall_clock.start() or nil
  local ok, result, captured = log_capture.capture(function()
    return guard_module.run()
  end, {
    enabled = os.getenv("MONO_TEST_VERBOSE") ~= "1",
  })
  local timing = _timing_enabled and wall_clock.finish(timer) or nil

  if ok and type(result) == "table" and result.ok == true then
    log_capture.collect_summary(summary, captured)
    if result.message then
      summary[result.message] = (summary[result.message] or 0) + 1
    end
    return nil, timing
  end

  local failure = {
    name = script.name,
    result = result,
    err = ok and nil or result,
    captured = captured,
  }
  return failure, timing
end

function M.run()
  local failures = {}
  local summary = {}
  local script_times = _timing_enabled and {} or nil

  for _, script in ipairs(catalog.guard_scripts) do
    local failure, timing = _run_script(script, summary)
    if _timing_enabled then
      script_times[#script_times + 1] = {
        name = script.name,
        elapsed_ms = timing.elapsed_ms,
      }
    end
    if failure then
      failures[#failures + 1] = failure
    end
  end

  if #failures > 0 then
    io.stdout:write("\n")
    print("Guard checks failed (" .. #failures .. "/" .. #catalog.guard_scripts .. ")")
    for index, failure in ipairs(failures) do
      print(index .. ") " .. failure.name)
      if type(failure.result) == "table" and failure.result.error then
        print(failure.result.error)
      elseif failure.err then
        print(failure.err)
      end
      log_capture.replay(failure.captured)
    end
    if _timing_enabled then
      _print_timing_report(script_times)
    end
    error("guard checks failed")
  end

  io.stdout:write("\n")
  for _, line in ipairs(log_capture.summary_lines(summary)) do
    print("[guard] suppressed x" .. line.count .. " " .. line.text)
  end
  if _timing_enabled then
    _print_timing_report(script_times)
  end
  for _, script in ipairs(catalog.guard_scripts) do
    print(script.name .. " ok")
  end
  return true
end

function M.main()
  M.run()
end

if ... == nil then
  M.main()
else
  return M
end
