local dice = require("src.ui.render.anim.dice")
local units = require("src.ui.render.anim.units")

local handlers = {}

function handlers.play_roll_dice_screen(state, anim, duration, hold_seconds, opts)
  dice.play_roll_dice_screen(anim, duration, hold_seconds, opts)
end

function handlers.play_overlay(state, anim, duration, opts)
  units.play_overlay(state, anim, duration, opts)
end

function handlers.play_missile(state, anim, duration, opts)
  units.play_missile(state, anim, duration, opts)
end

function handlers.play_monster(state, anim, duration, opts)
  units.play_monster(state, anim, duration, opts)
end

function handlers.play_clear_obstacles(state, anim, duration, opts)
  units.play_clear_obstacles(state, anim, duration, opts)
end

function handlers.play_move_effect(state, anim)
  return units.play_move_effect(state, anim)
end

function handlers.play_teleport_effect(state, anim, duration, opts)
  return units.play_teleport_effect(state, anim, duration, opts)
end

function handlers.play_forced_relocation(state, anim, duration, opts)
  return units.play_forced_relocation(state, anim, duration, opts)
end

function handlers.play_mine_trigger(state, anim, duration, opts)
  return units.play_mine_trigger(state, anim, duration, opts)
end

function handlers.play_roadblock_trigger(state, anim, duration, opts)
  return units.play_roadblock_trigger(state, anim, duration, opts)
end

function handlers.build_tip(state, anim)
  return units.build_tip(state, anim)
end

function handlers.clear_overlay(state, kind, tile_index)
  units.clear_overlay(state, kind, tile_index)
end

return handlers
