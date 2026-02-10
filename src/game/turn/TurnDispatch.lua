local number_utils = require("src.core.NumberUtils")
local logger = require("src.core.Logger")

local turn_dispatch = {}

local next_turn_cooldown = 0.4
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

local function _get_timestamp()
  assert(GameAPI ~= nil and GameAPI.get_timestamp ~= nil, "missing GameAPI.get_timestamp")
  local ts = GameAPI.get_timestamp()
  assert(type(ts) == "number", "invalid timestamp")
  return ts
end

local function _get_timestamp_diff_seconds(timestamp_1, timestamp_2)
  assert(GameAPI ~= nil and GameAPI.get_timestamp_diff ~= nil, "missing GameAPI.get_timestamp_diff")
  assert(type(timestamp_1) == "number" and type(timestamp_2) == "number", "invalid timestamps")
  return GameAPI.get_timestamp_diff(timestamp_1, timestamp_2)
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

local function _validate_actor_role(game, action)
  if not _is_turn_bound_ui_button(action and action.id) then
    return true
  end
  assert(game ~= nil and game.turn ~= nil, "missing game.turn")
  local current_index = game.turn.current_player_index
  local actor_role_id = action.actor_role_id
  if actor_role_id == nil then
    logger.warn("ui_button missing actor_role_id:", tostring(action.id))
    return false
  end
  if actor_role_id ~= current_index then
    logger.warn(
      "ui_button blocked by actor check:",
      tostring(action.id),
      "actor=" .. tostring(actor_role_id),
      "current=" .. tostring(current_index)
    )
    return false
  end
  return true
end

local function _resolve_actor_player(game, action)
  assert(game ~= nil and game.players ~= nil, "missing game.players")
  local actor_role_id = action and action.actor_role_id or nil
  if actor_role_id == nil then
    logger.warn("ui_button missing actor_role_id:", tostring(action and action.id))
    return nil
  end
  local player = game.players[actor_role_id]
  if not player then
    logger.warn("ui_button actor_role_id not mapped:", tostring(action and action.id), tostring(actor_role_id))
    return nil
  end
  return player
end

function turn_dispatch.step_turn(game)
  assert(game ~= nil, "missing game")
  assert(not game.finished, "game finished")
  game:advance_turn()
end

function turn_dispatch.clear_choice(state, opts)
  state.pending_choice = nil
  state.pending_choice_elapsed = 0
  state.pending_choice_id = nil
  if opts and opts.on_close_choice then
    opts.on_close_choice(state)
  end
end

function turn_dispatch.should_block_action(state, action_or_type)
  if not (state and state.ui and state.ui.input_blocked) then
    return false
  end
  local action_type = _normalize_action_type(action_or_type)
  if not action_type then
    return false
  end
  if action_type == "ui_button"
      and type(action_or_type) == "table"
      and action_or_type.id == "auto" then
    return false
  end
  return input_blocked_types[action_type] == true
end

function turn_dispatch.dispatch_action(game, state, action, opts)
  assert(action ~= nil, "missing action")
  if turn_dispatch.should_block_action(state, action) then
    return { status = "blocked" }
  end
  if action.type == "ui_button"
      or action.type == "choice_select"
      or action.type == "choice_cancel" then
    state.ui_dirty = true
  end
  if action.type == "ui_button" then
    if action.id == "auto" then
      local player = _resolve_actor_player(game, action)
      if not player then
        return { status = "rejected" }
      end
      player.auto = not (player.auto == true)
      return { status = "applied" }
    end

    if not _validate_actor_role(game, action) then
      return { status = "rejected" }
    end
    local slot_index = action.id and string.match(action.id, "^item_slot_(%d+)$")
    if slot_index then
      slot_index = number_utils.to_integer(slot_index)
      local choice = state.pending_choice
      if not choice or choice.kind ~= "item_phase_choice" then
        return { status = "rejected" }
      end
      assert(state.ui ~= nil, "missing state.ui")
      local item_ids = nil
      if action.actor_role_id and type(state.ui.item_slot_item_ids_by_role) == "table" then
        item_ids = state.ui.item_slot_item_ids_by_role[action.actor_role_id]
      end
      if not item_ids then
        item_ids = state.ui.item_slot_item_ids
      end
      if not item_ids then
        logger.warn("missing item_slot_item_ids for slot:", tostring(slot_index))
        return { status = "rejected" }
      end
      local item_id = item_ids[slot_index]
      if not item_id then
        logger.warn("missing item_id:", tostring(slot_index))
        return { status = "rejected" }
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
        return { status = "rejected" }
      end
      return turn_dispatch.dispatch_action(game, state, {
        type = "choice_select",
        choice_id = choice.id,
        option_id = item_id,
      }, opts)
    end
    if action.id == "next" then
      assert(game ~= nil, "missing game")
      local phase = game.turn.phase
      local now = _get_timestamp()
      if state.next_turn_locked then
        local allow = false
        if state.next_turn_lock_phase and phase and phase ~= state.next_turn_lock_phase then
          allow = true
        else
          assert(state.next_turn_last_click ~= nil, "missing next_turn_last_click")
          local diff = _get_timestamp_diff_seconds(now, state.next_turn_last_click)
          if diff and diff >= next_turn_cooldown then
            allow = true
          end
        end
        if not allow then
          return { status = "rejected" }
        end
      end
      state.next_turn_locked = true
      state.next_turn_last_click = now
      state.next_turn_lock_phase = phase
      turn_dispatch.step_turn(game)
      return { status = "applied" }
    end
    return { status = "rejected" }
  elseif action.type == "choice_select" or action.type == "choice_cancel" then
    local choice = state.pending_choice
    if not choice or not choice.id then
      logger.warn("choice action without pending choice:", tostring(action.type))
      return { status = "rejected" }
    end
    if not action.choice_id or action.choice_id ~= choice.id then
      logger.warn(
        "choice action mismatch:",
        tostring(action.type),
        "action_choice_id=" .. tostring(action.choice_id),
        "pending_choice_id=" .. tostring(choice.id)
      )
      return { status = "rejected" }
    end
    if game then
      assert(game.dispatch_action ~= nil, "missing game.dispatch_action")
      game:dispatch_action(action)
    end
    local pending = game and game.turn and game.turn.pending_choice or nil
    if not pending or not pending.id or pending.id ~= choice.id then
      turn_dispatch.clear_choice(state, opts)
    end
    return { status = "applied" }
  end
  return { status = "rejected" }
end

return turn_dispatch
