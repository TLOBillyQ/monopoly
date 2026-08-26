local dsl = require("packages.acceptance.step_dsl")
local game_driver = require("packages.acceptance.game_driver")

-- 跨域通用背景步骤：多个 feature 域共用的世界初始化句面住这里，
-- 域专属句面一律回各自模块。
return dsl.steps({
  ["游戏已初始化标准棋盘"] = function(world)
    world.driver = game_driver.new_game()
    return true
  end,
}, { name = "common" })
