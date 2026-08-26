local overlay = require("src.ui.render.anim.unit_overlay")
local move_anim = require("src.ui.render.move_anim")
local tip_text = require("src.ui.render.anim.tip_text")
local board_feedback = require("src.ui.render.board_feedback.service")
local unit_position = require("src.ui.render.support.unit_position")
local number_utils = require("src.foundation.number")
local timing = require("src.config.gameplay.timing")
local compute = require("src.ui.render.anim.overlay_compute")

local units = {}

local function _timing_or(value, fallback)
  if value ~= nil then
    return value
  end
  return fallback
end

local demolish_effect_followup_delay_seconds = _timing_or(timing.demolish_effect_followup_delay_seconds, 0.35)
local teleport_camera_hold_seconds = _timing_or(timing.teleport_effect_camera_hold_seconds, 1.0)
local roadblock_destroy_hold_seconds = _timing_or(timing.roadblock_destroy_hold_seconds, 0)
local _play_demolish_feedback

units.clear_overlay = overlay.clear_overlay

local function _pan_fn(opts)
  return opts and opts.pan_camera_to_position
end

local function _pan_to_position(state, tile_index, opts)
  if state == nil or tile_index == nil then return false end
  local pan_fn = _pan_fn(opts)
  if type(pan_fn) ~= "function" then return false end
  local pos = compute.resolve_tile_pos(state, tile_index)
  if pos == nil then return false end
  return pan_fn(state, pos) == true
end

local function _schedule_pan_release(state, release, duration, opts)
  local schedule = opts and opts.schedule
  if type(schedule) ~= "function" then
    release(state)
    return
  end
  local release_after = duration
  if not number_utils.is_numeric(release_after) or release_after < 0 then
    release_after = 0
  end
  schedule(release_after, function()
    release(state)
  end)
end

local function _pan_camera_to_tile(state, tile_index, duration, opts)
  if not _pan_to_position(state, tile_index, opts) then return end
  local release = opts and opts.release_target_pan
  if type(release) ~= "function" then return end
  _schedule_pan_release(state, release, duration, opts)
end

function units.play_overlay(state, anim, duration, opts)
  if anim and anim.kind == "roadblock" and anim.tile_index ~= nil then
    _pan_camera_to_tile(state, anim.tile_index, duration, opts)
  end
  overlay.play_overlay(state, anim, duration, opts)
end

local function _target_player_ids(anim)
  return anim and anim.target_player_ids or {}
end

local function _prepare_missile_targets(board_scene, anim)
  for _, player_id in ipairs(_target_player_ids(anim)) do
    move_anim.prepare_player_for_snap(board_scene, player_id, anim, "missile")
  end
end

local function _snap_missile_targets(board_scene, anim, to_index)
  for _, player_id in ipairs(_target_player_ids(anim)) do
    move_anim.snap_player_to_index(board_scene, player_id, to_index, anim, "play_sequence_missile_target")
  end
end

function units.play_missile(state, anim, duration, opts)
  local board_scene = assert(state.board_scene, "missing board_scene")
  local to_index = anim and anim.to_index or nil
  local tile_index = assert(anim.tile_index, "missing missile tile_index")
  _pan_camera_to_tile(state, tile_index, duration, opts)
  _prepare_missile_targets(board_scene, anim)
  _play_demolish_feedback(state, tile_index, opts, false)
  overlay.play_missile(state, anim, duration, opts)
  if to_index ~= nil then
    _snap_missile_targets(board_scene, anim, to_index)
  end
end

function units.play_monster(state, anim, duration, opts)
  local tile_index = assert(anim.tile_index, "missing monster tile_index")
  _pan_camera_to_tile(state, tile_index, duration, opts)
  _play_demolish_feedback(state, tile_index, opts, true)
end

function units.play_clear_obstacles(state, anim, duration, opts)
  if anim and anim.tile_index ~= nil then
    _pan_camera_to_tile(state, anim.tile_index, duration, opts)
  end
  overlay.play_clear_obstacles(state, anim, duration, opts)
end

function units.play_move_effect(state, anim)
  return move_anim.play_sequence(state.board_scene, anim)
end

local function _pan_camera_to_teleport_destination(state, anim, duration, opts)
  if anim == nil or anim.to_index == nil then
    return
  end
  local hold = duration
  if not number_utils.is_numeric(hold) or hold < teleport_camera_hold_seconds then
    hold = teleport_camera_hold_seconds
  end
  _pan_camera_to_tile(state, anim.to_index, hold, opts)
end

function units.play_teleport_effect(state, anim, duration, opts)
  _pan_camera_to_teleport_destination(state, anim, duration, opts)
  return move_anim.play_teleport(state.board_scene, anim)
end

units.play_forced_relocation = units.play_teleport_effect

local function _sanitize_delay(value)
  if not number_utils.is_numeric(value) or value < 0 then
    return 0
  end
  return value
end

