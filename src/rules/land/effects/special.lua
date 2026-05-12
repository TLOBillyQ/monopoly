local mine_effect = require("src.rules.effects.mine")
local angel_feedback = require("src.rules.items.angel_feedback")

local M = {}

local function _detention_executor(tile_type, label, effect_method)
  return {
    can_apply = function(ctx)
      return ctx.tile and ctx.tile.type == tile_type
    end,
    apply = function(ctx)
      if ctx.game:player_has_angel(ctx.player) then
        angel_feedback.publish(ctx.game, ctx.player, label, { tile_index = ctx.player.position })
        return
      end
      ctx.game[effect_method](ctx.game, ctx.player)
    end,
  }
end

M.executors = {
  hospital = _detention_executor("hospital", "住院", "player_apply_hospital_effects"),
  mountain = _detention_executor("mountain", "深山迷路", "player_apply_mountain_effects"),
  mine = {
    can_apply = function(ctx)
      local position = ctx.player and ctx.player.position
      local game = ctx.game
      return mine_effect.can_trigger(game, ctx.player, position)
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
