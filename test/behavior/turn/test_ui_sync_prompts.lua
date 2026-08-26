local suite = require("test.support.scenario_suites.ui_sync.prompts")

-- 场景 suite 循环改写：case.run 无参调用,方法 key 以 test_ 前缀动态生成,
-- LuaUnit 按方法名字典序执行,各 case 相互独立无顺序依赖。
TestUiSyncPrompts = {}

for _, case in ipairs(suite.tests or suite) do
  TestUiSyncPrompts["test_" .. case.name] = function(self)
    case.run()
  end
end


return TestUiSyncPrompts
