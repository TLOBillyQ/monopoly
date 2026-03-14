local status_ops = require("src.state.player_state_ops.status_ops")
local balance_ops = require("src.state.player_state_ops.balance_ops")
local deity_ops = require("src.state.player_state_ops.deity_ops")
local vehicle_ops = require("src.state.player_state_ops.vehicle_ops")
local location_ops = require("src.state.player_state_ops.location_ops")

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
