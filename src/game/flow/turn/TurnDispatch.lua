local logger = require("src.core.Logger")
local validator = require("src.game.flow.turn.TurnDispatchValidator")
local gameplay_loop_ports = require("src.game.flow.turn.GameplayLoopPorts")

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

local function _resolve_actor_player(game, action)
  assert(game ~= nil and game.players ~= nil, "missing game.players")
  local actor_role_id = action and action.actor_role_id or nil
  if actor_role_id == nil then
    logger.warn("ui_button missing actor_role_id:", tostring(action and action.id))
    return nil
  end
  local player = game:find_player_by_id(actor_role_id)
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
  local ports = gameplay_loop_ports.resolve(state and state.gameplay_loop_ports or nil)
  local ui_state = ports.get_ui_state and ports.get_ui_state(state) or nil
  return validator.should_block_action(ui_state, action_or_type)
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

    if not validator.validate_actor_role(game, action) then
      return { status = "rejected" }
    end
    local ports = gameplay_loop_ports.resolve(state and state.gameplay_loop_ports or nil)
    local ui_state = ports.get_ui_state and ports.get_ui_state(state) or nil
    local slot_result = validator.resolve_item_slot_action(ui_state, state, action)
    if slot_result ~= nil then
      if not slot_result.ok then
        return { status = "rejected" }
      end
      return turn_dispatch.dispatch_action(game, state, slot_result.action, opts)
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
    if not validator.validate_choice_action(game, action, choice) then
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
