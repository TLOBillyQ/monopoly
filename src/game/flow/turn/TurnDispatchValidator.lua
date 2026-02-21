local logger = require("src.core.Logger")
local item_slot_data = require("src.game.flow.turn.ItemSlotData")

local validator = {}

local input_blocked_types = {
  ui_button = true,
  choice_pick = true,
  choice_select = true,
  choice_cancel = true,
  market_confirm = true,
  market_select = true,
  popup_confirm = true,
}

local function _normalize_action_type(action_or_type)
  if type(action_or_type) == "table" then
    return action_or_type.type
  end
  return action_or_type
end

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
  if not (choice and choice.meta and choice.meta.player_id) then
    local current = game:current_player()
    return current and current.id or nil
  end
  local owner = game:find_player_by_id(choice.meta.player_id)
  if owner then
    return owner.id
  end
  local current = game:current_player()
  return current and current.id or nil
end

local function _resolve_input_blocked(ui_state_or_flag)
  if type(ui_state_or_flag) == "boolean" then
    return ui_state_or_flag
  end
  return ui_state_or_flag and ui_state_or_flag.input_blocked == true or false
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

function validator.should_block_action(ui_state_or_flag, action_or_type)
  if not _resolve_input_blocked(ui_state_or_flag) then
    return false
  end
  local action_type = _normalize_action_type(action_or_type)
  if not action_type then
    return false
  end
  if action_type == "popup_confirm" then
    return false
  end
  if action_type == "ui_button"
      and type(action_or_type) == "table"
      and action_or_type.id == "auto" then
    return false
  end
  return input_blocked_types[action_type] == true
end

function validator.validate_actor_role(game, action)
  if not _is_turn_bound_ui_button(action and action.id) then
    return true
  end
  assert(game ~= nil and game.turn ~= nil, "missing game.turn")
  local current_index = game.turn.current_player_index
  local current_player = current_index and game.players and game.players[current_index] or nil
  local current_id = current_player and current_player.id or nil
  local actor_role_id = action.actor_role_id
  if actor_role_id == nil then
    logger.warn("ui_button missing actor_role_id:", tostring(action.id))
    return false
  end
  if current_id == nil then
    logger.warn("ui_button missing current player id:", tostring(action.id))
    return false
  end
  if actor_role_id ~= current_id then
    logger.warn(
      "ui_button blocked by actor check:",
      tostring(action.id),
      "actor=" .. tostring(actor_role_id),
      "current=" .. tostring(current_id)
    )
    return false
  end
  return true
end

function validator.validate_choice_actor(game, action, choice)
  local actor_role_id = action and action.actor_role_id or nil
  if actor_role_id == nil then
    logger.warn("choice action missing actor_role_id:", tostring(action and action.type))
    return false
  end
  local expected = _resolve_choice_owner_role_id(game, choice)
  if expected ~= nil and actor_role_id ~= expected then
    logger.warn(
      "choice action blocked by actor check:",
      tostring(action and action.type),
      "actor=" .. tostring(actor_role_id),
      "expected=" .. tostring(expected)
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
    },
  }
end

return validator
