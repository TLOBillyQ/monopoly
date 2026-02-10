local modal_state = {}

function modal_state.open_choice(state, choice_id)
  assert(state ~= nil, "missing state")
  state.pending_choice_elapsed = 0
  state.pending_choice_id = choice_id
end

function modal_state.open_market(state, choice_id, option_ids, selected_option_id)
  assert(state ~= nil, "missing state")
  state.market_choice_option_ids = option_ids
  state.pending_choice_selected_option_id = selected_option_id
  modal_state.open_choice(state, choice_id)
end

function modal_state.select_market_option(state, option_id)
  assert(state ~= nil, "missing state")
  state.pending_choice_selected_option_id = option_id
end

function modal_state.close_choice(state)
  assert(state ~= nil, "missing state")
  state.market_choice_option_ids = nil
  state.pending_choice_selected_option_id = nil
end

function modal_state.open_popup(state, payload)
  assert(state ~= nil and state.ui ~= nil, "missing ui state")
  state.ui.popup_active = true
  state.ui.popup_payload = payload
  state.ui.popup_seq = (state.ui.popup_seq or 0) + 1
end

function modal_state.close_popup(state)
  assert(state ~= nil and state.ui ~= nil, "missing ui state")
  state.ui.popup_active = false
  state.ui.popup_payload = nil
end

return modal_state
