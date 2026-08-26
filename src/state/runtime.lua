local logger = require("src.foundation.log")
local tables = require("src.foundation.tables")
local dirty_tracker = require("src.state.dirty_tracker")
local ui_runtime = require("src.state.ui_runtime")
local board_runtime = require("src.state.board_runtime")

local runtime_state = {}

-- ui_runtime / board_runtime 切片已拆到同名子模块,这里保持原公共面不变。
runtime_state.ensure_ui_runtime = ui_runtime.ensure
runtime_state.is_ui_dirty = ui_runtime.is_ui_dirty
runtime_state.set_ui_dirty = ui_runtime.set_ui_dirty
runtime_state.get_ui_model = ui_runtime.get_ui_model
runtime_state.set_ui_model = ui_runtime.set_ui_model
runtime_state.get_pending_choice = ui_runtime.get_pending_choice
runtime_state.get_pending_choice_id = ui_runtime.get_pending_choice_id
runtime_state.set_pending_choice_id = ui_runtime.set_pending_choice_id
runtime_state.get_pending_choice_elapsed = ui_runtime.get_pending_choice_elapsed
runtime_state.set_pending_choice_elapsed = ui_runtime.set_pending_choice_elapsed
runtime_state.set_pending_choice = ui_runtime.set_pending_choice
runtime_state.get_modal_elapsed = ui_runtime.get_modal_elapsed
runtime_state.get_modal_ref = ui_runtime.get_modal_ref
runtime_state.set_modal_timer = ui_runtime.set_modal_timer

runtime_state.ensure_board_runtime = board_runtime.ensure
runtime_state.set_follow_target_position = board_runtime.set_follow_target_position
runtime_state.get_follow_target_position = board_runtime.get_follow_target_position

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

function runtime_state.ensure_anim_runtime(state)
  assert(type(state) == "table", "missing state")
  local anim_runtime = tables.ensure_table_field(state, "anim_runtime")
  tables.ensure_field(anim_runtime, "move_anim_seq", state.move_anim_seq)
  tables.ensure_field(anim_runtime, "action_anim_seq", state.action_anim_seq)
  return anim_runtime
end

function runtime_state.ensure_turn_runtime(state)
  assert(type(state) == "table", "missing state")
  local turn_runtime = tables.ensure_table_field(state, "turn_runtime")
  tables.ensure_field(turn_runtime, "next_turn_locked", state.next_turn_locked == true)
  tables.ensure_field(turn_runtime, "next_turn_last_click", state.next_turn_last_click)
  tables.ensure_field(turn_runtime, "next_turn_lock_phase", state.next_turn_lock_phase)
  tables.ensure_field(turn_runtime, "role_control_lock_active", state.role_control_lock_active == true)
  tables.ensure_field(turn_runtime, "role_control_lock_suppress", state.role_control_lock_suppress or 0)
  tables.ensure_field(turn_runtime, "landing_visual_release_pulse", false)
  tables.ensure_field(turn_runtime, "last_follow_player_id", nil)
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
  local debug_runtime = tables.ensure_table_field(state, "debug_runtime")
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
  local deadlines = tables.ensure_table_field(state, "deadlines")
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
version=4
projectHash=29217b511b5e2125
scope.0.id=chunk:src/state/runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=148
scope.0.semanticHash=03b2eafff014f5be
scope.1.id=function:_ensure_landing_visual_hold
scope.1.kind=function
scope.1.startLine=29
scope.1.endLine=44
scope.1.semanticHash=3b2f4da7d1eba23a
scope.2.id=function:runtime_state.ensure_anim_runtime
scope.2.kind=function
scope.2.startLine=46
scope.2.endLine=52
scope.2.semanticHash=1b8a54b758ef3e61
scope.3.id=function:runtime_state.ensure_turn_runtime
scope.3.kind=function
scope.3.startLine=54
scope.3.endLine=66
scope.3.semanticHash=74f466cd58ed28bc
scope.4.id=function:_get_landing_visual_hold
scope.4.kind=function
scope.4.startLine=68
scope.4.endLine=71
scope.4.semanticHash=08df5d5f955d8979
scope.5.id=function:_hold_bool_getter
scope.5.kind=function
scope.5.startLine=73
scope.5.endLine=77
scope.5.semanticHash=5ff72868f0dfc83e
scope.6.id=function:<anonymous>
scope.6.kind=function
scope.6.startLine=74
scope.6.endLine=76
scope.6.semanticHash=7e6539c509e8e469
scope.7.id=function:_hold_bool_setter
scope.7.kind=function
scope.7.startLine=79
scope.7.endLine=85
scope.7.semanticHash=818b53f7f379e930
scope.8.id=function:<anonymous>#2
scope.8.kind=function
scope.8.startLine=80
scope.8.endLine=84
scope.8.semanticHash=d6b70f792e0c0f8f
scope.9.id=function:runtime_state.get_landing_visual_hold_source
scope.9.kind=function
scope.9.startLine=92
scope.9.endLine=94
scope.9.semanticHash=126ac33559a2e692
scope.10.id=function:runtime_state.set_landing_visual_hold_source
scope.10.kind=function
scope.10.startLine=96
scope.10.endLine=99
scope.10.semanticHash=510161066988c1a2
scope.11.id=function:runtime_state.mark_landing_visual_release_pulse
scope.11.kind=function
scope.11.startLine=101
scope.11.endLine=105
scope.11.semanticHash=06292c4ebc1ad0e9
scope.12.id=function:runtime_state.take_landing_visual_release_pulse
scope.12.kind=function
scope.12.startLine=107
scope.12.endLine=112
scope.12.semanticHash=df2d0f5994ffc056
scope.13.id=function:runtime_state.ensure_debug_runtime
scope.13.kind=function
scope.13.startLine=114
scope.13.endLine=121
scope.13.semanticHash=f951198e9d6fcb31
scope.14.id=function:runtime_state.log_once
scope.14.kind=function
scope.14.startLine=123
scope.14.endLine=126
scope.14.semanticHash=9e60dca22aca9e78
scope.15.id=function:runtime_state.ensure_deadlines
scope.15.kind=function
scope.15.startLine=128
scope.15.endLine=135
scope.15.semanticHash=cf1d3d0cb10d3fb3
scope.16.id=function:runtime_state.ensure_all
scope.16.kind=function
scope.16.startLine=137
scope.16.endLine=145
scope.16.semanticHash=d423766b64ec5aab
]]
