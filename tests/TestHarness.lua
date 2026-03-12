require("tests.bootstrap")

local log_capture = require("tests.support.log_capture")
local number_utils = require("src.core.utils.number_utils")
local runtime_ports = require("src.core.ports.runtime_ports")
local unpack_args = table.unpack or unpack

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

local function _is_case_disabled(test, mode)
  local disabled_in = test and test.disabled_in
  return type(disabled_in) == "table" and disabled_in[mode] == true
end

local function _default_reporter()
  return {
    case_pass = function()
      io.stdout:write(".")
    end,
    case_fail = function()
      io.stdout:write("F")
    end,
    finish = function(summary)
      local lines = log_capture.summary_lines(summary)
      if #lines > 0 then
        print("")
        for _, line in ipairs(lines) do
          print("[captured] suppressed x" .. tostring(line.count) .. " " .. line.text)
        end
      end
    end,
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
  return {
    cpu = runtime_ports.cpu_now_seconds(),
    wall = runtime_ports.wall_now_seconds(),
  }
end

local function _elapsed_ms(timer)
  local cpu_elapsed = runtime_ports.cpu_diff_seconds(runtime_ports.cpu_now_seconds(), timer.cpu)
  local wall_elapsed = runtime_ports.wall_diff_seconds(runtime_ports.wall_now_seconds(), timer.wall)
  local elapsed_seconds = cpu_elapsed
  if elapsed_seconds <= 0 and wall_elapsed > 0 then
    elapsed_seconds = wall_elapsed
  end
  return math.floor(elapsed_seconds * 1000)
end

local function run_all(suites, opts)
  opts = opts or {}
  local reporter = opts.reporter or _default_reporter()
  local total = 0
  local failures = {}
  local summary = {}
  local slow_cases = {}
  local slow_ms = number_utils.to_integer(os.getenv("MONO_TEST_SLOW_MS")) or 500
  local capture_logs = opts.capture_logs ~= false and os.getenv("MONO_TEST_VERBOSE") ~= "1"

  for suite_index, suite in ipairs(suites) do
    local suite_name, tests = normalize_suite(suite, suite_index)
    for case_index, test in ipairs(tests) do
      local case_name, run, case_opts = normalize_case(test, case_index, suite_name)
      if not _is_case_disabled(case_opts, opts.mode) then
        local full_name = suite_name .. "." .. case_name
        local context = {
          suite_name = suite_name,
          case_name = case_name,
          full_name = full_name,
          case_opts = case_opts,
          mode = opts.mode,
        }
        total = total + 1
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
    end
  end

  if #slow_cases > 0 then
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
  }

  if #failures > 0 and opts.raise_on_failure ~= false then
    io.stdout:write("\n")
    print("Regression failed (" .. tostring(#failures) .. "/" .. tostring(total) .. ")")
    for i, failure in ipairs(failures) do
      print(tostring(i) .. ") " .. failure.name)
      if failure.captured and failure.captured.lines and #failure.captured.lines > 0 then
        log_capture.replay(failure.captured)
      end
      print(failure.err)
    end
    error("regression failed")
  end

  if #failures == 0 then
    print("\nAll regression checks passed (" .. tostring(total) .. ")")
  end

  return result
end

return { run_all = run_all }
