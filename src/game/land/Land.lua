local Land = {}
local logger = require("src.core.Logger")
local Tile = require("src.game.board.Tile")
local BoardUtils = require("src.game.item.ItemBoardUtils")
local Pricing = require("src.game.land.LandPricing")
local LandActions = require("src.game.land.LandActions")
local LandChoiceSpecs = require("src.game.land.LandChoiceSpecs")
local Inventory = require("src.game.item.ItemInventory")
local GameplayRules = require("Config.GameplayRules")

local tile_state = Tile.GetState
local ITEM_IDS = GameplayRules.item_ids

local function _CanBuy(ctx)
  local tile = ctx.tile
  local player = ctx.player
  assert(tile ~= nil, "missing tile")
  if tile.type ~= "land" then
    return false
  end
  local st = LandActions.SafeTileState(ctx.game, tile)
  return not st.owner_id
end

local function _ApplyBuy(ctx)
  local tile = ctx.tile
  local player = ctx.player
  if player.cash < tile.price then
    return {
      intent = {
        kind = "push_popup",
        payload = { title = "购买失败", body = player.name .. " 余额不足" },
      },
    }
  end
  player:DeductCash(tile.price)
  ctx.game:SetTileOwner(tile, player.id)
  ctx.game:SetPlayerProperty(player, tile.id, true)
  logger.Event(player.name .. " 购买 " .. tile.name .. " 花费 " .. tile.price)
end

local function _CanUpgrade(ctx)
  local tile = ctx.tile
  local player = ctx.player
  assert(tile ~= nil, "missing tile")
  if tile.type ~= "land" then
    return false
  end
  local st = LandActions.SafeTileState(ctx.game, tile)
  if st.owner_id ~= player.id then
    return false
  end
  if (st.level or 0) >= Pricing.MaxLevel(tile) then
    return false
  end
  return true
end

local function _ApplyUpgrade(ctx)
  local tile = ctx.tile
  local player = ctx.player
  local st = LandActions.SafeTileState(ctx.game, tile)
  local cost = Pricing.UpgradeCost(tile, st.level or 0)
  if player.cash < cost then
    return {
      intent = {
        kind = "push_popup",
        payload = { title = "升级失败", body = player.name .. " 余额不足" },
      },
    }
  end
  player:DeductCash(cost)
  local new_level = (st.level or 0) + 1
  ctx.game:SetTileLevel(tile, new_level)
  local ui_port = assert(ctx.game.ui_port, "missing ui_port")
  assert(ui_port.OnTileUpgraded ~= nil, "missing ui_port.OnTileUpgraded")
  ui_port:OnTileUpgraded(tile.id, new_level)
  logger.Event(player.name .. " 为 " .. tile.name .. " 加盖，花费 " .. cost)
end

local function _CanPayRent(ctx)
  local tile = ctx.tile
  local player = ctx.player
  assert(tile ~= nil, "missing tile")
  if tile.type ~= "land" then
    return false
  end
  local st = LandActions.SafeTileState(ctx.game, tile)
  return st.owner_id and st.owner_id ~= player.id
end

local function _ApplyPayRent(ctx)
  local tile = ctx.tile
  local player = ctx.player
  assert(tile ~= nil and tile.type == "land", "invalid land tile")
  local owner, st = LandActions.ResolveRentOwner(ctx.game, tile, tile_state)
  assert(owner ~= nil, "missing rent owner")

  if player.status.pending_free_rent then
    ctx.game:SetPlayerStatus(player, "pending_free_rent", false)
    logger.Event(player.name .. " 使用免费卡，免租 " .. tile.name)
    return
  end

  local total_value = BoardUtils.TotalInvested(tile, st.level)
  local strong_idx = Inventory.FindIndex(player, ITEM_IDS.strong)
  if strong_idx and player.cash >= total_value then
    return {
      waiting = true,
      reason = "rent_choice",
      intent = {
        kind = "need_choice",
        choice_spec = LandChoiceSpecs.RentPrompt(player.id, tile.id, "strong", total_value, tile.name),
      },
    }
  end

  local free_idx = Inventory.FindIndex(player, ITEM_IDS.free_rent)
  if free_idx then
    return {
      waiting = true,
      reason = "rent_choice",
      intent = {
        kind = "need_choice",
        choice_spec = LandChoiceSpecs.RentPrompt(player.id, tile.id, "free", nil, tile.name),
      },
    }
  end

  LandActions.ExecutePayRent(ctx.game, player.id, tile.id)
end

local function _CanTax(ctx)
  assert(ctx.tile ~= nil, "missing tile")
  return ctx.tile.type == "tax"
end

local function _ApplyTax(ctx)
  local player = ctx.player

  if player.status.pending_tax_free then
    logger.Event(player.name .. " 使用免税卡，本次免税")
    ctx.game:SetPlayerStatus(player, "pending_tax_free", false)
    return
  end

  local tax_idx = Inventory.FindIndex(player, ITEM_IDS.tax_free)
  if tax_idx then
    return {
      waiting = true,
      reason = "tax_choice",
      intent = {
        kind = "need_choice",
        choice_spec = LandChoiceSpecs.TaxPrompt(player.id),
      },
    }
  end

  LandActions.ExecutePayTax(ctx.game, player.id)
end

Land.executors = {
  buy_land = { can_apply = _CanBuy, apply = _ApplyBuy },
  upgrade_land = { can_apply = _CanUpgrade, apply = _ApplyUpgrade },
  pay_rent = { can_apply = _CanPayRent, apply = _ApplyPayRent },
  tax = { can_apply = _CanTax, apply = _ApplyTax },
}

return Land



