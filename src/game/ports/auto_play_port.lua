local auto_play_port = {}
local contract_helper = require("src.game.ports.contract_helper")

function auto_play_port.is_auto_player(game, player)
  return contract_helper.call_required_method(game, "auto_play_port", "auto_play_port", "is_auto_player", game, player) == true
end

function auto_play_port.pick_target_player(game, player, item_id, candidates)
  return contract_helper.call_required_method(game, "auto_play_port", "auto_play_port", "pick_target_player", game, player, item_id, candidates)
end

function auto_play_port.pick_remote_dice_value(game, player, dice_count)
  return contract_helper.call_required_method(game, "auto_play_port", "auto_play_port", "pick_remote_dice_value", game, player, dice_count)
end

function auto_play_port.pick_roadblock_target(game, player, candidates)
  return contract_helper.call_required_method(game, "auto_play_port", "auto_play_port", "pick_roadblock_target", game, player, candidates)
end

return auto_play_port
