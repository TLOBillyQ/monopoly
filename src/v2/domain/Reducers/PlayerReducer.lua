local events = require("src.v2.domain.Events")

local player_reducer = {}
local event_types = events.types

local function _player(state, seat)
  if seat == nil then
    return nil
  end
  return state.players[seat]
end

local function _append_property(player, tile_id)
  if player.properties == nil then
    player.properties = {}
  end
  player.properties[tile_id] = true
end

local function _eliminate_if_needed(player)
  if player.cash < 0 then
    player.eliminated = true
    player.cash = 0
  end
end

function player_reducer.apply(state, event)
  local payload = event.payload or {}

  if event.type == event_types.player_moved then
    local player = _player(state, payload.seat)
    if player then
      player.position = payload.to_index or player.position
    end
    return
  end

  if event.type == event_types.tile_bought then
    local player = _player(state, payload.owner_seat)
    if player then
      player.cash = player.cash - (payload.cost or 0)
      _append_property(player, payload.tile_id)
      _eliminate_if_needed(player)
    end
    return
  end

  if event.type == event_types.tile_upgraded then
    local player = _player(state, payload.owner_seat)
    if player then
      player.cash = player.cash - (payload.cost or 0)
      _eliminate_if_needed(player)
    end
    return
  end

  if event.type == event_types.rent_paid then
    local payer = _player(state, payload.from_seat)
    local receiver = _player(state, payload.to_seat)
    local amount = payload.amount or 0
    if payer then
      payer.cash = payer.cash - amount
      _eliminate_if_needed(payer)
    end
    if receiver then
      receiver.cash = receiver.cash + amount
    end
    return
  end

  if event.type == event_types.player_offline then
    local player = _player(state, payload.seat)
    if player then
      player.online = false
      player.offline_since = payload.at or state.clock.now
    end
    return
  end

  if event.type == event_types.player_online then
    local player = _player(state, payload.seat)
    if player then
      player.online = true
      player.offline_since = nil
      player.last_seen_at = payload.at or state.clock.now
    end
    return
  end

  if event.type == event_types.player_auto_set then
    local player = _player(state, payload.seat)
    if player then
      player.auto = payload.enabled == true
    end
    return
  end
end

return player_reducer
