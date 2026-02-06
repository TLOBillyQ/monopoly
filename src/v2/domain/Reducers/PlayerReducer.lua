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
  if player.cash <= 0 then
    player.eliminated = true
    if player.cash < 0 then
      player.cash = 0
    end
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

  if event.type == event_types.land_bought then
    local player = _player(state, payload.owner_seat)
    if player then
      player.cash = player.cash - (payload.cost or 0)
      _append_property(player, payload.tile_id)
      _eliminate_if_needed(player)
    end
    return
  end

  if event.type == event_types.land_upgraded then
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

  if event.type == event_types.player_cash_changed then
    local player = _player(state, payload.seat)
    if player then
      player.cash = (player.cash or 0) + (payload.delta or 0)
      if payload.value ~= nil then
        player.cash = payload.value
      end
      _eliminate_if_needed(player)
    end
    return
  end

  if event.type == event_types.player_balance_changed then
    local player = _player(state, payload.seat)
    if player then
      player.balances = player.balances or {}
      local currency = payload.currency
      if currency == "金币" then
        player.cash = (player.cash or 0) + (payload.delta or 0)
        if payload.value ~= nil then
          player.cash = payload.value
        end
        _eliminate_if_needed(player)
      elseif currency ~= nil then
        local current = player.balances[currency] or 0
        player.balances[currency] = current + (payload.delta or 0)
        if payload.value ~= nil then
          player.balances[currency] = payload.value
        end
      end
    end
    return
  end

  if event.type == event_types.player_status_set then
    local player = _player(state, payload.seat)
    if player then
      player.status = player.status or {}
      player.status[payload.key] = payload.value
    end
    return
  end

  if event.type == event_types.player_seat_set then
    local player = _player(state, payload.seat)
    if player then
      player.seat_vehicle_id = payload.vehicle_id
    end
    return
  end

  if event.type == event_types.player_property_set then
    local player = _player(state, payload.seat)
    if player then
      player.properties = player.properties or {}
      if payload.owned then
        player.properties[payload.tile_id] = true
      else
        player.properties[payload.tile_id] = nil
      end
    end
    return
  end

  if event.type == event_types.player_eliminated then
    local player = _player(state, payload.seat)
    if player then
      player.eliminated = true
      player.cash = 0
      player.properties = {}
      player.inventory = player.inventory or { items = {} }
      player.inventory.items = {}
      player.seat_vehicle_id = nil
    end
    return
  end

  if event.type == event_types.item_granted then
    local player = _player(state, payload.seat)
    if player then
      player.inventory = player.inventory or { items = {}, max_slots = 5 }
      player.inventory.items = player.inventory.items or {}
      if #player.inventory.items < (player.inventory.max_slots or 5) then
        player.inventory.items[#player.inventory.items + 1] = { id = payload.item_id }
      end
    end
    return
  end

  if event.type == event_types.item_consumed then
    local player = _player(state, payload.seat)
    if player and player.inventory and player.inventory.items then
      local remove_idx = nil
      for index, item in ipairs(player.inventory.items) do
        if item and item.id == payload.item_id then
          remove_idx = index
          break
        end
      end
      if remove_idx then
        table.remove(player.inventory.items, remove_idx)
      end
    end
    return
  end

  if event.type == event_types.item_discarded then
    local player = _player(state, payload.seat)
    if player and player.inventory and player.inventory.items then
      local count = payload.count or 1
      for _ = 1, count do
        if #player.inventory.items <= 0 then
          break
        end
        table.remove(player.inventory.items, 1)
      end
    end
  end
end

return player_reducer
