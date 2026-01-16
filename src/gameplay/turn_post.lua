local ItemPhase = require("src.gameplay.item_phase")

local function phase_post(tm, args)
  local player = args.player or tm.game:current_player()
  local phase_res = ItemPhase.run(tm, "post_action", {
    player = player,
    resume_state = "post_action",
    resume_args = { player = player },
  })
  if phase_res and phase_res.waiting then
    return "wait_choice", { resume_state = "post_action", resume_args = { player = player } }
  end
  return "end_turn", { player = player }
end

return phase_post
