-- 设计约束：force_skip/resolve_choice/resolve_target_select 不 require turn.actions.action_dispatcher，
-- 避免 turn 子树内部循环。dispatch 入口由调用方传入闭包或经 game:advance_turn 驱动。
local number_utils = require("src.foundation.number")
local timing = require("src.config.gameplay.timing")
local logger = require("src.foundation.log")
local runtime_state = require("src.state.runtime")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local fallback_registry = require("src.rules.choice.fallback_registry")
local resolve_port = require("src.turn.loop.resolve_port")

local M = {}

local _default_thresholds = { 5, 3 }

local function _resolve_thresholds()
  local cfg = timing.deadline_warning_thresholds
  if type(cfg) ~= "table" then
    return _default_thresholds
  end
  return cfg
end

local function _ensure_active(state)
  local deadlines = runtime_state.ensure_deadlines(state)
  return deadlines.active
end

local function _resolve_timeout(opts)
  if not opts then
    return 0
  end
  if number_utils.is_numeric(opts.timeout_seconds) and opts.timeout_seconds > 0 then
    return opts.timeout_seconds
  end
  return 0
end

local function _new_entry(scope, opts, timeout)
  return {
    scope = scope,
    elapsed = 0,
    timeout = timeout,
    on_timeout = opts.on_timeout,
    on_warn = opts.on_warn,
    priority = number_utils.is_numeric(opts.priority) and opts.priority or 0,
    fired_warn_5s = false,
    fired_warn_3s = false,
    fired_timeout = false,
    started_at = nil,
  }
end

local function _call_deadline_callback(callback, label, warn_args, ...)
  if type(callback) ~= "function" then
    return
  end
  local ok, err = pcall(callback, ...)
  if not ok then
    logger.warn("[Eggy]", label, table.unpack(warn_args), tostring(err))
  end
end

local function _fire_warn(entry, level)
  _call_deadline_callback(entry.on_warn, "DeadlineService.on_warn error", { entry.scope, level }, level)
end

local function _maybe_fire_warns(entry, remaining, thresholds)
  local warn_5s = thresholds[1] or 5
  local warn_3s = thresholds[2] or 3
  if not entry.fired_warn_5s and remaining <= warn_5s and remaining > warn_3s then
    entry.fired_warn_5s = true
    _fire_warn(entry, "warn_5s")
  end
  if not entry.fired_warn_3s and remaining <= warn_3s and remaining > 0 then
    entry.fired_warn_3s = true
    _fire_warn(entry, "warn_3s")
  end
end

local function _level_from_remaining(remaining, thresholds)
  if remaining <= 0 then
    return "expired"
  end
  local warn_3s = thresholds[2] or 3
  local warn_5s = thresholds[1] or 5
  if remaining <= warn_3s then
    return "warn_3s"
  end
  if remaining <= warn_5s then
    return "warn_5s"
  end
  return "normal"
end

function M.start(state, scope, opts)
  assert(type(state) == "table", "missing state")
  assert(type(scope) == "string" and scope ~= "", "invalid scope")
  opts = opts or {}
  local timeout = _resolve_timeout(opts)
  if timeout <= 0 then
    return nil
  end
  local active = _ensure_active(state)
  active[scope] = _new_entry(scope, opts, timeout)
  return active[scope]
end

function M.cancel(state, scope)
  if type(state) ~= "table" or type(scope) ~= "string" then
    return false
  end
  local active = _ensure_active(state)
  if active[scope] == nil then
    return false
  end
  active[scope] = nil
  return true
end

local _peek_result = {}

local function _build_peek_result(entry)
  local remaining = entry.timeout - entry.elapsed
  if remaining < 0 then remaining = 0 end
  _peek_result.scope = entry.scope
  _peek_result.remaining_seconds = remaining
  _peek_result.elapsed_seconds = entry.elapsed
  _peek_result.timeout_seconds = entry.timeout
  _peek_result.level = _level_from_remaining(remaining, _resolve_thresholds())
  return _peek_result
end

function M.peek(state, scope)
  if type(state) ~= "table" then
    return nil
  end
  local active = _ensure_active(state)
  if scope == "primary" then
    local primary = nil
    for _, entry in pairs(active) do
      if primary == nil or (entry.priority or 0) > (primary.priority or 0) then
        primary = entry
      end
    end
    return primary and _build_peek_result(primary) or nil
  end
  local entry = active[scope]
  return entry and _build_peek_result(entry) or nil
end

local _expired_scopes = {}
local _expired_entries = {}

