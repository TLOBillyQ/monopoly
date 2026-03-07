local constants = require("Config.generated.constants")
local vehicle_catalog = require("src.core.config.vehicle_catalog")

local common = {}

common.constants = constants
common.vehicle_catalog = vehicle_catalog
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
