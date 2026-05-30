local logger = require("src.foundation.log")
local dirty_tracker = require("src.state.dirty_tracker")

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
      deferred_dirty = dirty_tracker.new(),
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

local function _ui_getter(field)
  return function(state)
    return runtime_state.ensure_ui_runtime(state)[field]
  end
end

local function _ui_setter(field)
  return function(state, value)
    local ui_runtime = runtime_state.ensure_ui_runtime(state)
    ui_runtime[field] = value
    return value
  end
end

function runtime_state.is_ui_dirty(state)
  return runtime_state.ensure_ui_runtime(state).ui_dirty == true
end

function runtime_state.set_ui_dirty(state, dirty)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  ui_runtime.ui_dirty = dirty == true
  return ui_runtime.ui_dirty
end

runtime_state.get_ui_model = _ui_getter("ui_model")
runtime_state.set_ui_model = _ui_setter("ui_model")
runtime_state.get_local_actor_role_id = _ui_getter("local_actor_role_id")
runtime_state.set_local_actor_role_id = _ui_setter("local_actor_role_id")
runtime_state.get_pending_choice = _ui_getter("pending_choice")
runtime_state.get_pending_choice_id = _ui_getter("pending_choice_id")
runtime_state.set_pending_choice_id = _ui_setter("pending_choice_id")

runtime_state.get_pending_choice_elapsed = _ui_getter("pending_choice_elapsed")

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

runtime_state.get_modal_elapsed = _ui_getter("ui_modal_elapsed")

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
  if board_runtime.follow_targets == nil then
    board_runtime.follow_targets = {}
  end
  _ensure_field(board_runtime, "board_sync_pending", state.board_sync_pending == true)
  _ensure_field(board_runtime, "board_last_phase", state.board_last_phase)
  return board_runtime
end

function runtime_state.set_follow_target_position(state, player_id, position, opts)
  if state == nil or player_id == nil or position == nil then
    return false
  end
  local board_runtime = runtime_state.ensure_board_runtime(state)
  opts = opts or {}
  local next_seq = opts.seq
  local entry = board_runtime.follow_targets[player_id]
  local last_seq = entry and entry.seq
  if next_seq ~= nil and last_seq ~= nil and next_seq < last_seq then
    return false
  end
  if entry == nil then
    entry = {}
    board_runtime.follow_targets[player_id] = entry
  end
  entry.position = position
  entry.source = opts.source
  entry.seq = next_seq ~= nil and next_seq or entry.seq
  return true
end

function runtime_state.get_follow_target_position(state, player_id)
  if state == nil or player_id == nil then
    return nil
  end
  local board_runtime = runtime_state.ensure_board_runtime(state)
  local entry = board_runtime.follow_targets[player_id]
  return entry and entry.position or nil
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

local function _get_landing_visual_hold(state)
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  return _ensure_landing_visual_hold(turn_runtime)
end

local function _hold_bool_getter(field)
  return function(state)
    return _get_landing_visual_hold(state)[field] == true
  end
end

local function _hold_bool_setter(field)
  return function(state, value)
    local hold = _get_landing_visual_hold(state)
    hold[field] = value == true
    return hold[field]
  end
end

runtime_state.get_landing_visual_hold_active = _hold_bool_getter("active")
runtime_state.set_landing_visual_hold_active = _hold_bool_setter("active")
runtime_state.get_landing_visual_release_pending = _hold_bool_getter("release_pending")
runtime_state.set_landing_visual_release_pending = _hold_bool_setter("release_pending")

function runtime_state.get_landing_visual_hold_source(state)
  return _get_landing_visual_hold(state).source
end

function runtime_state.set_landing_visual_hold_source(state, source)
  _get_landing_visual_hold(state).source = source
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

function runtime_state.log_once(state, level, key, ...)
  local debug_runtime = runtime_state.ensure_debug_runtime(state)
  return logger.log_once(debug_runtime.log_once, level, key, ...)
end

function runtime_state.ensure_deadlines(state)
  assert(type(state) == "table", "missing state")
  local deadlines = _ensure_table(state, "deadlines")
  if deadlines.active == nil then
    deadlines.active = {}
  end
  return deadlines
end

function runtime_state.ensure_all(state)
  runtime_state.ensure_ui_runtime(state)
  runtime_state.ensure_board_runtime(state)
  runtime_state.ensure_anim_runtime(state)
  runtime_state.ensure_turn_runtime(state)
  runtime_state.ensure_debug_runtime(state)
  runtime_state.ensure_deadlines(state)
  return state
end

return runtime_state

