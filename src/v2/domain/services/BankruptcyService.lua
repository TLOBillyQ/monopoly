local common = require("src.v2.domain.services.Common")

local bankruptcy_service = {}

local function _reset_owned_tiles(state, seat)
  for tile_id, tile_state in pairs(state.board.tile_states or {}) do
    if tile_state.owner_id == seat then
      tile_state.owner_id = nil
      tile_state.level = 0
    end
  end
end

function bankruptcy_service.eliminate(state, seat)
  local player = state.players[seat]
  if not player or player.eliminated then
    return false
  end
  _reset_owned_tiles(state, seat)
  player.properties = {}
  common.clear_inventory(player)
  player.eliminated = true
  player.cash = 0
  player.seat_vehicle_id = nil
  return true
end

function bankruptcy_service.eliminate_if_needed(state, seat)
  local player = state.players[seat]
  if not player then
    return false
  end
  if (player.cash or 0) >= 0 then
    return false
  end
  return bankruptcy_service.eliminate(state, seat)
end

return bankruptcy_service
