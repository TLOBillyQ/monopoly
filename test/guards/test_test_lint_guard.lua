---@diagnostic disable: undefined-global
require("test.bootstrap").install_package_paths()

-- luacheck: ignore 143 (genuine busted injects luassert)
local luassert = assert
local guard = require("test.guards.lib.test_lint.guard")

-- 每条 fixture 都是合成 spec 源码,过真实 luacheck parser 验证 guard:
-- 对「断言只躲在条件分支里」真的会红,对合规写法放行——门禁的价值全在能变红。

local function _check(files)
  local paths = {}
  for path in pairs(files) do
    paths[#paths + 1] = path
  end
  return guard.check(paths, function(path)
    return files[path]
  end)
end

-- cb44141 之前 runner_spawn_carries_tool_discovery_env 的空转写法(原型 fixture)。
local _VACUOUS_IF = [=[
local check = require("luassert")
describe("spec lane", function()
  it("runner_spawn_carries_tool_discovery_env", function()
    local captured_options
    run({ run_command = function(command, options)
      captured_options = options
      return { ok = true }
    end })
    check.equal(0, 0)
    if captured_options ~= nil then
      check.truthy(captured_options.env.LUA54_BIN)
    end
  end)
end)
]=]

-- cb44141 修复后的写法:if/else 两个分支都断言。
local _BOTH_BRANCHES = [=[
local check = require("luassert")
describe("spec lane", function()
  it("runner_spawn_carries_tool_discovery_env", function()
    local captured_options = run()
    local expected = discover()
    if expected == nil then
      check.is_nil(captured_options)
    else
      check.truthy(captured_options.env.LUA54_BIN)
    end
  end)
end)
]=]

describe("TestLintGuard", function()
  it("test_flags_pre_cb44141_vacuous_if_as_red", function()
    local violations = _check({ ["test/behavior/x/test_env.lua"] = _VACUOUS_IF })
    luassert.is.equal(1, #violations)
    local line = violations[1]
    luassert.truthy(line:find("vacuous%-branch"))
    luassert.truthy(line:find("test/behavior/x/test_env.lua", 1, true))
    luassert.truthy(line:find("runner_spawn_carries_tool_discovery_env", 1, true))
  end)

  it("test_reports_the_line_of_the_offending_if", function()
    local violations = _check({ ["test/behavior/x/test_env.lua"] = _VACUOUS_IF })
    luassert.truthy(violations[1]:find(":10 ", 1, true) ~= nil
      or violations[1]:find(":10[ %]]") ~= nil)
  end)

  it("test_accepts_if_else_when_both_branches_assert", function()
    luassert.is.equal(0, #_check({ ["test/behavior/x/test_env.lua"] = _BOTH_BRANCHES }))
  end)

  it("test_flags_if_else_with_assertion_free_else_branch", function()
    local violations = _check({
      ["test/behavior/x/test_branch.lua"] = [=[
local check = require("luassert")
it("one_sided", function()
  local ok = run()
  if ok then
    check.is_true(ok)
  else
    recover()
  end
end)
]=],
    })
    luassert.is.equal(1, #violations)
    luassert.truthy(violations[1]:find("one_sided", 1, true))
  end)

  it("test_accepts_helper_call_as_branch_assertion", function()
    -- helper 展开让 then 分支被认定为有断言;不展开的话这条会被误报成红。
    luassert.is.equal(0, #_check({
      ["test/behavior/x/test_helper.lua"] = [=[
local check = require("luassert")
local function assert_ok(result)
  check.equal(0, result.code)
end
it("helper_counts_in_branch", function()
  local result = run()
  if result.code ~= nil then
    assert_ok(result)
  else
    check.is_nil(result.code)
  end
end)
]=],
    }))
  end)

  it("test_flags_conditional_assertion_even_via_helper", function()
    local violations = _check({
      ["test/behavior/x/test_helper.lua"] = [=[
local check = require("luassert")
local function assert_ok(result)
  check.equal(0, result.code)
end
it("helper_still_conditional", function()
  local result = run()
  if result ~= nil then
    assert_ok(result)
  end
end)
]=],
    })
    luassert.is.equal(1, #violations)
    luassert.truthy(violations[1]:find("helper_still_conditional", 1, true))
  end)

  it("test_does_not_expand_helper_that_itself_only_calls_another_helper", function()
    -- 多层 helper 不展开(工单 out of scope):outer_helper 体里没有直接断言,
    -- 调用它不算断言,这条 if 子树无断言可判,放行而非误报。
    luassert.is.equal(0, #_check({
      ["test/behavior/x/test_indirect.lua"] = [=[
local check = require("luassert")
local function inner_assert(result)
  check.equal(0, result.code)
end
local function outer_helper(result)
  inner_assert(result)
end
it("indirect_helper_is_not_expanded", function()
  local result = run()
  check.equal(0, result.code)
  if result.extra ~= nil then
    outer_helper(result)
  end
end)
]=],
    }))
  end)

  it("test_accepts_exemption_with_reason_on_previous_line", function()
    luassert.is.equal(0, #_check({
      ["test/behavior/x/test_allow.lua"] = [=[
local check = require("luassert")
it("allowed", function()
  local captured = run()
  -- lint-allow: vacuous-branch 兼容探测两种形态都合法(#122)
  if captured ~= nil then
    check.truthy(captured.env)
  end
end)
]=],
    }))
  end)

  it("test_accepts_exemption_on_the_same_line", function()
    luassert.is.equal(0, #_check({
      ["test/behavior/x/test_allow.lua"] = [=[
local check = require("luassert")
it("allowed_inline", function()
  local captured = run()
  if captured ~= nil then -- lint-allow: vacuous-branch 兼容探测(#122)
    check.truthy(captured.env)
  end
end)
]=],
    }))
  end)

  it("test_flags_exemption_without_reason_as_red", function()
    local violations = _check({
      ["test/behavior/x/test_allow.lua"] = [=[
local check = require("luassert")
it("not_allowed", function()
  local captured = run()
  -- lint-allow: vacuous-branch
  if captured ~= nil then
    check.truthy(captured.env)
  end
end)
]=],
    })
    luassert.is.equal(2, #violations)
    luassert.truthy(violations[1]:find("lint%-allow"))
    luassert.truthy(violations[1]:find("缺豁免理由", 1, true))
  end)

  it("test_flags_old_style_test_table_with_vacuous_branch", function()
    local violations = _check({
      ["test/behavior/legacy/test_old.lua"] = [=[
local luassert = assert(require("test.support.luassert_loader").load())
TestOld = {}
function TestOld.test_vacuous()
  local result = run()
  if result.ok then
    luassert.is_true(result.ok)
  end
end
function TestOld.test_covered()
  luassert.is_true(true)
end
]=],
    })
    luassert.is.equal(1, #violations)
    luassert.truthy(violations[1]:find("TestOld.test_vacuous", 1, true))
  end)

  it("test_flags_old_style_table_constructor_form", function()
    local violations = _check({
      ["test/behavior/legacy/test_old.lua"] = [=[
local check = require("luassert")
local TestLegacy = {
  test_vacuous = function()
    local result = run()
    if result.ok then
      check.is_true(result.ok)
    end
  end,
  test_covered = function()
    check.is_true(true)
  end,
}
]=],
    })
    luassert.is.equal(1, #violations)
    luassert.truthy(violations[1]:find("TestLegacy.test_vacuous", 1, true))
  end)

  it("test_ignores_bodies_with_no_assertions_at_all", function()
    luassert.is.equal(0, #_check({
      ["test/behavior/x/test_smoke.lua"] = [=[
it("smoke", function()
  local result = run()
  if result.ok then
    touch(result)
  end
end)
]=],
    }))
  end)

  it("test_accepts_loop_only_assertions_as_covered_leniently", function()
    luassert.is.equal(0, #_check({
      ["test/behavior/x/test_loop.lua"] = [=[
local check = require("luassert")
it("loop", function()
  local items = collect()
  for i = 1, #items do
    check.truthy(items[i].ok)
  end
end)
]=],
    }))
  end)

  it("test_resolves_it_target_passed_as_local_function_reference", function()
    local violations = _check({
      ["tools/packages/x/test/test_ref.lua"] = [=[
local check = require("luassert")
local function vacuous_case()
  local captured = run()
  if captured ~= nil then
    check.truthy(captured.env)
  end
end
describe("suite", function()
  it("referenced_case", vacuous_case)
end)
]=],
    })
    luassert.is.equal(1, #violations)
    luassert.truthy(violations[1]:find("suite referenced_case", 1, true))
  end)

  it("test_skips_unresolvable_it_target_without_crashing", function()
    luassert.is.equal(0, #_check({
      ["test/behavior/x/test_dynamic.lua"] = [=[
it("dynamic", pick_case())
it("bare")
]=],
    }))
  end)

  it("test_flags_unreadable_spec_instead_of_silently_skipping_it", function()
    local violations = guard.check({ "test/behavior/x/test_gone.lua" }, function()
      return nil
    end)
    luassert.is.equal(1, #violations)
    luassert.truthy(violations[1]:find("读不到", 1, true))
  end)

  it("test_flags_unparsable_spec_instead_of_silently_skipping_it", function()
    local violations = _check({ ["test/behavior/x/test_broken.lua"] = "local =\n" })
    luassert.is.equal(1, #violations)
    luassert.truthy(violations[1]:find("解析失败", 1, true))
  end)

  it("test_ignores_non_spec_paths", function()
    local vacuous = _VACUOUS_IF
    luassert.is.equal(0, #_check({
      ["src/rules/test_helper.lua"] = vacuous,
      ["test/support/cases.lua"] = vacuous,
      ["tools/packages/dry/test/fixtures/ledger_a.lua"] = vacuous,
      ["tools/packages/dry/runner.lua"] = vacuous,
    }))
  end)

  it("test_scans_tools_test_specs", function()
    local violations = _check({ ["tools/packages/dry/test/test_dry.lua"] = _VACUOUS_IF })
    luassert.is.equal(1, #violations)
    luassert.truthy(violations[1]:find("tools/packages/dry/test/test_dry.lua", 1, true))
  end)

  it("test_violation_report_carries_guard_rule_path_line_and_test_name", function()
    local line = table.concat(_check({ ["test/behavior/x/test_env.lua"] = _VACUOUS_IF }), "\n")
    luassert.truthy(line:find("test_lint_guard: vacuous%-branch: test/behavior/x/test_env%.lua:%d+ %["))
  end)
end)
