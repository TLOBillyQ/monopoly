local bootstrap = require("tests.bootstrap")
local catalog = require("tests.catalog")
local log_capture = require("tests.support.log_capture")

local M = {}

local function _run_script(script, summary)
  local guard_module = require(script.module_name)
  local ok, result, captured = log_capture.capture(function()
    return guard_module.run()
  end, {
    enabled = os.getenv("MONO_TEST_VERBOSE") ~= "1",
  })

  if ok and type(result) == "table" and result.ok == true then
    io.stdout:write(".")
    log_capture.collect_summary(summary, captured)
    if result.message then
      summary[result.message] = (summary[result.message] or 0) + 1
    end
    return nil
  end

  local failure = {
    name = script.name,
    result = result,
    err = ok and nil or result,
    captured = captured,
  }
  io.stdout:write("F")
  return failure
end

function M.run()
  bootstrap.install_package_paths()
  local failures = {}
  local summary = {}

  for _, script in ipairs(catalog.guard_scripts) do
    local failure = _run_script(script, summary)
    if failure then
      failures[#failures + 1] = failure
    end
  end

  if #failures > 0 then
    io.stdout:write("\n")
    print("Guard checks failed (" .. tostring(#failures) .. "/" .. tostring(#catalog.guard_scripts) .. ")")
    for index, failure in ipairs(failures) do
      print(tostring(index) .. ") " .. failure.name)
      if type(failure.result) == "table" and failure.result.error then
        print(failure.result.error)
      elseif failure.err then
        print(failure.err)
      end
      log_capture.replay(failure.captured)
    end
    error("guard checks failed")
  end

  io.stdout:write("\n")
  for _, line in ipairs(log_capture.summary_lines(summary)) do
    print("[guard] suppressed x" .. tostring(line.count) .. " " .. line.text)
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
