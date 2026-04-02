local runtime_state = {}

local function _ensure_table(root, key)
  local value = root[key]
  if type(value) ~= "table" then
    value = {}
    root[key] = value
  end
  return value
end

local function _ensure_field(tbl, key, fallback)
  if tbl[key] == nil then
    tbl[key] = fallback
  end
  return tbl[key]
end

local function _ensure_landing_visual_hold(turn_runtime)
  local hold = turn_runtime.landing_visual_hold
  if type(hold) ~= "table" then
    hold = {
      active = false,
      release_pending = false,
      flushing = false,
      frozen_ui_model = nil,
      source = nil,
      deferred_dirty = {
        any = false,
        players = false,
        board_tiles = false,
        turn = false,
        market = false,
        turn_countdown = false,
        inventory_ids = {},
      },
      release_callbacks = {},
    }
    turn_runtime.landing_visual_hold = hold
  end
  return hold
end

function runtime_state.ensure_ui_runtime(state)
  assert(type(state) == "table", "missing state")
  local ui_runtime = _ensure_table(state, "ui_runtime")
  _ensure_field(ui_runtime, "ui_dirty", false)
  _ensure_field(ui_runtime, "ui_model", nil)
  _ensure_field(ui_runtime, "pending_choice", nil)
  _ensure_field(ui_runtime, "pending_choice_elapsed", 0)
  _ensure_field(ui_runtime, "pending_choice_id", nil)
  _ensure_field(ui_runtime, "ui_modal_elapsed", 0)
  _ensure_field(ui_runtime, "ui_modal_ref", nil)
  if ui_runtime.item_name_by_id == nil then
    ui_runtime.item_name_by_id = state.item_name_by_id or {}
  end
  return ui_runtime
end

function runtime_state.is_ui_dirty(state)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  return ui_runtime.ui_dirty == true
end

function runtime_state.set_ui_dirty(state, dirty)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  ui_runtime.ui_dirty = dirty == true
  return ui_runtime.ui_dirty
end

function runtime_state.get_ui_model(state)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  return ui_runtime.ui_model
end

function runtime_state.set_ui_model(state, model)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  ui_runtime.ui_model = model
  return model
end

function runtime_state.get_local_actor_role_id(state)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  return ui_runtime.local_actor_role_id
end

function runtime_state.set_local_actor_role_id(state, role_id)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  ui_runtime.local_actor_role_id = role_id
  return role_id
end

function runtime_state.get_pending_choice(state)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  return ui_runtime.pending_choice
end

function runtime_state.get_pending_choice_id(state)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  return ui_runtime.pending_choice_id
end

function runtime_state.set_pending_choice_id(state, choice_id)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  ui_runtime.pending_choice_id = choice_id
  return choice_id
end

function runtime_state.get_pending_choice_elapsed(state)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  return ui_runtime.pending_choice_elapsed or 0
end

function runtime_state.set_pending_choice_elapsed(state, elapsed_seconds)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  local next_elapsed = elapsed_seconds or 0
  ui_runtime.pending_choice_elapsed = next_elapsed
  return next_elapsed
end

function runtime_state.set_pending_choice(state, choice, opts)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  opts = opts or {}
  local choice_id = opts.choice_id
  if choice_id == nil and choice ~= nil then
    choice_id = choice.id
  end
  local elapsed_seconds = opts.elapsed_seconds
  if elapsed_seconds == nil then
    elapsed_seconds = 0
  end
  ui_runtime.pending_choice = choice
  ui_runtime.pending_choice_id = choice_id
  ui_runtime.pending_choice_elapsed = elapsed_seconds
  return choice
end

function runtime_state.get_modal_elapsed(state)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  return ui_runtime.ui_modal_elapsed or 0
end

function runtime_state.get_modal_ref(state)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  return ui_runtime.ui_modal_ref
end

function runtime_state.set_modal_timer(state, payload)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  payload = payload or {}
  local elapsed_seconds = payload.elapsed_seconds or 0
  local ref = payload.ref
  ui_runtime.ui_modal_elapsed = elapsed_seconds
  ui_runtime.ui_modal_ref = ref
  return ref, elapsed_seconds
end

function runtime_state.ensure_board_runtime(state)
  assert(type(state) == "table", "missing state")
  local board_runtime = _ensure_table(state, "board_runtime")
  if board_runtime.board_last_positions == nil then
    board_runtime.board_last_positions = state.board_last_positions or {}
  end
  if board_runtime.follow_target_by_player_id == nil then
    board_runtime.follow_target_by_player_id = {}
  end
  if board_runtime.follow_target_source_by_player_id == nil then
    board_runtime.follow_target_source_by_player_id = {}
  end
  if board_runtime.follow_target_seq_by_player_id == nil then
    board_runtime.follow_target_seq_by_player_id = {}
  end
  _ensure_field(board_runtime, "board_sync_pending", state.board_sync_pending == true)
  _ensure_field(board_runtime, "board_last_phase", state.board_last_phase)
  _ensure_field(board_runtime, "board_last_vehicle_resync_seq", state.board_last_vehicle_resync_seq)
  return board_runtime
