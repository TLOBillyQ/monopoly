local suite = require("test.support.scenario_suites.bankruptcy.tile_owner")

-- 原生 LuaUnit 迁移:场景套件循环拍平 —— 每个 case 生成一个 test_ 前缀方法
-- (LuaUnit 方法名必须以 test 开头),无参调用 case.run(),用例数与改写前一一
-- 对应(12 例)。

TestBankruptcyTileOwner = {}

for _, case in ipairs(suite.tests or suite) do
  TestBankruptcyTileOwner["test_" .. case.name] = function(self)
    case.run()
  end
end


return TestBankruptcyTileOwner
