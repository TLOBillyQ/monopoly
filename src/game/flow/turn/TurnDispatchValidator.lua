local logger = require("src.core.Logger")
local number_utils = require("src.core.NumberUtils")
local item_slot_data = require("src.game.flow.turn.ItemSlotData")
local turn_action_gate = require("src.game.flow.turn.TurnActionGate")
local role_id_utils = require("src.core.RoleId")

local validator = {}

local function _is_turn_bound_ui_button(action_id)
  if action_id == "next" then
    return true
  end
  if action_id and string.match(action_id, "^item_slot_(%d+)$") then
    return true
  end
  return false
end

local function _resolve_choice_owner_role_id(game, choice)
  local owner_role_id = choice and number_utils.to_integer(choice.owner_role_id) or nil
  if owner_role_id ~= nil then
    return owner_role_id
  end
  local meta = choice and choice.meta or nil
  owner_role_id = meta and number_utils.to_integer(meta.player_id) or nil
  if owner_role_id ~= nil then
    return owner_role_id
  end
  local current = game and game.current_player and game:current_player() or nil
  return current and number_utils.to_integer(current.id) or nil
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

function validator.resolve_gate_state(state, ui_sync_ports)
  local gate = nil
  if ui_sync_ports and type(ui_sync_ports.resolve_ui_gate) == "function" then
    gate = ui_sync_ports.resolve_ui_gate(state)
  end
  gate = turn_action_gate.resolve_gate_state(gate)

  local game = type(state) == "table" and state.game or nil
  local turn = game and game.turn or nil
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

function validator.resolve_item_slot_action(item_slot_source, state, action)
  if not (action and action.id and string.match(action.id, "^item_slot_(%d+)$")) then
    return nil
  end
  local choice = state.pending_choice
  if not choice or choice.kind ~= "item_phase_choice" then
    return { ok = false }
  end
  local source = _resolve_item_slot_source(item_slot_source)
  local item_id = _resolve_item_slot_id(source, action.actor_role_id, action.id)
  if not item_id then
    logger.warn("missing item_id:", tostring(action.id))
    return { ok = false }
  end
  local options = assert(choice.options, "missing choice options")
  local option_ok = false
  for _, opt in ipairs(options) do
    local opt_id = opt.id or opt
    if opt_id == item_id then
      option_ok = true
      break
    end
  end
  if not option_ok then
    logger.warn("invalid item option:", tostring(item_id))
    return { ok = false }
  end
  return {
    ok = true,
    action = {
      type = "choice_select",
      choice_id = choice.id,
      option_id = item_id,
      actor_role_id = action.actor_role_id,
      input_source = action.input_source,
    },
  }
end

return validator
