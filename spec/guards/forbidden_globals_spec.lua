---@diagnostic disable: undefined-global
require("spec.bootstrap").install_package_paths()

local forbidden_globals = require("spec.guards.lib.forbidden_globals")

local function _build_violation_report(violations)
  local lines = {}
  for _, violation in ipairs(violations or {}) do
    lines[#lines + 1] =
      "forbidden_globals: "
      .. tostring(violation.path)
      .. ":"
      .. tostring(violation.line)
      .. " uses "
      .. tostring(violation.name)
      .. " (use "
      .. tostring(violation.replacement)
      .. " instead)"
    lines[#lines + 1] = "  " .. tostring(violation.text)
  end
  return table.concat(lines, "\n")
end

describe("guard: forbidden_globals", function()
  it("forbidden globals are not used", function()
    local result = forbidden_globals.run()
    local ok = result ~= nil and result.ok == true

    local full_report
    if ok then
      full_report = result.message or "forbidden_globals ok"
    elseif result and result.error then
      full_report = "forbidden_globals error: " .. tostring(result.error)
    else
      full_report = _build_violation_report(result and result.violations or {})
    end

    assert.is_true(ok, full_report)
  end)
end)
