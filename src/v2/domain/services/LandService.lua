local common = require("src.v2.domain.services.Common")

local land_service = {}

local function _tile_def(state, tile_id)
  return state.board.tile_defs[tile_id]
end

local function _tile_state(state, tile_id)
  local st = state.board.tile_states[tile_id]
  if not st then
    return { owner_id = nil, level = 0 }
  end
  return st
end

local function _upgrade_cost(tile_def, level)
  local costs = tile_def.upgrade_costs
  if type(costs) ~= "table" then
    return tile_def.upgrade_price or 0
  end
  local index = (level or 0) + 1
  return costs[index] or 0
end

local function _rent_for_level(tile_def, level)
  local rents = tile_def.rents
  if type(rents) ~= "table" then
    local base = tile_def.rent_base or 0
    local factor = level and level > 0 and level or 1
    return base * factor
  end
  local index = (level or 0) + 1
  return rents[index] or 0
end

local function _land_neighbors(state, tile_id)
  local map = state.board.map
  local neigh = map.neighbors[tile_id] or {}
  local list = {}
  for _, next_id in pairs(neigh) do
    local def = _tile_def(state, next_id)
    if def and def.type == "land" then
      list[#list + 1] = next_id
    end
  end
  return list
end

local function _contiguous_rent(state, tile_id, owner_id)
  local start_def = _tile_def(state, tile_id)
  if not start_def or start_def.type ~= "land" then
    return 0
  end
  local start_state = _tile_state(state, tile_id)
  if start_state.owner_id ~= owner_id then
    return 0
  end

  local total_rent = 0
  local queue = { tile_id }
  local visited = { [tile_id] = true }
  local cursor = 1
  while cursor <= #queue do
    local current_tile_id = queue[cursor]
    cursor = cursor + 1
    local current_state = _tile_state(state, current_tile_id)
    if current_state.owner_id == owner_id then
      local current_def = _tile_def(state, current_tile_id)
      total_rent = total_rent + _rent_for_level(current_def, current_state.level or 0)
      for _, next_tile_id in ipairs(_land_neighbors(state, current_tile_id)) do
        if not visited[next_tile_id] then
          visited[next_tile_id] = true
          queue[#queue + 1] = next_tile_id
        end
      end
    end
  end
  return total_rent
end

function land_service.can_buy(state, seat, tile_id)
  local player = state.players[seat]
  local def = _tile_def(state, tile_id)
  if not player or not def or def.type ~= "land" then
    return false
  end
  local st = _tile_state(state, tile_id)
  if st.owner_id ~= nil then
    return false
  end
  return player.cash >= (def.price or 0)
end

function land_service.can_upgrade(state, seat, tile_id)
  local player = state.players[seat]
  local def = _tile_def(state, tile_id)
  local st = _tile_state(state, tile_id)
  if not player or not def or def.type ~= "land" then
    return false
  end
  if st.owner_id ~= seat then
    return false
  end
  local level = st.level or 0
  local max_level = #(def.upgrade_costs or {})
  if max_level <= 0 then
    max_level = 3
  end
  if level >= max_level then
    return false
  end
  local cost = _upgrade_cost(def, level)
  return player.cash >= cost
end

function land_service.buy_cost(state, tile_id)
  local def = _tile_def(state, tile_id)
  return def and (def.price or 0) or 0
end

function land_service.upgrade_cost(state, tile_id, level)
  local def = _tile_def(state, tile_id)
  if not def then
    return 0
  end
  return _upgrade_cost(def, level)
end

function land_service.resolve_rent_owner(state, tile_id)
  local st = _tile_state(state, tile_id)
  local owner_seat = st.owner_id
  if not owner_seat then
    return nil, st
  end
  local owner = state.players[owner_seat]
  if not owner or owner.eliminated then
    return nil, st
  end
  if (owner.status and owner.status.stay_turns or 0) > 0 then
    local owner_tile_id = state.board.path[owner.position]
    local owner_tile = owner_tile_id and _tile_def(state, owner_tile_id)
    if owner_tile and owner_tile.type == "mountain" then
      return nil, st
    end
  end
  return owner, st
end

function land_service.rent_amount(state, tile_id, payer_seat)
  local owner, st = land_service.resolve_rent_owner(state, tile_id)
  if not owner then
    return 0, nil
  end
  local rent = _contiguous_rent(state, tile_id, st.owner_id)
  if common.has_deity(state.players[payer_seat], "poor") then
    rent = rent * 2
  end
  if common.has_deity(owner, "rich") then
    rent = rent * 2
  end
  if rent < 0 then
    rent = 0
  end
  return rent, st.owner_id
end

function land_service.tax_amount(state, seat)
  local player = state.players[seat]
  if not player then
    return 0
  end
  local fee = math.floor((player.cash or 0) * (state.rules.tax_rate or 0.5))
  if fee > player.cash then
    fee = player.cash
  end
  if fee < 0 then
    fee = 0
  end
  return fee
end

return land_service
