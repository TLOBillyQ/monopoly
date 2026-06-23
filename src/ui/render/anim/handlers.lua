local dice = require("src.ui.render.anim.dice")
local units = require("src.ui.render.anim.units")
local item_get_reveal = require("src.ui.render.anim.item_get_reveal")

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
handlers.play_item_get_reveal = item_get_reveal.play
handlers.build_tip = units.build_tip
handlers.clear_overlay = units.clear_overlay

return handlers

--[[ mutate4lua-manifest
version=2
projectHash=479dcf85a6a88d28
scope.0.id=chunk:src/ui/render/anim/handlers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=25
scope.0.semanticHash=2b637bd3cf4b6bc8
scope.0.lastMutatedAt=2026-06-23T13:59:05Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=3
scope.0.lastMutationKilled=3
scope.1.id=function:handlers.play_roll_dice_screen:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=9
scope.1.semanticHash=f3fd6228725b23f3
scope.1.lastMutatedAt=2026-06-23T13:59:05Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
]]
