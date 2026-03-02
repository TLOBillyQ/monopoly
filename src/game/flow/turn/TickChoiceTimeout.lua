local constants = require("Config.Generated.Constants")
local gameplay_rules = require("Config.GameplayRules")
local number_utils = require("src.core.NumberUtils")

local tick_choice_timeout = {}

local function _resolve_choice_owner_id(game, choice)
  local meta = choice and choice.meta or {}
  if meta.player_id and game.find_player_by_id then
    local player = game:find_player_by_id(meta.player_id)
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

  local timeout = constants.action_timeout_seconds or 0
  if type(opts.get_timeout_seconds) == "function" then
    local override = opts.get_timeout_seconds(game, state)
    if number_utils.is_numeric(override) then
      timeout = override
    end
  end
  if timeout <= 0 then
    state.pending_choice_elapsed = 0
    state.pending_choice_id = nil
    return
  end

  local pending = game.turn.pending_choice
  if pending and (not state.pending_choice or state.pending_choice.id ~= pending.id) then
    state.pending_choice = pending
    state.pending_choice_elapsed = 0
    state.pending_choice_id = pending.id
    opts.on_pending_choice(state, pending)
  elseif not pending then
    state.pending_choice = nil
    state.pending_choice_elapsed = 0
    state.pending_choice_id = nil
  end

  local active = opts.is_choice_active(state)
  if not active or not state.pending_choice then
    state.pending_choice_elapsed = 0
    state.pending_choice_id = nil
    return
  end

  if state.pending_choice_id ~= state.pending_choice.id then
    state.pending_choice_elapsed = 0
    state.pending_choice_id = state.pending_choice.id
  end

  state.pending_choice_elapsed = state.pending_choice_elapsed + dt
  local min_visible = gameplay_rules.auto_choice_min_visible_seconds or 0
  if type(opts.get_min_visible_seconds) == "function" then
    local override_min_visible = opts.get_min_visible_seconds(game, state, state.pending_choice)
    if number_utils.is_numeric(override_min_visible) and override_min_visible >= 0 then
      min_visible = override_min_visible
    end
  end

  if min_visible > 0 and state.pending_choice_elapsed >= min_visible then
    local choice = state.pending_choice
    local action = opts.build_action(game, state, choice, {
      mode = "tick_min_visible",
      elapsed_seconds = state.pending_choice_elapsed,
      min_visible_seconds = min_visible,
    })
    if action then
      _ensure_action_actor_role_id(game, choice, action)
      state.pending_choice_elapsed = 0
      opts.dispatch_action_with_close_choice(game, state, action)
      return
    end
  end

  if state.pending_choice_elapsed >= timeout then
    local choice = state.pending_choice
    state.pending_choice_elapsed = 0
    local action = opts.build_action(game, state, choice, {
      mode = "tick_timeout",
      elapsed_seconds = state.pending_choice_elapsed,
      timeout_seconds = timeout,
      min_visible_seconds = min_visible,
    })
    assert(action ~= nil, "missing timeout action")
    _ensure_action_actor_role_id(game, choice, action)
    opts.dispatch_action_with_close_choice(game, state, action)
  end
end

return tick_choice_timeout
