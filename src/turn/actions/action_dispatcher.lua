local logger = require("src.foundation.log")
local validator = require("src.turn.actions.validator")
local runtime_state = require("src.state.runtime")
local market_service = require("src.rules.market")
local output_state_adapter = require("src.turn.output.state_adapter")
local action_dispatch = require("src.turn.actions.action_dispatch")
local ctx_mod = require("src.turn.actions.context")
local defaults = require("src.turn.actions.defaults")

local turn_dispatch = {}

function turn_dispatch.step_turn(game)
  assert(game ~= nil, "missing game")
  if game.finished then
    return
  end
  game:advance_turn()
end

function turn_dispatch.clear_choice(state, opts)
  local output_ports = defaults.resolve_port_group(state, "output") or output_state_adapter
  output_ports.clear_pending_choice(state)
  if opts and opts.on_close_choice then
    opts.on_close_choice(state)
  end
end

local _built = action_dispatch.build({
  logger = logger,
  validator = validator,
  runtime_state = runtime_state,
  market_service = market_service,
  turn_dispatch_ref = turn_dispatch,
})

function turn_dispatch.should_block_action(state, action_or_type)
  local dispatch_ctx = ctx_mod.resolve_dispatch_context(state)
  local gate_state = validator.resolve_gate_state(state, dispatch_ctx.ui_sync_ports)
  return validator.should_block_action(gate_state, action_or_type)
end

function turn_dispatch.dispatch_action(game, state, action, opts)
  return _built.dispatch_action(game, state, action, opts, nil)
end

return turn_dispatch

--[[ mutate4lua-manifest
version=2
projectHash=70702fe94db16a2d
scope.0.id=chunk:src/turn/actions/action_dispatcher.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=47
scope.0.semanticHash=ea7c3dfdc0f43fc3
scope.1.id=function:turn_dispatch.step_turn:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=18
scope.1.semanticHash=8f42a79e73ef29f2
scope.2.id=function:turn_dispatch.clear_choice:20
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=26
scope.2.semanticHash=1d185116154f80eb
scope.3.id=function:turn_dispatch.should_block_action:36
scope.3.kind=function
scope.3.startLine=36
scope.3.endLine=40
scope.3.semanticHash=408a9852e710b525
scope.4.id=function:turn_dispatch.dispatch_action:42
scope.4.kind=function
scope.4.startLine=42
scope.4.endLine=44
scope.4.semanticHash=0e8b194fe1c98350
]]
