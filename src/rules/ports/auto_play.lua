local auto_play = {}
local contract_helper = require("src.rules.ports.contract_helper")

function auto_play.is_auto_player(game, player)
  return contract_helper.call_required_method(game, "auto_play_port", "auto_play_port", "is_auto_player", game, player) == true
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
version=2
projectHash=d991c4c5598f93f0
scope.0.id=chunk:src/rules/ports/auto_play.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=25
scope.0.semanticHash=7e99874620aa34c6
scope.1.id=function:auto_play.is_auto_player:4
scope.1.kind=function
scope.1.startLine=4
scope.1.endLine=6
scope.1.semanticHash=c3c83db9ab51ec3b
scope.2.id=function:auto_play.pick_target_player:8
scope.2.kind=function
scope.2.startLine=8
scope.2.endLine=10
scope.2.semanticHash=1b267aa592e84ee1
scope.3.id=function:auto_play.pick_remote_dice_value:12
scope.3.kind=function
scope.3.startLine=12
scope.3.endLine=14
scope.3.semanticHash=8c22ff8c48064465
scope.4.id=function:auto_play.pick_roadblock_target:16
scope.4.kind=function
scope.4.startLine=16
scope.4.endLine=18
scope.4.semanticHash=bb03b4fd935d9c6f
scope.5.id=function:auto_play.auto_action_for_choice:20
scope.5.kind=function
scope.5.startLine=20
scope.5.endLine=22
scope.5.semanticHash=5d7afc89f651aedd
]]