local function _collect_expired_entry(scope, entry, thresholds, dt, expired_n)
  if entry.fired_timeout then
    return expired_n
  end
  entry.elapsed = (entry.elapsed or 0) + dt
  local remaining = entry.timeout - entry.elapsed
  _maybe_fire_warns(entry, remaining, thresholds)
  if entry.elapsed < entry.timeout then
    return expired_n
  end
  entry.fired_timeout = true
  expired_n = expired_n + 1
  _expired_scopes[expired_n] = scope
  _expired_entries[expired_n] = entry
  return expired_n
end

local function _fire_timeout(entry, scope)
  _call_deadline_callback(entry.on_timeout, "DeadlineService.on_timeout error", { scope }, scope)
end

local function _expire_collected_entries(active, expired_n)
  for i = 1, expired_n do
    local scope = _expired_scopes[i]
    local entry = _expired_entries[i]
    _expired_scopes[i] = nil
    _expired_entries[i] = nil
    active[scope] = nil
    _fire_timeout(entry, scope)
  end
end

function M.tick(state, dt)
  if type(state) ~= "table" then
    return
  end
  if not number_utils.is_numeric(dt) or dt <= 0 then
    return
  end
  local active = _ensure_active(state)
  local thresholds = _resolve_thresholds()
  local expired_n = 0
  for scope, entry in pairs(active) do
    expired_n = _collect_expired_entry(scope, entry, thresholds, dt, expired_n)
  end
  _expire_collected_entries(active, expired_n)
end

function M.is_active(state, scope)
  if type(state) ~= "table" or type(scope) ~= "string" then
    return false
  end
  local active = _ensure_active(state)
  return active[scope] ~= nil
end

local function _resolve_modal_ports(state)
  local resolved = state and (state._resolved_gameplay_loop_ports or state.gameplay_loop_ports) or nil
  if type(resolved) ~= "table" then
    return nil
  end
  return resolved.modal
end

local function _resolve_output_ports(state)
  return resolve_port.resolve(state, "output", require("src.turn.output.state_adapter"))
end

local function _is_action_dispatchable(action)
  if type(action) ~= "table" then
    return false
  end
  return action.type == "choice_select"
    or action.type == "choice_cancel"
    or action.type == "complete_optional_action_phase"
end

local function _resolve_owner_actor_id(choice)
  return choice and choice.owner_role_id or nil
end

local function _resolve_current_player_actor_id(game)
  local p = game and game.turn and game.turn.current_player_index and game.players and game.players[game.turn.current_player_index]
  return p and p.id or nil
end

local function _ensure_actor_role_id(game, choice, action)
  if action.actor_role_id ~= nil then return end
  action.actor_role_id = _resolve_owner_actor_id(choice) or _resolve_current_player_actor_id(game)
end

local function _dispatch_via_close_choice(game, state, action)
  if game and type(game.dispatch_action) == "function" then
    pcall(game.dispatch_action, game, action)
  end
  if game and game.turn then
    local pending = game.turn.pending_choice
    if not pending or pending.id ~= action.choice_id then
      game.turn.pending_choice = nil
    end
  end
  local modal_ports = _resolve_modal_ports(state)
  if modal_ports and type(modal_ports.close_choice_modal) == "function" then
    pcall(modal_ports.close_choice_modal, state)
  end
  if type(state) == "table" then
    local output_ports = _resolve_output_ports(state)
    if output_ports and type(output_ports.clear_pending_choice) == "function" then
      pcall(output_ports.clear_pending_choice, state)
    end
  end
end

local function _refund_preconsume(state, choice)
  if type(choice) ~= "table" or type(choice.meta) ~= "table" then
    return
  end
  if choice.meta.item_preconsumed ~= true then
    return
  end
  local item_id = choice.meta.item_id
  local owner_id = choice.owner_role_id
  if item_id == nil or owner_id == nil then
    return
  end
  local ok, helper = pcall(require, "src.rules.choice.item_preconsume_policy")
  if ok and type(helper) == "table" and type(helper.refund) == "function" then
    pcall(helper.refund, state and state._game or nil, choice)
  end
end

local function _emit_force_skip_event(reason, choice)
  local ok, monopoly_events = pcall(require, "src.foundation.events")
  if ok and type(monopoly_events) == "table" and type(monopoly_events.emit) == "function" then
    pcall(monopoly_events.emit, "fb.choice_force_skipped", {
      reason = reason or "tick_timeout",
      choice_id = choice and choice.id or nil,
      kind = choice and choice.kind or nil,
    })
  end
  logger.info("[Eggy]", "choice_force_skipped",
    "reason=" .. tostring(reason),
    "choice_id=" .. tostring(choice and choice.id or nil),
    "kind=" .. tostring(choice and choice.kind or nil))
end

local function _mark_force_skip_pending(game, state)
  if type(state) == "table" then
    state._choice_force_skip_pending = true
  end
  if game and game.turn then
    game.turn._choice_force_skip_pending = true
  end
