local turn_action_gate = require("src.turn.policies.action_gate")
local ui_gate = require("src.turn.policies.ui_gate")

local validator_gate = {}

local function _extract_turn_state(state)
  if type(state) == "table" and state.game then
    return state.game.turn
  end
  return nil
end

local function _gate_flags(gate)
  return {
    input_blocked = gate.input_blocked == true,
    choice_active = gate.choice_active == true,
    market_active = gate.market_active == true,
    popup_active = gate.popup_active == true,
  }
end

local function _apply_turn_flags(flags, turn)
  flags.phase = turn and turn.phase or nil
  flags.detained_wait_active = turn and turn.detained_wait_active == true or false
  return flags
end

function validator_gate.resolve_gate_state(state, ui_sync_ports)
  local gate = turn_action_gate.resolve_gate_state(ui_gate.resolve(state, ui_sync_ports))
  return _apply_turn_flags(_gate_flags(gate), _extract_turn_state(state))
end

validator_gate.should_block_action = turn_action_gate.should_block_action

return validator_gate

--[[ mutate4lua-manifest
version=4
projectHash=cb1df15023a299a0
scope.0.id=chunk:src/turn/actions/validator_gate.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=36
scope.0.semanticHash=5c84ed9f5942698e
scope.1.id=function:_extract_turn_state
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=11
scope.1.semanticHash=88d9353b49d78aaf
scope.2.id=function:_gate_flags
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=20
scope.2.semanticHash=6f523b4d1f193759
scope.3.id=function:_apply_turn_flags
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=26
scope.3.semanticHash=4f926d7da10e46a1
scope.4.id=function:validator_gate.resolve_gate_state
scope.4.kind=function
scope.4.startLine=28
scope.4.endLine=31
scope.4.semanticHash=bc44dc0e6e386b1e
]]
