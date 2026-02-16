local constants = require("cfg.Generated.Constants")
local steal = require("game.item.handler.steal")
local mine = require("game.effect.mine")
local logger = require("core.logger")
local number_utils = require("core.math")

local misc_effect = {}

function misc_effect.pass_players_executor()
  return {
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
  }
end

function misc_effect.start_reward_executor()
  return {
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
      logger.event(
        player.name .. " 停在起点，获得 " .. number_utils.format_integer_part(constants.pass_start_bonus) .. " 金币"
      )
    end,
  }
end

function misc_effect.mine_executor()
  return {
    can_apply = function(ctx)
      local position = ctx.tile and ctx.tile.id
      local board = ctx.game.board
      return board and position and board:has_mine(position)
    end,
    apply = function(ctx)
      local player = ctx.player
      local game = ctx.game
      local position = ctx.tile.id
      local res = mine.apply(game, player, position)
      if res and res.hospitalized then
        return {
          kind = "need_landing",
          player_id = player.id,
          board_index = player.position,
        }
      end
    end,
  }
end

return misc_effect
