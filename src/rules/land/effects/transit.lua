local event_kinds = require("src.config.gameplay.event_kinds")
local timing = require("src.config.gameplay.timing")
local constants = require("src.config.content.constants")
local inventory = require("src.rules.items.inventory")
local presenter = require("src.rules.land.presenter")
local event_feed = require("src.rules.ports.event_feed")
local number_utils = require("src.foundation.lang.number")

local popup_show_seconds = timing.popup_dwell_default_seconds or 1.0

local M = {}

M.executors = {
  start_reward = {
    can_apply = function(ctx)
      return ctx.tile and ctx.tile.type == "start" and ctx.on_landing
    end,
    apply = function(ctx)
      local player = ctx.player
      local move_result = ctx.move_result or {}
      if move_result.passed_start and move_result.passed_start > 0 then return end
      local bonus = constants.pass_start_bonus
      if ctx.game:player_has_deity(player, "rich") then
        bonus = bonus * 2
      end
      ctx.game:add_player_cash(player, bonus)
      event_feed.publish(ctx.game, {
        kind = event_kinds.transit,
        text = player.name .. " 停在起点，获得 " .. number_utils.format_integer_part(bonus) .. " 金币",
      })
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
        presenter.push_popup(ctx.game, "道具卡", player.name .. " 获得道具 " .. item_name, {
          kind = "item_card",
          image_ref = cfg.id,
          auto_close_seconds = popup_show_seconds,
          popup_opts = { policy = "defer" },
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
  },
}

return M
