---@diagnostic disable: undefined-global
require("spec.bootstrap").install_package_paths()

local arch_view_guard = require("spec.guards.lib.arch_view_guard")

describe("guard: arch_view_guard", function()
  it("arch_view check passes", function()
    local result = arch_view_guard.run()
    local ok = result ~= nil and result.ok == true
    local full_report = ok and (result.message or "arch_view_guard ok")
      or (result and result.error or "arch_view_guard failed")
    assert.is_true(ok, full_report)
  end)
end)
