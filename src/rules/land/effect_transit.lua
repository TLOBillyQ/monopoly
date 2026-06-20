local event_kinds = require("src.config.gameplay.event_kinds")
local timing = require("src.config.gameplay.timing")
local constants = require("src.config.content.constants")
local inventory = require("src.rules.items.inventory")
local presenter = require("src.rules.land.presenter")
local achievement_progress = require("src.rules.ports.achievement_progress")
local event_feed = require("src.rules.ports.event_feed")
local number_utils = require("src.foundation.number")

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
      achievement_progress.cash_received(ctx.game, player, bonus)
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

--[[ mutate4lua-manifest
version=2
projectHash=a3e7afc722d12e30
scope.0.id=chunk:src/rules/land/effect_transit.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=63
scope.0.semanticHash=8bfbfe84be9b510f
scope.1.id=function:anonymous@15:15
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=17
scope.1.semanticHash=b7a346cfbcbacc44
scope.2.id=function:anonymous@18:18
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=31
scope.2.semanticHash=cf06c928dbdd597a
scope.3.id=function:anonymous@34:34
scope.3.kind=function
scope.3.startLine=34
scope.3.endLine=36
scope.3.semanticHash=2681f6a394f2baaf
scope.4.id=function:anonymous@37:37
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=58
scope.4.semanticHash=7d9edbe7962e7e98
]]
