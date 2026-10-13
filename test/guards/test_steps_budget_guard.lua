---@diagnostic disable: undefined-global
require("test.bootstrap").install_package_paths()

local luassert = assert
local guard = require("test.guards.lib.steps_budget_guard")

local function _content(lines)
  return string.rep("x\n", lines)
end

describe("TestStepsBudgetGuard", function()
  it("test_预算内全绿", function()
    local violations, total = guard.check(
      { "features/steps/a.lua", "features/steps/b.lua" },
      function() return _content(10) end,
      100
    )
    luassert.is.equal(0, #violations)
    luassert.is.equal(20, total)
  end)

  it("test_超预算即红,报文含合计与预算", function()
    local violations = guard.check(
      { "features/steps/a.lua" },
      function() return _content(101) end,
      100
    )
    luassert.is.equal(1, #violations)
    luassert.truthy(violations[1]:find("101"))
    luassert.truthy(violations[1]:find("100"))
  end)

  it("test_读不到文件按错误报出", function()
    local violations = guard.check(
      { "features/steps/a.lua" },
      function() return nil end,
      100
    )
    luassert.is.equal(1, #violations)
    luassert.truthy(violations[1]:find("读不到"))
  end)

  it("test_非 lua 文件不计入", function()
    local violations, total = guard.check(
      { "features/steps/notes.txt" },
      function() return _content(9999) end,
      100
    )
    luassert.is.equal(0, #violations)
    luassert.is.equal(0, total)
  end)

  it("test_run() 对真实仓库全绿(当前基线在预算内)", function()
    local result = guard.run()
    luassert.is_true(result.ok, result.error)
  end)
end)
