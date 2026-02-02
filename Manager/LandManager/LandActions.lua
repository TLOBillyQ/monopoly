local LandActions = {}
local constants = require("Config.Generated.Constants")
local Tile = require("Components.Tile")
local BoardUtils = require("Manager.ItemManager.ItemBoardUtils")
local Pricing = require("Manager.LandManager.LandPricing")
local Inventory = require("Manager.ItemManager.ItemInventory")
local GameplayRules = require("Config.GameplayRules")
local MONOPOLY_EVENT = require("Globals.MonopolyEvents")
local BankruptcyManager = require("Manager.GameManager.BankruptcyManager")

local tile_state = Tile.GetState
local ITEM_IDS = GameplayRules.item_ids

local function _EmitEvent(kind, payload)
  assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
  TriggerCustomEvent(kind, payload or {})
end

local function _EliminateIfBankrupt(game, player)
  assert(player ~= nil, "missing player")
  if player.cash > 0 then
    return
  end
  BankruptcyManager.Eliminate(game, player)
end

function LandActions.SafeTileState(game, tile)
  local ok, st = pcall(tile_state, game, tile)
  if not ok or type(st) ~= "table" then
    return { owner_id = nil, level = 0 }
  end
  return { owner_id = st.owner_id, level = st.level or 0 }
end

function LandActions.ResolveRentOwner(game, tile, state_fn)
  local st = LandActions.SafeTileState(game, tile)
  if state_fn then
    st = state_fn(game, tile)
  end
  local owner = nil
  if st.owner_id then
    owner = game.players[st.owner_id]
  end
  if not owner or owner.eliminated then
    game:SetTileOwner(tile, nil)
    return nil, st
  end

  if owner:IsInMountain(game) then
    _EmitEvent(MONOPOLY_EVENT.land.rent_skipped_mountain, {
      owner = owner,
      tile = tile,
      text = owner.name .. " 在深山，租金不收取",
    })
    return nil, st
  end

  return owner, st
end

local function _ContiguousRent(game, board, index, owner_id)
  assert(board ~= nil, "missing board")
  assert(board.map ~= nil, "missing board.map")
  local neighbors = assert(board.map.neighbors, "missing board.map.neighbors")

  local start_tile = assert(board:GetTile(index), "missing start tile: " .. tostring(index))
  assert(start_tile.type == "land", "invalid start tile: " .. tostring(index))
  local start_state = LandActions.SafeTileState(game, start_tile)
  if start_state.owner_id ~= owner_id then
    return 0
  end

  local rent_sum = 0
  local visited = {}
  local queue = { start_tile.id }
  visited[start_tile.id] = true

  BoardUtils.QueueWalk(queue, function(tile_id, push)
    local tile = board:GetTileById(tile_id)
    assert(tile ~= nil, "missing tile: " .. tostring(tile_id))
    if tile.type == "land" then
      local st2 = LandActions.SafeTileState(game, tile)
      if st2.owner_id == owner_id then
        rent_sum = rent_sum + Pricing.RentForLevel(tile, st2.level or 0)
        local neigh = assert(neighbors[tile_id], "missing neighbors: " .. tostring(tile_id))
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

function LandActions.ExecuteStrongCard(game, player_id, tile_id)
  local player = game.players[player_id]
  local tile = game.board:GetTileById(tile_id)
  local st = LandActions.SafeTileState(game, tile)
  local owner = nil
  if st.owner_id then
    owner = game.players[st.owner_id]
  end
  assert(owner ~= nil, "missing owner")

  local total_value = BoardUtils.TotalInvested(tile, st.level)
  if player.cash < total_value then return false end
  assert(Inventory.Consume(player, ITEM_IDS.strong) == true, "consume strong card failed")
  player:DeductCash(total_value)
  owner:AddCash(total_value)
  game:SetTileOwner(tile, player.id)
  game:SetPlayerProperty(owner, tile.id, false)
  game:SetPlayerProperty(player, tile.id, true)
  _EmitEvent(MONOPOLY_EVENT.land.strong_card_used, {
    player = player,
    owner = owner,
    tile = tile,
    amount = total_value,
    text = player.name .. " 使用强征卡，支付 " .. total_value .. " 强制购入 " .. tile.name,
  })
  return true
end

function LandActions.ExecuteFreeCard(game, player_id, tile_id)
  local player = game.players[player_id]
  local tile = game.board:GetTileById(tile_id)
  assert(Inventory.Consume(player, ITEM_IDS.free_rent) == true, "consume free rent failed")
  _EmitEvent(MONOPOLY_EVENT.land.free_rent_used, {
    player = player,
    tile = tile,
    text = player.name .. " 出示免费卡，免租 " .. tile.name,
  })
  return true
end

function LandActions.ExecutePayRent(game, player_id, tile_id)
  local player = game.players[player_id]
  local tile = game.board:GetTileById(tile_id)
  local owner, st = LandActions.ResolveRentOwner(game, tile)
  assert(owner ~= nil, "missing rent owner")

  local board = game.board
  local idx = assert(board:IndexOfTileId(tile.id), "missing tile index: " .. tostring(tile.id))
  local rent = _ContiguousRent(game, board, idx, owner.id)

  if player:HasDeity("poor") then rent = rent * 2 end
  if owner:HasDeity("rich") then rent = rent * 2 end

  if player.cash >= rent then
    player:DeductCash(rent)
    owner:AddCash(rent)
    _EmitEvent(MONOPOLY_EVENT.land.rent_paid, {
      player = player,
      owner = owner,
      tile = tile,
      amount = rent,
      text = player.name .. " 向 " .. owner.name .. " 支付租金 " .. rent,
    })
    _EliminateIfBankrupt(game, player)
  else
    local paid = player.cash
    owner:AddCash(paid)
    player:SetCash(0)
    _EmitEvent(MONOPOLY_EVENT.land.rent_bankrupt, {
      player = player,
      owner = owner,
      tile = tile,
      amount = paid,
      text = player.name .. " 资金不足，支付(".. owner.name ..") " .. paid .. " 后破产",
    })
    _EliminateIfBankrupt(game, player)
  end
  return true
end

function LandActions.ExecuteTaxFreeCard(game, player_id)
  local player = game.players[player_id]
  assert(Inventory.Consume(player, ITEM_IDS.tax_free) == true, "consume tax_free failed")
  _EmitEvent(MONOPOLY_EVENT.land.tax_free, {
    player = player,
    text = player.name .. " 出示免税卡，本次免税",
  })
  return true
end

function LandActions.ExecutePayTax(game, player_id)
  local player = game.players[player_id]
  local fee = math.floor(player.cash * constants.tax_rate)
  if player.cash < fee then fee = player.cash end

  player:DeductCash(fee)
  _EmitEvent(MONOPOLY_EVENT.land.tax_paid, {
    player = player,
    amount = fee,
    text = player.name .. " 在税务局支付税金 " .. fee,
  })

  _EliminateIfBankrupt(game, player)
  return true
end

return LandActions
