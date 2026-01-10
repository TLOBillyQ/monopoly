package.path = "src/?.lua;src/?/init.lua;?.lua;" .. package.path

local App = require("src.app")
local logger = require("src.services.logger")

local game = App.new({
  players = { "玩家1", "AI2", "AI3", "AI4" },
  ai = { [2] = true, [3] = true, [4] = true },
  auto_all = true,
})

logger.info("启动蛋仔大富翁，玩家数:", #game.players)
game:run(30)

logger.info("最终资金榜：")
for _, p in ipairs(game.players) do
  logger.info(p.name .. " 现金=" .. p.cash .. " 净资产估算=" .. p:net_worth(game.board))
end
