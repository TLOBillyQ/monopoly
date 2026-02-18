local agent = require("src.game.core.runtime.Agent")
local constants = require("Config.Generated.Constants")
local gameplay_rules = require("Config.GameplayRules")
local turn_dispatch = require("src.game.flow.turn.TurnDispatch")
local number_utils = require("src.core.NumberUtils")

local tick_timeout = {}

local function _resolve_ports(state)
  local ports = state and state.gameplay_loop_ports or nil
  if not ports then
    return nil
  end
  local modal_ports = ports.modal
  if type(modal_ports) ~= "table" then
    return nil
  end
  if type(modal_ports.close_choice_modal) == "function" or type(modal_ports.close_popup) == "function" then
    return modal_ports
  end
  return nil
end

local function _dispatch_action_with_close_choice(game, state, action)
  local ports = _resolve_ports(state)
  if not ports then
    return turn_dispatch.dispatch_action(game, state, action)
  end
  return turn_dispatch.dispatch_action(game, state, action, {
    on_close_choice = function(ctx)
      ports.close_choice_modal(ctx)
    end,
  })
end

local function _resolve_choice_owner(game, choice)
  local meta = choice and choice.meta or {}
  if meta.player_id and game.find_player_by_id then
    local player = game:find_player_by_id(meta.player_id)
    if player then
      return player
    end
  end
  if game.current_player then
    return game:current_player()
  end
  return nil
end

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

local function _pick_first_choice_option(choice)
  local options = assert(choice.options, "missing choice.options")
  local first = assert(options[1], "missing choice option")
  return first.id or first
end

local function _build_default_choice_action(game_ctx, choice)
  local auto_choice = agent.auto_action_for_choice(game_ctx, choice)
  if auto_choice then
    return auto_choice
  end
  return {
    type = "choice_select",
    choice_id = choice.id,
    option_id = _pick_first_choice_option(choice),
  }
end

local function _modal_timeout_seconds(_, state)
  local popup = state and state.ui and state.ui.popup_payload or nil
  local auto_close_seconds = popup and popup.auto_close_seconds or nil
  if auto_close_seconds ~= nil and number_utils.is_numeric(auto_close_seconds) and auto_close_seconds > 0 then
    return auto_close_seconds
  end
  local timeout = gameplay_rules.popup_auto_close_seconds
  if number_utils.is_numeric(timeout) and timeout > 0 then
    return timeout
  end
  return 1.0
end

function tick_timeout.step_choice_timeout(game, state, dt, opts)
  assert(game ~= nil, "missing game")
  assert(opts ~= nil, "missing opts")
  assert(opts.on_pending_choice ~= nil, "missing opts.on_pending_choice")
  assert(opts.is_choice_active ~= nil, "missing opts.is_choice_active")
  assert(opts.build_action ~= nil, "missing opts.build_action")
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
    local actor = _resolve_choice_owner(game, choice)
    if actor and agent.is_auto_player(actor) then
      local action = opts.build_action(game, state, choice)
      if action then
        _ensure_action_actor_role_id(game, choice, action)
        state.pending_choice_elapsed = 0
        _dispatch_action_with_close_choice(game, state, action)
        return
      end
    end
  end
  if state.pending_choice_elapsed >= timeout then
    local choice = state.pending_choice
    state.pending_choice_elapsed = 0
    local action = opts.build_action(game, state, choice)
    assert(action ~= nil, "missing timeout action")
    _ensure_action_actor_role_id(game, choice, action)
    _dispatch_action_with_close_choice(game, state, action)
  end
end

function tick_timeout.step_modal_timeout(state, dt, opts)
  local timeout = constants.action_timeout_seconds or 0
  if opts and opts.get_timeout_seconds then
    local override = opts.get_timeout_seconds(state)
    if override ~= nil and number_utils.is_numeric(override) then
      timeout = override
    end
  end
  if timeout <= 0 then
    state.ui_modal_elapsed = 0
    state.ui_modal_ref = nil
    return
  end
  assert(opts ~= nil, "missing opts")
  assert(opts.is_active ~= nil, "missing opts.is_active")
  assert(opts.on_timeout ~= nil, "missing opts.on_timeout")
  assert(opts.get_ref ~= nil, "missing opts.get_ref")
  if not opts.is_active(state) then
    state.ui_modal_elapsed = 0
    state.ui_modal_ref = nil
    return
  end
  local ref = assert(opts.get_ref(state), "missing modal ref")
  if state.ui_modal_ref ~= ref then
    state.ui_modal_ref = ref
    state.ui_modal_elapsed = 0
  end
  state.ui_modal_elapsed = state.ui_modal_elapsed + (dt or 0)
  if state.ui_modal_elapsed >= timeout then
    state.ui_modal_elapsed = 0
    opts.on_timeout(state)
  end
end

local function _noop()
end

local default_policy = {
  choice = {
    get_timeout_seconds = function()
      return constants.action_timeout_seconds or 0
    end,
    get_min_visible_seconds = function()
      return gameplay_rules.auto_choice_min_visible_seconds or 0
    end,
    build_action = function(game_ctx, _, choice)
      return _build_default_choice_action(game_ctx, choice)
    end,
  },
  modal = {
    get_timeout_seconds = function(game, state)
      return _modal_timeout_seconds(game, state)
    end,
    on_timeout = function(ctx)
      local ports = _resolve_ports(ctx)
      if ports and ports.close_popup then
        ports.close_popup(ctx)
        return
      end
    end,
  },
}

local function _clone_policy(policy)
  local copied = {}
  for key, value in pairs(policy) do
    if type(value) == "table" then
      local item = {}
      for sub_key, sub_value in pairs(value) do
        item[sub_key] = sub_value
      end
      copied[key] = item
    else
      copied[key] = value
    end
  end
  return copied
end

function tick_timeout.default_policy()
  return _clone_policy(default_policy)
end

function tick_timeout.step_default_choice(game, state, dt)
  local policy = tick_timeout.default_policy()
  tick_timeout.step_choice_timeout(game, state, dt, {
    on_pending_choice = _noop,
    is_choice_active = function(ctx)
      return ctx.pending_choice ~= nil
    end,
    build_action = policy.choice.build_action,
    get_timeout_seconds = policy.choice.get_timeout_seconds,
    get_min_visible_seconds = policy.choice.get_min_visible_seconds,
  })
end

function tick_timeout.step_default_modal(game, state, dt)
  local policy = tick_timeout.default_policy()
  tick_timeout.step_modal_timeout(state, dt, {
    is_active = function(ctx)
      return ctx.ui and ctx.ui.popup_active
    end,
    get_ref = function(ctx)
      assert(ctx.ui ~= nil, "missing ui")
      assert(ctx.ui.popup_active, "popup not active")
      return assert(ctx.ui.popup_seq, "missing popup_seq")
    end,
    get_timeout_seconds = function(state_ctx)
      return policy.modal.get_timeout_seconds(game, state_ctx)
    end,
    on_timeout = policy.modal.on_timeout,
  })
end

return tick_timeout
