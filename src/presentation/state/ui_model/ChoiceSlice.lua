local choice_view = require("src.presentation.ui.UIChoice")

local choice_slice = {}

function choice_slice.build_choice_and_market(game, env, ui_state)
  local choice = nil
  local pending = game.turn and game.turn.pending_choice
  if pending then
    choice = choice_view.build_choice_view(pending, { game = env.game })
    choice.id = pending.id
    choice.kind = pending.kind
    choice.route_key = pending.route_key
    choice.requires_confirm = pending.requires_confirm == true
  end
  local market = nil
  if choice and choice.kind == "market_buy" then
    local meta = choice.meta or {}
    market = {
      choice_id = choice.id,
      options = choice.options,
      allow_cancel = choice.allow_cancel,
      cancel_label = choice.cancel_label,
      selected_option_id = ui_state and ui_state.pending_choice_selected_option_id or nil,
      active_tab = choice.active_tab or meta.active_tab,
      page_index = choice.page_index or meta.page_index,
      page_count = choice.page_count or meta.page_count,
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
