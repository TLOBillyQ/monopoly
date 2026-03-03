local ui_view = require("src.presentation.api.UIViewService")

local item_phase_ask_flow = {}

function item_phase_ask_flow.dispatch(state, game, intent, opts, action_port)
  local intent_type = intent and intent.type
  if state._item_phase_ask_active ~= true then
    return false
  end
  if intent_type == "choice_select" then
    state._item_phase_ask_active = nil
    state._item_phase_confirmed = true
    state._suppress_item_slot_highlight_until_pick = nil
    ui_view.close_choice_modal(state)
    return true
  end
  if intent_type == "choice_cancel" then
    state._item_phase_ask_active = nil
    state._item_phase_confirmed = nil
    state._suppress_item_slot_highlight_until_pick = nil
    ui_view.close_choice_modal(state)
    local choice = state.ui_model and state.ui_model.choice or nil
    if choice and choice.id then
      action_port.dispatch_action(game, state, {
        type = "choice_cancel",
        choice_id = choice.id,
        actor_role_id = intent.actor_role_id,
      }, opts)
    end
    return true
  end
  return false
end

return item_phase_ask_flow