local function _resolve_minimum_delay(delay, minimum_delay)
  local resolved_delay = _sanitize_delay(delay)
  local floor = _sanitize_delay(minimum_delay)
  if resolved_delay < floor then
    return floor
  end
  return resolved_delay
end

local function _resolve_mine_hit_position(board_scene, player_id, tile_index)
  local unit = board_scene.units_by_player_id and board_scene.units_by_player_id[player_id] or nil
  return unit_position.read_unit_position(unit) or unit_position.read_scene_tile_position(board_scene, tile_index)
end

local function _play_mine_feedback(state, anim, player_id, tile_index, hit_pos)
  local cue_name = anim and anim.cue_name or "mine_blast"
  if hit_pos ~= nil then
    board_feedback.play_player_cue(state, cue_name, player_id, { pos = hit_pos })
    return
  end
  board_feedback.play_tile_cue(state, cue_name, tile_index, {})
end

function _play_demolish_feedback(state, tile_index, opts, use_building_tile_position)
  board_feedback.play_tile_cue(state, "mine_blast", tile_index, {
    use_building_tile_position = use_building_tile_position == true,
  })
  local schedule = opts and opts.schedule or nil
  if type(schedule) == "function" and demolish_effect_followup_delay_seconds > 0 then
    schedule(demolish_effect_followup_delay_seconds, function()
      board_feedback.play_tile_cue(state, "upgrade_land_smoke", tile_index, {
        use_building_tile_position = use_building_tile_position == true,
      })
    end)
    return
  end
  board_feedback.play_tile_cue(state, "upgrade_land_smoke", tile_index, {
    use_building_tile_position = use_building_tile_position == true,
  })
end

local function _clear_mine_overlay(opts, state, tile_index)
  local clear_overlay = assert(opts and opts.clear_overlay, "missing clear_overlay")
  clear_overlay(state, "mine", tile_index)
end

local function _schedule_mine_trigger_snap(opts, state, board_scene, player_id, anim, to_index, snap_delay, schedule)
  -- #550:回调内同帧先销毁雷、再瞬移人,演出时长由 anim duration 承担
  schedule(snap_delay, function()
    _clear_mine_overlay(opts, state, anim.tile_index)
    move_anim.prepare_player_for_snap(board_scene, player_id, anim, "mine_trigger")
    return move_anim.snap_player_to_index(board_scene, player_id, to_index, anim, "play_sequence_mine_trigger")
  end)
end

function units.play_mine_trigger(state, anim, duration, opts)
  local board_scene = assert(state.board_scene, "missing board_scene")
  local player_id = assert(anim.player_id, "missing player_id")
  local tile_index = assert(anim.tile_index, "missing tile_index")
  local to_index = assert(anim.to_index, "missing to_index")
  local hit_pos = _resolve_mine_hit_position(board_scene, player_id, tile_index)

  local schedule = opts and opts.schedule or nil
  if type(schedule) == "function" then
    _play_mine_feedback(state, anim, player_id, tile_index, hit_pos)
    local snap_delay = _sanitize_delay(duration)
    _schedule_mine_trigger_snap(opts, state, board_scene, player_id, anim, to_index, snap_delay, schedule)
    return snap_delay
  end
  -- Fallback: no scheduler - 反馈立即播,随后同帧先销毁雷、再瞬移人(与回调同序)
  _play_mine_feedback(state, anim, player_id, tile_index, hit_pos)
  _clear_mine_overlay(opts, state, tile_index)
  move_anim.prepare_player_for_snap(board_scene, player_id, anim, "mine_trigger")
  local snap_delay = move_anim.snap_player_to_index(board_scene, player_id, to_index, anim, "play_sequence_mine_trigger")
  return _resolve_minimum_delay(snap_delay, duration)
end

local function _schedule_fn(opts)
  return opts and opts.schedule or nil
end

function units.play_roadblock_trigger(state, anim, duration, opts)
  local clear_overlay = assert(opts and opts.clear_overlay, "missing clear_overlay")
  local tile_index = assert(anim.tile_index, "missing tile_index")
  local schedule = _schedule_fn(opts)
  if type(schedule) == "function" and roadblock_destroy_hold_seconds > 0 then
    schedule(roadblock_destroy_hold_seconds, function()
      clear_overlay(state, "roadblock", tile_index)
    end)
    return _resolve_minimum_delay(roadblock_destroy_hold_seconds, duration)
  end
  clear_overlay(state, "roadblock", tile_index)
  return _resolve_minimum_delay(0, duration)
end

units.build_tip = tip_text.build

return units

