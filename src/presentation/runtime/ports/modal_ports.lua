local modal_ports = {}

function modal_ports.build()
  return {
    close_choice_modal = function(state)
      local ui_view = require("src.presentation.runtime.view")
      ui_view.close_choice_modal(state)
    end,
    open_choice_modal = function(state, choice, market)
      local ui_view = require("src.presentation.runtime.view")
      ui_view.open_choice_modal(state, choice, market)
    end,
    open_pre_confirm_screen = function(state, choice, option_id, title, body)
      local controller = require("src.presentation.runtime.controllers.choice_screen_service.openers")
      controller.open_pre_confirm_screen(state, choice, option_id, title, body)
    end,
    close_popup = function(state)
      local ui_view = require("src.presentation.runtime.view")
      ui_view.close_popup(state)
    end,
  }
end

return modal_ports
