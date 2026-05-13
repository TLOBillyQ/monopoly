local choice_route_policy = require("src.ui.input.choice_route")
local choice_contract = require("src.config.choice.contract")
local local_actor_resolver = require("src.ui.coord.local_actor_resolver")
local role_id_utils = require("src.foundation.identity.role_id")
local runtime = require("src.ui.render.runtime_ui")
local runtime_ports = require("src.foundation.ports.runtime_ports")

local choice_ui_state = {}

local _input_blocked_phases = {
  wait_action_anim = true,
  wait_move_anim = true,
  wait_landing_visual = true,
  detained_wait = true,
  inter_turn_wait = true,
}

function choice_ui_state.is_input_blocked_phase(phase)
  return _input_blocked_phases[phase] == true
end

local function _resolve_choice_owner_role_id(game, choice)
  local owner_role_id = choice_contract.resolve_owner_or_meta_role_id(choice)
  if owner_role_id ~= nil then
    return owner_role_id
  end
  local current_index = game and game.turn and game.turn.current_player_index or nil
  local player = current_index and game and game.players and game.players[current_index] or nil
  return role_id_utils.normalize(player and player.id or nil)
end

local function _find_player(game, role_id)
  if game == nil or role_id == nil then
    return nil
  end
  if type(game.find_player_by_id) == "function" then
    return game:find_player_by_id(role_id)
  end
  for _, player in ipairs(game.players or {}) do
    if role_id_utils.equals(player and player.id or nil, role_id) then
      return player
    end
  end
  return nil
end

local function _is_input_blocked_phase(game)
  local phase = game and game.turn and game.turn.phase or nil
  return choice_ui_state.is_input_blocked_phase(phase)
end

local function _is_local_role(state, owner_role_id)
  if owner_role_id == nil then
    return false
  end

  local local_role_id = role_id_utils.normalize(local_actor_resolver.resolve_local(state))
  if local_role_id ~= nil then
    return role_id_utils.equals(local_role_id, owner_role_id)
  end

  local roles = runtime_ports.resolve_roles()
  if type(roles) == "table" and #roles == 1 then
    local role_id = role_id_utils.normalize(runtime.resolve_role_id(roles[1]))
    if role_id ~= nil then
      return role_id_utils.equals(role_id, owner_role_id)
    end
  end

  return false
end

choice_ui_state.resolve_route_key = choice_route_policy.resolve

local _cached_gate_state = {}

function choice_ui_state.resolve_gate_state(game, state, choice)
  local route_key = choice_ui_state.resolve_route_key(choice)
  local ui = state and state.ui or nil
  local owner_role_id = _resolve_choice_owner_role_id(game, choice)
  local owner_player = _find_player(game, owner_role_id)
  local local_owner = _is_local_role(state, owner_role_id)
  local owner_auto = owner_player and (owner_player.is_ai == true or owner_player.auto == true) or false
  local expects_ui = route_key ~= "base_inline" and not _is_input_blocked_phase(game) and local_owner and not owner_auto
  local open

  if route_key == "base_inline" or route_key == "item_phase_passive" then
    open = true
  elseif route_key == "market" then
    open = ui and ui.market_active == true or false
  else
    open = ui and ui.choice_active == true and ui.active_choice_screen_key == route_key or false
  end

  _cached_gate_state.route_key = route_key
  _cached_gate_state.owner_role_id = owner_role_id
  _cached_gate_state.local_owner = local_owner
  _cached_gate_state.owner_auto = owner_auto
  _cached_gate_state.expects_ui = expects_ui
  _cached_gate_state.open = open
  _cached_gate_state.should_warn = expects_ui and not open
  return _cached_gate_state
end

function choice_ui_state.should_reconcile(game, state, choice)
  local gate = choice_ui_state.resolve_gate_state(game, state, choice)
  return gate.expects_ui and not gate.open
end

return choice_ui_state
