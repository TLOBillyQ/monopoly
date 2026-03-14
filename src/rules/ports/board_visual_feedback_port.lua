local board_visual_feedback_port = {}
local contract_helper = require("src.rules.ports.contract_helper")

function board_visual_feedback_port.sync_many(game, payload)
  local handled = contract_helper.call_required_method(
    game,
    "board_visual_feedback_port",
    "board_visual_feedback_port",
    "sync_many",
    game,
    payload
  )
  return handled == true
end

return board_visual_feedback_port
