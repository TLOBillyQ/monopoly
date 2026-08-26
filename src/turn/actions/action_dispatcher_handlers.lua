local validator = require("src.turn.actions.validator")
local runtime_state = require("src.state.runtime")
local optional_action_completion = require("src.turn.optional_action_completion")
local ctx_mod = require("src.turn.actions.context")
local defaults = require("src.turn.actions.defaults")
local item_slot_click = require("src.turn.actions.item_slot_click")
local helpers = require("src.turn.actions.action_dispatcher_helpers")
local share_panel = require("src.foundation.ports.share_panel")
local control = require("src.player.control")

local handlers = {}

-- ui_button：auto 开关

-- 首次开启托管弹宿主分享面板。shown 标记只在宿主调用成功之后锁存：role 解析不出、
-- 宿主 Role 缺 show_map_share_panel、或宿主调用抛错时本次不弹但也不锁存，
-- 下次开启托管可重试（失败路径一律 warn，不静默吞）。宿主调用机制收敛在
-- share_panel.try_show（与分享按钮共用），日志前缀沿用历史钉住的 "auto share panel"。
local function _try_show_share_panel(actor_role_id, player)
  -- actor_role_id 恒可解析:唯一调用方 handle_auto_toggle 先经
  -- ctx_mod.resolve_actor_player 把 normalize 不出 role_id 的 action 挡成
  -- rejected。曾经的「unresolvable」分支不可达——等价变异体,按 #257 删冗余。
  if share_panel.try_show(actor_role_id, "auto share panel") then
    player.auto_share_panel_shown = true
  end
end

function handlers.handle_auto_toggle(game, action)
  local player = ctx_mod.resolve_actor_player(game, action)
  if not player then
    return { status = "rejected" }
  end
  local result = control.toggle_manual_delegation(player)
  -- 分享绑定「变为开启」：关闭方向的点击（含初始已托管的 roster/debug 对局）
  -- 与未变化的补位电脑命令不弹分享面板。
  if result.enabled and player.auto_share_panel_shown ~= true then
    _try_show_share_panel(action.actor_role_id, player)
  end
  return { status = "applied" }
end

-- ui_button：next 行动按钮冷却锁

local function _phase_lock_released(turn_runtime, phase)
  if turn_runtime.next_turn_lock_phase and phase and phase ~= turn_runtime.next_turn_lock_phase then
    return true
  end
  return turn_runtime.next_turn_last_click == nil
end

local function _lock_released(turn_runtime, phase)
  if not turn_runtime.next_turn_locked then
    return true
  end
  return _phase_lock_released(turn_runtime, phase)
end

function handlers.allow_next_turn(turn_runtime, phase, now, ctx)
  if _lock_released(turn_runtime, phase) then
    return true
  end
  local diff = ctx_mod.resolve_timestamp_diff_seconds(ctx, now, turn_runtime.next_turn_last_click)
  return diff and diff >= defaults.next_turn_cooldown
end

function handlers.handle_next_turn(step_turn_fn, game, state, action, ctx)
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  local phase = game.turn.phase
  local now = ctx_mod.resolve_timestamp_now(ctx)
  if not handlers.allow_next_turn(turn_runtime, phase, now, ctx) then
    return { status = "rejected" }
  end
  turn_runtime.next_turn_locked = true
  turn_runtime.next_turn_last_click = now
  turn_runtime.next_turn_lock_phase = phase
  if phase == "wait_action" then
    game:dispatch_action(action)
  else
    step_turn_fn(game)
  end
  return { status = "applied" }
end

-- ui_button：cancel 转发为 choice_cancel

function handlers.handle_cancel(dispatch_fn, game, state, action, opts, ctx)
  local choice = ctx_mod.resolve_pending_choice(game, state, ctx)
  if choice == nil or choice.allow_cancel == false then
    return { status = "rejected" }
  end
  return dispatch_fn(game, state, {
    type = "choice_cancel",
    choice_id = choice.id,
    actor_role_id = action.actor_role_id,
    input_source = action.input_source,
  }, opts, ctx)
end

-- ui_button：next 行动按钮

function handlers.handle_next(game, state, action, opts, ctx, step_turn_fn)
  if not validator.validate_actor_role(game, action) then
    return { status = "rejected" }
  end
  if action.id ~= "next" then
    return { status = "rejected" }
  end
  return handlers.handle_next_turn(step_turn_fn, game, state, action, ctx)
end

