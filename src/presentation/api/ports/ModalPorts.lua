local M = {}

function M.build()
  return {
    close_choice_modal = function(state)
      local ui_view = require("src.presentation.api.UIView")
      ui_view.close_choice_modal(state)
    end,
    open_choice_modal = function(state, choice, market)
      local ui_view = require("src.presentation.api.UIView")
      ui_view.open_choice_modal(state, choice, market)
    end,
    close_popup = function(state)
      local ui_view = require("src.presentation.api.UIView")
      ui_view.close_popup(state)
    end,
  }
end

return M
