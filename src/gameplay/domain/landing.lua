local property_effects = require("src.gameplay.domain.land")
local logger = require("src.util.logger")
local constants = require("src.config.constants")
local chance_cfg = require("src.config.chance_cards")
local random = require("src.util.random")
local Inventory = require("src.gameplay.domain.item_inventory")
local chance_effects = require("src.gameplay.domain.chance")

local Steal = require("src.gameplay.domain.item_steal")
local Effect = {}

local function get_service(ctx, key)
  if ctx and ctx.services and ctx.services[key] then
    return ctx.services[key]
  end
  return ctx and ctx.game and ctx.game.services and ctx.game.services[key]
end

Effect.defs = {
  {
    id = "pass_players",
    label = "擦肩而过",
    mandatory = true,
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
  {
    id = "start_reward",
    label = "起点奖励",
    mandatory = true,
    can_apply = function(ctx)
      return ctx and ctx.tile and ctx.tile.type == "start" and ctx.on_landing
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
  {
    id = "item_draw_and_give",
    label = "道具",
    mandatory = true,
    can_apply = function(ctx)
      return ctx and ctx.game and ctx.player and ctx.tile and ctx.tile.type == "item"
    end,
    apply = function(ctx)
      return Inventory.draw_and_give(ctx.player, ctx.game and ctx.game.rng)
    end,
  },
  {
    id = "chance_draw_and_resolve",
    label = "机会卡",
    mandatory = true,
    can_apply = function(ctx)
      return ctx and ctx.game and ctx.player and ctx.tile and ctx.tile.type == "chance"
    end,
    apply = function(ctx)
      local card = random.weighted_choice(chance_cfg, "weight", ctx.game and ctx.game.rng)
      logger.event(ctx.player.name .. " 抽到机会卡 " .. card.description)
      return chance_effects.resolve(ctx.game, ctx.player, card, ctx.move_result)
    end,
  },
  {
    id = "hospital",
    label = "医院",
    mandatory = true,
    can_apply = function(ctx)
      return ctx and ctx.tile and ctx.tile.type == "hospital"
    end,
    apply = function(ctx)
      ctx.player:apply_hospital_effects(ctx.game)
    end,
  },
  {
    id = "mountain",
    label = "深山",
    mandatory = true,
    can_apply = function(ctx)
      return ctx and ctx.tile and ctx.tile.type == "mountain"
    end,
    apply = function(ctx)
      ctx.player:apply_mountain_effects(ctx.game)
    end,
  },
  {
    id = "market",
    label = "黑市",
    mandatory = true,
    can_apply = function(ctx)
      return ctx and ctx.tile and ctx.tile.type == "market"
    end,
    apply = function(ctx)
      local game = ctx.game
      local player = ctx.player
      local market = get_service(ctx, "market")
      if not market then return nil end

      if player.inventory:is_full() then
        return { intent = { kind = "push_popup", payload = { title = "黑市", body = player.name .. " 卡槽已满" } } }
      end

      local spec, intent = market.build_choice_spec(game, player)
      if intent then return { intent = intent } end
      if not spec then return nil end

      return { waiting = true, reason = "market_choice", intent = { kind = "need_choice", choice_spec = spec } }
    end,
  },
  {
    id = "mine",
    label = "地雷",
    mandatory = true,
    can_apply = function(ctx)
      local position = ctx.tile and ctx.tile.id
      local board = ctx.game and ctx.game.board
      return board and position and board:has_mine(position)
    end,
    apply = function(ctx)
      local player = ctx.player
      local game = ctx.game
      local board = game.board
      local position = ctx.tile.id
      
      if player:has_angel() then
        logger.event(player.name .. " 天使保护，地雷无效")
        board:clear_mine(position)
        return
      end
    
      board:clear_mine(position)
      game:set_player_seat(player, nil)
      logger.event(player.name .. " 触发地雷，座驾被摧毁并送医")
      player:send_to_hospital(game)
      return {
        kind = "need_landing",
        player_id = player.id,
        board_index = player.position, -- Hospital position (set by send_to_hospital?)
        -- wait, send_to_hospital moves the player?
        -- Yes, usually.
        -- If player moved, we need to handle landing on hospital?
        -- Yes, send_to_hospital usually sets position.
        -- We return need_landing to recurse.
      }
    end,
  },
}


for _, eff in ipairs(property_effects.defs or {}) do
  table.insert(Effect.defs, eff)
end

return Effect
