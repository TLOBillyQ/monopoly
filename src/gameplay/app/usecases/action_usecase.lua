local ActionUsecase = {}
ActionUsecase.__index = ActionUsecase

function ActionUsecase.new(opts)
  opts = opts or {}
  assert(opts.game, "ActionUsecase requires game")
  assert(opts.turn_usecase, "ActionUsecase requires turn_usecase")
  local self = {
    game = opts.game,
    turn_usecase = opts.turn_usecase,
  }
  return setmetatable(self, ActionUsecase)
end

function ActionUsecase:advance_turn()
  if self.turn_usecase then
    self.turn_usecase:advance()
  end
end

function ActionUsecase:handle_choice(action)
  if not action then
    return false
  end
  if action.type == "choice_select" or action.type == "choice_cancel" then
    if self.turn_usecase then
      self.turn_usecase:dispatch_choice(action)
      return true
    end
  end
  return false
end

function ActionUsecase:pending_choice()
  if self.turn_usecase and self.turn_usecase.pending_choice then
    return self.turn_usecase:pending_choice()
  end
end

return ActionUsecase
