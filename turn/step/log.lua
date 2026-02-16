local turn_decision = require("turn.step.decide")

local turn_logger = {}

function turn_logger.log_turn_start(game)
  turn_decision.log_turn_start(game)
end

return turn_logger