--[[ mutate4lua-manifest
version=4
projectHash=f4d2c4bc6173958d
scope.0.id=chunk:src/ui/render/anim/units.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=237
scope.0.semanticHash=98d29824918f424e
scope.1.id=function:_timing_or
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=17
scope.1.semanticHash=5d2dbc03da2169ee
scope.2.id=function:_pan_fn
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=28
scope.2.semanticHash=ac1dbf12b688483f
scope.3.id=function:_pan_to_position
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=37
scope.3.semanticHash=75c24d2346afd9b3
scope.4.id=function:_schedule_pan_release
scope.4.kind=function
scope.4.startLine=39
scope.4.endLine=52
scope.4.semanticHash=04da53c4dc3fb9df
scope.5.id=function:<anonymous>
scope.5.kind=function
scope.5.startLine=49
scope.5.endLine=51
scope.5.semanticHash=600a75ce96a391b3
scope.6.id=function:_pan_camera_to_tile
scope.6.kind=function
scope.6.startLine=54
scope.6.endLine=59
scope.6.semanticHash=c1789d5d89c2a736
scope.7.id=function:units.play_overlay
scope.7.kind=function
scope.7.startLine=61
scope.7.endLine=66
scope.7.semanticHash=679e8d8b6652e584
scope.8.id=function:_target_player_ids
scope.8.kind=function
scope.8.startLine=68
scope.8.endLine=70
scope.8.semanticHash=80095546cf231a6e
scope.9.id=function:_prepare_missile_targets
scope.9.kind=function
scope.9.startLine=72
scope.9.endLine=76
scope.9.semanticHash=2b9101ae756dd7cc
scope.10.id=function:_snap_missile_targets
scope.10.kind=function
scope.10.startLine=78
scope.10.endLine=82
scope.10.semanticHash=c3b52f6ddd87216a
scope.11.id=function:units.play_missile
scope.11.kind=function
scope.11.startLine=84
scope.11.endLine=95
scope.11.semanticHash=860d924f381f9279
scope.12.id=function:units.play_monster
scope.12.kind=function
scope.12.startLine=97
scope.12.endLine=101
scope.12.semanticHash=d56d391ecc5cdb81
scope.13.id=function:units.play_clear_obstacles
scope.13.kind=function
scope.13.startLine=103
scope.13.endLine=108
scope.13.semanticHash=89ea7d361785fba3
scope.14.id=function:units.play_move_effect
scope.14.kind=function
scope.14.startLine=110
scope.14.endLine=112
scope.14.semanticHash=8628d913171643ea
scope.15.id=function:_pan_camera_to_teleport_destination
scope.15.kind=function
scope.15.startLine=114
scope.15.endLine=123
scope.15.semanticHash=7fd6bf797aa88e6a
scope.16.id=function:units.play_teleport_effect
scope.16.kind=function
scope.16.startLine=125
scope.16.endLine=128
scope.16.semanticHash=7e6835110040b1ce
scope.17.id=function:_sanitize_delay
scope.17.kind=function
scope.17.startLine=132
scope.17.endLine=137
scope.17.semanticHash=d988c7fda12ed118
scope.18.id=function:_resolve_minimum_delay
scope.18.kind=function
scope.18.startLine=139
scope.18.endLine=146
scope.18.semanticHash=0d9e0671ddfedbe0
scope.19.id=function:_resolve_mine_hit_position
scope.19.kind=function
scope.19.startLine=148
scope.19.endLine=151
scope.19.semanticHash=f3a7967a12d7985a
scope.20.id=function:_play_mine_feedback
scope.20.kind=function
scope.20.startLine=153
scope.20.endLine=160
scope.20.semanticHash=10c5d75a2d914d66
scope.21.id=function:_play_demolish_feedback
scope.21.kind=function
scope.21.startLine=162
scope.21.endLine=178
scope.21.semanticHash=69ae6e1239417476
scope.22.id=function:<anonymous>#2
scope.22.kind=function
scope.22.startLine=168
scope.22.endLine=172
scope.22.semanticHash=ec3af3c7d3b41157
scope.23.id=function:_clear_mine_overlay
scope.23.kind=function
scope.23.startLine=180
scope.23.endLine=183
scope.23.semanticHash=33acfbb695dc4ce5
scope.24.id=function:_schedule_mine_trigger_snap
scope.24.kind=function
scope.24.startLine=185
scope.24.endLine=192
scope.24.semanticHash=c335564da2c9a4d4
scope.25.id=function:<anonymous>#3
scope.25.kind=function
scope.25.startLine=187
scope.25.endLine=191
scope.25.semanticHash=bee18fd3a9517860
scope.26.id=function:units.play_mine_trigger
scope.26.kind=function
scope.26.startLine=194
scope.26.endLine=214
scope.26.semanticHash=d4aeea5ef2a7ad51
scope.27.id=function:_schedule_fn
scope.27.kind=function
scope.27.startLine=216
scope.27.endLine=218
scope.27.semanticHash=616a2ca60599c94f
scope.28.id=function:units.play_roadblock_trigger
scope.28.kind=function
scope.28.startLine=220
scope.28.endLine=232
scope.28.semanticHash=478bd3f1e5e227a0
scope.29.id=function:<anonymous>#4
scope.29.kind=function
scope.29.startLine=225
scope.29.endLine=227
scope.29.semanticHash=f6c5cfa014c7336c
]]
