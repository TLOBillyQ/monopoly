local overlay = require("src.presentation.view.render.action_anim_unit_overlay")
local tip_text = require("src.presentation.view.render.action_anim_tip_text")

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

function units.play_clear_obstacles(state, anim, duration, opts)
  overlay.play_clear_obstacles(state, anim, duration, opts)
end

function units.build_tip(state, anim)
  return tip_text.build(state, anim)
end

return units
