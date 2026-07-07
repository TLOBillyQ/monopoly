local action_button_wait = {}

local function _has_blocking_ui(ui_sync_ports, state)
  return (ui_sync_ports and ui_sync_ports.is_choice_active and ui_sync_ports.is_choice_active(state))
      or (ui_sync_ports and ui_sync_ports.is_popup_active and ui_sync_ports.is_popup_active(state))
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
  if _is_input_blocked_port(ui_sync_ports, state) then
    return false
  end
  if _has_blocking_ui(ui_sync_ports, state) then
    return false
  end
  if game.turn and game.turn.pending_choice then
    return false
  end
  return true
end

return action_button_wait

--[[ mutate4lua-manifest
version=2
projectHash=44f0cbedf324ae22
scope.0.id=chunk:src/turn/policies/action_button_wait.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=51
scope.0.semanticHash=810b20d12e2f4196
scope.1.id=function:_has_blocking_ui:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=6
scope.1.semanticHash=b2dfbbffacaa2abc
scope.2.id=function:_is_ui_state_absent:8
scope.2.kind=function
scope.2.startLine=8
scope.2.endLine=12
scope.2.semanticHash=8a5d0a83abd5b53d
scope.3.id=function:_is_input_blocked_port:14
scope.3.kind=function
scope.3.startLine=14
scope.3.endLine=18
scope.3.semanticHash=27f9bc4e781bc073
scope.4.id=function:_get_valid_ui_sync:20
scope.4.kind=function
scope.4.startLine=20
scope.4.endLine=25
scope.4.semanticHash=fec753337eed910b
scope.5.id=function:action_button_wait.is_action_button_wait_active:27
scope.5.kind=function
scope.5.startLine=27
scope.5.endLine=48
scope.5.semanticHash=e378111aa307ef49
]]
