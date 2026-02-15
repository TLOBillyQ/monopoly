local logger = require("src.core.Logger")
local constants = require("Config.Generated.Constants")
local chance_cfg = require("Config.Generated.ChanceCards")
local gameplay_rules = require("Config.GameplayRules")
local tile = require("src.game.systems.board.Tile")
local board_utils = require("src.game.systems.land.LandBoardUtils")
local pricing = require("src.game.systems.land.LandPricing")
local land_actions = require("src.game.systems.land.LandActions")
local land_choice_specs = require("src.game.systems.land.LandChoiceSpecs")
local inventory = require("src.game.systems.items.ItemInventory")
local chance_effects = require("src.game.systems.chance.Chance")
local landing_presenter = require("src.game.systems.land.LandingPresenter")
local mine_effect = require("src.game.systems.effects.MineEffect")
local steal = require("src.game.systems.items.ItemSteal")
local market = require("src.game.systems.market.Market")
local vehicle_feature = require("src.game.systems.vehicle.VehicleFeature")
local number_utils = require("src.core.NumberUtils")
local monopoly_event = require("src.game.core.runtime.MonopolyEvents")

local land = {}

local tile_state = tile.get_state
local item_ids = gameplay_rules.item_ids
local action_anim_duration = gameplay_rules.action_anim_default_seconds or 1.0
local popup_show_seconds = gameplay_rules.popup_auto_close_seconds or 1.0

local chance_weights = {}
for i, cfg in ipairs(chance_cfg) do
  local weight = cfg.weight or 0
  if weight < 0 then
    weight = 0
  end
  chance_weights[i] = weight
end

local function _is_drawable_chance_card(card)
  if vehicle_feature.is_vehicle_chance_card(card) and not vehicle_feature.is_enabled() then
    return false
  end
  return true
end

local function _pick_chance_card()
  local total_weight = 0
  local first_drawable = nil
  for i, card in ipairs(chance_cfg) do
    if _is_drawable_chance_card(card) then
      first_drawable = first_drawable or card
      total_weight = total_weight + (chance_weights[i] or 0)
    end
  end

  if first_drawable == nil then
    return nil
  end
  if total_weight <= 0 then
    return first_drawable
  end

  local rand = LuaAPI.rand() * total_weight
  local accumulated = 0
  for i, card in ipairs(chance_cfg) do
    if _is_drawable_chance_card(card) then
      accumulated = accumulated + (chance_weights[i] or 0)
      if accumulated >= rand then
        return card
      end
    end
  end

  if #chance_cfg == 0 then
    return nil
  end
  return first_drawable
end

local function _can_buy(ctx)
  local tile = ctx.tile
  assert(tile ~= nil, "missing tile")
  if tile.type ~= "land" then
    return false
  end
  local st = land_actions.safe_tile_state(ctx.game, tile)
  return not st.owner_id
end

local function _apply_buy(ctx)
  local tile = ctx.tile
  local player = ctx.player
  if ctx.game:player_balance(player, "金币") < tile.price then
    return {
      intent = {
        kind = "push_popup",
        payload = { title = "购买失败", body = player.name .. " 余额不足" },
      },
    }
  end
  ctx.game:deduct_player_cash(player, tile.price)
  ctx.game:set_tile_owner(tile, player.id)
  ctx.game:set_player_property(player, tile.id, true)
  logger.event(player.name .. " 购买 " .. tile.name .. " 花费 " .. tile.price)
end

local function _can_upgrade(ctx)
  local tile = ctx.tile
  local player = ctx.player
  assert(tile ~= nil, "missing tile")
  if tile.type ~= "land" then
    return false
  end
  local st = land_actions.safe_tile_state(ctx.game, tile)
  if st.owner_id ~= player.id then
    return false
  end
  if (st.level or 0) >= pricing.max_level(tile) then
    return false
  end
  return true
end

