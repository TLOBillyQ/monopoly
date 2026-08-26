if arg then rawset(arg, 0, "tools/packages/mutate/test/test_mutate4lua_tooling_contract.lua") end
local suite = require("test.support.tooling_suites.architecture.mutate4lua_tooling_contract")

-- 原生 LuaUnit 迁移:套件循环拍平 —— 每个 case 生成一个 test_ 前缀方法
-- (LuaUnit 方法名必须以 test 开头),无参调用 case.run(),用例数与改写前
-- 一一对应(#361 P8 删 reference_cli 文本扫描后 8 例)。

TestMutate4luaToolingContract = {}

for _, case in ipairs(suite.tests or {}) do
  TestMutate4luaToolingContract["test_" .. case.name] = function(self)
    case.run()
  end
end


return TestMutate4luaToolingContract
