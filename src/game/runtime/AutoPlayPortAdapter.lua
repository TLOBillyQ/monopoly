local agent = require("src.game.core.ai.Agent")

local adapter = {}

function adapter.build()
  return {
    is_auto_player = function(_, player)
      return agent.is_auto_player(player)
    end,
    pick_target_player = function(game, player, item_id, candidates)
      return agent.pick_target_player(game, player, item_id, candidates)
    end,
    pick_remote_dice_value = function(game, player, dice_count)
      return agent.pick_remote_dice_value(game, player, dice_count)
    end,
    pick_roadblock_target = function(game, player, _candidates)
      return agent.pick_roadblock_target(game, player)
    end,
  }
end

return adapter
