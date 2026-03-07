local panel_presenter = require("src.presentation.widgets.UIPanelPresenter")

local presenter = {}

function presenter.refresh(state, ui_model, deps)
  return panel_presenter.refresh(state, ui_model, deps)
end

return presenter
