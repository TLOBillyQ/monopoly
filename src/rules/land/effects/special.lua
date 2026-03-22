local mine_effect = require("src.rules.effects.mine_effect")

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
      return mine_effect.can_trigger(ctx.game, ctx.player, position)
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
