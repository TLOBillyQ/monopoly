local bootstrap = require("tests.bootstrap")
local tooling_parallel = require("tests.support.tooling_parallel")

bootstrap.install_package_paths()

local support = tooling_parallel._test_support

local function _assert_equal(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
  end
end

local function _suite(module_name, tests)
  return {
    module_name = module_name,
    tests = tests or { { name = "default" } },
  }
end

local function _test_auto_workers_windows()
  _assert_equal(support.resolve_worker_count(nil, 0, true), 1, "windows auto should floor at 1 even with zero suites")
  _assert_equal(support.resolve_worker_count(nil, 2, true), 2, "windows auto should cap at 2")
  _assert_equal(support.resolve_worker_count(nil, 5, true), 2, "windows auto should not exceed configured max")
end

local function _test_auto_workers_non_windows()
  _assert_equal(support.resolve_worker_count(nil, 0, false), 1, "non-windows auto floors at 1")
  _assert_equal(support.resolve_worker_count(nil, 4, false), 3, "non-windows auto caps at 3")
  _assert_equal(support.resolve_worker_count("2", 5, false), 2, "explicit workers must be honored")
end

local function _test_suite_cost_hints_and_fallback()
  _assert_equal(support.suite_cost(_suite("suites.architecture.arch_view_live_tooling_contract")), 40, "live suite should hit hint")
  _assert_equal(support.suite_cost(_suite("suites.architecture.script_tools_io_tooling_contract")), 28, "IO suite should hit hint")
  local fallback = support.suite_cost(_suite("unmapped", { { name = "one" }, { name = "two" } }))
  if fallback ~= 2 then
    error("fallback should use #tests when no hint: " .. tostring(fallback))
  end
end

local function _test_build_execution_plan_distribution()
  local suites = {
    _suite("suites.architecture.arch_view_live_tooling_contract"),
    _suite("suites.architecture.script_tools_io_tooling_contract"),
    _suite("suites.architecture.script_tools_mutate_tooling_contract"),
    _suite("suites.architecture.mutate4lua_tooling_contract"),
  }
  local plan = support.build_execution_plan(suites, 3)
  local seen = {}
  for _, round in ipairs(plan.rounds) do
    for _, suite in ipairs(round) do
      local identity = suite.module_name
      if seen[identity] then
        error("suite repeated in rounds: " .. identity)
      end
      seen[identity] = true
    end
  end
  for _, suite in ipairs(suites) do
    if not seen[suite.module_name] then
      error("suite missing from rounds: " .. suite.module_name)
    end
  end
  if #plan.rounds == 0 then
    error("plan produced zero rounds")
  end
  if plan.worker_total ~= 3 then
    error("worker_total should equal requested lanes when suites >= lanes")
  end
end

return {
  name = "tooling_parallel_contract",
  tests = {
    { name = "auto_workers_windows", run = _test_auto_workers_windows },
    { name = "auto_workers_non_windows", run = _test_auto_workers_non_windows },
    { name = "suite_cost_hints", run = _test_suite_cost_hints_and_fallback },
    { name = "rounds_cover_all_suites", run = _test_build_execution_plan_distribution },
  },
}
