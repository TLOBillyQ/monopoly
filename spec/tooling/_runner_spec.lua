---@diagnostic disable: undefined-global

require("spec.bootstrap").install_package_paths()

local tooling_parallel = require("spec.support.tooling_parallel")

local function suite(name)
  return {
    name = name,
    module_name = name,
    tests = {
      {
        name = "smoke",
        run = function()
          assert.is_true(true)
        end,
      },
    },
  }
end

describe("tooling_parallel runner", function()
  it("runs a minimal suite successfully", function()
    local result = tooling_parallel.run({ suite("spec.tooling.runner_smoke") }, { workers = 1 })

    assert.is_table(result)
    assert.is_false(result.failed)
  end)
end)
