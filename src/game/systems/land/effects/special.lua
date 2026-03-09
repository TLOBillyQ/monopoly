local mine_effect = require("src.game.systems.effects.mine_effect")

local M = {}

M.executors = {
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
  mine = {
    can_apply = function(ctx)
      local position = ctx.player and ctx.player.position
      local board = ctx.game.board
      if not (board and position and board:has_mine(position)) then
        return false
      end
      local mine = board:get_mine(position)
      if type(mine) ~= "table" then
        return true
      end
      if mine.armed ~= true then
        return false
      end
      local player = ctx.player
      local turn = ctx.game and ctx.game.turn or nil
      if player and mine.owner_id == player.id and mine.placed_turn_count ~= nil
          and turn and mine.placed_turn_count == turn.turn_count then
        return false
      end
      return true
    end,
    apply = function(ctx)
      local player = ctx.player
      local game = ctx.game
      local position = player.position
      local res = mine_effect.apply(game, player, position)
      if res and res.hospitalized then
        if res.wait_action_anim == true then
          return {
            waiting = true,
            wait_action_anim = true,
            next_state = res.next_state,
            next_args = res.next_args,
          }
        end
        return {
          kind = "need_landing",
          player_id = player.id,
          board_index = player.position,
        }
      end
    end,
  },
}

return M