local function _apply_upgrade(ctx)
  local tile = ctx.tile
  local player = ctx.player
  local st = land_actions.safe_tile_state(ctx.game, tile)
  local cost = pricing.upgrade_cost(tile, st.level or 0)
  if ctx.game:player_balance(player, "金币") < cost then
    return {
      intent = {
        kind = "push_popup",
        payload = { title = "升级失败", body = player.name .. " 余额不足" },
      },
    }
  end
  ctx.game:deduct_player_cash(player, cost)
  local new_level = (st.level or 0) + 1
  ctx.game:set_tile_level(tile, new_level)
  monopoly_event.emit(monopoly_event.land.tile_upgraded, {
    tile_id = tile.id,
    level = new_level,
  })
  logger.event(player.name .. " 为 " .. tile.name .. " 加盖，花费 " .. cost)
  local ui_port = ctx.game.ui_port
  if ui_port and ui_port.wait_action_anim then
    local tile_index = ctx.game.board:index_of_tile_id(tile.id)
    if tile_index then
      ctx.game:queue_action_anim({
        kind = "upgrade_land",
        player_id = player.id,
        tile_index = tile_index,
        duration = action_anim_duration,
      })
    end
  end
end

local function _can_pay_rent(ctx)
  local tile = ctx.tile
  local player = ctx.player
  assert(tile ~= nil, "missing tile")
  if tile.type ~= "land" then
    return false
  end
  local st = land_actions.safe_tile_state(ctx.game, tile)
  return st.owner_id and st.owner_id ~= player.id
end

local function _apply_pay_rent(ctx)
  local tile = ctx.tile
  local player = ctx.player
  assert(tile ~= nil and tile.type == "land", "invalid land tile")
  local owner, st = land_actions.resolve_rent_owner(ctx.game, tile, tile_state)
  if not owner then
    return
  end

  if player.status.pending_free_rent then
    ctx.game:set_player_status(player, "pending_free_rent", false)
    logger.event(player.name .. " 使用免费卡，免租 " .. tile.name)
    return
  end

  local total_value = board_utils.total_invested(tile, st.level)
  local strong_idx = nil
  local free_idx = nil
  for idx, it in ipairs(inventory.items(player)) do
    if it.id == item_ids.strong then
      strong_idx = idx
      if free_idx then
        break
      end
    elseif it.id == item_ids.free_rent then
      free_idx = idx
      if strong_idx then
        break
      end
    end
  end
  local can_use_strong = strong_idx and ctx.game:player_balance(player, "金币") >= total_value
  if can_use_strong then
    return {
      waiting = true,
      reason = "rent_choice",
      intent = {
        kind = "need_choice",
        choice_spec = land_choice_specs.rent_prompt(player.id, tile.id, "strong", total_value, tile.name),
      },
    }
  end

  if free_idx then
    land_actions.execute_free_card(ctx.game, player.id, tile.id)
    return
  end

  land_actions.execute_pay_rent(ctx.game, player.id, tile.id)
end

local function _can_tax(ctx)
  assert(ctx.tile ~= nil, "missing tile")
  return ctx.tile.type == "tax"
end

local function _apply_tax(ctx)
  local player = ctx.player

  if player.status.pending_tax_free then
    logger.event(player.name .. " 使用免税卡，本次免税")
    ctx.game:set_player_status(player, "pending_tax_free", false)
    return
  end

  local tax_idx = inventory.find_index(player, item_ids.tax_free)
  if tax_idx then
    return {
      waiting = true,
      reason = "tax_choice",
      intent = {
        kind = "need_choice",
        choice_spec = land_choice_specs.tax_prompt(player.id),
      },
    }
  end

  land_actions.execute_pay_tax(ctx.game, player.id)
end

