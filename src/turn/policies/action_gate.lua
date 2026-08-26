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

-- item_slot_click 自身不推进状态：要么被裁定拒绝（只发提示），要么转成
-- choice_select 再走一遍本闸。因此输入锁期间也放行——兑现「道具槽全时段可点、
-- 点了必有反馈」口径(#162)。
local function _is_always_permitted(action_type)
  return not action_type
    or action_type == "popup_confirm"
    or action_type == "item_slot_click"
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

local _GATE_FLAG_KEYS = {
  "input_blocked",
  "choice_active",
  "market_active",
  "popup_active",
  "detained_wait_active",
}

local function _normalize_gate_flags(source)
  local gate_state = {}
  for _, key in ipairs(_GATE_FLAG_KEYS) do
    gate_state[key] = source[key] == true
  end
  gate_state.phase = source.phase
  return gate_state
end

function turn_action_gate.resolve_gate_state(gate_state_or_flag)
  if type(gate_state_or_flag) ~= "table" then
    return _normalize_gate_flags({ input_blocked = gate_state_or_flag == true })
  end
  return _normalize_gate_flags(gate_state_or_flag)
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
version=4
projectHash=e1fa57f38155cb3d
scope.0.id=chunk:src/turn/policies/action_gate.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=87
scope.0.semanticHash=602c786bba03b5e9
scope.1.id=function:_normalize_action_type
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=21
scope.1.semanticHash=90c051feb9cf542f
scope.2.id=function:_is_always_permitted
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=30
scope.2.semanticHash=12b062ab67e602e1
scope.3.id=function:_is_auto_button
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=36
scope.3.semanticHash=dc27c324abe7bb94
scope.4.id=function:_has_active_modal_state
scope.4.kind=function
scope.4.startLine=38
scope.4.endLine=43
scope.4.semanticHash=749d97117f212ae2
scope.5.id=function:_is_next_button_in_active_state
scope.5.kind=function
scope.5.startLine=45
scope.5.endLine=50
scope.5.semanticHash=b24723e0cb6ca6ae
scope.6.id=function:_normalize_gate_flags
scope.6.kind=function
scope.6.startLine=60
scope.6.endLine=67
scope.6.semanticHash=ccb208c7ec645a68
scope.7.id=function:turn_action_gate.resolve_gate_state
scope.7.kind=function
scope.7.startLine=69
scope.7.endLine=74
scope.7.semanticHash=480efdbc62b4ebb1
scope.8.id=function:turn_action_gate.should_block_action
scope.8.kind=function
scope.8.startLine=76
scope.8.endLine=84
scope.8.semanticHash=931c808d3aed12d4
]]
