local choice_route_policy = require("src.ui.input.choice_route_policy")
local choice_contract = require("src.core.choice.contract")
local local_actor_resolver = require("src.ui.ctl.local_actor_resolver")
local role_id_utils = require("src.core.utils.role_id")
local runtime = require("src.ui.render.runtime_ui")
local runtime_ports = require("src.core.ports.runtime_ports")
local runtime_state = require("src.ui.runtime.state")

local choice_ui_state = {}

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

local function _is_waiting_anim_phase(game)
  local phase = game and game.turn and game.turn.phase or nil
  return phase == "wait_action_anim" or phase == "wait_move_anim"
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
  if type(roles) == "table" and #roles > 0 then
    for _, role in ipairs(roles) do
      local role_id = role_id_utils.normalize(runtime.resolve_role_id(role))
      if role_id_utils.equals(role_id, owner_role_id) then
        return true
      end
    end
  end

  local current_model = runtime_state.get_ui_model(state)
  local current_player_id = role_id_utils.normalize(current_model and current_model.current_player_id or nil)
  return current_player_id ~= nil and role_id_utils.equals(current_player_id, owner_role_id)
end

function choice_ui_state.resolve_route_key(choice)
  return choice_route_policy.resolve(choice)
end

function choice_ui_state.resolve_gate_state(game, state, choice)
  local route_key = choice_ui_state.resolve_route_key(choice)
  local ui = state and state.ui or nil
  local owner_role_id = _resolve_choice_owner_role_id(game, choice)
  local owner_player = _find_player(game, owner_role_id)
  local local_owner = _is_local_role(state, owner_role_id)
  local owner_auto = owner_player and (owner_player.is_ai == true or owner_player.auto == true) or false
  local expects_ui = route_key ~= "base_inline" and not _is_waiting_anim_phase(game) and local_owner and not owner_auto
  local open = false

  if route_key == "base_inline" then
    open = true
  elseif route_key == "market" then
    open = ui and ui.market_active == true or false
  else
    open = ui and ui.choice_active == true and ui.active_choice_screen_key == route_key or false
  end

  return {
    route_key = route_key,
    owner_role_id = owner_role_id,
    local_owner = local_owner,
    owner_auto = owner_auto,
    expects_ui = expects_ui,
    open = open,
    should_warn = expects_ui and not open,
  }
end

function choice_ui_state.should_reconcile(game, state, choice)
  local gate = choice_ui_state.resolve_gate_state(game, state, choice)
  return gate.expects_ui and not gate.open
end

return choice_ui_state
