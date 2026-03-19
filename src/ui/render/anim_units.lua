local overlay = require("src.ui.render.anim_unit_overlay")
local move_anim = require("src.ui.render.move_anim")
local tip_text = require("src.ui.render.anim_tip_text")

local units = {}

function units.clear_overlay(state, kind, tile_index)
  overlay.clear_overlay(state, kind, tile_index)
end

function units.play_overlay(state, anim, duration, opts)
  overlay.play_overlay(state, anim, duration, opts)
end

function units.play_missile(state, anim, duration, opts)
  overlay.play_missile(state, anim, duration, opts)
end

function units.play_monster(state, anim, duration, opts)
  overlay.play_monster(state, anim, duration, opts)
end

function units.play_clear_obstacles(state, anim, duration, opts)
  overlay.play_clear_obstacles(state, anim, duration, opts)
end

function units.play_move_effect(state, anim)
  return move_anim.play_sequence(state.board_scene, anim)
end

function units.build_tip(state, anim)
  return tip_text.build(state, anim)
end

return units
