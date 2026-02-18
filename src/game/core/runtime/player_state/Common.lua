local constants = require("Config.Generated.Constants")
local vehicles_cfg = require("Config.Generated.Vehicles")

local common = {}

local vehicle_by_id = {}
for _, cfg in ipairs(vehicles_cfg) do
  vehicle_by_id[cfg.id] = cfg
end

common.constants = constants
common.vehicle_by_id = vehicle_by_id
common.default_vehicle_cfg = {
  id = 0,
  name = "",
  dice_count = constants.default_dice_count,
  indestructible = false,
}

function common.player_status_table(player)
  player.status = player.status or {}
  return player.status
end

function common.normalize_currency(currency)
  assert(currency ~= nil and currency ~= "", "missing currency")
  return currency
end

function common.mark_players(game)
  game.dirty.any = true
  game.dirty.players = true
end

return common
