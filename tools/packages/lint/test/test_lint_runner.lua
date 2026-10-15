---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/lint/test/test_lint_runner.lua") end
require("test.bootstrap").install_package_paths()

local check = require("luassert")
local availability = require("foundation.tool_availability")
local runner = require("packages.lint.runner")

-- 经注入缝替换 luacheck 自举跑一次 lint;自举失败时 luacheck 不得被拉起。
local function _execute_with_luacheck_bootstrap(ensure)
  return runner.execute({
    targets = { "tools/packages/lint" },
    ensure_luacheck_tree = ensure,
    run_command = function() error("luacheck must not run when its bootstrap failed") end,
  })
end

describe("lint runner bootstrap", function()

-- #112:luacheck 装不上(网络)是不可用,不是 lint 失败——退 3,诊断点名工具与步骤。
it("luacheck install network failure reports unavailable", function()
  local result = _execute_with_luacheck_bootstrap(function()
    local detail = "luarocks install failed for luacheck: Error: Failed downloading luacheck"
    return nil, detail, availability.unavailable("luacheck", "install", detail)
  end)
  check.equal(3, result.code)
  check.equal("", result.stdout)
  check.matches("[lint] status=unavailable tool=luacheck step=install", result.stderr, 1, true)
  check.matches("未运行", result.stderr, 1, true)
  check.matches("Failed downloading luacheck", result.stderr, 1, true)
end)

it("non network bootstrap failure stays a real failure", function()
  local result = _execute_with_luacheck_bootstrap(function() return nil, "mkdir failed" end)
  check.equal(1, result.code)
  check.equal("mkdir failed\n", result.stderr)
end)

end)
