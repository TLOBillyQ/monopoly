local events = require("src.v2.domain.Events")

local choice_reducer = {}
local event_types = events.types

function choice_reducer.apply(state, event)
  local turn = state.turn
  local payload = event.payload or {}

  if event.type == event_types.choice_opened then
    turn.pending_interaction = payload.choice
    turn.choice_deadline = payload.deadline
    turn.choice_remaining = nil
    return
  end

  if event.type == event_types.choice_resolved then
    turn.pending_interaction = nil
    turn.choice_deadline = nil
    turn.choice_remaining = nil
    return
  end
end

return choice_reducer
