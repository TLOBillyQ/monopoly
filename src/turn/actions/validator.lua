local logger = require("src.core.utils.logger")
local number_utils = require("src.core.utils.number_utils")
local item_slot_data = require("src.turn.actions.item_slot_data")
local turn_action_gate = require("src.turn.policies.action_gate")
local role_id_utils = require("src.core.utils.role_id")
local choice_contract = require("src.core.choice.contract")
local runtime_state = require("src.state.runtime_state")
local availability = require("src.rules.items.availability")

local validator = {}

local function _is_turn_bound_ui_button(action_id)
  return action_id == "next" or action_id and string.match(action_id, "^item_slot_(%d+)$") ~= nil
end

local function _resolve_current_player_role_id(game)
  local current = game and game.current_player and game:current_player() or nil
  return current and number_utils.to_integer(current.id) or nil
end

local function _resolve_choice_owner_role_id(game, choice)
  local owner_role_id = choice_contract.resolve_owner_role_id(choice)
  if owner_role_id ~= nil then
    return owner_role_id
  end
  return _resolve_current_player_role_id(game)
end

local function _resolve_item_slot_source(item_slot_source)
  if type(item_slot_source) == "table" and type(item_slot_source.resolve_slot_action) == "function" then
    return item_slot_source
  end
  return item_slot_data.from_ui_state(item_slot_source)
end

local function _resolve_item_slot_id(source, actor_role_id, slot_id)
  if not source or type(source.resolve_slot_action) ~= "function" then
    return nil
  end
  return source.resolve_slot_action(actor_role_id, slot_id)
end

local function _resolve_runtime_game(state, game)
  return game or (state and state.game)
end

local function _resolve_pending_item_phase_choice(state, runtime_game)
  local choice = runtime_state.get_pending_choice(state)
  if (not choice) and runtime_game and runtime_game.turn then
    choice = runtime_game.turn.pending_choice
  end
  if not choice or (choice.kind ~= "item_phase_choice" and choice.kind ~= "item_phase_passive") then
    return nil
  end
  return choice
end

local function _resolve_item_phase_choice(state, runtime_game)
  return _resolve_pending_item_phase_choice(state, runtime_game)
end

local function _choice_has_item_option(choice, item_id)
  local options = assert(choice.options, "missing choice options")
  for _, option in ipairs(options) do
    if (option.id or option) == item_id then
      return true
    end
  end
  return false
end

local function _validate_item_phase_option(choice, item_id)
  if _choice_has_item_option(choice, item_id) then
    return true
  end
  logger.warn("invalid item option:", tostring(item_id))
  return false
end

local function _resolve_item_phase_actor(runtime_game, actor_role_id)
  if not runtime_game or type(runtime_game.find_player_by_id) ~= "function" then
    return nil
  end
  return runtime_game:find_player_by_id(actor_role_id)
end

local function _validate_item_phase_availability(runtime_game, choice, actor_role_id, item_id)
  local actor = _resolve_item_phase_actor(runtime_game, actor_role_id)
  local phase = choice and choice.meta and choice.meta.phase or nil
  if not actor or type(phase) ~= "string" or phase == "" then
    return true
  end
  local can_offer = availability.can_offer_in_phase(runtime_game, actor, item_id, phase)
  if can_offer then
    return true
  end
  logger.warn("item slot denied by availability:", tostring(item_id), tostring(phase))
  return false
end

local function _resolve_selected_item_id(item_slot_source, action)
  local source = _resolve_item_slot_source(item_slot_source)
  local item_id = _resolve_item_slot_id(source, action.actor_role_id, action.id)
  if item_id then
    return item_id
  end
  logger.warn("missing item_id:", tostring(action.id))
  return nil
end

local function _validate_item_slot_action(runtime_game, choice, action, item_id)
  if not _validate_item_phase_option(choice, item_id) then
    return false
  end
  if not _validate_item_phase_availability(runtime_game, choice, action.actor_role_id, item_id) then
    return false
  end
  return true
end

local function _build_choice_select_action(choice, action, item_id)
  return {
    type = "choice_select",
    choice_id = choice.id,
    option_id = item_id,
    actor_role_id = action.actor_role_id,
    input_source = action.input_source,
  }
end

