local ctx_mod = require("src.turn.actions.context")
local defaults = require("src.turn.actions.defaults")

local ui_button_dispatch = {}

local function _handle_auto_toggle(game, action)
  local player = ctx_mod.resolve_actor_player(game, action)
  if not player then
    return { status = "rejected" }
  end
  player.auto = player.auto ~= true
  return { status = "applied" }
end

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

local function _handle_next_turn(game, state, action, ctx, runtime_state, turn_dispatch_ref)
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
    turn_dispatch_ref.step_turn(game)
  end
  return { status = "applied" }
end

local function _handle_cancel(game, state, action, opts, ctx, validator, dispatch_action)
  if not validator.validate_actor_role(game, action) then
    return { status = "rejected" }
  end
  local choice = ctx_mod.resolve_pending_choice(game, state, ctx)
  if choice == nil or choice.allow_cancel == false then
    return { status = "rejected" }
  end
  return dispatch_action(game, state, {
    type = "choice_cancel",
    choice_id = choice.id,
    actor_role_id = action.actor_role_id,
    input_source = action.input_source,
  }, opts, ctx)
end

local function _handle_slot_or_next(game, state, action, opts, ctx, validator, runtime_state, turn_dispatch_ref, dispatch_action)
  if not validator.validate_actor_role(game, action) then
    return { status = "rejected" }
  end
  local slot_result = validator.resolve_item_slot_action(ctx.item_slot_source, state, action, game)
  if slot_result ~= nil then
    if not slot_result.ok then
      return { status = "rejected" }
    end
    return dispatch_action(game, state, slot_result.action, opts, ctx)
  end
  if action.id == "next" then
    return _handle_next_turn(game, state, action, ctx, runtime_state, turn_dispatch_ref)
  end
  return { status = "rejected" }
end

function ui_button_dispatch.handle(game, state, action, opts, ctx, validator, runtime_state, turn_dispatch_ref, dispatch_action)
  if action.id == "auto" then
    return _handle_auto_toggle(game, action)
  end
  if action.id == "cancel" then
    return _handle_cancel(game, state, action, opts, ctx, validator, dispatch_action)
  end
  return _handle_slot_or_next(game, state, action, opts, ctx, validator, runtime_state, turn_dispatch_ref, dispatch_action)
end

return ui_button_dispatch

--[[ mutate4lua-manifest
version=2
projectHash=f1044548848d547c
scope.0.id=chunk:src/turn/actions/ui_button_dispatch.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=91
scope.0.semanticHash=d7530297bae22271
scope.1.id=function:_handle_auto_toggle:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=13
scope.1.semanticHash=f0795c687df1f661
scope.2.id=function:_allow_next_turn:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=27
scope.2.semanticHash=c2c8170d039ea768
scope.3.id=function:_handle_next_turn:29
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=45
scope.3.semanticHash=72639b4dd9c6255a
scope.4.id=function:_handle_cancel:47
scope.4.kind=function
scope.4.startLine=47
scope.4.endLine=61
scope.4.semanticHash=5503de013d237129
scope.5.id=function:_handle_slot_or_next:63
scope.5.kind=function
scope.5.startLine=63
scope.5.endLine=78
scope.5.semanticHash=ed85143eda6e7ec2
scope.6.id=function:ui_button_dispatch.handle:80
scope.6.kind=function
scope.6.startLine=80
scope.6.endLine=88
scope.6.semanticHash=815dcb9e02381508
]]
