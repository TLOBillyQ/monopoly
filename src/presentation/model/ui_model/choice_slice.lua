local choice_view = require("src.presentation.view.widgets.choice")
local runtime_state = require("src.core.state_access.runtime_state")

local choice_slice = {}

function choice_slice.build_choice_and_market(game, env, ui_state)
  local choice = nil
  local pending = game.turn and game.turn.pending_choice
  if pending then
    choice = choice_view.build_choice_view(pending, { game = env.game })
  end
  local market = nil
  local ui_runtime = ui_state and runtime_state.ensure_ui_runtime(ui_state) or nil
  if choice and choice.route_key == "market" then
    market = {
      choice_id = choice.id,
      options = choice.options,
      allow_cancel = choice.allow_cancel,
      cancel_label = choice.cancel_label,
      selected_option_id = ui_runtime and ui_runtime.pending_choice_selected_option_id or nil,
      active_tab = choice.active_tab,
      page_index = choice.page_index,
      page_count = choice.page_count,
    }
  end
  return choice, market
end

function choice_slice.build_popup(ui_runtime)
  if ui_runtime and ui_runtime.popup_active and ui_runtime.popup_payload then
    return {
      title = ui_runtime.popup_payload.title,
      body = ui_runtime.popup_payload.body,
      button_text = ui_runtime.popup_payload.button_text,
    }
  end
  return nil
end

return choice_slice
