local dice = require("src.ui.render.anim.dice")
local units = require("src.ui.render.anim.units")

local handlers = {}

function handlers.play_roll_dice_screen(state, anim, duration, hold_seconds, opts)
  dice.play_roll_dice_screen(anim, duration, hold_seconds, opts)
end

handlers.play_overlay = units.play_overlay
handlers.play_missile = units.play_missile
handlers.play_monster = units.play_monster
handlers.play_clear_obstacles = units.play_clear_obstacles
handlers.play_move_effect = units.play_move_effect
handlers.play_teleport_effect = units.play_teleport_effect
handlers.play_forced_relocation = units.play_forced_relocation
handlers.play_mine_trigger = units.play_mine_trigger
handlers.play_roadblock_trigger = units.play_roadblock_trigger
handlers.build_tip = units.build_tip
handlers.clear_overlay = units.clear_overlay

return handlers

--[[ mutate4lua-manifest
version=4
projectHash=59a6d0934671c57c
scope.0.id=chunk:src/ui/render/anim/handlers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=23
scope.0.semanticHash=0a865aabfef2f312
scope.1.id=function:handlers.play_roll_dice_screen
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=4d00d79c24f7444b
]]