local executors = {
  pass_players = {
    can_apply = function(ctx)
      local enc = ctx.move_result and ctx.move_result.encountered_players
      return enc and #enc > 0
    end,
    apply = function(ctx)
      local encountered = ctx.move_result.encountered_players
      local ids = {}
      for _, p in ipairs(encountered) do
        if type(p) == "table" then
          table.insert(ids, p.id)
        else
          table.insert(ids, p)
        end
      end
      return steal.handle_pass_players(ctx.game, ctx.player, ids)
    end,
  },
  start_reward = {
    can_apply = function(ctx)
      return ctx.tile and ctx.tile.type == "start" and ctx.on_landing
    end,
    apply = function(ctx)
      local player = ctx.player
      local move_result = ctx.move_result or {}
      if move_result.passed_start and move_result.passed_start > 0 then
        return
      end
      ctx.game:add_player_cash(player, constants.pass_start_bonus)
      logger.event(
        player.name .. " 停在起点，获得 " .. number_utils.format_integer_part(constants.pass_start_bonus) .. " 金币"
      )
    end,
  },
  item_draw_and_give = {
    can_apply = function(ctx)
      return ctx.game and ctx.player and ctx.tile and ctx.tile.type == "item"
    end,
    apply = function(ctx)
      local player = ctx.player
      local cfg = inventory.draw_random()
      assert(cfg ~= nil, "missing drawn item cfg")
      local ok = inventory.give(player, cfg.id, { game = ctx.game })
      if ok then
        local item_name = inventory.item_name(cfg.id)
        landing_presenter.push_popup(ctx.game, "道具卡", player.name .. " 获得道具 " .. item_name, {
          kind = "item_card",
          image_ref = cfg.id,
          auto_close_seconds = popup_show_seconds,
        })
        landing_presenter.queue_action_anim(ctx.game, {
          kind = "item_use",
          player_id = player.id,
          item_id = cfg.id,
          item_name = item_name,
          duration = popup_show_seconds,
        })
      end
    end,
  },
  chance_draw_and_resolve = {
    can_apply = function(ctx)
      return ctx.game and ctx.player and ctx.tile and ctx.tile.type == "chance"
    end,
    apply = function(ctx)
      local card = _pick_chance_card() or chance_cfg[1]
      if not card then
        return
      end
      logger.event(ctx.player.name .. " 抽到机会卡 " .. card.description)
      landing_presenter.push_popup(ctx.game, "机会卡", ctx.player.name .. " 抽到机会卡：" .. card.description, {
        kind = "chance_card",
        image_ref = card.id,
        auto_close_seconds = popup_show_seconds,
      })
      landing_presenter.queue_action_anim(ctx.game, {
        kind = "chance",
        player_id = ctx.player.id,
        card_id = card.id,
        card_desc = card.description,
        duration = popup_show_seconds,
      })
      return chance_effects.resolve(ctx.game, ctx.player, card, ctx.move_result)
    end,
  },
  hospital = {
    can_apply = function(ctx)
      return ctx.tile and ctx.tile.type == "hospital"
    end,
    apply = function(ctx)
      ctx.game:player_apply_hospital_effects(ctx.player)
    end,
  },
  mountain = {
    can_apply = function(ctx)
      return ctx.tile and ctx.tile.type == "mountain"
    end,
    apply = function(ctx)
      ctx.game:player_apply_mountain_effects(ctx.player)
    end,
  },
  market = {
    can_apply = function(ctx)
      return ctx.tile and ctx.tile.type == "market"
    end,
    apply = function(ctx)
      local game = ctx.game
      local player = ctx.player
      local spec, intent = market.build_choice_spec(player, game)
      if intent then
        return { intent = intent }
      end
      assert(spec ~= nil, "missing market choice spec")

      return { waiting = true, reason = "market_choice", intent = { kind = "need_choice", choice_spec = spec } }
    end,
  },
  buy_land = { can_apply = _can_buy, apply = _apply_buy },
  upgrade_land = { can_apply = _can_upgrade, apply = _apply_upgrade },
  pay_rent = { can_apply = _can_pay_rent, apply = _apply_pay_rent },
  tax = { can_apply = _can_tax, apply = _apply_tax },
  mine = {
    can_apply = function(ctx)
      local position = ctx.tile and ctx.tile.id
      local board = ctx.game.board
      return board and position and board:has_mine(position)
    end,
    apply = function(ctx)
      local player = ctx.player
      local game = ctx.game
      local position = ctx.tile.id
      local res = mine_effect.apply(game, player, position)
      if res and res.hospitalized then
        return {
          kind = "need_landing",
          player_id = player.id,
          board_index = player.position,
        }
      end
    end,
  },
}

land.executors = executors

function land.register_effect_executors(effect_registry)
  assert(effect_registry ~= nil, "missing effect_registry")
  assert(effect_registry.register_many ~= nil, "invalid effect_registry")
  effect_registry:register_many(executors)
end

return land
