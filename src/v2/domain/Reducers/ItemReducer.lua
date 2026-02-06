local events = require("src.v2.domain.Events")

local item_reducer = {}
local event_types = events.types

function item_reducer.apply(state, event)
  local payload = event.payload or {}
  if event.type == event_types.choice_opened then
    local choice = payload.choice
    if choice and choice.kind == "market_buy" then
      local first = choice.options and choice.options[1]
      if first then
        state.ui_selected_market_option = first.id or first
      end
    end
    return
  end

  if event.type == event_types.choice_resolved then
    state.ui_selected_market_option = nil
  end
end

return item_reducer
