-- turn/actions 派发深模块：动作类型 → handler 映射、ui_button（auto / cancel /
-- item_slot_N / next 冷却锁）、choice / market / force_skip / 可选行动收尾的
-- 子处理与装配全部在本文件内完成；校验统一走 src.turn.actions.validator。
local validator = require("src.turn.actions.validator")
local runtime_state = require("src.state.runtime")
local market_service = require("src.rules.market")
local output_state_adapter = require("src.turn.output.state_adapter")
local force_resolve = require("src.turn.deadlines")
local optional_action_completion = require("src.turn.optional_action_completion")
local ctx_mod = require("src.turn.actions.context")
local defaults = require("src.turn.actions.defaults")

local turn_dispatch = {}

-- 前置声明：handler 内的重入派发直接走本地函数，不再经闭包回指。
local _dispatch_action

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

local INVALIDATING_ACTION_TYPES = {
  ui_button = true,
  choice_select = true,
  choice_cancel = true,
  complete_optional_action_phase = true,
  market_page_prev = true,
  market_page_next = true,
  market_tab_select = true,
}

local function _should_invalidate_ui(action)
  return INVALIDATING_ACTION_TYPES[action.type] == true
end

local function _invalidate_ui_model(output_ports, state)
  if output_ports and type(output_ports.invalidate_ui_model) == "function" then
    output_ports.invalidate_ui_model(state)
  end
end

local function _allows_market_cancel_while_blocked(gate_state, game, state, action, ctx)
  if not gate_state or gate_state.input_blocked ~= true then
    return false
  end
  if not action or action.type ~= "choice_cancel" then
    return false
  end
  local choice = ctx_mod.resolve_pending_choice(game, state, ctx)
  if choice == nil or choice.kind ~= "market_buy" then
    return false
  end
  return action.choice_id ~= nil and choice.id ~= nil and action.choice_id == choice.id
end

-- ui_button：auto 开关

local function _handle_auto_toggle(game, action)
  local player = ctx_mod.resolve_actor_player(game, action)
  if not player then
    return { status = "rejected" }
  end
  player.auto = player.auto ~= true
  return { status = "applied" }
end

-- ui_button：next 行动按钮冷却锁

local function _allow_next_turn(turn_runtime, phase, now, ctx)
  if not turn_runtime.next_turn_locked then
    return true
  end
  if turn_runtime.next_turn_lock_phase and phase and phase ~= turn_runtime.next_turn_lock_phase then
    return true
  end
  if turn_runtime.next_turn_last_click == nil then
    return true
  end
  local diff = ctx_mod.resolve_timestamp_diff_seconds(ctx, now, turn_runtime.next_turn_last_click)
  return diff and diff >= defaults.next_turn_cooldown
end

local function _handle_next_turn(game, state, action, ctx)
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  local phase = game.turn.phase
  local now = ctx_mod.resolve_timestamp_now(ctx)
  if not _allow_next_turn(turn_runtime, phase, now, ctx) then
    return { status = "rejected" }
  end
  turn_runtime.next_turn_locked = true
  turn_runtime.next_turn_last_click = now
  turn_runtime.next_turn_lock_phase = phase
  if phase == "wait_action" then
    game:dispatch_action(action)
  else
    turn_dispatch.step_turn(game)
  end
  return { status = "applied" }
end

-- ui_button：cancel 转发为 choice_cancel

local function _handle_cancel(game, state, action, opts, ctx)
  if not validator.validate_actor_role(game, action) then
    return { status = "rejected" }
  end
  local choice = ctx_mod.resolve_pending_choice(game, state, ctx)
  if choice == nil or choice.allow_cancel == false then
    return { status = "rejected" }
  end
  return _dispatch_action(game, state, {
    type = "choice_cancel",
    choice_id = choice.id,
    actor_role_id = action.actor_role_id,
    input_source = action.input_source,
  }, opts, ctx)
end

-- ui_button：item_slot_N 解析或 next 兜底

local function _handle_slot_or_next(game, state, action, opts, ctx)
  if not validator.validate_actor_role(game, action) then
    return { status = "rejected" }
  end
  local slot_result = validator.resolve_item_slot_action(ctx.item_slot_source, state, action, game)
  if slot_result ~= nil then
    if not slot_result.ok then
      return { status = "rejected" }
    end
    return _dispatch_action(game, state, slot_result.action, opts, ctx)
  end
  if action.id == "next" then
    return _handle_next_turn(game, state, action, ctx)
  end
  return { status = "rejected" }
end

