local land_actions = {}
local constants = require("Config.Generated.Constants")
local board_utils = require("src.game.item.ItemBoardUtils")
local pricing = require("src.game.land.LandPricing")
local inventory = require("src.game.item.ItemInventory")
local gameplay_rules = require("Config.GameplayRules")
local monopoly_event = require("src.game.game.MonopolyEvents")
local bankruptcy_manager = require("src.game.game.BankruptcyManager")

local item_ids = gameplay_rules.item_ids
local _emit_event = monopoly_event.emit
local tile_state_path = { "board", "tiles", nil }

local function _eliminate_if_bankrupt(game, player)
  if not player or player.cash > 0 then
    return
  end
  bankruptcy_manager.eliminate(game, player)
end

function land_actions.safe_tile_state(game, tile)
  if not (game and game.store and tile and tile.type == "land") then
    return { owner_id = nil, level = 0 }
  end
  tile_state_path[3] = tile.id
  local st = game.store:get(tile_state_path)
  if type(st) ~= "table" then
    return { owner_id = nil, level = 0 }
  end
  return { owner_id = st.owner_id, level = st.level or 0 }
end

local function _ensure_land_neighbors(board)
  if board.land_neighbors then
    return board.land_neighbors
  end
  assert(board.map ~= nil and board.map.neighbors ~= nil, "missing board.map.neighbors")
  local neighbors = board.map.neighbors
  local land_neighbors = {}
  for _, tile in ipairs(board.path or {}) do
    if tile and tile.type == "land" then
      local neigh = neighbors[tile.id]
      assert(neigh ~= nil, "missing neighbors: " .. tostring(tile.id))
      local list = {}
      for _, next_id in pairs(neigh) do
        local next_tile = board:get_tile_by_id(next_id)
        if next_tile and next_tile.type == "land" then
          list[#list + 1] = next_id
        end
      end
      land_neighbors[tile.id] = list
    end
  end
  board.land_neighbors = land_neighbors
  return land_neighbors
end

local function _get_rent_cache(game, owner_id)
  local version = game._land_rent_version or 0
  local cache = game._land_rent_cache
  if not cache or cache.version ~= version then
    cache = { version = version, by_owner = {} }
    game._land_rent_cache = cache
  end
  local owner_cache = cache.by_owner[owner_id]
  if not owner_cache then
    owner_cache = { tile_sum = {} }
    cache.by_owner[owner_id] = owner_cache
  end
  return owner_cache.tile_sum
end

function land_actions.resolve_rent_owner(game, tile, state_fn)
  local st = land_actions.safe_tile_state(game, tile)
  if state_fn then
    st = state_fn(game, tile)
  end
  local owner = nil
  if st.owner_id then
    owner = game.players[st.owner_id]
  end
  if not owner or owner.eliminated then
    game:set_tile_owner(tile, nil)
    return nil, st
  end

  if owner:is_in_mountain(game) then
    _emit_event(monopoly_event.land.rent_skipped_mountain, {
      owner = owner,
      tile = tile,
      text = owner.name .. " 在深山，租金不收取",
    })
    return nil, st
  end

  return owner, st
end

local function _contiguous_rent(game, board, index, owner_id)
  assert(board ~= nil, "missing board")
  assert(board.map ~= nil, "missing board.map")
  local land_neighbors = _ensure_land_neighbors(board)

  local start_tile = assert(board:get_tile(index), "missing start tile: " .. tostring(index))
  assert(start_tile.type == "land", "invalid start tile: " .. tostring(index))
  local start_state = land_actions.safe_tile_state(game, start_tile)
  if start_state.owner_id ~= owner_id then
    return 0
  end

  local tile_sum = _get_rent_cache(game, owner_id)
  local cached = tile_sum[start_tile.id]
  if cached then
    return cached
  end

  local rent_sum = 0
  local visited = { [start_tile.id] = true }
  local queue = { start_tile.id }
  local head = 1
  local component = {}

  while head <= #queue do
    local tile_id = queue[head]
    head = head + 1

    local tile = board:get_tile_by_id(tile_id)
    assert(tile ~= nil, "missing tile: " .. tostring(tile_id))
    if tile.type == "land" then
      local st2 = land_actions.safe_tile_state(game, tile)
      if st2.owner_id == owner_id then
        component[#component + 1] = tile_id
        rent_sum = rent_sum + pricing.rent_for_level(tile, st2.level or 0)
        local neigh = land_neighbors[tile_id]
        assert(neigh ~= nil, "missing neighbors: " .. tostring(tile_id))
        for _, next_id in ipairs(neigh) do
          if not visited[next_id] then
            visited[next_id] = true
            queue[#queue + 1] = next_id
          end
        end
      end
    end
  end

  for _, tile_id in ipairs(component) do
    tile_sum[tile_id] = rent_sum
  end
  return rent_sum
end

function land_actions.execute_strong_card(game, player_id, tile_id)
  local player = game.players[player_id]
  local tile = game.board:get_tile_by_id(tile_id)
  local st = land_actions.safe_tile_state(game, tile)
  local owner = nil
  if st.owner_id then
    owner = game.players[st.owner_id]
  end
  assert(owner ~= nil, "missing owner")

  local total_value = board_utils.total_invested(tile, st.level)
  if player.cash < total_value then return false end
  assert(inventory.consume(player, item_ids.strong) == true, "consume strong card failed")
  player:deduct_cash(total_value)
  owner:add_cash(total_value)
  game:set_tile_owner(tile, player.id)
  game:set_player_property(owner, tile.id, false)
  game:set_player_property(player, tile.id, true)
  _emit_event(monopoly_event.land.strong_card_used, {
    player = player,
    owner = owner,
    tile = tile,
    amount = total_value,
    text = player.name .. " 使用强征卡，支付 " .. total_value .. " 强制购入 " .. tile.name,
  })
  return true
end

function land_actions.execute_free_card(game, player_id, tile_id)
  local player = game.players[player_id]
  local tile = game.board:get_tile_by_id(tile_id)
  assert(inventory.consume(player, item_ids.free_rent) == true, "consume free rent failed")
  _emit_event(monopoly_event.land.free_rent_used, {
    player = player,
    tile = tile,
    text = player.name .. " 出示免费卡，免租 " .. tile.name,
  })
  return true
end

function land_actions.execute_pay_rent(game, player_id, tile_id)
  local player = game.players[player_id]
  local tile = game.board:get_tile_by_id(tile_id)
  local owner, st = land_actions.resolve_rent_owner(game, tile)
  if not owner then
    return false
  end

  local board = game.board
  local idx = assert(board:index_of_tile_id(tile.id), "missing tile index: " .. tostring(tile.id))
  local rent = _contiguous_rent(game, board, idx, owner.id)

  if player:has_deity("poor") then rent = rent * 2 end
  if owner:has_deity("rich") then rent = rent * 2 end

  if player.cash >= rent then
    player:deduct_cash(rent)
    owner:add_cash(rent)
    _emit_event(monopoly_event.land.rent_paid, {
      player = player,
      owner = owner,
      tile = tile,
      amount = rent,
      text = player.name .. " 向 " .. owner.name .. " 支付租金 " .. rent,
    })
    _eliminate_if_bankrupt(game, player)
  else
    local paid = player.cash
    owner:add_cash(paid)
    player:set_cash(0)
    _emit_event(monopoly_event.land.rent_bankrupt, {
      player = player,
      owner = owner,
      tile = tile,
      amount = paid,
      text = player.name .. " 资金不足，支付(".. owner.name ..") " .. paid .. " 后破产",
    })
    _eliminate_if_bankrupt(game, player)
  end
  return true
end

function land_actions.execute_tax_free_card(game, player_id)
  local player = game.players[player_id]
  assert(inventory.consume(player, item_ids.tax_free) == true, "consume tax_free failed")
  _emit_event(monopoly_event.land.tax_free, {
    player = player,
    text = player.name .. " 出示免税卡，本次免税",
  })
  return true
end

function land_actions.execute_pay_tax(game, player_id)
  local player = game.players[player_id]
  local fee = math.floor(player.cash * constants.tax_rate)
  if player.cash < fee then fee = player.cash end

  player:deduct_cash(fee)
  _emit_event(monopoly_event.land.tax_paid, {
    player = player,
    amount = fee,
    text = player.name .. " 在税务局支付税金 " .. fee,
  })

  _eliminate_if_bankrupt(game, player)
  return true
end

return land_actions
