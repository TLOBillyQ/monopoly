local logger = require("src.core.Logger")
local constants = require("Config.Generated.Constants")
local chance_cfg = require("Config.Generated.ChanceCards")
local gameplay_rules = require("Config.GameplayRules")
local inventory = require("src.game.item.ItemInventory")
local chance_effects = require("src.game.chance.Chance")
local intent_dispatcher = require("src.game.intent.IntentDispatcher")
local mine_effect = require("src.game.effect.MineEffect")
local steal = require("src.game.item.ItemSteal")
local market = require("src.game.market.Market")
local vehicle_feature = require("src.game.vehicle.VehicleFeature")
local number_utils = require("src.core.NumberUtils")

local landing = {}

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

local function _push_landing_popup(game, title, body, opts)
  if not (game and game.ui_port) then
    return false
  end
  opts = opts or {}
  intent_dispatcher.dispatch(game, {
    kind = "push_popup",
    payload = {
      title = title,
      body = body,
      image_ref = opts.image_ref,
      auto_close_seconds = opts.auto_close_seconds,
    },
  })
  return true
end

local popup_show_seconds = gameplay_rules.popup_auto_close_seconds or 1.0

landing.executors = {
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
        _push_landing_popup(ctx.game, "道具卡", player.name .. " 获得道具 " .. item_name, {
          image_ref = cfg.id,
          auto_close_seconds = popup_show_seconds,
        })
        local ui_port = ctx.game.ui_port
        if ui_port and ui_port.wait_action_anim then
          ctx.game:queue_action_anim({
            kind = "item_use",
            player_id = player.id,
            item_id = cfg.id,
            item_name = item_name,
            duration = popup_show_seconds,
          })
        end
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
      _push_landing_popup(ctx.game, "机会卡", ctx.player.name .. " 抽到机会卡：" .. card.description, {
        image_ref = card.id,
        auto_close_seconds = popup_show_seconds,
      })
      local ui_port = ctx.game.ui_port
      if ui_port and ui_port.wait_action_anim then
        ctx.game:queue_action_anim({
          kind = "chance",
          player_id = ctx.player.id,
          card_id = card.id,
          card_desc = card.description,
          duration = popup_show_seconds,
        })
      end
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
      if intent then return { intent = intent } end
      assert(spec ~= nil, "missing market choice spec")

      return { waiting = true, reason = "market_choice", intent = { kind = "need_choice", choice_spec = spec } }
    end,
  },
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

return landing
