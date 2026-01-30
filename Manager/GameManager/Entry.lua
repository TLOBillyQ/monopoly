local EggyLayer = require("Manager.TurnManager.GUI.Layer")
local Game = require("Manager.GameManager.Game")
local logger = require("Library.Monopoly.Logger")

local Entry = {}

local function create_game()
  return Game.new({
    players = { "玩家1", "AI2", "AI3", "AI4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = true,
    seed = GameAPI.get_timestamp(),
  })
end

function Entry.install()
  logger.configure_game_time(GameAPI)
  local layer = EggyLayer.new({ game_factory = create_game })
  layer:install_game_init()
  layer:start_tick_loop()
  return layer
end

return Entry
