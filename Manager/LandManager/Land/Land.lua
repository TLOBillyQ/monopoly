local Land = {}
local logger = require("Components.Logger")
local Tile = require("Components.Tile")
local BoardUtils = require("Manager.ItemManager.Item.ItemBoardUtils")
local Pricing = require("Manager.LandManager.Land.LandPricing")
local LandActions = require("Manager.LandManager.Land.LandActions")
local LandChoiceSpecs = require("Manager.LandManager.Land.LandChoiceSpecs")
local Inventory = require("Manager.ItemManager.Item.ItemInventory")
local gameplay_constants = require("Config.GameplayConstants")

local tile_state = Tile.get_state
local ITEM_IDS = gameplay_constants.item_ids

local function can_buy(ctx)
  local tile = ctx.tile
  local player = ctx.player
  assert(tile ~= nil, "missing tile")
  if tile.type ~= "land" then
    return false
  end
  local st = LandActions.safe_tile_state(ctx.game, tile)
  return not st.owner_id
end

local function apply_buy(ctx)
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
  player:deduct_cash(tile.price)
  ctx.game:set_tile_owner(tile, player.id)
  ctx.game:set_player_property(player, tile.id, true)
  logger.event(player.name .. " 购买 " .. tile.name .. " 花费 " .. tile.price)
end

local function can_upgrade(ctx)
  local tile = ctx.tile
  local player = ctx.player
  assert(tile ~= nil, "missing tile")
  if tile.type ~= "land" then
    return false
  end
  local st = LandActions.safe_tile_state(ctx.game, tile)
  if st.owner_id ~= player.id then
    return false
  end
  if (st.level or 0) >= Pricing.max_level(tile) then
    return false
  end
  return true
end

local function apply_upgrade(ctx)
  local tile = ctx.tile
  local player = ctx.player
  local st = LandActions.safe_tile_state(ctx.game, tile)
  local cost = Pricing.upgrade_cost(tile, st.level or 0)
  if player.cash < cost then
    return {
      intent = {
        kind = "push_popup",
        payload = { title = "升级失败", body = player.name .. " 余额不足" },
      },
    }
  end
  player:deduct_cash(cost)
  local new_level = (st.level or 0) + 1
  ctx.game:set_tile_level(tile, new_level)
  local ui_port = assert(ctx.game.ui_port, "missing ui_port")
  assert(ui_port.on_tile_upgraded ~= nil, "missing ui_port.on_tile_upgraded")
  ui_port:on_tile_upgraded(tile.id, new_level)
  logger.event(player.name .. " 为 " .. tile.name .. " 加盖，花费 " .. cost)
end

local function can_pay_rent(ctx)
  local tile = ctx.tile
  local player = ctx.player
  assert(tile ~= nil, "missing tile")
  if tile.type ~= "land" then
    return false
  end
  local st = LandActions.safe_tile_state(ctx.game, tile)
  return st.owner_id and st.owner_id ~= player.id
end

local function apply_pay_rent(ctx)
  local tile = ctx.tile
  local player = ctx.player
  assert(tile ~= nil and tile.type == "land", "invalid land tile")
  local owner, st = LandActions.resolve_rent_owner(ctx.game, tile, tile_state)
  assert(owner ~= nil, "missing rent owner")

  if player.status.pending_free_rent then
    ctx.game:set_player_status(player, "pending_free_rent", false)
    logger.event(player.name .. " 使用免费卡，免租 " .. tile.name)
    return
  end

  local total_value = BoardUtils.total_invested(tile, st.level)
  local strong_idx = Inventory.find_index(player, ITEM_IDS.strong)
  if strong_idx and player.cash >= total_value then
    return {
      waiting = true,
      reason = "rent_choice",
      intent = {
        kind = "need_choice",
        choice_spec = LandChoiceSpecs.rent_prompt(player.id, tile.id, "strong", total_value, tile.name),
      },
    }
  end

  local free_idx = Inventory.find_index(player, ITEM_IDS.free_rent)
  if free_idx then
    return {
      waiting = true,
      reason = "rent_choice",
      intent = {
        kind = "need_choice",
        choice_spec = LandChoiceSpecs.rent_prompt(player.id, tile.id, "free", nil, tile.name),
      },
    }
  end

  LandActions.execute_pay_rent(ctx.game, player.id, tile.id)
end

local function can_tax(ctx)
  assert(ctx.tile ~= nil, "missing tile")
  return ctx.tile.type == "tax"
end

local function apply_tax(ctx)
  local player = ctx.player

  if player.status.pending_tax_free then
    logger.event(player.name .. " 使用免税卡，本次免税")
    ctx.game:set_player_status(player, "pending_tax_free", false)
    return
  end

  local tax_idx = Inventory.find_index(player, ITEM_IDS.tax_free)
  if tax_idx then
    return {
      waiting = true,
      reason = "tax_choice",
      intent = {
        kind = "need_choice",
        choice_spec = LandChoiceSpecs.tax_prompt(player.id),
      },
    }
  end

  LandActions.execute_pay_tax(ctx.game, player.id)
end

Land.executors = {
  buy_land = { can_apply = can_buy, apply = apply_buy },
  upgrade_land = { can_apply = can_upgrade, apply = apply_upgrade },
  pay_rent = { can_apply = can_pay_rent, apply = apply_pay_rent },
  tax = { can_apply = can_tax, apply = apply_tax },
}

return Land



