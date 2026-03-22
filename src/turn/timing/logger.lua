local turn_decision = require("src.turn.waits.decision")

local turn_logger = {}

function turn_logger.log_turn_start(game)
  turn_decision.log_turn_start(game)
end

return turn_logger
