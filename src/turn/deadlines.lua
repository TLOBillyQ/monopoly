-- 设计约束：force_skip/resolve_choice/resolve_target_select 不 require turn.actions.action_dispatcher，
-- 避免 turn 子树内部循环。dispatch 入口由调用方传入闭包或经 game:advance_turn 驱动。
local number_utils = require("src.foundation.number")
local timing = require("src.config.gameplay.timing")
local logger = require("src.foundation.log")
local runtime_state = require("src.state.runtime")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local fallback_registry = require("src.rules.choice.fallback_registry")

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

local function _fire_warn(entry, level)
  if type(entry.on_warn) ~= "function" then
    return
  end
  local ok, err = pcall(entry.on_warn, level)
  if not ok then
    logger.warn("[Eggy]", "DeadlineService.on_warn error", entry.scope, level, tostring(err))
  end
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
    if not entry.fired_timeout then
      entry.elapsed = (entry.elapsed or 0) + dt
      local remaining = entry.timeout - entry.elapsed
      _maybe_fire_warns(entry, remaining, thresholds)
      if entry.elapsed >= entry.timeout then
        entry.fired_timeout = true
        expired_n = expired_n + 1
        _expired_scopes[expired_n] = scope
        _expired_entries[expired_n] = entry
      end
    end
  end
  for i = 1, expired_n do
    local scope = _expired_scopes[i]
    local entry = _expired_entries[i]
    _expired_scopes[i] = nil
    _expired_entries[i] = nil
    active[scope] = nil
    if type(entry.on_timeout) == "function" then
      local ok, err = pcall(entry.on_timeout, scope)
      if not ok then
        logger.warn("[Eggy]", "DeadlineService.on_timeout error", scope, tostring(err))
      end
    end
  end
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
  local resolved = state and (state._resolved_gameplay_loop_ports or state.gameplay_loop_ports) or nil
  local output_ports = type(resolved) == "table" and resolved.output or nil
  if type(output_ports) == "table" then
    return output_ports
  end
  return require("src.turn.output.state_adapter")
end

local function _is_action_dispatchable(action)
  if type(action) ~= "table" then
    return false
  end
  return action.type == "choice_select" or action.type == "choice_cancel"
end

local function _ensure_actor_role_id(game, choice, action)
  if action.actor_role_id ~= nil then
    return
  end
  local owner = choice and choice.owner_role_id or nil
  if owner ~= nil then
    action.actor_role_id = owner
    return
  end
  local current = game and game.turn and game.turn.current_player_index or nil
  local player = current and game.players and game.players[current] or nil
  if player then
    action.actor_role_id = player.id
  end
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

function M.force_skip(game, state, choice, reason)
  if type(state) == "table" then
    state._choice_force_skip_pending = true
  end
  if game and game.turn then
    game.turn._choice_force_skip_pending = true
  end
  _refund_preconsume(state, choice)
  if type(state) == "table" then
    state._item_phase_ask_active = nil
    local output_ports = _resolve_output_ports(state)
    if output_ports and type(output_ports.clear_pending_choice) == "function" then
      pcall(output_ports.clear_pending_choice, state)
    end
  end
  if game and game.turn then
    game.turn.pending_choice = nil
  end
  if type(state) == "table" then
    M.cancel(state, "choice")
    M.cancel(state, "market_buy")
    M.cancel(state, "target_select")
    M.cancel(state, "modal_popup")
  end
  _emit_force_skip_event(reason, choice)
  if game and not game.finished and type(game.advance_turn) == "function" then
    pcall(game.advance_turn, game)
  end
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

function M.resolve_choice(game, state, choice, reason)
  if type(choice) ~= "table" or choice.id == nil then
    M.force_skip(game, state, choice, reason or "no_choice")
    return
  end
  local action = _try_choice_auto(game, state, choice)
  if _is_action_dispatchable(action) then
    _ensure_actor_role_id(game, choice, action)
    _dispatch_via_close_choice(game, state, action)
    return
  end
  if action == nil or (type(action) == "table" and action.type == "choice_force_skip") then
    local kind = choice.kind
    local fb_action = fallback_registry.resolve(kind, game, choice)
    if _is_action_dispatchable(fb_action) then
      if fb_action.choice_id == nil then
        fb_action.choice_id = choice.id
      end
      _ensure_actor_role_id(game, choice, fb_action)
      _dispatch_via_close_choice(game, state, fb_action)
      return
    end
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