local function _resolve_item_slot_resolution(item_slot_source, state, action, game)
  if not (action and action.id and string.match(action.id, "^item_slot_(%d+)$")) then
    return {
      ok = false,
      reason = "invalid_action",
    }
  end

  local runtime_game = _resolve_runtime_game(state, game)
  local choice = _resolve_item_phase_choice(state, runtime_game)
  if not choice then
    return {
      ok = false,
      reason = "missing_choice",
    }
  end

  local item_id = _resolve_selected_item_id(item_slot_source, action)
  if not item_id then
    return {
      ok = false,
      reason = "missing_item_id",
    }
  end

  if not _validate_item_phase_option(choice, item_id) then
    return {
      ok = false,
      reason = "invalid_item_option",
    }
  end

  if not _validate_item_phase_availability(runtime_game, choice, action.actor_role_id, item_id) then
    return {
      ok = false,
      reason = "item_slot_denied_by_availability",
    }
  end

  return {
    ok = true,
    action = _build_choice_select_action(choice, action, item_id),
  }
end

function validator.resolve_gate_state(state, ui_sync_ports)
  local gate = turn_action_gate.resolve_gate_state(
    ui_sync_ports and type(ui_sync_ports.resolve_ui_gate) == "function" and ui_sync_ports.resolve_ui_gate(state) or nil
  )
  local turn = type(state) == "table" and state.game and state.game.turn or nil
  return {
    input_blocked = gate.input_blocked == true,
    choice_active = gate.choice_active == true,
    market_active = gate.market_active == true,
    popup_active = gate.popup_active == true,
    phase = turn and turn.phase or nil,
    detained_wait_active = turn and turn.detained_wait_active == true or false,
  }
end

function validator.should_block_action(gate_state_or_flag, action_or_type)
  return turn_action_gate.should_block_action(gate_state_or_flag, action_or_type)
end

function validator.validate_actor_role(game, action)
  if not _is_turn_bound_ui_button(action and action.id) then
    return true
  end
  assert(game ~= nil and game.turn ~= nil, "missing game.turn")
  local current_index = game.turn.current_player_index
  local current_player = current_index and game.players and game.players[current_index] or nil
  local current_role_id = role_id_utils.normalize(current_player and current_player.id or nil)
  local actor_role_id = role_id_utils.normalize(action.actor_role_id)
  if actor_role_id == nil then
    logger.warn("ui_button missing actor_role_id:", tostring(action.id))
    return false
  end
  if current_role_id == nil then
    logger.warn("ui_button missing current_role_id:", tostring(action.id))
    return false
  end
  if not role_id_utils.equals(actor_role_id, current_role_id) then
    logger.warn(
      "ui_button blocked by actor check:",
      tostring(action.id),
      "actor_role_id=" .. tostring(actor_role_id),
      "current_role_id=" .. tostring(current_role_id)
    )
    return false
  end
  return true
end

function validator.validate_choice_actor(game, action, choice)
  local actor_role_id = role_id_utils.normalize(action and action.actor_role_id or nil)
  if actor_role_id == nil then
    logger.warn("choice action missing actor_role_id:", tostring(action and action.type))
    return false
  end
  local owner_role_id = _resolve_choice_owner_role_id(game, choice)
  if owner_role_id ~= nil and not role_id_utils.equals(actor_role_id, owner_role_id) then
    logger.warn(
      "choice action blocked by actor check:",
      tostring(action and action.type),
      "actor_role_id=" .. tostring(actor_role_id),
      "owner_role_id=" .. tostring(owner_role_id)
    )
    return false
  end
  return true
end

function validator.validate_choice_id(action, choice)
  if not action or not choice then
    return false
  end
  if not action.choice_id or action.choice_id ~= choice.id then
    logger.warn(
      "choice action mismatch:",
      tostring(action.type),
      "action_choice_id=" .. tostring(action.choice_id),
      "pending_choice_id=" .. tostring(choice.id)
    )
    return false
  end
  return true
end

function validator.validate_choice_action(game, action, choice)
  if not choice or not choice.id then
    logger.warn("choice action without pending choice:", tostring(action and action.type))
    return false
  end
  if not validator.validate_choice_actor(game, action, choice) then
    return false
  end
  return validator.validate_choice_id(action, choice)
end

function validator.resolve_item_slot_action(item_slot_source, state, action, game)
  local result = _resolve_item_slot_resolution(item_slot_source, state, action, game)
  if result.reason == "invalid_action" then
    return nil
  end
  if not result.ok then
    return { ok = false }
  end
  return result
end

validator._resolve_item_slot_resolution = _resolve_item_slot_resolution
validator._validate_item_slot_action = _validate_item_slot_action

return validator
