local events = require("src.v2.domain.Events")

local match_reducer = {}
local event_types = events.types

function match_reducer.apply(state, event)
  if event.type ~= event_types.match_finished then
    return
  end
  local payload = event.payload or {}
  state.match.finished = true
  state.match.winner_ids = payload.winner_ids or {}
  state.match.winner_names = payload.winner_names or {}
  state.match.reason = payload.reason
  state.status = "finished"
end

return match_reducer