local function _handle_ui_button(game, state, action, opts, ctx)
  if action.id == "auto" then
    return _handle_auto_toggle(game, action)
  end
  if action.id == "cancel" then
    return _handle_cancel(game, state, action, opts, ctx)
  end
  return _handle_slot_or_next(game, state, action, opts, ctx)
end

-- choice_select / choice_cancel

local function _clear_choice_if_closed(game, state, opts, choice)
  local pending = game and game.turn and game.turn.pending_choice or nil
  if choice and (not pending or not pending.id or pending.id ~= choice.id) then
    turn_dispatch.clear_choice(state, opts)
  end
end

local function _handle_choice_action(game, state, action, opts, ctx)
  local choice = ctx_mod.resolve_pending_choice(game, state, ctx)
  if not validator.validate_choice_action(game, action, choice) then
    return { status = "rejected" }
  end
  if game then
    assert(game.dispatch_action ~= nil, "missing game.dispatch_action")
    game:dispatch_action(action)
  end
  _clear_choice_if_closed(game, state, opts, choice)
  return { status = "applied" }
end

-- market_page_prev / market_page_next / market_tab_select

local function _apply_market_navigation(game, state, action, ctx, choice)
  if not choice or choice.kind ~= "market_buy" then
    return false
  end
  if not validator.validate_choice_action(game, action, choice) then
    return false
  end
  if not market_service.choice.apply_navigation(game, choice, action) then
    return false
  end
  ctx.output_ports.sync_pending_choice(state, choice)
  return true
end

local function _handle_market_navigation(game, state, action, opts, ctx)
  local choice = ctx_mod.resolve_pending_choice(game, state, ctx)
  if not _apply_market_navigation(game, state, action, ctx, choice) then
    return { status = "rejected" }
  end
  return { status = "applied" }
end

-- choice_force_skip

local function _handle_force_skip(game, state, action, opts, ctx)
  local choice = ctx_mod.resolve_pending_choice(game, state, ctx)
  force_resolve.force_skip(game, state, choice, action.reason or "dispatch")
  return { status = "applied" }
end

-- complete_optional_action_phase

local function _optional_completion_status(result)
  if result.ok == true then
    return { status = "applied" }
  end
  if result.reason == "blocked" then
    return { status = "blocked", reason = result.reason }
  end
  return { status = "rejected", reason = result.reason }
end

local function _handle_optional_action_completion(game, state, action, opts, ctx)
  local gate_state = validator.resolve_gate_state(state, ctx.ui_sync_ports)
  local result = optional_action_completion.complete_optional_action_phase(game, action.actor_role_id, state, {
    gate_state = gate_state,
    input_source = action.input_source,
    dispatch_choice_action = function(choice_action)
      return _dispatch_action(game, state, choice_action, opts, ctx)
    end,
  })
  return _optional_completion_status(result)
end

local _ACTION_HANDLERS = {
  ui_button = _handle_ui_button,
  choice_select = _handle_choice_action,
  choice_cancel = _handle_choice_action,
  complete_optional_action_phase = _handle_optional_action_completion,
  market_page_prev = _handle_market_navigation,
  market_page_next = _handle_market_navigation,
  market_tab_select = _handle_market_navigation,
  choice_force_skip = _handle_force_skip,
}

_dispatch_action = function(game, state, action, opts, dispatch_ctx)
  assert(action ~= nil, "missing action")
  if action.input_source == nil then
    action.input_source = "user"
  end
  local ctx = ctx_mod.resolve_dispatch_context(state, dispatch_ctx)
  local gate_state = validator.resolve_gate_state(state, ctx.ui_sync_ports)
  local blocked_by_gate = validator.should_block_action(gate_state, action)
  local allows_market_cancel = _allows_market_cancel_while_blocked(gate_state, game, state, action, ctx)
  if blocked_by_gate and not allows_market_cancel then
    return { status = "blocked" }
  end
  if _should_invalidate_ui(action) then
    _invalidate_ui_model(ctx.output_ports, state)
  end
  local handler = _ACTION_HANDLERS[action.type]
  if handler ~= nil then
    return handler(game, state, action, opts, ctx)
  end
  return { status = "rejected" }
end

function turn_dispatch.should_block_action(state, action_or_type)
  local dispatch_ctx = ctx_mod.resolve_dispatch_context(state)
  local gate_state = validator.resolve_gate_state(state, dispatch_ctx.ui_sync_ports)
  return validator.should_block_action(gate_state, action_or_type)
end

-- dispatch_ctx 为可选注入位（缺省从 state 解析），供重入派发与 spec 注入端口。
function turn_dispatch.dispatch_action(game, state, action, opts, dispatch_ctx)
  return _dispatch_action(game, state, action, opts, dispatch_ctx)
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
