local choice_route_policy = require("src.config.choice.route_policy")
local ui_gate_sync = require("src.ui.ports.ui_sync.gate")
local choice_owner = require("src.ui.ports.ui_sync.choice_owner")
local player_control_snapshot = require("src.turn.output.player_control_snapshot")

local choice_ui_state = {}

local _input_blocked_phases = {
  wait_action_anim = true,
  wait_move_anim = true,
  wait_landing_visual = true,
  detained_wait = true,
  inter_turn_wait = true,
}

function choice_ui_state.is_phase_input_blocked(phase)
  return _input_blocked_phases[phase] == true
end

local function _is_game_input_blocked_phase(game)
  local phase = game and game.turn and game.turn.phase or nil
  return choice_ui_state.is_phase_input_blocked(phase)
end

choice_ui_state.resolve_route_key = choice_route_policy.resolve

local _cached_gate_state = {}
local _open_state_gate = {}

local function _choice_screen_active(gate, ui, route_key)
  return gate.choice_active and ui ~= nil and ui.active_choice_screen_key == route_key or false
end

local function _resolve_choice_open_state(route_key, ui, game)
  if choice_route_policy.is_screenless_route(route_key) then
    return true
  end
  local gate = ui_gate_sync.snapshot(ui, _open_state_gate)
  if route_key == "market" then
    return gate.market_active
  end
  return _choice_screen_active(gate, ui, route_key)
end

-- 拥有者是否由电脑执行:消费 turn 输出侧物化的同一份玩家控制快照。
local function _owner_computer_controlled(game, owner_role_id)
  local entry = player_control_snapshot.find(game, owner_role_id)
  return entry ~= nil and entry.is_computer_controlled == true or false
end

-- 是否期待 UI 参与:非内联路由、非输入阻塞、owner 是本进程服务的席位且非电脑执行。
local function _expects_ui(route_key, game, served_owner, owner_computer_controlled)
  return route_key ~= "base_inline" and not _is_game_input_blocked_phase(game) and served_owner and not owner_computer_controlled
end

local function _resolve_owner_state(game, choice, route_key)
  local owner_role_id = choice_owner.resolve_owner_role_id(game, choice)
  local served_owner = choice_owner.owner_is_served_seat(owner_role_id)
  local owner_computer_controlled = _owner_computer_controlled(game, owner_role_id)
  local expects_ui = _expects_ui(route_key, game, served_owner, owner_computer_controlled)
  return owner_role_id, served_owner, owner_computer_controlled, expects_ui
end

function choice_ui_state.resolve_gate_state(game, state, choice)
  local route_key = choice_ui_state.resolve_route_key(choice)
  local ui = state and state.ui or nil
  local owner_role_id, served_owner, owner_computer_controlled, expects_ui = _resolve_owner_state(game, choice, route_key)
  local open = _resolve_choice_open_state(route_key, ui, game)
  _cached_gate_state.route_key = route_key
  _cached_gate_state.owner_role_id = owner_role_id
  _cached_gate_state.served_owner = served_owner
  _cached_gate_state.owner_computer_controlled = owner_computer_controlled
  _cached_gate_state.expects_ui = expects_ui
  _cached_gate_state.open = open
  _cached_gate_state.should_warn = expects_ui and not open
  return _cached_gate_state
end

function choice_ui_state.should_reconcile(game, state, choice)
  local gate = choice_ui_state.resolve_gate_state(game, state, choice)
  return gate.expects_ui and not gate.open
end

return choice_ui_state

--[[ mutate4lua-manifest
version=4
projectHash=90a767a75a3cdff3
scope.0.id=chunk:src/ui/ports/ui_sync/choice_state.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=85
scope.0.semanticHash=0129c7310cbf37f9
scope.1.id=function:choice_ui_state.is_phase_input_blocked
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=18
scope.1.semanticHash=92047a25c743520b
scope.2.id=function:_is_game_input_blocked_phase
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=23
scope.2.semanticHash=e8af86822fc69918
scope.3.id=function:_choice_screen_active
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=32
scope.3.semanticHash=208729b1cd1bf922
scope.4.id=function:_resolve_choice_open_state
scope.4.kind=function
scope.4.startLine=34
scope.4.endLine=43
scope.4.semanticHash=dcdbb7a722f81ef8
scope.5.id=function:_owner_computer_controlled
scope.5.kind=function
scope.5.startLine=46
scope.5.endLine=49
scope.5.semanticHash=64e58fafe0b29be4
scope.6.id=function:_expects_ui
scope.6.kind=function
scope.6.startLine=52
scope.6.endLine=54
scope.6.semanticHash=5df44622d2dbfd5d
scope.7.id=function:_resolve_owner_state
scope.7.kind=function
scope.7.startLine=56
scope.7.endLine=62
scope.7.semanticHash=e51c712df9b5e2f5
scope.8.id=function:choice_ui_state.resolve_gate_state
scope.8.kind=function
scope.8.startLine=64
scope.8.endLine=77
scope.8.semanticHash=6689437fe09babe7
scope.9.id=function:choice_ui_state.should_reconcile
scope.9.kind=function
scope.9.startLine=79
scope.9.endLine=82
scope.9.semanticHash=2dd8ee01d3588060
]]