end

function runtime_state.set_follow_target_position(state, player_id, position, opts)
  if state == nil or player_id == nil or position == nil then
    return false
  end
  local board_runtime = runtime_state.ensure_board_runtime(state)
  opts = opts or {}
  local next_seq = opts.seq
  local last_seq = board_runtime.follow_target_seq_by_player_id[player_id]
  if next_seq ~= nil and last_seq ~= nil and next_seq < last_seq then
    return false
  end
  board_runtime.follow_target_by_player_id[player_id] = position
  board_runtime.follow_target_source_by_player_id[player_id] = opts.source
  if next_seq ~= nil then
    board_runtime.follow_target_seq_by_player_id[player_id] = next_seq
  end
  return true
end

function runtime_state.get_follow_target_position(state, player_id)
  if state == nil or player_id == nil then
    return nil
  end
  local board_runtime = runtime_state.ensure_board_runtime(state)
  return board_runtime.follow_target_by_player_id[player_id]
end

function runtime_state.ensure_anim_runtime(state)
  assert(type(state) == "table", "missing state")
  local anim_runtime = _ensure_table(state, "anim_runtime")
  _ensure_field(anim_runtime, "move_anim_seq", state.move_anim_seq)
  _ensure_field(anim_runtime, "action_anim_seq", state.action_anim_seq)
  return anim_runtime
end

function runtime_state.ensure_turn_runtime(state)
  assert(type(state) == "table", "missing state")
  local turn_runtime = _ensure_table(state, "turn_runtime")
  _ensure_field(turn_runtime, "next_turn_locked", state.next_turn_locked == true)
  _ensure_field(turn_runtime, "next_turn_last_click", state.next_turn_last_click)
  _ensure_field(turn_runtime, "next_turn_lock_phase", state.next_turn_lock_phase)
  _ensure_field(turn_runtime, "role_control_lock_active", state.role_control_lock_active == true)
  _ensure_field(turn_runtime, "role_control_lock_suppress", state.role_control_lock_suppress or 0)
  _ensure_field(turn_runtime, "landing_visual_release_pulse", false)
  _ensure_field(turn_runtime, "last_follow_player_id", nil)
  _ensure_landing_visual_hold(turn_runtime)
  return turn_runtime
end

function runtime_state.get_landing_visual_hold(state)
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  return _ensure_landing_visual_hold(turn_runtime)
end

function runtime_state.get_landing_visual_hold_active(state)
  local hold = runtime_state.get_landing_visual_hold(state)
  return hold.active == true
end

function runtime_state.set_landing_visual_hold_active(state, active)
  local hold = runtime_state.get_landing_visual_hold(state)
  hold.active = active == true
  return hold.active
end

function runtime_state.get_landing_visual_release_pending(state)
  local hold = runtime_state.get_landing_visual_hold(state)
  return hold.release_pending == true
end

function runtime_state.set_landing_visual_release_pending(state, release_pending)
  local hold = runtime_state.get_landing_visual_hold(state)
  hold.release_pending = release_pending == true
  return hold.release_pending
end

function runtime_state.get_landing_visual_hold_source(state)
  local hold = runtime_state.get_landing_visual_hold(state)
  return hold.source
end

function runtime_state.set_landing_visual_hold_source(state, source)
  local hold = runtime_state.get_landing_visual_hold(state)
  hold.source = source
  return source
end

function runtime_state.mark_landing_visual_release_pulse(state)
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  turn_runtime.landing_visual_release_pulse = true
  return true
end

function runtime_state.take_landing_visual_release_pulse(state)
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  local active = turn_runtime.landing_visual_release_pulse == true
  turn_runtime.landing_visual_release_pulse = false
  return active
end

function runtime_state.ensure_debug_runtime(state)
  assert(type(state) == "table", "missing state")
  local debug_runtime = _ensure_table(state, "debug_runtime")
  if debug_runtime.log_once == nil then
    debug_runtime.log_once = state._log_once or {}
  end
  return debug_runtime
end

function runtime_state.ensure_all(state)
  runtime_state.ensure_ui_runtime(state)
  runtime_state.ensure_board_runtime(state)
  runtime_state.ensure_anim_runtime(state)
  runtime_state.ensure_turn_runtime(state)
  runtime_state.ensure_debug_runtime(state)
  return state
end

return runtime_state
