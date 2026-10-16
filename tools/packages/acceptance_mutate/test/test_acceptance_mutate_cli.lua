---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/acceptance_mutate/test/test_acceptance_mutate_cli.lua") end
require("test.bootstrap").install_package_paths()
local check = require("luassert")
local proc = require("foundation.proc")
local lua = require("foundation.lua54").lua54_bin()

describe("acceptance mutate native cli", function()
  it("help describes native execution and availability", function()
    local result = proc.run_command({ lua, "tools/cli.lua", "acceptance-mutate", "--help" })
    check.same(0, result.code, result.output)
    check.matches("原生 Windows 支持", result.output, 1, true)
    check.matches("--skip-if-unavailable", result.output, 1, true)
  end)

  it("cli and absolute lane report a missing feature as a real failure", function()
    local root = require("foundation.bootstrap").resolve("tools/packages/acceptance_mutate/mutate_lane.lua").repo_root
    for _, command in ipairs({
      { lua, "tools/cli.lua", "acceptance-mutate", "--feature", "missing.feature" },
      { lua, root .. "/tools/packages/acceptance_mutate/mutate_lane.lua", "--feature", "missing.feature" },
      { lua, "tools/cli.lua", "acceptance-mutate", "--skip-if-unavailable", "--feature", "missing.feature" },
    }) do
      local result = proc.run_command(command)
      check.same(1, result.code, result.output)
      check.matches("feature", result.output, 1, true)
      check.is_nil(result.output:find("status=unavailable", 1, true))
      check.is_nil(result.output:find("status=skipped", 1, true))
    end
  end)
end)
