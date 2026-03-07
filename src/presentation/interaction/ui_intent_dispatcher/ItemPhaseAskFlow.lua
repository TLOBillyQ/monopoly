local ui_view = require("src.presentation.api.UIViewService")
local choice_common = require("src.presentation.ui.choice_screen_service.common")
local runtime_state = require("src.core.RuntimeState")

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
    local current_model = runtime_state.get_ui_model(state)
    local choice = current_model and current_model.choice or nil
    state._skip_item_slot_highlight_replay_choice_id = choice and choice.id or nil
    if choice_common.requires_item_slot_pre_confirm(choice) and type(choice.options) == "table" and #choice.options == 1 then
      local opt = choice.options[1]
      local opt_id = type(opt) == "table" and opt.id or opt
      if opt_id ~= nil then
        action_port.dispatch_action(game, state, {
          type = "choice_select",
          choice_id = choice.id,
          option_id = opt_id,
          actor_role_id = intent.actor_role_id,
        }, opts)
      end
    end
    ui_view.close_choice_modal(state)
    return true
  end
  if intent_type == "choice_cancel" then
    state._item_phase_ask_active = nil
    state._item_phase_confirmed = nil
    state._suppress_item_slot_highlight_until_pick = nil
    state._skip_item_slot_highlight_replay_choice_id = nil
    ui_view.close_choice_modal(state)
    local current_model = runtime_state.get_ui_model(state)
    local choice = current_model and current_model.choice or nil
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
