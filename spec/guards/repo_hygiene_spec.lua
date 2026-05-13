---@diagnostic disable: undefined-global
require("spec.bootstrap").install_package_paths()

local repo_hygiene = require("spec.guards.lib.repo_hygiene")

describe("guard: repo_hygiene", function()
  it("repo hygiene checks pass", function()
    local result = repo_hygiene.run()
    local ok = result ~= nil and result.ok == true
    local full_report = ok and (result.message or "repo_hygiene ok")
      or (result and result.error or "repo_hygiene failed")
    assert.is_true(ok, full_report)
  end)
end)
