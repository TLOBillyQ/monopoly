local modal_state = require("src.presentation.interaction.UIModalStateCoordinator")
local openers = require("src.presentation.ui.choice_screen_service.openers")
local common = require("src.presentation.ui.choice_screen_service.common")

local service = {}

function service.open_choice_modal(state, choice, market)
  return openers.open_choice_modal(state, choice, market)
end

function service.open_player_or_remote_screen(state, choice, choice_id, screen_key)
  openers.open_player_or_remote_screen(state, choice, choice_id, screen_key)
end

function service.open_target_screen(state, choice, choice_id)
  openers.open_target_screen(state, choice, choice_id)
end

function service.open_building_screen(state, choice, choice_id)
  openers.open_building_screen(state, choice, choice_id)
end

function service.select_choice_option(state, option_id)
  if not option_id then
    return
  end
  modal_state.select_choice_option(state, option_id)
  local ui = state and state.ui
  if not ui then
    return
  end
  if ui.active_choice_screen_key == "building" then
    local screen = ui.choice_screens and ui.choice_screens.building or nil
    local choice = state.ui_model and state.ui_model.choice or nil
    if screen and screen.title then
      ui:set_label(screen.title, common.resolve_choice_title(choice, "building", option_id))
    end
  end
end

function service.hide_choice_screens(ui)
  common.hide_choice_screens(ui)
end

function service.resolve_screen_key(choice)
  return common.resolve_screen_key(choice)
end

function service.resolve_canvas_for_screen(screen_key)
  return common.resolve_canvas_for_screen(screen_key)
end

return service
