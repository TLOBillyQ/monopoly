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

local function _is_always_permitted(action_type)
  return not action_type or action_type == "popup_confirm"
end

local function _is_auto_button(action_or_type, action_type)
  return action_type == "ui_button"
    and type(action_or_type) == "table"
    and action_or_type.id == "auto"
end

local function _has_active_modal_state(gate_state)
  return gate_state.choice_active
    or gate_state.market_active
    or gate_state.popup_active
    or gate_state.detained_wait_active
end

local function _is_next_button_in_active_state(action_or_type, action_type, gate_state)
  if action_type ~= "ui_button" then return false end
  if type(action_or_type) ~= "table" then return false end
  if action_or_type.id ~= "next" then return false end
  return _has_active_modal_state(gate_state)
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
  if _is_always_permitted(action_type) then return false end
  if _is_auto_button(action_or_type, action_type) then return false end
  if _is_next_button_in_active_state(action_or_type, action_type, gate_state) then return true end
  if not gate_state.input_blocked then return false end
  return not not input_blocked_types[action_type]
end

return turn_action_gate

--[[ mutate4lua-manifest
version=2
projectHash=8b5e1f643cd43a7b
scope.0.id=chunk:src/turn/policies/action_gate.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=79
scope.0.semanticHash=fbcfce109ff2e492
scope.1.id=function:_normalize_action_type:16
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=21
scope.1.semanticHash=7afd8bd521481757
scope.2.id=function:_is_always_permitted:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=25
scope.2.semanticHash=3b63ea6876a757b3
scope.3.id=function:_is_auto_button:27
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=31
scope.3.semanticHash=866ff809a8eceb4a
scope.4.id=function:_has_active_modal_state:33
scope.4.kind=function
scope.4.startLine=33
scope.4.endLine=38
scope.4.semanticHash=f05418045090f5bc
scope.5.id=function:_is_next_button_in_active_state:40
scope.5.kind=function
scope.5.startLine=40
scope.5.endLine=45
scope.5.semanticHash=d198f41cc36f2457
scope.6.id=function:turn_action_gate.resolve_gate_state:47
scope.6.kind=function
scope.6.startLine=47
scope.6.endLine=66
scope.6.semanticHash=74cdb2fb7f0de504
scope.7.id=function:turn_action_gate.should_block_action:68
scope.7.kind=function
scope.7.startLine=68
scope.7.endLine=76
scope.7.semanticHash=697cc004f647baf1
]]
