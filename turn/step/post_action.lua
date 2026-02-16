local item_phase = require("game.item.phase")

local function _phase_post_action(turn_mgr, args)
  local player = args.player
  local game = turn_mgr.game

  local phase_res = item_phase.run(turn_mgr, "post_action", {
    player = player,
    resume_state = "end_turn",
    resume_args = { player = player },
  })
  if phase_res and phase_res.waiting then
    local resume_state = phase_res.resume_state or "end_turn"
    local resume_args = phase_res.resume_args or { player = player }
    if phase_res.wait_action_anim then
      return "wait_action_anim", { resume_state = resume_state, resume_args = resume_args }
    end
    return "wait_choice", { resume_state = resume_state, resume_args = resume_args }
  end

  return "end_turn", { player = player }
end

return _phase_post_action
