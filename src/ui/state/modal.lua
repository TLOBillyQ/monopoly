local modal_state = {}
local runtime_state = require("src.ui.state.runtime")

local function _ui_runtime(state)
  return runtime_state.ensure_ui_runtime(state)
end

function modal_state.open_choice(state, choice_id, option_ids, selected_option_id)
  assert(state ~= nil, "missing state")
  runtime_state.set_pending_choice_elapsed(state, 0)
  runtime_state.set_pending_choice_id(state, choice_id)
  local ui_runtime = _ui_runtime(state)
  ui_runtime.choice_visible_option_ids = option_ids
  ui_runtime.pending_choice_selected_option_id = selected_option_id
end

modal_state.open_market = modal_state.open_choice

function modal_state.select_choice_option(state, option_id)
  assert(state ~= nil, "missing state")
  local ui_runtime = _ui_runtime(state)
  ui_runtime.pending_choice_selected_option_id = option_id
  runtime_state.set_ui_dirty(state, true)
end

modal_state.select_market_option = modal_state.select_choice_option

function modal_state.close_choice(state)
  assert(state ~= nil, "missing state")
  local ui_runtime = _ui_runtime(state)
  ui_runtime.choice_visible_option_ids = nil
  ui_runtime.pending_choice_selected_option_id = nil
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
