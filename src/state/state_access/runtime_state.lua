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
  if type(turn_runtime.landing_visual_hold) ~= "table" then
    turn_runtime.landing_visual_hold = {
      active = false,
      release_pending = false,
      flushing = false,
      frozen_ui_model = nil,
      deferred_dirty = {
        any = false,
        players = false,
        board_tiles = false,
        turn = false,
        market = false,
        turn_countdown = false,
        inventory_ids = {},
      },
      deferred_popups = {},
      deferred_runtime_events = {},
      deferred_board_visual_syncs = {},
      deferred_tile_updates = {},
      deferred_owner_changes = {},
      deferred_bankruptcy_clears = {},
    }
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
