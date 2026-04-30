local constants = require("src.config.content.constants")
local tables = require("src.foundation.lang.tables")

local common = {}

common.constants = constants

function common.player_status_table(player)
  player.status = player.status or {}
  return player.status
end

function common.normalize_currency(currency)
  return tables.normalize_currency(currency)
end

function common.mark_players(game)
  game.dirty.any = true
  game.dirty.players = true
end

return common
