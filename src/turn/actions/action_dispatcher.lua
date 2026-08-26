-- turn/actions 派发深模块：本文件只负责动作类型 → handler 映射与装配
-- （ui_button / item_slot_click / choice / market / force_skip / 可选行动收尾），
-- 子处理实现分居 action_dispatcher_handlers / action_dispatcher_helpers /
-- action_dispatcher_market；校验统一走 src.turn.actions.validator，
-- 道具槽点击的裁定独占在 src.turn.actions.item_slot_click。
local validator = require("src.turn.actions.validator")
local output_state_adapter = require("src.turn.output.state_adapter")
local ctx_mod = require("src.turn.actions.context")
local defaults = require("src.turn.actions.defaults")
local handlers = require("src.turn.actions.action_dispatcher_handlers")
local helpers = require("src.turn.actions.action_dispatcher_helpers")
local market = require("src.turn.actions.action_dispatcher_market")

local turn_dispatch = {}

local function _step_turn(game)
  assert(game ~= nil, "missing game")
  if game.finished then
    return
  end
  game:advance_turn()
end

local function _clear_choice(state, opts)
  local output_ports = defaults.resolve_port_group(state, "output") or output_state_adapter
  output_ports.clear_pending_choice(state)
  if opts and opts.on_close_choice then
    opts.on_close_choice(state)
  end
end

local function _build_default_handlers(dispatch_action, dispatcher)
  return {
    ui_button = function(game, state, action, opts, ctx)
      return handlers.handle_ui_button(dispatch_action, dispatcher.step_turn, game, state, action, opts, ctx)
    end,
    item_slot_click = function(game, state, action, opts, ctx)
      return handlers.handle_item_slot_click(dispatch_action, game, state, action, opts, ctx)
    end,
    choice_select = function(game, state, action, opts, ctx)
      return handlers.handle_choice_action(game, state, action, opts, ctx, dispatcher)
    end,
    choice_cancel = function(game, state, action, opts, ctx)
      return handlers.handle_choice_action(game, state, action, opts, ctx, dispatcher)
    end,
    complete_optional_action_phase = function(game, state, action, opts, ctx)
      return handlers.handle_optional_action_completion(dispatch_action, game, state, action, opts, ctx)
    end,
    market_page_prev = market.handle_market_navigation,
    market_page_next = market.handle_market_navigation,
    market_tab_select = market.handle_market_navigation,
    choice_force_skip = market.handle_force_skip,
  }
end

local function _dependency(deps, key, fallback)
  return deps[key] or fallback
end

function turn_dispatch.new(deps)
  deps = deps or {}
  local gate = _dependency(deps, "gate", validator)
  local context = _dependency(deps, "context", ctx_mod)
  local dispatcher = {
    step_turn = _dependency(deps, "step_turn", _step_turn),
    clear_choice = _dependency(deps, "clear_choice", _clear_choice),
  }
  local action_handlers
  local dispatch_action

  dispatch_action = function(game, state, action, opts, dispatch_ctx)
    assert(action ~= nil, "missing action")
    helpers.ensure_input_source(action)
    local ctx = context.resolve_dispatch_context(state, dispatch_ctx)
    local gate_state = gate.resolve_gate_state(state, ctx.ui_sync_ports)
    local blocked_by_gate = gate.should_block_action(gate_state, action)
    local allows_market_cancel = helpers.allows_market_cancel_while_blocked(gate_state, game, state, action, ctx)
    if blocked_by_gate and not allows_market_cancel then
      return { status = "blocked" }
    end
    if helpers.should_invalidate_ui(action) then
      helpers.invalidate_ui_model(ctx.output_ports, state)
    end
    local handler = action_handlers[action.type]
    if handler ~= nil then
      return handler(game, state, action, opts, ctx, dispatch_action)
    end
    return { status = "rejected" }
  end

  action_handlers = _dependency(deps, "handlers", _build_default_handlers(dispatch_action, dispatcher))

  function dispatcher.should_block_action(state, action_or_type)
    local dispatch_ctx = context.resolve_dispatch_context(state)
    local gate_state = gate.resolve_gate_state(state, dispatch_ctx.ui_sync_ports)
    return gate.should_block_action(gate_state, action_or_type)
  end

  function dispatcher.dispatch_action(game, state, action, opts)
    return dispatch_action(game, state, action, opts, nil)
  end

  return dispatcher
end

turn_dispatch.step_turn = _step_turn
turn_dispatch.clear_choice = _clear_choice

local default_dispatcher = turn_dispatch.new({
  step_turn = function(game)
    return turn_dispatch.step_turn(game)
  end,
  clear_choice = function(state, opts)
    return turn_dispatch.clear_choice(state, opts)
  end,
})

turn_dispatch.should_block_action = default_dispatcher.should_block_action
turn_dispatch.dispatch_action = default_dispatcher.dispatch_action

return turn_dispatch

--[[ mutate4lua-manifest
version=4
projectHash=0823084a1f8e333f
scope.0.id=chunk:src/turn/actions/action_dispatcher.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=122
scope.0.semanticHash=e29b585f140c10e8
scope.1.id=function:_step_turn
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=22
scope.1.semanticHash=aebb1f582c42aecc
scope.2.id=function:_clear_choice
scope.2.kind=function
scope.2.startLine=24
scope.2.endLine=30
scope.2.semanticHash=a68f4a8cf230c67b
scope.3.id=function:_build_default_handlers
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=54
scope.3.semanticHash=05dd041e6b1abeea
scope.4.id=function:<anonymous>
scope.4.kind=function
scope.4.startLine=34
scope.4.endLine=36
scope.4.semanticHash=21f0f874c0887220
scope.5.id=function:<anonymous>#2
scope.5.kind=function
scope.5.startLine=37
scope.5.endLine=39
scope.5.semanticHash=0544c5f316c5f49c
scope.6.id=function:<anonymous>#3
scope.6.kind=function
scope.6.startLine=40
scope.6.endLine=42
scope.6.semanticHash=0544c5f316c5f49c
scope.7.id=function:<anonymous>#4
scope.7.kind=function
scope.7.startLine=43
scope.7.endLine=45
scope.7.semanticHash=0544c5f316c5f49c
scope.8.id=function:<anonymous>#5
scope.8.kind=function
scope.8.startLine=46
scope.8.endLine=48
scope.8.semanticHash=0544c5f316c5f49c
scope.9.id=function:_dependency
scope.9.kind=function
scope.9.startLine=56
scope.9.endLine=58
scope.9.semanticHash=a6edcefc1078400a
scope.10.id=function:turn_dispatch.new
scope.10.kind=function
scope.10.startLine=60
scope.10.endLine=104
scope.10.semanticHash=44055abedde7b0a4
scope.11.id=function:dispatch_action
scope.11.kind=function
scope.11.startLine=71
scope.11.endLine=89
scope.11.semanticHash=a9ce3098351ff3cb
scope.12.id=function:dispatcher.should_block_action
scope.12.kind=function
scope.12.startLine=93
scope.12.endLine=97
scope.12.semanticHash=c7ea937c21774047
scope.13.id=function:dispatcher.dispatch_action
scope.13.kind=function
scope.13.startLine=99
scope.13.endLine=101
scope.13.semanticHash=08c77c5ae6345701
scope.14.id=function:<anonymous>#6
scope.14.kind=function
scope.14.startLine=110
scope.14.endLine=112
scope.14.semanticHash=f1ce1850b7232305
scope.15.id=function:<anonymous>#7
scope.15.kind=function
scope.15.startLine=113
scope.15.endLine=115
scope.15.semanticHash=aba9250a8c6b104f
]]
