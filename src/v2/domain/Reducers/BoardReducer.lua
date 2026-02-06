local events = require("src.v2.domain.Events")

local board_reducer = {}
local event_types = events.types

function board_reducer.apply(state, event)
  local payload = event.payload or {}
  local tile_id = payload.tile_id
  local tile_state = tile_id and state.board.tile_states[tile_id] or nil

  if event.type == event_types.land_bought or event.type == event_types.tile_owner_set then
    if tile_id == nil then
      return
    end
    if tile_state == nil then
      tile_state = { owner_id = nil, level = 0 }
      state.board.tile_states[tile_id] = tile_state
    end
    tile_state.owner_id = payload.owner_seat
    if payload.level ~= nil then
      tile_state.level = payload.level
    elseif event.type == event_types.land_bought then
      tile_state.level = 1
    end
    return
  end

  if event.type == event_types.land_upgraded or event.type == event_types.tile_level_set then
    if tile_id == nil then
      return
    end
    if tile_state == nil then
      tile_state = { owner_id = nil, level = 0 }
      state.board.tile_states[tile_id] = tile_state
    end
    local level = payload.level
    if type(level) ~= "number" then
      level = (tile_state.level or 0) + 1
    end
    tile_state.level = level
    return
  end

  if event.type == event_types.overlay_roadblock_set then
    local index = payload.index
    if index ~= nil then
      state.board.overlays.roadblocks[index] = payload.enabled == true and true or nil
    end
    return
  end

  if event.type == event_types.overlay_mine_set then
    local index = payload.index
    if index ~= nil then
      state.board.overlays.mines[index] = payload.enabled == true and true or nil
    end
    return
  end

  if event.type == event_types.market_limit_set then
    local product_id = payload.product_id
    if product_id ~= nil then
      state.market.global_limits[product_id] = payload.remaining
    end
  end
end

return board_reducer
