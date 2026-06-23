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
version=2
projectHash=d92937ab771e6261
scope.0.id=chunk:src/rules/land/effect_transit.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=49
scope.0.semanticHash=1a478c2b7719182d
scope.0.lastMutatedAt=2026-06-23T13:52:52Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=7
scope.0.lastMutationKilled=7
scope.1.id=function:anonymous@13:13
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=15
scope.1.semanticHash=b7a346cfbcbacc44
scope.1.lastMutatedAt=2026-06-23T13:52:52Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=4
scope.2.id=function:anonymous@16:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=30
scope.2.semanticHash=7d74b5865f21c5e4
scope.2.lastMutatedAt=2026-06-23T13:52:52Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=9
scope.2.lastMutationKilled=9
scope.3.id=function:anonymous@33:33
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=35
scope.3.semanticHash=2681f6a394f2baaf
scope.3.lastMutatedAt=2026-06-23T13:52:52Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=5
scope.3.lastMutationKilled=5
scope.4.id=function:anonymous@36:36
scope.4.kind=function
scope.4.startLine=36
scope.4.endLine=44
scope.4.semanticHash=3c489050c149c33f
scope.4.lastMutatedAt=2026-06-23T13:52:52Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=4
scope.4.lastMutationKilled=4
]]
