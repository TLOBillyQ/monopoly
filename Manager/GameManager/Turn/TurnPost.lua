local ItemPhase = require("Manager.GameManager.Item.ItemPhase")

local function phase_post(tm, args)
  local player = args.player or tm.game:current_player()
  local phase_res = ItemPhase.run(tm, "post_action", {
    player = player,
    resume_state = "post_action",
    resume_args = { player = player },
  })
  if phase_res and phase_res.waiting then
    local resume_state = phase_res.resume_state or "post_action"
    local resume_args = phase_res.resume_args or { player = player }
    if phase_res.wait_action_anim then
      return "wait_action_anim", { resume_state = resume_state, resume_args = resume_args }
    end
    return "wait_choice", { resume_state = resume_state, resume_args = resume_args }
  end
  return "end_turn", { player = player }
end

return phase_post
