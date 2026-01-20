local bootstrap = require("bootstrap")
bootstrap()

local logger = require("src.util.logger")
local Game = require("src.game")
local EggyLayer = require("src.adapters.eggy.eggy_layer")

local function create_game()
  return Game.new({
    players = { "玩家1", "AI2", "AI3", "AI4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = true,
  })
end

logger.clear()

local layer = EggyLayer.new({ game_factory = create_game })
layer:set_game(layer:new_game())

layer:tick_once(0.1)
layer:tick_once(0.1)
