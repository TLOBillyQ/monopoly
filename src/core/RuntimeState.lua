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

function runtime_state.ensure_ui_runtime(state)
  assert(type(state) == "table", "missing state")
  local ui_runtime = _ensure_table(state, "ui_runtime")
  if ui_runtime.item_name_by_id == nil then
    ui_runtime.item_name_by_id = state.item_name_by_id or {}
  end
  if ui_runtime.choice_visible_option_ids == nil then
    ui_runtime.choice_visible_option_ids = state.choice_visible_option_ids
  end
  if ui_runtime.pending_choice_selected_option_id == nil then
    ui_runtime.pending_choice_selected_option_id = state.pending_choice_selected_option_id
  end
  return ui_runtime
end

function runtime_state.ensure_board_runtime(state)
  assert(type(state) == "table", "missing state")
  local board_runtime = _ensure_table(state, "board_runtime")
  if board_runtime.board_last_positions == nil then
    board_runtime.board_last_positions = state.board_last_positions or {}
  end
  _ensure_field(board_runtime, "board_sync_pending", state.board_sync_pending == true)
  _ensure_field(board_runtime, "board_last_phase", state.board_last_phase)
  _ensure_field(board_runtime, "board_last_vehicle_resync_seq", state.board_last_vehicle_resync_seq)
  return board_runtime
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
  _ensure_field(turn_runtime, "afk_actor_role_id", nil)
  _ensure_field(turn_runtime, "afk_elapsed_seconds", 0)
  _ensure_field(turn_runtime, "afk_tracking_active", false)
  if type(turn_runtime.afk_elapsed_seconds_by_role) ~= "table" then
    turn_runtime.afk_elapsed_seconds_by_role = {}
  end
  return turn_runtime
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
