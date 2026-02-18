local status_ops = require("src.game.core.runtime.player_state.StatusOps")
local balance_ops = require("src.game.core.runtime.player_state.BalanceOps")
local deity_ops = require("src.game.core.runtime.player_state.DeityOps")
local vehicle_ops = require("src.game.core.runtime.player_state.VehicleOps")
local location_ops = require("src.game.core.runtime.player_state.LocationOps")

local game_state_players = {}

local groups = {
  status_ops,
  balance_ops,
  deity_ops,
  vehicle_ops,
  location_ops,
}

for _, group in ipairs(groups) do
  for key, fn in pairs(group) do
    game_state_players[key] = fn
  end
end

return game_state_players