end

local function _clear_force_skip_state(game, state)
  if type(state) == "table" then
    state._item_phase_ask_active = nil
    local output_ports = _resolve_output_ports(state)
    if output_ports then
      local clear_pending_choice = output_ports.clear_pending_choice
      if type(clear_pending_choice) == "function" then
        pcall(clear_pending_choice, state)
      end
    end
  end
  if game and game.turn then
    game.turn.pending_choice = nil
  end
end

local function _cancel_choice_deadlines(state)
  if type(state) ~= "table" then
    return
  end
  M.cancel(state, "choice")
  M.cancel(state, "market_buy")
  M.cancel(state, "target_select")
  M.cancel(state, "modal_popup")
end

local function _advance_after_force_skip(game)
  if game and not game.finished and type(game.advance_turn) == "function" then
    pcall(game.advance_turn, game)
  end
end

function M.force_skip(game, state, choice, reason)
  _mark_force_skip_pending(game, state)
  _refund_preconsume(state, choice)
  _clear_force_skip_state(game, state)
  _cancel_choice_deadlines(state)
  _emit_force_skip_event(reason, choice)
  _advance_after_force_skip(game)
end

local function _try_choice_auto(game, state, choice)
  local elapsed = 0
  if type(state) == "table" then
    local entry = M.peek(state, choice and choice.kind == "market_buy" and "market_buy" or "choice")
    if entry then
      elapsed = entry.elapsed_seconds or 0
    else
      elapsed = runtime_state.get_pending_choice_elapsed(state) or 0
    end
  end
  return choice_auto_policy.decide(game, state, choice, {
    mode = "tick_timeout",
    elapsed_seconds = elapsed,
    min_visible_seconds = 0,
    allow_first_option_fallback = true,
  })
end

local function _dispatch_choice_action(game, state, choice, action)
  if not _is_action_dispatchable(action) then
    return false
  end
  if action.choice_id == nil then
    action.choice_id = choice.id
  end
  _ensure_actor_role_id(game, choice, action)
  _dispatch_via_close_choice(game, state, action)
  return true
end

local function _resolve_fallback_choice_action(game, choice, action)
  if not (action == nil or (type(action) == "table" and action.type == "choice_force_skip")) then
    return nil
  end
  return fallback_registry.resolve(choice.kind, game, choice)
end

function M.resolve_choice(game, state, choice, reason)
  if type(choice) ~= "table" or choice.id == nil then
    M.force_skip(game, state, choice, reason or "no_choice")
    return
  end
  local action = _try_choice_auto(game, state, choice)
  if _dispatch_choice_action(game, state, choice, action) then
    return
  end
  if _dispatch_choice_action(game, state, choice, _resolve_fallback_choice_action(game, choice, action)) then
    return
  end
  M.force_skip(game, state, choice, reason or "tick_timeout")
end

