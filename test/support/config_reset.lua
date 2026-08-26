local logger = require("src.foundation.log")

local M = {}

local _mutable_singleton_configs = {
  require("src.config.content.constants"),
  require("src.config.gameplay.debug_flags"),
}

function M.reset_all()
  for _, config in ipairs(_mutable_singleton_configs) do
    if type(config) == "table" and type(config.reset) == "function" then
      config.reset()
    end
  end

  -- logger.test_mode 也是全局可变状态,但它不是 config、没有 reset(),于是一直漏在
  -- 复位机制之外。测试基线是 true(test/support/env.lua 在 require 时设一次),
  -- 而多条 spec 会临时切到 false 去演练生产期行为却从不恢复 —— turn_timer_policy_spec
  -- 有几十处 set_test_mode(false),log_spec 的 after_each 也把它留在 false。
  --
  -- 于是 test_mode 会顺着执行序泄漏:谁排在污染者后面,谁就在 test_mode=false 下跑。
  -- lifecycle_spec 那条「待决选择跨回合必须硬失败」的不变量正是这么失灵的 —— 它在
  -- busted 的顺序下侥幸躲过,在 mutate driver 的 harness 顺序下当场变红,导致整个变异
  -- 车道在 main 上就跑不动(基线回归红,--mutate-all 无法启动)。
  --
  -- 复位到基线,泄漏就止于每个 case 的边界,不再取决于谁先谁后。
  logger.set_test_mode(true)
end

return M