--[[ mutate4lua-manifest
version=2
projectHash=d862b0ee5a1cc623
scope.0.id=chunk:src/state/runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=277
scope.0.semanticHash=92480e894b3ee1b8
scope.1.id=function:_ensure_table:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=13
scope.1.semanticHash=34ec0d5ec76ecad4
scope.2.id=function:_ensure_field:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=20
scope.2.semanticHash=f94c60173b15314e
scope.3.id=function:_ensure_landing_visual_hold:22
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=37
scope.3.semanticHash=776e464b7ff97ad6
scope.4.id=function:runtime_state.ensure_ui_runtime:39
scope.4.kind=function
scope.4.startLine=39
scope.4.endLine=53
scope.4.semanticHash=787ec474ee86ff18
scope.5.id=function:anonymous@56:56
scope.5.kind=function
scope.5.startLine=56
scope.5.endLine=58
scope.5.semanticHash=541ec51aa47c26b8
scope.6.id=function:_ui_getter:55
scope.6.kind=function
scope.6.startLine=55
scope.6.endLine=59
scope.6.semanticHash=9bb5948ddb9c710d
scope.7.id=function:anonymous@62:62
scope.7.kind=function
scope.7.startLine=62
scope.7.endLine=66
scope.7.semanticHash=51962c2d03353c04
scope.8.id=function:_ui_setter:61
scope.8.kind=function
scope.8.startLine=61
scope.8.endLine=67
scope.8.semanticHash=c53d6d1aa3ab3bad
scope.9.id=function:runtime_state.is_ui_dirty:69
scope.9.kind=function
scope.9.startLine=69
scope.9.endLine=71
scope.9.semanticHash=2fee32b560761339
scope.10.id=function:runtime_state.set_ui_dirty:73
scope.10.kind=function
scope.10.startLine=73
scope.10.endLine=77
scope.10.semanticHash=773c4f073374fb10
scope.11.id=function:runtime_state.set_pending_choice_elapsed:89
scope.11.kind=function
scope.11.startLine=89
scope.11.endLine=94
scope.11.semanticHash=80a3297e16ccd75f
scope.12.id=function:runtime_state.set_pending_choice:96
scope.12.kind=function
scope.12.startLine=96
scope.12.endLine=111
scope.12.semanticHash=fa047b10b42d6f9f
scope.13.id=function:runtime_state.get_modal_ref:115
scope.13.kind=function
scope.13.startLine=115
scope.13.endLine=118
scope.13.semanticHash=f684517a33660ffe
scope.14.id=function:runtime_state.set_modal_timer:120
scope.14.kind=function
scope.14.startLine=120
scope.14.endLine=128
scope.14.semanticHash=67ec824af9801fbb
scope.15.id=function:runtime_state.ensure_board_runtime:130
scope.15.kind=function
scope.15.startLine=130
scope.15.endLine=142
scope.15.semanticHash=19c29390fbf84211
scope.16.id=function:runtime_state.set_follow_target_position:144
scope.16.kind=function
scope.16.startLine=144
scope.16.endLine=164
scope.16.semanticHash=7f84403d2a43a9b0
scope.17.id=function:runtime_state.get_follow_target_position:166
scope.17.kind=function
scope.17.startLine=166
scope.17.endLine=173
scope.17.semanticHash=2b3e322f6b88a93b
scope.18.id=function:runtime_state.ensure_anim_runtime:175
scope.18.kind=function
scope.18.startLine=175
scope.18.endLine=181
scope.18.semanticHash=e28d0d5673ae3b9d
scope.19.id=function:runtime_state.ensure_turn_runtime:183
scope.19.kind=function
scope.19.startLine=183
scope.19.endLine=195
scope.19.semanticHash=251dbed54c8c7cf1
scope.20.id=function:_get_landing_visual_hold:197
scope.20.kind=function
scope.20.startLine=197
scope.20.endLine=200
scope.20.semanticHash=f637fb7b364f63f8
scope.21.id=function:anonymous@203:203
scope.21.kind=function
scope.21.startLine=203
scope.21.endLine=205
scope.21.semanticHash=e6499e47dc9c2d02
scope.22.id=function:_hold_bool_getter:202
scope.22.kind=function
scope.22.startLine=202
scope.22.endLine=206
scope.22.semanticHash=08f8804607002e93
scope.23.id=function:anonymous@209:209
scope.23.kind=function
scope.23.startLine=209
scope.23.endLine=213
scope.23.semanticHash=4a47445f88a0e5d8
scope.24.id=function:_hold_bool_setter:208
scope.24.kind=function
scope.24.startLine=208
scope.24.endLine=214
scope.24.semanticHash=b177ca3fa4359051
scope.25.id=function:runtime_state.get_landing_visual_hold_source:221
scope.25.kind=function
scope.25.startLine=221
scope.25.endLine=223
scope.25.semanticHash=ceda1d01d1dd37f6
scope.26.id=function:runtime_state.set_landing_visual_hold_source:225
scope.26.kind=function
scope.26.startLine=225
scope.26.endLine=228
scope.26.semanticHash=d8fc4f6460a276b4
scope.27.id=function:runtime_state.mark_landing_visual_release_pulse:230
scope.27.kind=function
scope.27.startLine=230
scope.27.endLine=234
scope.27.semanticHash=711ebd4b7eb10844
scope.28.id=function:runtime_state.take_landing_visual_release_pulse:236
scope.28.kind=function
scope.28.startLine=236
scope.28.endLine=241
scope.28.semanticHash=90d6eba93d59b929
scope.29.id=function:runtime_state.ensure_debug_runtime:243
scope.29.kind=function
scope.29.startLine=243
scope.29.endLine=250
scope.29.semanticHash=21b2f26e118ee171
scope.30.id=function:runtime_state.log_once:252
scope.30.kind=function
scope.30.startLine=252
scope.30.endLine=255
scope.30.semanticHash=f7249bd083d6609c
scope.31.id=function:runtime_state.ensure_deadlines:257
scope.31.kind=function
scope.31.startLine=257
scope.31.endLine=264
scope.31.semanticHash=8da15394e63bc5e4
scope.32.id=function:runtime_state.ensure_all:266
scope.32.kind=function
scope.32.startLine=266
scope.32.endLine=274
scope.32.semanticHash=10686a5fbb9495c2
]]
