local turn_action_gate = require("src.turn.policies.action_gate")

local validator_gate = {}

local function _resolve_ui_gate(state, ui_sync_ports)
  if ui_sync_ports and type(ui_sync_ports.resolve_ui_gate) == "function" then
    return ui_sync_ports.resolve_ui_gate(state)
  end
  return nil
end

local function _extract_turn_state(state)
  if type(state) == "table" and state.game then
    return state.game.turn
  end
  return nil
end

function validator_gate.resolve_gate_state(state, ui_sync_ports)
  local gate = turn_action_gate.resolve_gate_state(_resolve_ui_gate(state, ui_sync_ports))
  local turn = _extract_turn_state(state)
  return {
    input_blocked = gate.input_blocked == true,
    choice_active = gate.choice_active == true,
    market_active = gate.market_active == true,
    popup_active = gate.popup_active == true,
    phase = turn and turn.phase or nil,
    detained_wait_active = turn and turn.detained_wait_active == true or false,
  }
end

validator_gate.should_block_action = turn_action_gate.should_block_action

return validator_gate

--[[ mutate4lua-manifest
version=2
projectHash=ef27f7ee6f6fbcce
scope.0.id=chunk:src/turn/actions/validator_gate.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=35
scope.0.semanticHash=5f6dd84bc905fab5
scope.0.lastMutatedAt=2026-07-07T02:10:35Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=1
scope.0.lastMutationKilled=1
scope.1.id=function:_resolve_ui_gate:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=a58d42ec64d1e93c
scope.1.lastMutatedAt=2026-07-07T02:10:35Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=5
scope.2.id=function:_extract_turn_state:12
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=17
scope.2.semanticHash=7a4dc08f584b619e
scope.2.lastMutatedAt=2026-07-07T02:10:35Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:validator_gate.resolve_gate_state:19
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=30
scope.3.semanticHash=15a739dad90911bf
scope.3.lastMutatedAt=2026-07-07T02:10:35Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=17
scope.3.lastMutationKilled=17
]]
