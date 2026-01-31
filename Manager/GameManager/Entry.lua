local Runtime = require("Manager.System.Runtime")
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
  logger.configure_game_time()
  return Runtime.install({ game_factory = create_game })
end

return Entry
