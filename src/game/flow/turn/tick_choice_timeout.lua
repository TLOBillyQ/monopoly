local constants = require("Config.generated.constants")
local gameplay_rules = require("src.core.config.gameplay_rules")
local number_utils = require("src.core.utils.number_utils")
local gameplay_loop_ports = require("src.game.flow.turn.gameplay_loop_ports")
local choice_contract = require("src.core.choice.choice_contract")

local tick_choice_timeout = {}

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

function tick_choice_timeout.step(game, state, dt, opts)
  assert(game ~= nil, "missing game")
  assert(opts ~= nil, "missing opts")
  assert(opts.on_pending_choice ~= nil, "missing opts.on_pending_choice")
  assert(opts.is_choice_active ~= nil, "missing opts.is_choice_active")
  assert(opts.build_action ~= nil, "missing opts.build_action")
  assert(type(opts.dispatch_action_with_close_choice) == "function", "missing opts.dispatch_action_with_close_choice")

  local ports = gameplay_loop_ports.resolve(state and state.gameplay_loop_ports or nil)
  local output_ports = ports.output
  local timeout = constants.action_timeout_seconds or 0
  if type(opts.get_timeout_seconds) == "function" then
    local override = opts.get_timeout_seconds(game, state)
    if number_utils.is_numeric(override) then
      timeout = override
    end
  end
  if timeout <= 0 then
    output_ports.set_pending_choice_elapsed(state, 0)
    output_ports.set_pending_choice_id(state, nil)
    return
  end

  local pending = game.turn.pending_choice
  local active_choice = output_ports.get_pending_choice(state)
  if pending and (not active_choice or active_choice.id ~= pending.id) then
    output_ports.sync_pending_choice(state, pending)
    opts.on_pending_choice(state, pending)
  elseif not pending then
    output_ports.clear_pending_choice(state)
  end

  local active = opts.is_choice_active(state)
  active_choice = output_ports.get_pending_choice(state)
  if not active or not active_choice then
    output_ports.set_pending_choice_elapsed(state, 0)
    output_ports.set_pending_choice_id(state, nil)
    return
  end

  if output_ports.get_pending_choice_id(state) ~= active_choice.id then
    output_ports.set_pending_choice_elapsed(state, 0)
    output_ports.set_pending_choice_id(state, active_choice.id)
  end

  local pending_choice_elapsed = output_ports.get_pending_choice_elapsed(state) + dt
  output_ports.set_pending_choice_elapsed(state, pending_choice_elapsed)
  local min_visible = gameplay_rules.auto_choice_min_visible_seconds or 0
  if type(opts.get_min_visible_seconds) == "function" then
    local override_min_visible = opts.get_min_visible_seconds(game, state, active_choice)
    if number_utils.is_numeric(override_min_visible) and override_min_visible >= 0 then
      min_visible = override_min_visible
    end
  end

  if min_visible > 0 and pending_choice_elapsed >= min_visible then
    local choice = active_choice
    local action = opts.build_action(game, state, choice, {
      mode = "tick_min_visible",
      elapsed_seconds = pending_choice_elapsed,
      min_visible_seconds = min_visible,
    })
    if action then
      _ensure_action_actor_role_id(game, choice, action)
      output_ports.set_pending_choice_elapsed(state, 0)
      opts.dispatch_action_with_close_choice(game, state, action)
      return
    end
  end

  if pending_choice_elapsed >= timeout then
    local choice = active_choice
    output_ports.set_pending_choice_elapsed(state, 0)
    local action = opts.build_action(game, state, choice, {
      mode = "tick_timeout",
      elapsed_seconds = pending_choice_elapsed,
      timeout_seconds = timeout,
      min_visible_seconds = min_visible,
    })
    assert(action ~= nil, "missing timeout action")
    _ensure_action_actor_role_id(game, choice, action)
    opts.dispatch_action_with_close_choice(game, state, action)
  end
end

return tick_choice_timeout
