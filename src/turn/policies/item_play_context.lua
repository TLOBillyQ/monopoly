local auto_play_port = require("src.rules.ports.auto_play")

local item_auto_play_context = {}

function item_auto_play_context.build(game, player, context)
  local ctx = context or {}
  local is_auto_player = player and auto_play_port.is_auto_player(game, player) == true or false
  ctx.is_auto_player = is_auto_player
  ctx.by_ai = is_auto_player

  if not is_auto_player then
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
version=2
projectHash=c10834de2db278ad
scope.0.id=chunk:src/turn/policies/item_play_context.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=31
scope.0.semanticHash=cbb7e46ef77aea62
scope.1.id=function:anonymous@16:16
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=18
scope.1.semanticHash=a8e4f0ec416519e8
scope.2.id=function:anonymous@22:22
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=24
scope.2.semanticHash=91b47b1a58caab47
scope.3.id=function:item_auto_play_context.build:5
scope.3.kind=function
scope.3.startLine=5
scope.3.endLine=28
scope.3.semanticHash=3d6bc171a425729f
]]
