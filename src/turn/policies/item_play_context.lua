local auto_play_port = require("src.rules.ports.auto_play")
local control = require("src.player.control")

local item_auto_play_context = {}

local function _is_computer_controlled(player)
  return player and control.is_computer_controlled(player) == true or false
end

function item_auto_play_context.build(game, player, context)
  local ctx = context or {}
  local is_computer_controlled = _is_computer_controlled(player)
  ctx.is_computer_controlled = is_computer_controlled

  if not is_computer_controlled then
    return ctx
  end

  if type(ctx.select_target_player) ~= "function" then
    ctx.select_target_player = function(item_id, candidates)
      return auto_play_port.pick_target_player(game, player, item_id, candidates)
    end
  end

  if type(ctx.select_remote_dice) ~= "function" then
    ctx.select_remote_dice = function(dice_count)
      return auto_play_port.pick_remote_dice_value(game, player, dice_count)
    end
  end

  return ctx
end

return item_auto_play_context

--[[ mutate4lua-manifest
version=4
projectHash=1020f62c2ebca95a
scope.0.id=chunk:src/turn/policies/item_play_context.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=35
scope.0.semanticHash=227940905d5172ff
scope.1.id=function:_is_computer_controlled
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=8e28a68763ad737b
scope.2.id=function:item_auto_play_context.build
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=32
scope.2.semanticHash=145022b4563f5a94
scope.3.id=function:ctx.select_target_player
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=22
scope.3.semanticHash=249e4c138b486177
scope.4.id=function:ctx.select_remote_dice
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=28
scope.4.semanticHash=9662844558837f1d
]]
