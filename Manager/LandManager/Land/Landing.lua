local logger = require("Library.Monopoly.Logger")
local constants = require("Config.Generated.Constants")
local chance_cfg = require("Config.Generated.ChanceCards")
local random = require("Library.Monopoly.Random")
local Inventory = require("Manager.ItemManager.Item.ItemInventory")
local chance_effects = require("Manager.GameManager.Chance")
local MineEffect = require("Manager.EffectManager.Effect.MineEffect")
local Steal = require("Manager.ItemManager.Item.ItemSteal")
local SERVICE_KEY = require("Globals.ServiceKeys")

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
      return Steal.handle_pass_players(ctx.game, ctx.player, ids)
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
      player:add_cash(constants.pass_start_bonus)
      logger.event(player.name .. " 停在起点，获得 " .. constants.pass_start_bonus .. " 金币")
    end,
  },
  item_draw_and_give = {
    can_apply = function(ctx)
      return ctx.game and ctx.player and ctx.tile and ctx.tile.type == "item"
    end,
    apply = function(ctx)
      return Inventory.draw_and_give(ctx.player, ctx.game.rng, { game = ctx.game })
    end,
  },
  chance_draw_and_resolve = {
    can_apply = function(ctx)
      return ctx.game and ctx.player and ctx.tile and ctx.tile.type == "chance"
    end,
    apply = function(ctx)
      local card = random.weighted_choice(chance_cfg, "weight", ctx.game.rng)
      logger.event(ctx.player.name .. " 抽到机会卡 " .. card.description)
      return chance_effects.resolve(ctx.game, ctx.player, card, ctx.move_result)
    end,
  },
  hospital = {
    can_apply = function(ctx)
      return ctx.tile and ctx.tile.type == "hospital"
    end,
    apply = function(ctx)
      ctx.player:apply_hospital_effects(ctx.game)
    end,
  },
  mountain = {
    can_apply = function(ctx)
      return ctx.tile and ctx.tile.type == "mountain"
    end,
    apply = function(ctx)
      ctx.player:apply_mountain_effects(ctx.game)
    end,
  },
  market = {
    can_apply = function(ctx)
      return ctx.tile and ctx.tile.type == "market"
    end,
    apply = function(ctx)
      local game = ctx.game
      local player = ctx.player
      local market = game:get_service(SERVICE_KEY.market, ctx)

      local spec, intent = market.build_choice_spec(player, game)
      if intent then return { intent = intent } end
      if not spec then return nil end

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
      local res = MineEffect.apply(game, player, position)
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
