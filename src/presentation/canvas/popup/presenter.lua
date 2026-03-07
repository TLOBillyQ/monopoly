local popup_renderer = require("src.presentation.widgets.popup_renderer")

local presenter = {}

function presenter.show(state, payload)
  return popup_renderer.show_popup(state, payload)
end

function presenter.hide(state)
  return popup_renderer.hide_popup(state)
end

function presenter.switch_canvas(state, kind, target_canvas, fallback_canvas)
  return popup_renderer.switch_popup_canvas(state, kind, target_canvas, fallback_canvas)
end

return presenter
