local market_view = require("visual.render.shop_view")
local canvas = require("visual.control.canvas")

local renderer = {}

function renderer.open_market_panel(state, choice, choice_id, market)
  local ui = state.ui
  canvas.switch(ui, canvas.CANVAS_MARKET)
  local market_payload = market or {
    choice_id = choice_id,
    options = choice.options,
    allow_cancel = choice.allow_cancel,
    cancel_label = choice.cancel_label,
    selected_option_id = state.pending_choice_selected_option_id,
  }
  market_view.refresh_market(state, market_payload)
  ui.market_active = true
end

function renderer.close_market_panel(state)
  market_view.close_market_panel(state)
end

return renderer
