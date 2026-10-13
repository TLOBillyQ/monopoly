local suite = require("test.support.scenario_suites.movement.relocation")
require("test.bootstrap").install_package_paths()
local luassert = assert(require("test.support.luassert_loader").load())
local support = require("test.support.shared_support")

TestRelocation = {}

for _, case in ipairs(suite.tests or suite) do
  TestRelocation["test_" .. case.name] = function(self)
    case.run()
  end
end

TestRelocationDirect = {}

function TestRelocationDirect:test_relocate_without_destination_errors()
  local game = support.new_game()
  local ok, err = pcall(function()
    game:player_relocate(game.players[1], {})
  end)

  luassert.is_false(ok, "relocate without a destination should fail")
  luassert.truthy(tostring(err):find("missing relocation destination", 1, true) ~= nil,
    "relocate error should name the missing destination")
end


-- mutate 车道统一返回全部类（#283 多类文件 return 首类假幸存方向）：
-- 正常车道扫 _G 收全部 Test* 类，但 mutate 内建 runner 只跑 return 的表，
-- 只 return 首个类会让其余类的用例在变异车道完全不执行。合并全部类，
-- 每个 test* 方法跑所属类 setUp/tearDown（见 multi_class_return）。
return require("test.support.multi_class_return").merge(
  TestRelocation,
  TestRelocationDirect
)
