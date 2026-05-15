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
