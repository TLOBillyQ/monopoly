local ui_view = require("src.ui.UIView")

local turn_dispatch = {}

local next_turn_cooldown = 0.4

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
  assert(opts ~= nil and opts.on_close_choice ~= nil, "missing opts.on_close_choice")
  opts.on_close_choice(state)
end

function turn_dispatch.dispatch_action(game, state, action, opts)
  assert(action ~= nil, "missing action")
  if state.ui and state.ui.input_blocked then
    if action.type == "ui_button"
        or action.type == "choice_select"
        or action.type == "choice_cancel" then
      return
    end
  end
  if action.type == "ui_button"
      or action.type == "choice_select"
      or action.type == "choice_cancel" then
    state.ui_dirty = true
  end
  if action.type == "ui_button" then
    local slot_index = action.id and string.match(action.id, "^item_slot_(%d+)$")
    if slot_index then
      slot_index = tonumber(slot_index)
      local choice = state.pending_choice
      assert(choice ~= nil and choice.kind == "item_phase_choice", "invalid item phase choice")
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
      assert(option_ok, "invalid item option: " .. tostring(item_id))
      turn_dispatch.dispatch_action(game, state, {
        type = "choice_select",
        choice_id = choice.id,
        option_id = item_id,
      }, opts)
      return
    end
    if action.id == "next" then
      local phase = nil
      assert(game ~= nil and game.store ~= nil, "missing game.store")
      assert(game.store.get ~= nil, "missing store.Get")
      phase = game.store:get({ "turn", "phase" })
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
          return
        end
      end
      state.next_turn_locked = true
      state.next_turn_last_click = now
      state.next_turn_lock_phase = phase
      turn_dispatch.step_turn(game)
    elseif action.id == "auto" then
      state.ui.auto_play = not state.ui.auto_play
      state.auto_runner:set_enabled(state.ui.auto_play)
      state.auto_runner:reset_timer()
    elseif action.id == "restart" then
      assert(opts ~= nil and opts.on_restart ~= nil, "missing opts.on_restart")
      opts.on_restart(game, state, action, opts)
    end
  elseif action.type == "choice_select" or action.type == "choice_cancel" then
    turn_dispatch.clear_choice(state, {
      on_close_choice = function(ctx)
        ui_view.close_choice_modal(ctx)
      end,
    })
    if game then
      assert(game.dispatch_action ~= nil, "missing game.dispatch_action")
      game:dispatch_action(action)
    end
  end
end

return turn_dispatch
