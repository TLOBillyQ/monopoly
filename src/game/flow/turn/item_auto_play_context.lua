local agent = require("src.game.core.ai.agent")

local item_auto_play_context = {}

function item_auto_play_context.build(game, player, context)
  local ctx = context or {}
  local is_auto_player = player and agent.is_auto_player(player) == true or false
  ctx.is_auto_player = is_auto_player
  ctx.by_ai = is_auto_player

  if not is_auto_player then
    return ctx
  end

  if type(ctx.select_target_player) ~= "function" then
    ctx.select_target_player = function(item_id, candidates)
      return agent.pick_target_player(game, player, item_id, candidates)
    end
  end

  if type(ctx.select_remote_dice) ~= "function" then
    ctx.select_remote_dice = function(dice_count)
      return agent.pick_remote_dice_value(game, player, dice_count)
    end
  end

  return ctx
end

return item_auto_play_context
