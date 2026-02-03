local Logger = require("src.core.Logger")
local Constants = require("Config.Generated.Constants")
local ChanceCfg = require("Config.Generated.ChanceCards")
require "vendor.third_party.Utils"
local Inventory = require("src.game.item.ItemInventory")
local ChanceEffects = require("src.game.chance.Chance")
local MineEffect = require("src.game.effect.MineEffect")
local Steal = require("src.game.item.ItemSteal")
local MarketManager = require("src.game.market.MarketManager")

local Landing = {}

Landing.executors = {
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
      return Steal.HandlePassPlayers(ctx.game, ctx.player, ids)
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
      player:AddCash(Constants.pass_start_bonus)
      Logger.Event(player.name .. " 停在起点，获得 " .. Constants.pass_start_bonus .. " 金币")
    end,
  },
  item_draw_and_give = {
    can_apply = function(ctx)
      return ctx.game and ctx.player and ctx.tile and ctx.tile.type == "item"
    end,
    apply = function(ctx)
      return Inventory.DrawAndGive(ctx.player, ctx.game.rng, { game = ctx.game })
    end,
  },
  chance_draw_and_resolve = {
    can_apply = function(ctx)
      return ctx.game and ctx.player and ctx.tile and ctx.tile.type == "chance"
    end,
    apply = function(ctx)
      local picked = Utils.choice_weight_list(ChanceCfg, 1, function(item)
        return item.weight or 0
      end, true)
      local card = picked[1] or ChanceCfg[1]
      if not card then
        return
      end
      Logger.Event(ctx.player.name .. " 抽到机会卡 " .. card.description)
      return ChanceEffects.Resolve(ctx.game, ctx.player, card, ctx.move_result)
    end,
  },
  hospital = {
    can_apply = function(ctx)
      return ctx.tile and ctx.tile.type == "hospital"
    end,
    apply = function(ctx)
      ctx.player:ApplyHospitalEffects(ctx.game)
    end,
  },
  mountain = {
    can_apply = function(ctx)
      return ctx.tile and ctx.tile.type == "mountain"
    end,
    apply = function(ctx)
      ctx.player:ApplyMountainEffects(ctx.game)
    end,
  },
  market = {
    can_apply = function(ctx)
      return ctx.tile and ctx.tile.type == "market"
    end,
    apply = function(ctx)
      local game = ctx.game
      local player = ctx.player
      local spec, intent = MarketManager.BuildChoiceSpec(player, game)
      if intent then return { intent = intent } end
      assert(spec ~= nil, "missing market choice spec")

      return { waiting = true, reason = "market_choice", intent = { kind = "need_choice", choice_spec = spec } }
    end,
  },
  mine = {
    can_apply = function(ctx)
      local position = ctx.tile and ctx.tile.id
      local board = ctx.game.board
      return board and position and board:HasMine(position)
    end,
    apply = function(ctx)
      local player = ctx.player
      local game = ctx.game
      local position = ctx.tile.id
      local res = MineEffect.Apply(game, player, position)
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

return Landing

