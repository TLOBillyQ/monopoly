package.path = package.path .. ";./?/init.lua"

local function normalize_suite(suite, suite_index)
  if suite and suite.tests then
    return suite.name or ("suite_" .. tostring(suite_index)), suite.tests
  end
  return "suite_" .. tostring(suite_index), suite or {}
end

local function normalize_case(test, case_index, suite_name)
  if type(test) == "function" then
    return "case_" .. tostring(case_index), test
  end
  if type(test) == "table" and type(test.run) == "function" then
    return test.name or ("case_" .. tostring(case_index)), test.run
  end
  error("invalid test case in " .. tostring(suite_name) .. " at index " .. tostring(case_index))
end

local function run_all(suites)
  local total = 0
  local failures = {}

  for suite_index, suite in ipairs(suites) do
    local suite_name, tests = normalize_suite(suite, suite_index)
    for case_index, test in ipairs(tests) do
      local case_name, run = normalize_case(test, case_index, suite_name)
      local full_name = suite_name .. "." .. case_name
      total = total + 1
      math.randomseed(1)
      local ok, err = xpcall(run, debug.traceback)
      if ok then
        io.stdout:write(".")
      else
        io.stdout:write("F")
        failures[#failures + 1] = {
          name = full_name,
          err = err,
        }
      end
    end
  end

  if #failures > 0 then
    io.stdout:write("\n")
    print("Regression failed (" .. tostring(#failures) .. "/" .. tostring(total) .. ")")
    for i, failure in ipairs(failures) do
      print(tostring(i) .. ") " .. failure.name)
      print(failure.err)
    end
    error("regression failed")
  end

  print("\nAll regression checks passed (" .. tostring(total) .. ")")
end

return { run_all = run_all }
