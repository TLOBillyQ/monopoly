local events = require("src.v2.domain.Events")

local board_reducer = {}
local event_types = events.types

function board_reducer.apply(state, event)
  local payload = event.payload or {}
  local tile_id = payload.tile_id
  if tile_id == nil then
    return
  end

  local tile_state = state.board.tile_states[tile_id]
  if event.type == event_types.tile_bought then
    if tile_state == nil then
      tile_state = { owner_id = nil, level = 0 }
      state.board.tile_states[tile_id] = tile_state
    end
    tile_state.owner_id = payload.owner_seat
    tile_state.level = payload.level or 1
    return
  end

  if event.type == event_types.tile_upgraded then
    if tile_state == nil then
      return
    end
    local level = payload.level
    if type(level) ~= "number" then
      level = (tile_state.level or 0) + 1
    end
    if level > 3 then
      level = 3
    end
    tile_state.level = level
    return
  end
end

return board_reducer
