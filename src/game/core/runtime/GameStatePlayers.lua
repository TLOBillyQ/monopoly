local status_ops = require("src.game.core.player.state_ops.StatusOps")
local balance_ops = require("src.game.core.player.state_ops.BalanceOps")
local deity_ops = require("src.game.core.player.state_ops.DeityOps")
local vehicle_ops = require("src.game.core.player.state_ops.VehicleOps")
local location_ops = require("src.game.core.player.state_ops.LocationOps")

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
