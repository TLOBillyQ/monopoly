local role_id_utils = require("src.foundation.identity")

local optional_action_completion = {}

local function _current_player(game)
  if game and type(game.current_player) == "function" then
    return game:current_player()
  end
  local turn = game and game.turn or nil
  local index = turn and turn.current_player_index or nil
  return index and game and game.players and game.players[index] or nil
end

local function _current_player_id(game)
  local player = _current_player(game)
  return role_id_utils.normalize(player and player.id or nil)
end

local function _pending_choice(game, opts)
  if opts and opts.choice ~= nil then
    return opts.choice
  end
  return game and game.turn and game.turn.pending_choice or nil
end

local function _is_blocked(opts)
  local gate_state = opts and opts.gate_state or nil
  return gate_state and gate_state.input_blocked == true
end

function optional_action_completion.is_optional_action_choice(choice)
  local kind = choice and choice.kind or nil
  return kind == "item_phase_passive" or kind == "landing_optional_effect"
end

function optional_action_completion.is_cancelable_optional_action_choice(choice)
  return optional_action_completion.is_optional_action_choice(choice) and choice.allow_cancel ~= false
end

function optional_action_completion.can_complete_optional_action_phase(game, actor_id, state, opts)
  opts = opts or {}
  local choice = _pending_choice(game, opts)
  if not optional_action_completion.is_optional_action_choice(choice) then
    return { ok = false, reason = "no_optional_action" }
  end
  if choice.allow_cancel == false then
    return { ok = false, reason = "not_cancelable_optional_action", choice = choice }
  end
  if _is_blocked(opts) then
    return { ok = false, reason = "blocked", choice = choice }
  end
  if opts.require_actor ~= false then
    local normalized_actor_id = role_id_utils.normalize(actor_id)
    if normalized_actor_id == nil then
      return { ok = false, reason = "missing_actor", choice = choice }
    end
    local current_player_id = _current_player_id(game)
    if current_player_id ~= nil and not role_id_utils.equals(normalized_actor_id, current_player_id) then
      return { ok = false, reason = "not_current_player", choice = choice }
    end
  end
  return { ok = true, choice = choice }
end

local function _build_choice_cancel_action(choice, actor_id, input_source)
  return {
    type = "choice_cancel",
    choice_id = choice.id,
    actor_role_id = role_id_utils.normalize(actor_id),
    input_source = input_source,
  }
end

local function _dispatch_with_game(game, action)
  if game and type(game.dispatch_action) == "function" then
    game:dispatch_action(action)
    return { status = "applied" }
  end
  return { status = "rejected" }
end

function optional_action_completion.complete_optional_action_phase(game, actor_id, state, opts)
  opts = opts or {}
  local allowed = optional_action_completion.can_complete_optional_action_phase(game, actor_id, state, opts)
  if allowed.ok ~= true then
    return allowed
  end
  local action = _build_choice_cancel_action(allowed.choice, actor_id, opts.input_source)
  local dispatch = opts.dispatch_choice_action
  local dispatch_result
  if type(dispatch) == "function" then
    dispatch_result = dispatch(action)
  else
    dispatch_result = _dispatch_with_game(game, action)
  end
  local status = dispatch_result and dispatch_result.status or nil
  return {
    ok = status == "applied",
    status = status,
    reason = status == "applied" and nil or "dispatch_rejected",
    action = action,
    choice = allowed.choice,
  }
end

return optional_action_completion
