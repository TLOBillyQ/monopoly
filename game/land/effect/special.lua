local shop = require("game.shop")
local inventory = require("game.item.inventory")
local presenter = require("game.land.presenter")
local gameplay_rules = require("cfg.GameplayRules")
local logger = require("core.logger")

local special_effect = {}

local popup_show_seconds = gameplay_rules.popup_auto_close_seconds or 1.0

function special_effect.hospital_executor()
  return {
    can_apply = function(ctx)
      return ctx.tile and ctx.tile.type == "hospital"
    end,
    apply = function(ctx)
      ctx.game:player_apply_hospital_effects(ctx.player)
    end,
  }
end

function special_effect.mountain_executor()
  return {
    can_apply = function(ctx)
      return ctx.tile and ctx.tile.type == "mountain"
    end,
    apply = function(ctx)
      ctx.game:player_apply_mountain_effects(ctx.player)
    end,
  }
end

function special_effect.market_executor()
  return {
    can_apply = function(ctx)
      return ctx.tile and ctx.tile.type == "market"
    end,
    apply = function(ctx)
      local game = ctx.game
      local player = ctx.player
      local spec, intent = shop.build_choice_spec(player, game)
      if intent then
        return { intent = intent }
      end
      assert(spec ~= nil, "missing shop choice spec")
      return { waiting = true, reason = "market_choice", intent = { kind = "need_choice", choice_spec = spec } }
    end,
  }
end

function special_effect.item_executor()
  return {
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
        presenter.push_popup(ctx.game, "道具卡", player.name .. " 获得道具 " .. item_name, {
          kind = "item_card",
          image_ref = cfg.id,
          auto_close_seconds = popup_show_seconds,
        })
        presenter.queue_action_anim(ctx.game, {
          kind = "item_use",
          player_id = player.id,
          item_id = cfg.id,
          item_name = item_name,
          duration = popup_show_seconds,
        })
      end
    end,
  }
end

return special_effect
