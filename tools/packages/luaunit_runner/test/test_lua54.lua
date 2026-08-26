---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/luaunit_runner/test/test_lua54.lua") end
require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local bin = require("packages.luaunit_runner.lua54")

TestBinSpec = {}

-- 默认后端 = LuaUnit 运行器({ lua5.4, tools/packages/luaunit_runner/runner.lua })。
-- 本模块是 lua54.lua，runner 路径同目录推导。
-- --busted-bin / BUSTED_BIN 逃生舱已删除：argv_prefix 无参数，
-- 恒返回默认后端,不读任何环境变量。
function TestBinSpec:test_argv_prefix_defaults_to_lua54_and_runner()
  local prefix = bin.argv_prefix()
  lu.assertEquals(#prefix, 2)
  lu.assertEvalToTrue(tostring(prefix[2]):find("runner%.lua$"))
  lu.assertEvalToTrue(tostring(prefix[2]):find("luaunit_runner", 1, true))
end

function TestBinSpec:test_runner_path_resolves_the_luaunit_runner_next_to_the_module()
  local path = bin.runner_path()
  lu.assertEvalToTrue(path:find("tools/packages/luaunit_runner/runner%.lua$"))
end


return TestBinSpec
