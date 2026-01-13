local TurnManager = require("src.gameplay.app.services.turn_manager")

local TurnUsecase = {}
TurnUsecase.__index = TurnUsecase

function TurnUsecase.new(game)
  local tm = TurnManager.new(game)
  local self = {
    game = game,
    turn_manager = tm,
  }
  return setmetatable(self, TurnUsecase)
end

function TurnUsecase:advance()
  if not self.game or self.game.finished then
    return
  end
  self.turn_manager:run_turn()
  if self.game.check_victory then
    self.game:check_victory()
  end
end

function TurnUsecase:dispatch_choice(action)
  if not action or not self.game or self.game.finished then
    return
  end
  self.turn_manager:dispatch(action)
  if self.game.check_victory then
    self.game:check_victory()
  end
end

function TurnUsecase:pending_choice()
  if not self.game or not self.game.store then
    return nil
  end
  return self.game.store:get({ "turn", "pending_choice" })
end

return TurnUsecase