function M.resolve_target_select(game, state, target_ctx, reason)
  local choice = nil
  if type(target_ctx) == "table" then
    choice = target_ctx.choice
  end
  if choice == nil and game and game.turn then
    choice = game.turn.pending_choice
  end
  M.force_skip(game, state, choice, reason or "target_select_timeout")
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=15a362725cdeb4ff
scope.0.id=chunk:src/turn/deadlines.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=412
scope.0.semanticHash=cbc02a04c07622ec
scope.1.id=function:_resolve_thresholds:15
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=21
scope.1.semanticHash=2234c7730cedcf91
scope.2.id=function:_ensure_active:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=26
scope.2.semanticHash=218d50b8035c4f78
scope.3.id=function:_resolve_timeout:28
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=36
scope.3.semanticHash=c2ca88cd22fdfbef
scope.4.id=function:_new_entry:38
scope.4.kind=function
scope.4.startLine=38
scope.4.endLine=51
scope.4.semanticHash=fc628022fadec23f
scope.5.id=function:_call_deadline_callback:53
scope.5.kind=function
scope.5.startLine=53
scope.5.endLine=61
scope.5.semanticHash=98293f59f2976f5f
scope.6.id=function:_fire_warn:63
scope.6.kind=function
scope.6.startLine=63
scope.6.endLine=65
scope.6.semanticHash=a8680a9eda420cd9
scope.7.id=function:_maybe_fire_warns:67
scope.7.kind=function
scope.7.startLine=67
scope.7.endLine=78
scope.7.semanticHash=3d7528824952bd05
scope.8.id=function:_level_from_remaining:80
scope.8.kind=function
scope.8.startLine=80
scope.8.endLine=93
scope.8.semanticHash=db874ab6e8fca7fd
scope.9.id=function:M.start:95
scope.9.kind=function
scope.9.startLine=95
scope.9.endLine=106
scope.9.semanticHash=d2dbd4201881f38b
scope.10.id=function:M.cancel:108
scope.10.kind=function
scope.10.startLine=108
scope.10.endLine=118
scope.10.semanticHash=a40644978bcdfd47
scope.11.id=function:_build_peek_result:122
scope.11.kind=function
scope.11.startLine=122
scope.11.endLine=131
scope.11.semanticHash=40be2ba60136f2c6
scope.12.id=function:_collect_expired_entry:154
scope.12.kind=function
scope.12.startLine=154
scope.12.endLine=169
scope.12.semanticHash=12650af2c39c06e6
scope.13.id=function:_fire_timeout:171
scope.13.kind=function
scope.13.startLine=171
scope.13.endLine=173
scope.13.semanticHash=1946bb4b20a6a80e
scope.14.id=function:M.is_active:202
scope.14.kind=function
scope.14.startLine=202
scope.14.endLine=208
scope.14.semanticHash=c76f718a441331ab
scope.15.id=function:_resolve_modal_ports:210
scope.15.kind=function
scope.15.startLine=210
scope.15.endLine=216
scope.15.semanticHash=ccfd0be6013bdd33
scope.16.id=function:_resolve_output_ports:218
scope.16.kind=function
scope.16.startLine=218
scope.16.endLine=220
scope.16.semanticHash=53d7c5c0e488be20
scope.17.id=function:_is_action_dispatchable:222
scope.17.kind=function
scope.17.startLine=222
scope.17.endLine=227
scope.17.semanticHash=4d72692495468093
scope.18.id=function:_resolve_owner_actor_id:229
scope.18.kind=function
scope.18.startLine=229
scope.18.endLine=231
scope.18.semanticHash=a36f90c40f1f7fda
scope.19.id=function:_resolve_current_player_actor_id:233
scope.19.kind=function
scope.19.startLine=233
scope.19.endLine=236
scope.19.semanticHash=75813f76748301e3
scope.20.id=function:_ensure_actor_role_id:238
scope.20.kind=function
scope.20.startLine=238
scope.20.endLine=241
scope.20.semanticHash=9fb6eab3386ac4d2
scope.21.id=function:_dispatch_via_close_choice:243
scope.21.kind=function
scope.21.startLine=243
scope.21.endLine=263
scope.21.semanticHash=6fc9e367c3c96496
scope.22.id=function:_refund_preconsume:265
scope.22.kind=function
scope.22.startLine=265
scope.22.endLine=281
scope.22.semanticHash=42ad534e2a50a7ef
scope.23.id=function:_emit_force_skip_event:283
scope.23.kind=function
scope.23.startLine=283
scope.23.endLine=296
scope.23.semanticHash=14a9ec323f203f29
scope.24.id=function:_mark_force_skip_pending:298
scope.24.kind=function
scope.24.startLine=298
scope.24.endLine=305
scope.24.semanticHash=d83eb47bcc8068fe
scope.25.id=function:_clear_force_skip_state:307
scope.25.kind=function
scope.25.startLine=307
scope.25.endLine=321
scope.25.semanticHash=9f1b6b27dbd73e67
scope.26.id=function:_cancel_choice_deadlines:323
scope.26.kind=function
scope.26.startLine=323
scope.26.endLine=331
scope.26.semanticHash=3126b04a8291e2af
scope.27.id=function:_advance_after_force_skip:333
scope.27.kind=function
scope.27.startLine=333
scope.27.endLine=337
scope.27.semanticHash=ca68a6f1e1e4603d
scope.28.id=function:M.force_skip:339
scope.28.kind=function
scope.28.startLine=339
scope.28.endLine=346
scope.28.semanticHash=737ac223c280963c
scope.29.id=function:_try_choice_auto:348
scope.29.kind=function
scope.29.startLine=348
scope.29.endLine=364
scope.29.semanticHash=fcec8ba7082b2950
scope.30.id=function:_dispatch_choice_action:366
scope.30.kind=function
scope.30.startLine=366
scope.30.endLine=376
scope.30.semanticHash=7e9f2ecc40f3f04e
scope.31.id=function:_resolve_fallback_choice_action:378
scope.31.kind=function
scope.31.startLine=378
scope.31.endLine=383
scope.31.semanticHash=332f4831fc54f602
scope.32.id=function:M.resolve_choice:385
scope.32.kind=function
scope.32.startLine=385
scope.32.endLine=398
scope.32.semanticHash=69222930c20414bc
scope.33.id=function:M.resolve_target_select:400
scope.33.kind=function
scope.33.startLine=400
scope.33.endLine=409
scope.33.semanticHash=1cda3581c6814c94
]]
