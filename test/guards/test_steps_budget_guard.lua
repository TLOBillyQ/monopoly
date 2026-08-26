---@diagnostic disable: undefined-global
require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local guard = require("test.guards.lib.steps_budget_guard")

local function _content(lines)
  return string.rep("x\n", lines)
end

TestStepsBudgetGuard = {}

TestStepsBudgetGuard["test_预算内全绿"] = function(self)
  local violations, total = guard.check(
    { "features/steps/a.lua", "features/steps/b.lua" },
    function() return _content(10) end,
    100
  )
  lu.assertIs(#violations, 0)
  lu.assertIs(total, 20)
end

TestStepsBudgetGuard["test_超预算即红,报文含合计与预算"] = function(self)
  local violations = guard.check(
    { "features/steps/a.lua" },
    function() return _content(101) end,
    100
  )
  lu.assertIs(#violations, 1)
  lu.assertEvalToTrue(violations[1]:find("101"))
  lu.assertEvalToTrue(violations[1]:find("100"))
end

TestStepsBudgetGuard["test_读不到文件按错误报出"] = function(self)
  local violations = guard.check(
    { "features/steps/a.lua" },
    function() return nil end,
    100
  )
  lu.assertIs(#violations, 1)
  lu.assertEvalToTrue(violations[1]:find("读不到"))
end

TestStepsBudgetGuard["test_非 lua 文件不计入"] = function(self)
  local violations, total = guard.check(
    { "features/steps/notes.txt" },
    function() return _content(9999) end,
    100
  )
  lu.assertIs(#violations, 0)
  lu.assertIs(total, 0)
end

TestStepsBudgetGuard["test_run() 对真实仓库全绿(当前基线在预算内)"] = function(self)
  local result = guard.run()
  lu.assertTrue(result.ok, result.error)
end


return TestStepsBudgetGuard