function handlers.handle_ui_button(dispatch_fn, step_turn_fn, game, state, action, opts, ctx)
  if action.id == "auto" then
    return handlers.handle_auto_toggle(game, action)
  end
  if action.id == "cancel" then
    return handlers.handle_cancel(dispatch_fn, game, state, action, opts, ctx)
  end
  return handlers.handle_next(game, state, action, opts, ctx, step_turn_fn)
end

-- item_slot_click：裁定独占在 item_slot_click，本处只按结论走。

function handlers.handle_item_slot_click(dispatch_fn, game, state, action, opts, ctx)
  local resolution = item_slot_click.resolve(game, action)
  if resolution.status ~= "select" then
    return { status = "rejected" }
  end
  return dispatch_fn(game, state, resolution.action, opts, ctx)
end

-- choice_select / choice_cancel

function handlers.handle_choice_action(game, state, action, opts, ctx, turn_dispatch)
  local choice = ctx_mod.resolve_pending_choice(game, state, ctx)
  if not validator.validate(action, { game = game, choice = choice }) then
    return { status = "rejected" }
  end
  if game then
    assert(game.dispatch_action ~= nil, "missing game.dispatch_action")
    game:dispatch_action(action)
  end
  helpers.clear_choice_if_closed(turn_dispatch, game, state, opts, choice)
  return { status = "applied" }
end

-- complete_optional_action_phase

function handlers.handle_optional_action_completion(dispatch_fn, game, state, action, opts, ctx)
  local gate_state = validator.resolve_gate_state(state, ctx.ui_sync_ports)
  local result = optional_action_completion.complete_optional_action_phase(game, action.actor_role_id, state, {
    gate_state = gate_state,
    input_source = action.input_source,
    dispatch_choice_action = function(choice_action)
      return dispatch_fn(game, state, choice_action, opts, ctx)
    end,
  })
  return helpers.optional_completion_status(result)
end

return handlers

--[[ mutate4lua-manifest
version=4
projectHash=b0d5c07e8a8f0e04
scope.0.id=chunk:src/turn/actions/action_dispatcher_handlers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=161
scope.0.semanticHash=5c082fcf0ac66511
scope.1.id=function:_try_show_share_panel
scope.1.kind=function
scope.1.startLine=19
scope.1.endLine=26
scope.1.semanticHash=32339c68f9919f94
scope.2.id=function:handlers.handle_auto_toggle
scope.2.kind=function
scope.2.startLine=28
scope.2.endLine=40
scope.2.semanticHash=3b7753fe70138634
scope.3.id=function:_phase_lock_released
scope.3.kind=function
scope.3.startLine=44
scope.3.endLine=49
scope.3.semanticHash=b62d441797b8eb9b
scope.4.id=function:_lock_released
scope.4.kind=function
scope.4.startLine=51
scope.4.endLine=56
scope.4.semanticHash=7e68f2414ab1b8f4
scope.5.id=function:handlers.allow_next_turn
scope.5.kind=function
scope.5.startLine=58
scope.5.endLine=64
scope.5.semanticHash=97d79c1345432270
scope.6.id=function:handlers.handle_next_turn
scope.6.kind=function
scope.6.startLine=66
scope.6.endLine=82
scope.6.semanticHash=28d5edb6d4655b12
scope.7.id=function:handlers.handle_cancel
scope.7.kind=function
scope.7.startLine=86
scope.7.endLine=97
scope.7.semanticHash=048c4b6a5c3145d0
scope.8.id=function:handlers.handle_next
scope.8.kind=function
scope.8.startLine=101
scope.8.endLine=109
scope.8.semanticHash=227a8d1f8bbc38ca
scope.9.id=function:handlers.handle_ui_button
scope.9.kind=function
scope.9.startLine=111
scope.9.endLine=119
scope.9.semanticHash=e800930689efd1ac
scope.10.id=function:handlers.handle_item_slot_click
scope.10.kind=function
scope.10.startLine=123
scope.10.endLine=129
scope.10.semanticHash=41df25b1cf76b088
scope.11.id=function:handlers.handle_choice_action
scope.11.kind=function
scope.11.startLine=133
scope.11.endLine=144
scope.11.semanticHash=5a3c80e581f6dafd
scope.12.id=function:handlers.handle_optional_action_completion
scope.12.kind=function
scope.12.startLine=148
scope.12.endLine=158
scope.12.semanticHash=fdf104cd68c0f988
scope.13.id=function:<anonymous>
scope.13.kind=function
scope.13.startLine=153
scope.13.endLine=155
scope.13.semanticHash=ce6ae601295cf8b5
]]
