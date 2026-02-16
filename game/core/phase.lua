local phase_begin = require("turn.step.begin")
local phase_roll = require("turn.step.roll")
local phase_move = require("turn.step.walk")
local phase_land = require("turn.step.arrive")
local phase_post_action = require("turn.step.post_action")
local phase_end_turn = require("turn.step.end_turn")

local phase = {}

function phase.build_default_phases()
  return {
    start = phase_begin,
    roll = phase_roll,
    move = phase_move,
    landing = phase_land,
    post_action = phase_post_action,
    end_turn = phase_end_turn,
  }
end

return phase
