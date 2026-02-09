local logger = require("src.core.Logger")
local constants = require("Config.Generated.Constants")
local chance_cfg = require("Config.Generated.ChanceCards")
local inventory = require("src.game.item.ItemInventory")
local chance_effects = require("src.game.chance.Chance")
local mine_effect = require("src.game.effect.MineEffect")
local steal = require("src.game.item.ItemSteal")
local market = require("src.game.market.Market")

local landing = {}

local chance_weights = {}
local chance_total_weight = 0
for i, cfg in ipairs(chance_cfg) do
  local weight = cfg.weight or 0
  if weight < 0 then
    weight = 0
  end
  chance_weights[i] = weight
  chance_total_weight = chance_total_weight + weight
end

local function _pick_chance_card()
  if #chance_cfg == 0 then
    return nil
  end
  if chance_total_weight <= 0 then
    return chance_cfg[1]
  end
  local rand = LuaAPI.rand() * chance_total_weight
  local accumulated = 0
  for i, card in ipairs(chance_cfg) do
    accumulated = accumulated + (chance_weights[i] or 0)
    if accumulated >= rand then
      return card
    end
  end
  return chance_cfg[1]
end

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
      logger.event(player.name .. " 停在起点，获得 " .. constants.pass_start_bonus .. " 金币")
    end,
  },
  item_draw_and_give = {
    can_apply = function(ctx)
      return ctx.game and ctx.player and ctx.tile and ctx.tile.type == "item"
    end,
    apply = function(ctx)
      return inventory.draw_and_give(ctx.player, { game = ctx.game })
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
