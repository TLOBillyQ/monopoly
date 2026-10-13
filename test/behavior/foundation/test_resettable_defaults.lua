require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
-- resettable_defaults 是 constants / debug_flags 收敛后的共同模块体。reset() 的语义
-- (清掉调用方后加的键、铺回默认值、且 reset 自身不被清掉)原先分散在两个 config 文件里,
-- 现在只有这一处实现——全仓测试的隔离性都压在它身上:test/support/config_reset 每个
-- before_each 都调它,漏一条语义就是跨 case 的状态泄漏。
--
-- 它没有可变异位点(纯表操作,无比较无字面量分支),变异测试护不住,只能靠直接 spec。

local resettable_defaults = require("src.foundation.resettable_defaults")

local function _assert_eq(a, b, msg) luassert.is.equal(b, a, msg) end


describe("TestResettableDefaults", function()

  it("test_exposes_the_defaults_on_the_built_module", function()
    local built = resettable_defaults.build({ alpha = 1, beta = "two" })

    _assert_eq(built.alpha, 1, "numeric default should be readable")
    _assert_eq(built.beta, "two", "string default should be readable")
  end)

  it("test_restores_an_overwritten_default_on_reset", function()
    local built = resettable_defaults.build({ alpha = 1 })
    built.alpha = 99

    built.reset()

    _assert_eq(built.alpha, 1, "an overwritten default must go back to its default value")
  end)

  it("test_drops_keys_the_caller_added_on_reset", function()
    local built = resettable_defaults.build({ alpha = 1 })
    built.injected = "test-only"

    built.reset()

    _assert_eq(built.injected, nil, "a caller-added key must not survive reset")
    _assert_eq(built.alpha, 1, "defaults must still be present after the wipe")
  end)

  it("test_keeps_reset_callable_across_repeated_resets", function()
    local built = resettable_defaults.build({ alpha = 1 })

    -- reset 挂在元表 __index 上正是为了躲开它自己的清扫。掉进表体就会被第一次
    -- reset 抹掉,第二次调用直接炸——而每个 before_each 都要调一次。
    built.reset()
    built.alpha = 42
    built.reset()

    _assert_eq(built.alpha, 1, "reset must stay usable after the first call")
  end)

  it("test_gives_each_built_module_its_own_state", function()
    local first = resettable_defaults.build({ alpha = 1 })
    local second = resettable_defaults.build({ alpha = 1 })

    first.alpha = 99

    _assert_eq(second.alpha, 1, "two built modules must not share a table")
    first.reset()
    _assert_eq(first.alpha, 1, "resetting one module must not need the other")
  end)


end)
