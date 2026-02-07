local number_utils = require("src.core.NumberUtils")
local logger = require("src.core.Logger")
local store_paths = require("src.core.StorePaths")

local turn_dispatch = {}

local next_turn_cooldown = 0.4
local input_blocked_types = {
  ui_button = true,
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
    local slot_index = action.id and string.match(action.id, "^item_slot_(%d+)$")
    if slot_index then
      slot_index = number_utils.to_integer(slot_index)
      local choice = state.pending_choice
      if not choice or choice.kind ~= "item_phase_choice" then
        return { status = "rejected" }
      end
      assert(state.ui ~= nil, "missing state.ui")
      assert(state.ui.item_slot_item_ids ~= nil, "missing item_slot_item_ids")
      local item_id = assert(state.ui.item_slot_item_ids[slot_index], "missing item_id: " .. tostring(slot_index))
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
      local phase = nil
      assert(game ~= nil and game.store ~= nil, "missing game.store")
      assert(game.store.get ~= nil, "missing store.Get")
      phase = game.store:get(store_paths.turn.phase)
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
    elseif action.id == "auto" then
      state.ui.auto_play = not state.ui.auto_play
      state.auto_runner:set_enabled(state.ui.auto_play)
      state.auto_runner:reset_timer()
      return { status = "applied" }
    elseif action.id == "restart" then
      assert(opts ~= nil and opts.on_restart ~= nil, "missing opts.on_restart")
      opts.on_restart(game, state, action, opts)
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
    local pending = game and game.store and game.store.get and game.store:get(store_paths.turn.pending_choice) or nil
    if not pending or not pending.id or pending.id ~= choice.id then
      turn_dispatch.clear_choice(state, opts)
    end
    return { status = "applied" }
  end
  return { status = "rejected" }
end

return turn_dispatch
