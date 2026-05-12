local turn_action_gate = {}

local input_blocked_types = {
  ui_button = true,
  choice_pick = true,
  choice_select = true,
  choice_cancel = true,
  market_confirm = true,
  market_select = true,
  market_page_prev = true,
  market_page_next = true,
  market_tab_select = true,
  popup_confirm = true,
}

local function _normalize_action_type(action_or_type)
  if type(action_or_type) == "table" then
    return action_or_type.type
  end
  return action_or_type
end

function turn_action_gate.resolve_gate_state(gate_state_or_flag)
  if type(gate_state_or_flag) ~= "table" then
    return {
      input_blocked = gate_state_or_flag == true,
      choice_active = false,
      market_active = false,
      popup_active = false,
      detained_wait_active = false,
      phase = nil,
    }
  end
  return {
    input_blocked = gate_state_or_flag.input_blocked == true,
    choice_active = gate_state_or_flag.choice_active == true,
    market_active = gate_state_or_flag.market_active == true,
    popup_active = gate_state_or_flag.popup_active == true,
    detained_wait_active = gate_state_or_flag.detained_wait_active == true,
    phase = gate_state_or_flag.phase,
  }
end

function turn_action_gate.should_block_action(gate_state_or_flag, action_or_type)
  local gate_state = turn_action_gate.resolve_gate_state(gate_state_or_flag)
  local action_type = _normalize_action_type(action_or_type)
  if not action_type then
    return false
  end
  if action_type == "popup_confirm" then
    return false
  end
  if action_type == "ui_button"
      and type(action_or_type) == "table"
      and action_or_type.id == "auto" then
    return false
  end

  if action_type == "ui_button"
      and type(action_or_type) == "table"
      and action_or_type.id == "next"
      and (
        gate_state.choice_active
        or gate_state.market_active
        or gate_state.popup_active
        or gate_state.detained_wait_active
      ) then
    return true
  end

  if not gate_state.input_blocked then
    return false
  end
  return input_blocked_types[action_type] == true
end

return turn_action_gate
