local LandActions = {}
local constants = require("Config.Generated.Constants")
local Tile = require("Components.Tile")
local BoardUtils = require("Manager.ItemManager.Item.ItemBoardUtils")
local Pricing = require("Manager.LandManager.Land.LandPricing")
local Inventory = require("Manager.ItemManager.Item.ItemInventory")
local gameplay_constants = require("Config.GameplayConstants")
local MONOPOLY_EVENT = require("Globals.MonopolyEvents")
local SERVICE_KEY = require("Globals.ServiceKeys")

local tile_state = Tile.get_state
local ITEM_IDS = gameplay_constants.item_ids

local function emit_event(kind, payload)
  if TriggerCustomEvent then
    TriggerCustomEvent(kind, payload or {})
  end
end

local function eliminate_if_bankrupt(game, player)
  if not player or player.cash > 0 then
    return
  end
  local bankruptcy = game:get_service(SERVICE_KEY.bankruptcy)
  bankruptcy.eliminate(game, player)
end

function LandActions.safe_tile_state(game, tile)
  local ok, st = pcall(tile_state, game, tile)
  if not ok or type(st) ~= "table" then
    return { owner_id = nil, level = 0 }
  end
  return { owner_id = st.owner_id, level = st.level or 0 }
end

function LandActions.resolve_rent_owner(game, tile, state_fn)
  local st = LandActions.safe_tile_state(game, tile)
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
    emit_event(MONOPOLY_EVENT.land.rent_skipped_mountain, {
      owner = owner,
      tile = tile,
      text = owner.name .. " 在深山，租金不收取",
    })
    return nil, st
  end

  return owner, st
end

local function contiguous_rent(game, board, index, owner_id)
  local map = board and board.map
  local neighbors = map and map.neighbors
  if not neighbors then
    local length = board:length()
    local rent_sum = 0
    local i = index
    while i >= 1 do
      local t = board:get_tile(i)
      if t.type == "land" then
        local st2 = LandActions.safe_tile_state(game, t)
        if st2.owner_id == owner_id then
          rent_sum = rent_sum + Pricing.rent_for_level(t, st2.level or 0)
          i = i - 1
        else
          break
        end
      else
        break
      end
    end
    i = index + 1
    while i <= length do
      local t = board:get_tile(i)
      if t.type == "land" then
        local st2 = LandActions.safe_tile_state(game, t)
        if st2.owner_id == owner_id then
          rent_sum = rent_sum + Pricing.rent_for_level(t, st2.level or 0)
          i = i + 1
        else
          break
        end
      else
        break
      end
    end
    return rent_sum
  end

  local start_tile = board:get_tile(index)
  if not start_tile or start_tile.type ~= "land" then
    return 0
  end
  local start_state = LandActions.safe_tile_state(game, start_tile)
  if start_state.owner_id ~= owner_id then
    return 0
  end

  local rent_sum = 0
  local visited = {}
  local queue = { start_tile.id }
  visited[start_tile.id] = true

  BoardUtils.queue_walk(queue, function(tile_id, push)
    local tile = board:get_tile_by_id(tile_id)
    if tile and tile.type == "land" then
      local st2 = LandActions.safe_tile_state(game, tile)
      if st2.owner_id == owner_id then
        rent_sum = rent_sum + Pricing.rent_for_level(tile, st2.level or 0)
        local neigh = neighbors[tile_id] or {}
        for _, next_id in pairs(neigh) do
          if not visited[next_id] then
            visited[next_id] = true
            push(next_id)
          end
        end
      end
    end
  end)

  return rent_sum
end

function LandActions.execute_strong_card(game, player_id, tile_id)
  local player = game.players[player_id]
  local tile = game.board:get_tile_by_id(tile_id)
  local st = LandActions.safe_tile_state(game, tile)
  local owner = nil
  if st.owner_id then
    owner = game.players[st.owner_id]
  end
  if not owner then return false end

  local total_value = BoardUtils.total_invested(tile, st.level)
  if player.cash < total_value then return false end
  if not Inventory.consume(player, ITEM_IDS.strong) then return false end
  player:deduct_cash(total_value)
  owner:add_cash(total_value)
  game:set_tile_owner(tile, player.id)
  game:set_player_property(owner, tile.id, false)
  game:set_player_property(player, tile.id, true)
  emit_event(MONOPOLY_EVENT.land.strong_card_used, {
    player = player,
    owner = owner,
    tile = tile,
    amount = total_value,
    text = player.name .. " 使用强征卡，支付 " .. total_value .. " 强制购入 " .. tile.name,
  })
  return true
end

function LandActions.execute_free_card(game, player_id, tile_id)
  local player = game.players[player_id]
  local tile = game.board:get_tile_by_id(tile_id)
  if not Inventory.consume(player, ITEM_IDS.free_rent) then return false end
  emit_event(MONOPOLY_EVENT.land.free_rent_used, {
    player = player,
    tile = tile,
    text = player.name .. " 出示免费卡，免租 " .. tile.name,
  })
  return true
end

function LandActions.execute_pay_rent(game, player_id, tile_id)
  local player = game.players[player_id]
  local tile = game.board:get_tile_by_id(tile_id)
  local owner, st = LandActions.resolve_rent_owner(game, tile)
  if not owner then
    return true
  end

  local board = game.board
  local idx = board:index_of_tile_id(tile.id) or 1
  local rent = contiguous_rent(game, board, idx, owner.id)

  if player:has_deity("poor") then rent = rent * 2 end
  if owner:has_deity("rich") then rent = rent * 2 end

  if player.cash >= rent then
    player:deduct_cash(rent)
    owner:add_cash(rent)
    emit_event(MONOPOLY_EVENT.land.rent_paid, {
      player = player,
      owner = owner,
      tile = tile,
      amount = rent,
      text = player.name .. " 向 " .. owner.name .. " 支付租金 " .. rent,
    })
    eliminate_if_bankrupt(game, player)
  else
    local paid = player.cash
    owner:add_cash(paid)
    player:set_cash(0)
    emit_event(MONOPOLY_EVENT.land.rent_bankrupt, {
      player = player,
      owner = owner,
      tile = tile,
      amount = paid,
      text = player.name .. " 资金不足，支付(".. owner.name ..") " .. paid .. " 后破产",
    })
    eliminate_if_bankrupt(game, player)
  end
  return true
end

function LandActions.execute_tax_free_card(game, player_id)
  local player = game.players[player_id]
  if not Inventory.consume(player, ITEM_IDS.tax_free) then return false end
  emit_event(MONOPOLY_EVENT.land.tax_free, {
    player = player,
    text = player.name .. " 出示免税卡，本次免税",
  })
  return true
end

function LandActions.execute_pay_tax(game, player_id)
  local player = game.players[player_id]
  local fee = math.floor(player.cash * constants.tax_rate)
  if player.cash < fee then fee = player.cash end

  player:deduct_cash(fee)
  emit_event(MONOPOLY_EVENT.land.tax_paid, {
    player = player,
    amount = fee,
    text = player.name .. " 在税务局支付税金 " .. fee,
  })

  eliminate_if_bankrupt(game, player)
  return true
end

return LandActions
