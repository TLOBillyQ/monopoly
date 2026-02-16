local chance_cfg = require("cfg.Generated.ChanceCards")
local vehicle_feature = require("game.vehicle")
local chance_resolver = require("chance")
local presenter = require("game.land.presenter")
local logger = require("core.logger")
local gameplay_rules = require("cfg.GameplayRules")

local chance_effect = {}

local popup_show_seconds = gameplay_rules.popup_auto_close_seconds or 1.0

local chance_weights = {}
for i, cfg in ipairs(chance_cfg) do
  local weight = cfg.weight or 0
  if weight < 0 then
    weight = 0
  end
  chance_weights[i] = weight
end

local function _is_drawable(card)
  if vehicle_feature.is_vehicle_chance_card(card) and not vehicle_feature.is_enabled() then
    return false
  end
  return true
end

function chance_effect.pick_card()
  local total_weight = 0
  local first_drawable = nil
  for i, card in ipairs(chance_cfg) do
    if _is_drawable(card) then
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
    if _is_drawable(card) then
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

function chance_effect.executor()
  return {
    can_apply = function(ctx)
      return ctx.game and ctx.player and ctx.tile and ctx.tile.type == "chance"
    end,
    apply = function(ctx)
      local card = chance_effect.pick_card() or chance_cfg[1]
      if not card then
        return
      end
      logger.event(ctx.player.name .. " 抽到机会卡 " .. card.description)
      presenter.push_popup(ctx.game, "机会卡", ctx.player.name .. " 抽到机会卡：" .. card.description, {
        kind = "chance_card",
        image_ref = card.id,
        auto_close_seconds = popup_show_seconds,
      })
      presenter.queue_action_anim(ctx.game, {
        kind = "chance",
        player_id = ctx.player.id,
        card_id = card.id,
        card_desc = card.description,
        duration = popup_show_seconds,
      })
      return chance_resolver.resolve(ctx.game, ctx.player, card, ctx.move_result)
    end,
  }
end

return chance_effect
