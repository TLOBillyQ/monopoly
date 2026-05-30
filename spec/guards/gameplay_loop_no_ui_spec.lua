---@diagnostic disable: undefined-global
require("spec.bootstrap").install_package_paths()

local gameplay_loop_no_ui = require("spec.guards.lib.gameplay_loop_no_ui")

describe("guard: gameplay_loop_no_ui", function()
  it("gameplay loop tick runs without ui", function()
    local result = gameplay_loop_no_ui.run()
    local ok = result ~= nil and result.ok == true
    local full_report = ok and (result.message or "tick ok")
      or ("gameplay_loop_no_ui error: " .. tostring(result and result.error or "unknown error"))
    assert.is_true(ok, full_report)
  end)
end)
