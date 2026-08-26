local event_kinds = require("src.config.gameplay.event_kinds")
local constants = require("src.config.content.constants")
local inventory = require("src.rules.items.inventory")
local gain_reveal = require("src.rules.items.gain_reveal")
local achievement_progress = require("src.rules.ports.achievement_progress")
local event_feed = require("src.rules.ports.event_feed")
local number_utils = require("src.foundation.number")

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
        gain_reveal.queue(ctx.game, player, cfg.id, { source = "item_tile" })
      end
    end,
  },
}

return M

--[[ mutate4lua-manifest
version=4
projectHash=430c4f0120657120
scope.0.id=chunk:src/rules/land/effect_transit.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=49
scope.0.semanticHash=a0fa28a4e0cf09f4
scope.1.id=function:<anonymous>
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=15
scope.1.semanticHash=bc5d3c9ac1725f2e
scope.2.id=function:<anonymous>#2
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=30
scope.2.semanticHash=f385d2536f5a6dd6
scope.3.id=function:<anonymous>#3
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=35
scope.3.semanticHash=5478285cc23f89ec
scope.4.id=function:<anonymous>#4
scope.4.kind=function
scope.4.startLine=36
scope.4.endLine=44
scope.4.semanticHash=b4d5aea4ce5b4e25
]]
