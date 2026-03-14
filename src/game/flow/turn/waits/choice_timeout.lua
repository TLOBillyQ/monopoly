local constants = require("src.config.content.constants")
local gameplay_rules = require("src.config.gameplay.gameplay_rules")
local logger = require("src.core.utils.logger")
local number_utils = require("src.core.utils.number_utils")
local choice_contract = require("src.core.choice.contract")
local runtime_state = require("src.state.state_access.runtime_state")
local output_state_adapter = require("src.game.flow.output_adapters.output_state_adapter")

local tick_choice_timeout = {}

local function _log_once(state, key, ...)
  local debug_runtime = runtime_state.ensure_debug_runtime(state)
  if debug_runtime.log_once[key] then
    return
  end
  debug_runtime.log_once[key] = true
  logger.warn(...)
end

local function _resolve_output_ports(state)
  local resolved = state and (state._resolved_gameplay_loop_ports or state.gameplay_loop_ports) or nil
  local output_ports = type(resolved) == "table" and resolved.output or nil
  if type(output_ports) == "table" then
    return output_ports
  end
  return output_state_adapter
end

local function _resolve_choice_owner_id(game, choice)
  local owner_role_id = choice_contract.resolve_owner_role_id(choice)
  if owner_role_id ~= nil and game.find_player_by_id then
    local player = game:find_player_by_id(owner_role_id)
    if player then
      return player.id
    end
  end
  local current = game.turn and game.turn.current_player_index or nil
  local player = current and game.players and game.players[current] or nil
  return player and player.id or nil
end

local function _ensure_action_actor_role_id(game, choice, action)
  if not action or action.actor_role_id ~= nil then
    return action
  end
  local owner_id = _resolve_choice_owner_id(game, choice)
  if owner_id ~= nil then
    action.actor_role_id = owner_id
  end
  return action
end

local function _assert_step_opts(game, opts)
  assert(game ~= nil, "missing game")
  assert(opts ~= nil, "missing opts")
  assert(opts.on_pending_choice ~= nil, "missing opts.on_pending_choice")
  assert(opts.is_choice_active ~= nil, "missing opts.is_choice_active")
  assert(opts.build_action ~= nil, "missing opts.build_action")
  assert(type(opts.dispatch_action_with_close_choice) == "function", "missing opts.dispatch_action_with_close_choice")
end

local function _resolve_timeout_seconds(game, state, opts)
  local output_ports = _resolve_output_ports(state)
  local timeout = constants.action_timeout_seconds or 0
  if type(opts.get_timeout_seconds) == "function" then
    local override = opts.get_timeout_seconds(game, state)
    if number_utils.is_numeric(override) then
      timeout = override
    end
  end
  return output_ports, timeout
end

local function _sync_pending_choice_ui(game, state, opts, output_ports)
  local pending = game.turn.pending_choice
  local active_choice = output_ports.get_pending_choice(state)
  if pending and (not active_choice or active_choice.id ~= pending.id) then
    output_ports.sync_pending_choice(state, pending)
    opts.on_pending_choice(state, pending)
  elseif not pending then
    output_ports.clear_pending_choice(state)
  end
  return pending, output_ports.get_pending_choice(state)
end

local function _resolve_missing_ui_warning(state, game, opts, pending, active_choice, ui_choice_active)
  local active = pending ~= nil or active_choice ~= nil
  local resolved_ui_gate = nil
  if active and active_choice and type(opts.resolve_choice_ui_state) == "function" then
    resolved_ui_gate = opts.resolve_choice_ui_state(game, state, active_choice)
  end
  local should_warn_missing_ui = active and active_choice and not ui_choice_active
  if type(resolved_ui_gate) == "table" then
    should_warn_missing_ui = resolved_ui_gate.should_warn == true
  end
  return active, should_warn_missing_ui
end

local function _maybe_warn_missing_ui(state, active_choice, should_warn_missing_ui)
  if not should_warn_missing_ui then
    return
  end
  _log_once(
    state,
    "choice_runtime_without_ui_" .. tostring(active_choice.id),
    "[Eggy]",
    "runtime pending choice active without ui.choice_active",
    "choice_id=" .. tostring(active_choice.id),
    "kind=" .. tostring(active_choice.kind),
    "owner_role_id=" .. tostring(active_choice.owner_role_id),
    "route_key=" .. tostring(active_choice.route_key)
  )
end

local function _sync_elapsed_choice_id(state, output_ports, active_choice)
  if output_ports.get_pending_choice_id(state) ~= active_choice.id then
    output_ports.set_pending_choice_elapsed(state, 0)
    output_ports.set_pending_choice_id(state, active_choice.id)
  end
end

local function _resolve_min_visible_seconds(game, state, active_choice, opts)
  local min_visible = gameplay_rules.auto_choice_min_visible_seconds or 0
  if type(opts.get_min_visible_seconds) == "function" then
    local override_min_visible = opts.get_min_visible_seconds(game, state, active_choice)
    if number_utils.is_numeric(override_min_visible) and override_min_visible >= 0 then
      min_visible = override_min_visible
    end
  end
  return min_visible
end

local function _dispatch_choice_tick_action(game, state, choice, output_ports, opts, payload)
  local action = opts.build_action(game, state, choice, payload)
  if not action then
    return false
  end
  _ensure_action_actor_role_id(game, choice, action)
  output_ports.set_pending_choice_elapsed(state, 0)
  opts.dispatch_action_with_close_choice(game, state, action)
  return true
end

function tick_choice_timeout.step(game, state, dt, opts)
  _assert_step_opts(game, opts)
  local output_ports, timeout = _resolve_timeout_seconds(game, state, opts)
  if timeout <= 0 then
    output_ports.set_pending_choice_elapsed(state, 0)
    output_ports.set_pending_choice_id(state, nil)
    return
  end
  local pending, active_choice = _sync_pending_choice_ui(game, state, opts, output_ports)
  local ui_choice_active = opts.is_choice_active(state) == true
  local active, should_warn_missing_ui = _resolve_missing_ui_warning(
    state, game, opts, pending, active_choice, ui_choice_active
  )
  _maybe_warn_missing_ui(state, active_choice, should_warn_missing_ui)
  if not active or not active_choice then
    output_ports.set_pending_choice_elapsed(state, 0)
    output_ports.set_pending_choice_id(state, nil)
    return
  end
  _sync_elapsed_choice_id(state, output_ports, active_choice)
  local pending_choice_elapsed = output_ports.get_pending_choice_elapsed(state) + dt
  output_ports.set_pending_choice_elapsed(state, pending_choice_elapsed)
  local min_visible = _resolve_min_visible_seconds(game, state, active_choice, opts)
  if min_visible > 0 and pending_choice_elapsed >= min_visible then
    if _dispatch_choice_tick_action(game, state, active_choice, output_ports, opts, {
      mode = "tick_min_visible",
      elapsed_seconds = pending_choice_elapsed,
      min_visible_seconds = min_visible,
    }) then
      return
    end
  end
  if pending_choice_elapsed >= timeout then
    local action = opts.build_action(game, state, active_choice, {
      mode = "tick_timeout",
      elapsed_seconds = pending_choice_elapsed,
      timeout_seconds = timeout,
      min_visible_seconds = min_visible,
    })
    assert(action ~= nil, "missing timeout action")
    _ensure_action_actor_role_id(game, active_choice, action)
    output_ports.set_pending_choice_elapsed(state, 0)
    opts.dispatch_action_with_close_choice(game, state, action)
  end
end

tick_choice_timeout._resolve_choice_owner_id = _resolve_choice_owner_id

return tick_choice_timeout
