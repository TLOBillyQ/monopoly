---@diagnostic disable: undefined-global
require("spec.bootstrap").install_package_paths()

local agent_instructions = require("spec.guards.lib.agent_instructions")

describe("guard: agent_instructions", function()
  it("agent instructions checks pass", function()
    local result = agent_instructions.run()
    local ok = result ~= nil and result.ok == true
    local full_report = ok and (result.message or "agent_instructions ok")
      or (result and result.error or "agent_instructions failed")
    assert.is_true(ok, full_report)
  end)
end)
