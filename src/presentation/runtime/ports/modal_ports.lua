local modal_controller = require("src.presentation.runtime.controllers.modal_controller")
local choice_openers = require("src.presentation.runtime.controllers.choice_screens.openers")

local modal_ports = {}

function modal_ports.build()
  return {
    close_choice_modal = function(state)
      modal_controller.close_choice_modal(state)
    end,
    open_choice_modal = function(state, choice, market)
      modal_controller.open_choice_modal(state, choice, market)
    end,
    open_pre_confirm_screen = function(state, choice, option_id, title, body)
      choice_openers.open_pre_confirm_screen(state, choice, option_id, title, body)
    end,
    close_popup = function(state)
      modal_controller.close_popup(state)
    end,
  }
end

return modal_ports
