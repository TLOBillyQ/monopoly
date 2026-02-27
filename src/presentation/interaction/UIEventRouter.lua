local canvas_event_router = require("src.presentation.canvas_runtime.CanvasEventRouter")

local ui_event_router = {}

function ui_event_router.unbind(state)
  return canvas_event_router.unbind(state)
end

function ui_event_router.bind(state, get_game)
  assert(state ~= nil, "missing state")
  local function resolve_game()
    if type(get_game) == "function" then
      return get_game()
    end
    return get_game
  end
  return canvas_event_router.bind(state, resolve_game)
end

return ui_event_router
