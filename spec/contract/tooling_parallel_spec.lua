---@diagnostic disable: undefined-global, undefined-field

require("spec.bootstrap").install_package_paths()

local support = require("spec.support.tooling_parallel")._test_support

local function suite(module_name, tests)
  return {
    module_name = module_name,
    tests = tests or { { name = "default" } },
  }
end

describe("tooling_parallel contract", function()
  it("auto_workers_windows", function()
    assert.equals(1, support.resolve_worker_count(nil, 0, true))
    assert.equals(1, support.resolve_worker_count(nil, 2, true))
    assert.equals(1, support.resolve_worker_count(nil, 5, true))
  end)

  it("auto_workers_non_windows", function()
    assert.equals(1, support.resolve_worker_count(nil, 0, false))
    assert.equals(3, support.resolve_worker_count(nil, 4, false))
    assert.equals(2, support.resolve_worker_count("2", 5, false))
  end)

  it("suite_cost_hints", function()
    assert.equals(40, support.suite_cost(suite("spec.support.tooling_suites.architecture.arch_view_live_tooling_contract")))
    assert.equals(2, support.suite_cost(suite("unmapped", { { name = "one" }, { name = "two" } })))
  end)

  it("rounds_cover_all_suites", function()
    local suites = {
      suite("spec.support.tooling_suites.architecture.arch_view_live_tooling_contract"),
      suite("spec.support.tooling_suites.architecture.mutate4lua_tooling_contract"),
    }
    local plan = support.build_execution_plan(suites, 3)
    local seen = {}

    for _, round in ipairs(plan.rounds) do
      for _, entry in ipairs(round) do
        local identity = entry.module_name
        assert.is_true(not seen[identity])
        seen[identity] = true
      end
    end

    for _, entry in ipairs(suites) do
      assert.is_true(seen[entry.module_name] == true)
    end

    assert.is_true(#plan.rounds > 0)
    assert.equals(2, plan.worker_total)
  end)
end)
