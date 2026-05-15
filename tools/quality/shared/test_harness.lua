require("spec.bootstrap")

local log_capture = require("spec.support.log_capture")
local number_utils = require("src.foundation.number")
local wall_clock = require("spec.support.wall_clock")
local unpack_args = table.unpack or unpack
local _timing_enabled = os.getenv("MONO_TEST_TIMING") == "1"

local function normalize_suite(suite, suite_index)
  if suite and suite.tests then
    return suite.name or ("suite_" .. tostring(suite_index)), suite.tests
  end
  return "suite_" .. tostring(suite_index), suite or {}
end

local function normalize_case(test, case_index, suite_name)
  if type(test) == "function" then
    return "case_" .. tostring(case_index), test, {}
  end
  if type(test) == "table" and type(test.run) == "function" then
    return test.name or ("case_" .. tostring(case_index)), test.run, test
  end
  error("invalid test case in " .. tostring(suite_name) .. " at index " .. tostring(case_index))
end

local function _default_reporter()
  return {
    case_pass = function()
      io.stdout:write(".")
    end,
    case_fail = function()
      io.stdout:write("F")
    end,
    finish = function() end,
  }
end

local function _quiet_reporter()
  return {
    case_pass = function() end,
    case_fail = function() end,
    finish = function() end,
  }
end

local function _run_hook(hook, ...)
  if type(hook) ~= "function" then
    return true
  end
  local args = { ... }
  return xpcall(function()
    hook(unpack_args(args))
  end, debug.traceback)
end

local function _start_timer()
  if _timing_enabled then
    return wall_clock.start()
  end
  return {
    started = os.time(),
    source = "os.time",
  }
end

local function _elapsed_ms(timer)
  if _timing_enabled then
    return wall_clock.finish(timer).elapsed_ms
  end
  local elapsed = (os.time() - (timer and timer.started or 0)) * 1000
  if not number_utils.is_numeric(elapsed) or elapsed < 0 then
    return 0
  end
  return elapsed
end

local function run_all(suites, opts)
  opts = opts or {}
  local reporter = opts.reporter or _default_reporter()
  local quiet = opts.quiet == true
  local summary_label = opts.summary_label or "regression"
  local total = 0
  local failures = {}
  local summary = {}
  local slow_cases = {}
  local case_times = {}
  local suite_times = {}
  local slow_ms = number_utils.to_integer(os.getenv("MONO_TEST_SLOW_MS")) or 500
  local capture_logs = opts.capture_logs ~= false and os.getenv("MONO_TEST_VERBOSE") ~= "1"
  local total_timer = _start_timer()

  for suite_index, suite in ipairs(suites) do
    local suite_name, tests = normalize_suite(suite, suite_index)
    local suite_timer = _start_timer()
    local suite_case_count = 0
    for case_index, test in ipairs(tests) do
      local case_name, run, case_opts = normalize_case(test, case_index, suite_name)
      local full_name = suite_name .. "." .. case_name
      local context = {
        suite = suite,
        suite_index = suite_index,
        suite_name = suite_name,
        suite_module = suite and suite.module_name or nil,
        case_name = case_name,
        full_name = full_name,
        case_opts = case_opts,
      }
      total = total + 1
      suite_case_count = suite_case_count + 1
      math.randomseed(1)
      local timer = _start_timer()
      local before_ok, before_err = _run_hook(opts.before_case, context)
      local ok = before_ok
      local err = before_err
      local captured = { lines = {} }
      if before_ok then
        ok, err, captured = log_capture.capture(run, { enabled = capture_logs })
      end
      local after_ok, after_err = _run_hook(opts.after_case, context, ok, err, captured)
      if ok and not after_ok then
        ok = false
        err = after_err
      end
      local elapsed_ms = _elapsed_ms(timer)
      context.elapsed_ms = elapsed_ms
      case_times[#case_times + 1] = {
        name = full_name,
        suite_name = suite_name,
        elapsed_ms = elapsed_ms,
        timer_source = timer.source,
      }
      if elapsed_ms >= slow_ms then
        slow_cases[#slow_cases + 1] = {
          name = full_name,
          ms = elapsed_ms,
        }
      end
      if ok then
        log_capture.collect_summary(summary, captured)
        reporter.case_pass(full_name, captured)
      else
        reporter.case_fail(full_name, err, captured)
        failures[#failures + 1] = {
          name = full_name,
          err = err,
          captured = captured,
        }
      end
    end
    suite_times[#suite_times + 1] = {
      name = suite_name,
      elapsed_ms = _elapsed_ms(suite_timer),
      case_count = suite_case_count,
      timer_source = suite_timer.source,
    }
  end

  if #slow_cases > 0 and not quiet then
    print("")
    print("Slow cases (>= " .. tostring(slow_ms) .. "ms):")
    table.sort(slow_cases, function(left, right)
      return left.ms > right.ms
    end)
    for _, entry in ipairs(slow_cases) do
      print(string.format("  [%5dms] %s", entry.ms, entry.name))
    end
  end

  reporter.finish(summary, failures)

  local result = {
    total = total,
    failures = failures,
    failed = #failures > 0,
    summary = summary,
    slow_cases = slow_cases,
    timing_data = {
      total_elapsed_ms = _elapsed_ms(total_timer),
      suite_times = suite_times,
      case_times = case_times,
      timer_source = total_timer.source,
    },
  }

  if #failures > 0 and opts.raise_on_failure ~= false then
    if not quiet then
      io.stdout:write("\n")
      print(string.format(
        "%s failed (%d/%d)",
        tostring(summary_label),
        #failures,
        total
      ))
      for i, failure in ipairs(failures) do
        print(tostring(i) .. ") " .. failure.name)
        if failure.captured and failure.captured.lines and #failure.captured.lines > 0 then
          log_capture.replay(failure.captured)
        end
        print(failure.err)
      end
    end
    error("regression failed")
  end

  if #failures == 0 and not quiet then
    print(string.format("\nAll %s checks passed (%d)", tostring(summary_label), total))
  end

  return result
end

return { run_all = run_all, quiet_reporter = _quiet_reporter }
