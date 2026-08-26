local runtime_state = require("src.state.runtime")
local control = require("src.player.control")
local ui_gate = require("src.turn.policies.ui_gate")
local tables = require("src.foundation.tables")

local auto_context = {}

local function _resolve_current_player_index(game, ctx)
  if ctx.current_player_index then
    return ctx.current_player_index
  end
  return game.turn and game.turn.current_player_index or nil
end

local function _is_computer_controlled(player)
  return player and control.is_computer_controlled(player) or false
end

local function _player_at(game, index)
  return index and game.players and game.players[index] or nil
end

local function _player_id(player)
  return player and player.id or nil
end

function auto_context.build(game, context)
  local ctx = context or {}
  ctx.game_finished = game.finished

  local current_player_index = _resolve_current_player_index(game, ctx)
  ctx.current_player_index = current_player_index

  local player = _player_at(game, current_player_index)
  if ctx.current_player_id == nil then
    ctx.current_player_id = _player_id(player)
  end
  if ctx.current_player_computer_controlled == nil then
    ctx.current_player_computer_controlled = _is_computer_controlled(player)
  end
  return ctx
end

local function _resolve_pending_choice(game, state)
  return game and game.turn and game.turn.pending_choice or runtime_state.get_pending_choice(state)
end

local function _ensure_tick_context(state)
  return tables.ensure_absent_field(state, "_tick_context")
end

local function _gate_flag(gate, key)
  return gate and gate[key] == true or false
end

local function _gate_modal_active(gate)
  return gate and (gate.popup_active == true or gate.market_active == true or gate.choice_active == true) or false
end

local function _apply_gate_flags(ctx, gate)
  ctx.choice_active = _gate_flag(gate, "choice_active")
  ctx.market_active = _gate_flag(gate, "market_active")
  ctx.popup_active = _gate_flag(gate, "popup_active")
  ctx.modal_active = _gate_modal_active(gate)
end

function auto_context.build_tick(game, state, ui_sync_ports)
  local gate = ui_gate.resolve(state, ui_sync_ports)
  local pending_choice = _resolve_pending_choice(game, state)
  local ctx = _ensure_tick_context(state)
  ctx.game = game
  ctx.state = state
  ctx.pending_choice = pending_choice
  ctx.current_player_index = nil
  ctx.current_player_id = nil
  ctx.current_player_computer_controlled = nil
  _apply_gate_flags(ctx, gate)
  ctx.modal_buttons = nil
  return auto_context.build(game, ctx)
end

return auto_context

--[[ mutate4lua-manifest
version=4
projectHash=eb1ec9b460fb9312
scope.0.id=chunk:src/turn/policies/auto_context.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=83
scope.0.semanticHash=94a90b01d5604b92
scope.1.id=function:_resolve_current_player_index
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=13
scope.1.semanticHash=dacafe54b746ad36
scope.2.id=function:_is_computer_controlled
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=17
scope.2.semanticHash=23564489bf094ae1
scope.3.id=function:_player_at
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=21
scope.3.semanticHash=bafa57000621798c
scope.4.id=function:_player_id
scope.4.kind=function
scope.4.startLine=23
scope.4.endLine=25
scope.4.semanticHash=616a2ca60599c94f
scope.5.id=function:auto_context.build
scope.5.kind=function
scope.5.startLine=27
scope.5.endLine=42
scope.5.semanticHash=5c85f116df9fd792
scope.6.id=function:_resolve_pending_choice
scope.6.kind=function
scope.6.startLine=44
scope.6.endLine=46
scope.6.semanticHash=af9bf038e9c991da
scope.7.id=function:_ensure_tick_context
scope.7.kind=function
scope.7.startLine=48
scope.7.endLine=50
scope.7.semanticHash=a9c1c4b362850cf7
scope.8.id=function:_gate_flag
scope.8.kind=function
scope.8.startLine=52
scope.8.endLine=54
scope.8.semanticHash=e57dbd55a7ba0b36
scope.9.id=function:_gate_modal_active
scope.9.kind=function
scope.9.startLine=56
scope.9.endLine=58
scope.9.semanticHash=2dcf29a02f2d7af9
scope.10.id=function:_apply_gate_flags
scope.10.kind=function
scope.10.startLine=60
scope.10.endLine=65
scope.10.semanticHash=68abd6ff7aa94604
scope.11.id=function:auto_context.build_tick
scope.11.kind=function
scope.11.startLine=67
scope.11.endLine=80
scope.11.semanticHash=783de0305b144a82
]]
