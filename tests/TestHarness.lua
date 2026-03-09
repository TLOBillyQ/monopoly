require("tests.bootstrap")

local log_capture = require("tests.support.log_capture")

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

local function run_all(suites, opts)
  opts = opts or {}
  local reporter = opts.reporter or _default_reporter()
  local total = 0
  local failures = {}
  local summary = {}
  local capture_logs = opts.capture_logs ~= false and os.getenv("MONO_TEST_VERBOSE") ~= "1"

  for suite_index, suite in ipairs(suites) do
    local suite_name, tests = normalize_suite(suite, suite_index)
    for case_index, test in ipairs(tests) do
      local case_name, run, case_opts = normalize_case(test, case_index, suite_name)
      if not _is_case_disabled(case_opts, opts.mode) then
        local full_name = suite_name .. "." .. case_name
        total = total + 1
        math.randomseed(1)
        local ok, err, captured = log_capture.capture(run, { enabled = capture_logs })
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

  reporter.finish(summary, failures)

  if #failures > 0 then
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

  print("\nAll regression checks passed (" .. tostring(total) .. ")")
end

return { run_all = run_all }
