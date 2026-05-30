---@diagnostic disable: undefined-global
require("spec.bootstrap").install_package_paths()

local fixed_type_guard = require("spec.guards.lib.fixed_type_guard")

local function _build_violation_report(violations)
  local lines = {}
  for _, violation in ipairs(violations or {}) do
    lines[#lines + 1] =
      "fixed_type_guard: "
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

describe("guard: fixed_type_guard", function()
  it("fixed literals use float format", function()
    local result = fixed_type_guard.run()
    local ok = result ~= nil and result.ok == true

    local full_report
    if ok then
      full_report = result.message or "fixed_type_guard ok"
    elseif result and result.error then
      full_report = "fixed_type_guard error: " .. tostring(result.error)
    else
      full_report = _build_violation_report(result and result.violations or {})
    end

    assert.is_true(ok, full_report)
  end)
end)
