local action_button_wait = {}

local function _choice_active(ui_sync_ports, state)
  return ui_sync_ports and ui_sync_ports.is_choice_active and ui_sync_ports.is_choice_active(state)
end

local function _popup_active(ui_sync_ports, state)
  return ui_sync_ports and ui_sync_ports.is_popup_active and ui_sync_ports.is_popup_active(state)
end

local function _has_blocking_ui(ui_sync_ports, state)
  return _choice_active(ui_sync_ports, state) or _popup_active(ui_sync_ports, state)
end

local function _is_ui_state_absent(ui_sync_ports, state)
  return ui_sync_ports
    and ui_sync_ports.get_ui_state
    and not ui_sync_ports.get_ui_state(state)
end

local function _is_input_blocked_port(ui_sync_ports, state)
  return ui_sync_ports
    and ui_sync_ports.is_input_blocked
    and ui_sync_ports.is_input_blocked(state)
end

local function _get_valid_ui_sync(game, state, ports)
  if not (game and state and ports) then
    return nil, false
  end
  return ports.ui_sync, true
end

local function _is_blocked_after_ui_ready(game, state, ui_sync_ports)
  if _is_input_blocked_port(ui_sync_ports, state) then
    return true
  end
  if _has_blocking_ui(ui_sync_ports, state) then
    return true
  end
  return game.turn ~= nil and game.turn.pending_choice ~= nil
end

function action_button_wait.is_action_button_wait_active(game, state, ports)
  local ui_sync_ports, is_valid = _get_valid_ui_sync(game, state, ports)
  if not is_valid then
    return false
  end
  if _is_ui_state_absent(ui_sync_ports, state) then
    return false
  end
  if game.finished then
    return false
  end
  return not _is_blocked_after_ui_ready(game, state, ui_sync_ports)
end

return action_button_wait

--[[ mutate4lua-manifest
version=4
projectHash=e98cb06526c7156d
scope.0.id=chunk:src/turn/policies/action_button_wait.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=59
scope.0.semanticHash=76ac815db9cae4bc
scope.1.id=function:_choice_active
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=5
scope.1.semanticHash=ccaae8f2995001b5
scope.2.id=function:_popup_active
scope.2.kind=function
scope.2.startLine=7
scope.2.endLine=9
scope.2.semanticHash=ccaae8f2995001b5
scope.3.id=function:_has_blocking_ui
scope.3.kind=function
scope.3.startLine=11
scope.3.endLine=13
scope.3.semanticHash=646501ae3680ab17
scope.4.id=function:_is_ui_state_absent
scope.4.kind=function
scope.4.startLine=15
scope.4.endLine=19
scope.4.semanticHash=6ad1bf60dc851ab7
scope.5.id=function:_is_input_blocked_port
scope.5.kind=function
scope.5.startLine=21
scope.5.endLine=25
scope.5.semanticHash=ccaae8f2995001b5
scope.6.id=function:_get_valid_ui_sync
scope.6.kind=function
scope.6.startLine=27
scope.6.endLine=32
scope.6.semanticHash=3e313e4f2593bd76
scope.7.id=function:_is_blocked_after_ui_ready
scope.7.kind=function
scope.7.startLine=34
scope.7.endLine=42
scope.7.semanticHash=2944d894723415bd
scope.8.id=function:action_button_wait.is_action_button_wait_active
scope.8.kind=function
scope.8.startLine=44
scope.8.endLine=56
scope.8.semanticHash=d9788b2ee0219282
]]
