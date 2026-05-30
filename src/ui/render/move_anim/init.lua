local playback = require("src.ui.render.move_anim.playback")
local stop = require("src.ui.render.move_anim.stop")

local move_anim = {}

move_anim.step_duration             = playback.step_duration
move_anim.one_step                  = playback.one_step
move_anim.play_sequence             = function(board_scene, anim_ctx)
  return playback.play_sequence(board_scene, anim_ctx, move_anim)
end
move_anim.play_teleport             = stop.play_teleport
move_anim.snap_player_to_index      = stop.snap_player_to_index
move_anim.prepare_player_for_snap   = stop.prepare_player_for_snap
move_anim.stop_player_presentation  = stop.stop_player_presentation
move_anim.clear_player_token        = stop.clear_player_token
move_anim.has_active_stop_context   = stop.has_active_stop_context

return move_anim

--[[ mutate4lua-manifest
version=2
projectHash=e4357b9dc29a107d
scope.0.id=chunk:src/ui/render/move_anim/init.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=19
scope.0.semanticHash=8658a6dcec3d1d7e
scope.1.id=function:anonymous@8:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=10
scope.1.semanticHash=7bfae2656ea94cc8
]]
