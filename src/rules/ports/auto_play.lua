local auto_play = {}
local contract_helper = require("src.rules.ports.contract_helper")

function auto_play.is_computer_controlled(game, player)
  return contract_helper.call_required_method(game, "auto_play_port", "auto_play_port", "is_computer_controlled", game, player) == true
end

function auto_play.pick_target_player(game, player, item_id, candidates)
  return contract_helper.call_required_method(game, "auto_play_port", "auto_play_port", "pick_target_player", game, player, item_id, candidates)
end

function auto_play.pick_remote_dice_value(game, player, dice_count)
  return contract_helper.call_required_method(game, "auto_play_port", "auto_play_port", "pick_remote_dice_value", game, player, dice_count)
end

function auto_play.pick_roadblock_target(game, player, candidates)
  return contract_helper.call_required_method(game, "auto_play_port", "auto_play_port", "pick_roadblock_target", game, player, candidates)
end

function auto_play.auto_action_for_choice(game, choice)
  return contract_helper.call_required_method(game, "auto_play_port", "auto_play_port", "auto_action_for_choice", game, choice)
end

return auto_play

--[[ mutate4lua-manifest
version=4
projectHash=09f0fe2ad73388c6
scope.0.id=chunk:src/rules/ports/auto_play.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=25
scope.0.semanticHash=d75606c336d07a2f
scope.1.id=function:auto_play.is_computer_controlled
scope.1.kind=function
scope.1.startLine=4
scope.1.endLine=6
scope.1.semanticHash=64d8f0f61f9b7bf4
scope.2.id=function:auto_play.pick_target_player
scope.2.kind=function
scope.2.startLine=8
scope.2.endLine=10
scope.2.semanticHash=3ff0ec55830c8ea6
scope.3.id=function:auto_play.pick_remote_dice_value
scope.3.kind=function
scope.3.startLine=12
scope.3.endLine=14
scope.3.semanticHash=5225d4c6399d0b12
scope.4.id=function:auto_play.pick_roadblock_target
scope.4.kind=function
scope.4.startLine=16
scope.4.endLine=18
scope.4.semanticHash=5225d4c6399d0b12
scope.5.id=function:auto_play.auto_action_for_choice
scope.5.kind=function
scope.5.startLine=20
scope.5.endLine=22
scope.5.semanticHash=00a4ee26c89fb566
]]
